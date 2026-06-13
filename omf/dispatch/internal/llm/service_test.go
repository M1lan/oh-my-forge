package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestListMergesLlamaSwapAndOllamaModels(t *testing.T) {
	client := NewClient(Config{LlamaSwapURL: "http://llama", OllamaURL: "http://ollama", HTTPClient: fakeHTTP(t, map[string]string{
		"GET http://llama/v1/models": `{"data":[{"id":"/Users/milan.santosi/qwen36-mlx"},{"id":"qwen3-coder:latest"}]}`,
		"GET http://ollama/api/tags": `{"models":[{"name":"qwen3-coder:latest","size":9000000000},{"name":"nomic-embed-text:latest","size":274000000}]}`,
	})})

	models, err := client.List(context.Background())
	if err != nil {
		t.Fatalf("List returned error: %v", err)
	}
	if len(models) != 3 {
		t.Fatalf("models len = %d, want 3: %#v", len(models), models)
	}
	assertModel(t, models, "/Users/milan.santosi/qwen36-mlx", SourceLlamaSwap)
	assertModel(t, models, "qwen3-coder:latest", SourceBoth)
	assertModel(t, models, "nomic-embed-text:latest", SourceOllama)
}

func TestLoadCallsLlamaSwapChatCompletionEndpoint(t *testing.T) {
	transport := recordingTransport{responses: map[string]string{
		"POST http://llama/v1/chat/completions": `{"id":"warmup","choices":[]}`,
	}}
	client := NewClient(Config{LlamaSwapURL: "http://llama", HTTPClient: &http.Client{Transport: &transport}, BudgetsGiB: map[string]uint64{"qwen3-coder:latest": 9}, MaxGiB: 14})
	if err := client.Load(context.Background(), "qwen3-coder:latest"); err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if len(transport.calls) != 1 || transport.calls[0] != "POST http://llama/v1/chat/completions" {
		t.Fatalf("calls = %#v", transport.calls)
	}
	if !strings.Contains(transport.bodies[0], `"model":"qwen3-coder:latest"`) {
		t.Fatalf("load body did not target model: %s", transport.bodies[0])
	}
}

func TestUnloadCallsLlamaSwapUnloadEndpoint(t *testing.T) {
	transport := recordingTransport{responses: map[string]string{
		"POST http://llama/api/models/unload": `{"status":"ok"}`,
	}}
	client := NewClient(Config{LlamaSwapURL: "http://llama", HTTPClient: &http.Client{Transport: &transport}})
	if err := client.Unload(context.Background(), "qwen3-coder:latest"); err != nil {
		t.Fatalf("Unload returned error: %v", err)
	}
	if len(transport.calls) != 1 || transport.calls[0] != "POST http://llama/api/models/unload" {
		t.Fatalf("calls = %#v", transport.calls)
	}
	if !strings.Contains(transport.bodies[0], `"model":"qwen3-coder:latest"`) {
		t.Fatalf("unload body did not target model: %s", transport.bodies[0])
	}
}

func TestLoadRejectsOverBudgetBeforeHTTP(t *testing.T) {
	transport := recordingTransport{responses: map[string]string{}}
	client := NewClient(Config{LlamaSwapURL: "http://llama", HTTPClient: &http.Client{Transport: &transport}, BudgetsGiB: map[string]uint64{"huge": 99}, MaxGiB: 14})
	err := client.Load(context.Background(), "huge")
	if err == nil {
		t.Fatal("Load accepted over-budget model")
	}
	if !IsBudgetError(err) {
		t.Fatalf("err = %T %[1]v, want budget error", err)
	}
	if len(transport.calls) != 0 {
		t.Fatalf("over-budget load made HTTP calls: %#v", transport.calls)
	}
}

func TestLoadAdmitsFitsModel(t *testing.T) {
	transport := recordingTransport{responses: map[string]string{
		"POST http://llama/v1/chat/completions": `{"id":"warmup","choices":[]}`,
	}}
	client := NewClient(Config{LlamaSwapURL: "http://llama", HTTPClient: &http.Client{Transport: &transport}, BudgetsGiB: map[string]uint64{"fits": 13}, MaxGiB: 14})
	if err := client.Load(context.Background(), "fits"); err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
}

func assertModel(t *testing.T, models []Model, name string, source Source) {
	t.Helper()
	for _, model := range models {
		if model.Name == name {
			if model.Source != source {
				t.Fatalf("model %q source = %s, want %s", name, model.Source, source)
			}
			return
		}
	}
	t.Fatalf("model %q missing from %#v", name, models)
}

func fakeHTTP(t *testing.T, responses map[string]string) *http.Client {
	t.Helper()
	return &http.Client{Transport: &recordingTransport{responses: responses}}
}

type recordingTransport struct {
	responses map[string]string
	calls     []string
	bodies    []string
}

func (r *recordingTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	key := req.Method + " " + req.URL.String()
	r.calls = append(r.calls, key)
	if req.Body != nil {
		body, _ := io.ReadAll(req.Body)
		r.bodies = append(r.bodies, string(body))
	}
	payload, ok := r.responses[key]
	if !ok {
		payload = `{"error":"unexpected request"}`
		return &http.Response{StatusCode: http.StatusNotFound, Body: io.NopCloser(strings.NewReader(payload)), Header: make(http.Header)}, nil
	}
	if !json.Valid([]byte(payload)) {
		panic("test response must be json")
	}
	return &http.Response{StatusCode: http.StatusOK, Body: io.NopCloser(strings.NewReader(payload)), Header: make(http.Header)}, nil
}
