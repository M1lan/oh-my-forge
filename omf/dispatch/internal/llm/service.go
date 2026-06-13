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
)

const (
	DefaultLlamaSwapURL = "http://127.0.0.1:8080"
	DefaultOllamaURL    = "http://127.0.0.1:11434"
	DefaultMaxGiB       = 14
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

type Config struct {
	LlamaSwapURL string
	OllamaURL    string
	HTTPClient   *http.Client
	BudgetsGiB   map[string]uint64
	MaxGiB       uint64
}

type Client struct {
	llamaSwapURL string
	ollamaURL    string
	httpClient   *http.Client
	budgetsGiB   map[string]uint64
	maxGiB       uint64
}

func NewClient(cfg Config) *Client {
	client := cfg.HTTPClient
	if client == nil {
		client = http.DefaultClient
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
	if err := c.checkBudget(model); err != nil {
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

func (c *Client) checkBudget(model string) error {
	budget, ok := c.budgetsGiB[model]
	if !ok || budget <= c.maxGiB {
		return nil
	}
	return BudgetError{Model: model, BudgetGiB: budget, MaxGiB: c.maxGiB}
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
