package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"omf/dispatch/internal/omfcore"
)

const (
	DefaultLlamaSwapURL = "http://127.0.0.1:8080"
	DefaultOllamaURL    = "http://127.0.0.1:11434"
	DefaultMaxGiB       = 14
	DefaultHTTPTimeout  = 30 * time.Second
)

type Source string

const (
	SourceLlamaSwap Source = "llama-swap"
	SourceOllama    Source = "ollama"
	SourceBoth      Source = "llama-swap+ollama"
)

type Model struct {
	Name      string
	Source    Source
	SizeBytes uint64
}

// Guard is the optional admission gate satisfied by *omfcore.Client. When set,
// Load asks the compiled omf-core floor to re-admit the model's footprint and
// confirms the single-flight runtime lock is free before warming a model. It is
// defense in depth: checkBudgetGiB already screens known sizes in-process, but
// the compiled floor is the authoritative budget and the only holder of the
// cross-process lock.
type Guard interface {
	GuardAdmit(ctx context.Context, peakGiB, budgetGiB uint64, isMLX bool) error
	GuardLockFree(ctx context.Context, path string) (bool, error)
}

type Config struct {
	LlamaSwapURL string
	OllamaURL    string
	HTTPClient   *http.Client
	BudgetsGiB   map[string]uint64
	MaxGiB       uint64
	Guard        Guard
}

type Client struct {
	llamaSwapURL string
	ollamaURL    string
	httpClient   *http.Client
	budgetsGiB   map[string]uint64
	maxGiB       uint64
	guard        Guard
}

func NewClient(cfg Config) *Client {
	client := cfg.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: DefaultHTTPTimeout}
	}
	limits := cfg.BudgetsGiB
	if limits == nil {
		limits = map[string]uint64{}
	}
	maxGiB := cfg.MaxGiB
	if maxGiB == 0 {
		maxGiB = DefaultMaxGiB
	}
	return &Client{
		llamaSwapURL: normalizeURL(cfg.LlamaSwapURL, DefaultLlamaSwapURL),
		ollamaURL:    normalizeURL(cfg.OllamaURL, DefaultOllamaURL),
		httpClient:   client,
		budgetsGiB:   limits,
		maxGiB:       maxGiB,
		guard:        cfg.Guard,
	}
}

func (c *Client) List(ctx context.Context) ([]Model, error) {
	llamaModels, err := c.listLlamaSwap(ctx)
	if err != nil {
		return nil, err
	}
	ollamaModels, err := c.listOllama(ctx)
	if err != nil {
		return nil, err
	}

	byName := make(map[string]int)
	models := make([]Model, 0, len(llamaModels)+len(ollamaModels))
	for _, model := range llamaModels {
		model.Source = SourceLlamaSwap
		byName[model.Name] = len(models)
		models = append(models, model)
	}
	for _, model := range ollamaModels {
		if idx, ok := byName[model.Name]; ok {
			models[idx].Source = SourceBoth
			if models[idx].SizeBytes == 0 {
				models[idx].SizeBytes = model.SizeBytes
			}
			continue
		}
		model.Source = SourceOllama
		byName[model.Name] = len(models)
		models = append(models, model)
	}
	return models, nil
}

func (c *Client) Load(ctx context.Context, model string) error {
	peakGiB, known, err := c.modelGiB(ctx, model)
	if err != nil {
		return err
	}
	if known {
		if err := c.checkBudgetGiB(model, peakGiB); err != nil {
			return err
		}
	}
	if err := c.guardAdmit(ctx, peakGiB, known); err != nil {
		return err
	}
	body := map[string]any{
		"model": model,
		"messages": []map[string]string{{
			"role":    "user",
			"content": "omf load warmup",
		}},
		"max_tokens": 1,
		"stream":     false,
	}
	return c.postJSON(ctx, c.llamaSwapURL+"/v1/chat/completions", body, nil)
}

func (c *Client) Unload(ctx context.Context, model string) error {
	return c.postJSON(ctx, c.llamaSwapURL+"/api/models/unload", map[string]string{"model": model}, nil)
}

type BudgetError struct {
	Model     string
	BudgetGiB uint64
	MaxGiB    uint64
}

