package mlx

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestInspectAdoptsExistingSafeWrapperAndLlamaSwapEntry(t *testing.T) {
	manager := Manager{
		WrapperPath:         DefaultWrapperPath,
		LlamaSwapConfigPath: "llama-swap.yaml",
		ReadFile: fakeReadFile(map[string]string{
			DefaultWrapperPath: safeWrapperFixture,
			"llama-swap.yaml":  safeLlamaSwapFixture,
		}),
	}
	report, err := manager.Inspect(context.Background(), "qwen36-mlx")
	if err != nil {
		t.Fatalf("Inspect returned error: %v", err)
	}
	if report.WrapperPath != DefaultWrapperPath {
		t.Fatalf("wrapper path = %q", report.WrapperPath)
	}
	if report.ModelID != DefaultModelID {
		t.Fatalf("model id = %q, want %q", report.ModelID, DefaultModelID)
	}
	if report.Caps != (Caps{WiredGiB: 14, MemoryGiB: 18, CacheGiB: 2}) {
		t.Fatalf("caps = %#v", report.Caps)
	}
	if !report.UsesWrapper || !report.GroupSwap || !report.GroupExclusive || !report.GroupMember {
		t.Fatalf("llama-swap adoption flags = %#v", report)
	}
	if report.PromptCacheBytes > 2<<30 {
		t.Fatalf("prompt cache bytes = %d, want <= 2GiB", report.PromptCacheBytes)
	}
}

func TestInspectRejectsRawMLXServerOrProcessSuspension(t *testing.T) {
	manager := Manager{
		WrapperPath:         DefaultWrapperPath,
		LlamaSwapConfigPath: "llama-swap.yaml",
		ReadFile: fakeReadFile(map[string]string{
			DefaultWrapperPath: DefaultWrapperPath,
			"llama-swap.yaml":  strings.ReplaceAll(safeLlamaSwapFixture, "${mlx-server}", "python -m mlx_lm.server && kill -STOP 123"),
		}),
	}
	_, err := manager.Inspect(context.Background(), "qwen36-mlx")
	if err == nil {
		t.Fatal("Inspect accepted raw mlx_lm.server/process suspension")
	}
	if !IsDriftError(err) {
		t.Fatalf("err = %T %[1]v, want drift error", err)
	}
}

func TestLoadUsesLlamaSwapClientAfterInspectingExistingWrapper(t *testing.T) {
	fake := &fakeLLM{}
	manager := Manager{
		WrapperPath:         DefaultWrapperPath,
		LlamaSwapConfigPath: "llama-swap.yaml",
		ReadFile: fakeReadFile(map[string]string{
			DefaultWrapperPath: safeWrapperFixture,
			"llama-swap.yaml":  safeLlamaSwapFixture,
		}),
		LLM: fake,
	}
	report, err := manager.Load(context.Background(), "qwen36-mlx")
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if report.ModelID != DefaultModelID {
		t.Fatalf("model id = %q", report.ModelID)
	}
	if len(fake.loads) != 1 || fake.loads[0] != DefaultModelID {
		t.Fatalf("loads = %#v, want [%q]", fake.loads, DefaultModelID)
	}
}

func fakeReadFile(files map[string]string) func(string) ([]byte, error) {
	return func(path string) ([]byte, error) {
		txt, ok := files[path]
		if !ok {
			return nil, errors.New("missing fixture: " + path)
		}
		return []byte(txt), nil
	}
}

type fakeLLM struct{ loads []string }

func (f *fakeLLM) Load(_ context.Context, model string) error {
	f.loads = append(f.loads, model)
	return nil
}

const safeWrapperFixture = `
import mlx.core as mx

GiB = 1 << 30
WIRED_CAP = 14 * GiB
MEM_LIMIT = 18 * GiB
CACHE_LIMIT = 2 * GiB

_orig_set_wired_limit = mx.set_wired_limit

def _clamped_set_wired_limit(limit):
    return _orig_set_wired_limit(min(limit, WIRED_CAP))

mx.set_wired_limit = _clamped_set_wired_limit
mx.set_memory_limit(MEM_LIMIT)
mx.set_cache_limit(CACHE_LIMIT)

from mlx_lm.server import main
`

const safeLlamaSwapFixture = `
macros:
  mlx-server: "/Users/milan.santosi/.local/bin/mlx_lm_server_safe"

models:
  "/Users/milan.santosi/qwen36-mlx":
    cmd: |
      ${mlx-server}
      --model /Users/milan.santosi/qwen36-mlx
      --host 127.0.0.1
      --port ${PORT}
      --prefill-step-size 512
      --prompt-concurrency 1
      --decode-concurrency 1
      --prompt-cache-size 1
      --prompt-cache-bytes 1073741824
    proxy: "http://127.0.0.1:${PORT}"
    checkEndpoint: "/v1/models"
    ttl: 600

groups:
  llm:
    swap: true
    exclusive: true
    members:
      - "/Users/milan.santosi/qwen36-mlx"
`