func (e BudgetError) Error() string {
	return fmt.Sprintf("model %q budget %d GiB exceeds max %d GiB", e.Model, e.BudgetGiB, e.MaxGiB)
}

func IsBudgetError(err error) bool {
	var budget BudgetError
	return errors.As(err, &budget)
}

// ErrLoadInFlight is returned when another model load holds the single-flight
// runtime lock, so this load must not race it for VRAM.
var ErrLoadInFlight = errors.New("another model load is in flight")

// modelGiB resolves a model's GiB footprint: an explicit budget first, then the
// discovered ollama size. known=false means neither source knew the size, in
// which case no budget or admission check can be made (proceed unguarded).
func (c *Client) modelGiB(ctx context.Context, model string) (uint64, bool, error) {
	if budget, ok := c.budgetsGiB[model]; ok {
		return budget, true, nil
	}
	models, err := c.List(ctx)
	if err != nil {
		return 0, false, err
	}
	for _, discovered := range models {
		if discovered.Name == model && discovered.SizeBytes != 0 {
			return bytesToGiBCeil(discovered.SizeBytes), true, nil
		}
	}
	return 0, false, nil
}

// guardAdmit runs the compiled omf-core floor before a warmup: it confirms the
// single-flight lock is free, then re-admits the footprint against the budget.
// A nil guard or unknown size skips it. A vanished binary (ErrUnavailable) is
// treated as skip rather than a hard block, since app.go only wires the guard
// when omf-core was located -- a mid-flight disappearance should not wedge the
// load. ErrRefused (over budget) and a held lock DO block.
func (c *Client) guardAdmit(ctx context.Context, peakGiB uint64, known bool) error {
	if c.guard == nil || !known {
		return nil
	}
	free, err := c.guard.GuardLockFree(ctx, "")
	if err != nil {
		if errors.Is(err, omfcore.ErrUnavailable) {
			return nil
		}
		return err
	}
	if !free {
		return ErrLoadInFlight
	}
	if err := c.guard.GuardAdmit(ctx, peakGiB, c.maxGiB, false); err != nil {
		if errors.Is(err, omfcore.ErrUnavailable) {
			return nil
		}
		return err
	}
	return nil
}

func (c *Client) checkBudgetGiB(model string, budget uint64) error {
	if budget <= c.maxGiB {
		return nil
	}
	return BudgetError{Model: model, BudgetGiB: budget, MaxGiB: c.maxGiB}
}

func bytesToGiBCeil(size uint64) uint64 {
	const gib = 1 << 30
	return (size + gib - 1) / gib
}

func (c *Client) listLlamaSwap(ctx context.Context) ([]Model, error) {
	var payload struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := c.getJSON(ctx, c.llamaSwapURL+"/v1/models", &payload); err != nil {
		return nil, fmt.Errorf("list llama-swap models: %w", err)
	}
	models := make([]Model, 0, len(payload.Data))
	for _, item := range payload.Data {
		if item.ID == "" {
			continue
		}
		models = append(models, Model{Name: item.ID})
	}
	return models, nil
}

func (c *Client) listOllama(ctx context.Context) ([]Model, error) {
	var payload struct {
		Models []struct {
			Name string `json:"name"`
			Size uint64 `json:"size"`
		} `json:"models"`
	}
	if err := c.getJSON(ctx, c.ollamaURL+"/api/tags", &payload); err != nil {
		return nil, fmt.Errorf("list ollama models: %w", err)
	}
	models := make([]Model, 0, len(payload.Models))
	for _, item := range payload.Models {
		if item.Name == "" {
			continue
		}
		models = append(models, Model{Name: item.Name, SizeBytes: item.Size})
	}
	return models, nil
}

func (c *Client) getJSON(ctx context.Context, url string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if err := checkStatus(resp); err != nil {
		return err
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func (c *Client) postJSON(ctx context.Context, url string, in any, out any) error {
	data, err := json.Marshal(in)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if err := checkStatus(resp); err != nil {
		return err
	}
	if out == nil {
		_, _ = io.Copy(io.Discard, resp.Body)
		return nil
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func checkStatus(resp *http.Response) error {
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
	return fmt.Errorf("%s: %s", resp.Status, strings.TrimSpace(string(body)))
}

func normalizeURL(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		value = fallback
	}
	return strings.TrimRight(value, "/")
}
