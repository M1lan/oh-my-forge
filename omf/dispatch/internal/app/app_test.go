package app

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"omf/dispatch/internal/llm"
	"omf/dispatch/internal/router"
)

func TestRunLoadsManifestAndExecutesResolvedPlan(t *testing.T) {
	dir := t.TempDir()
	manifestPath := filepath.Join(dir, "omf.toml")
	writeFile(t, manifestPath, `
schema_version = 0

[[backend]]
name = "forge"
kind = "forge"
routing = "private"
interactive = ["forge"]
oneshot = ["forge", "-p"]
env_allowlist = ["PATH"]
`)

	var got router.Plan
	a := App{
		ManifestPath: manifestPath,
		Runner: router.Runner{ExecReplace: func(argv []string, env map[string]string) error {
			got = router.Plan{Mode: router.ModeExecReplace, Argv: argv, Env: env}
			return nil
		}},
		Environ: map[string]string{"PATH": "/bin"},
		HomeDir: router.PrivateHome,
	}
	code := a.Run([]string{"forge"})
	if code != 0 {
		t.Fatalf("Run exit code = %d, want 0", code)
	}
	if got.Mode != router.ModeExecReplace {
		t.Fatalf("mode = %s", got.Mode)
	}
	assertStrings(t, got.Argv, []string{"forge"})
	if got.Env["FORGE_CONFIG"] != router.PrivateForgeConfig {
		t.Fatalf("FORGE_CONFIG = %q", got.Env["FORGE_CONFIG"])
	}
}

func TestRunReturnsUsageForMissingProfile(t *testing.T) {
	a := App{ManifestPath: filepath.Join(t.TempDir(), "missing.toml")}
	if code := a.Run(nil); code != 2 {
		t.Fatalf("Run exit code = %d, want 2", code)
	}
}

func TestRunLLMListUsesLocalLLMService(t *testing.T) {
	var out strings.Builder
	a := App{
		LLM:    &fakeLLM{models: []llm.Model{{Name: "qwen3-coder:latest", Source: llm.SourceBoth}}},
		Stdout: &out,
	}
	code := a.Run([]string{"llm", "list"})
	if code != 0 {
		t.Fatalf("Run exit code = %d, want 0", code)
	}
	if got := out.String(); got != "qwen3-coder:latest\tllama-swap+ollama\n" {
		t.Fatalf("stdout = %q", got)
	}
}

func TestRunLLMLoadAndUnloadUseLocalLLMService(t *testing.T) {
	fake := &fakeLLM{}
	a := App{LLM: fake}
	if code := a.Run([]string{"llm", "load", "qwen3-coder:latest"}); code != 0 {
		t.Fatalf("load exit code = %d, want 0", code)
	}
	if code := a.Run([]string{"llm", "unload", "qwen3-coder:latest"}); code != 0 {
		t.Fatalf("unload exit code = %d, want 0", code)
	}
	assertStrings(t, fake.loads, []string{"qwen3-coder:latest"})
	assertStrings(t, fake.unloads, []string{"qwen3-coder:latest"})
}

func TestRunLLMRejectsUnknownLLMVerbAsUsage(t *testing.T) {
	a := App{LLM: &fakeLLM{}}
	if code := a.Run([]string{"llm", "unknown"}); code != 2 {
		t.Fatalf("Run exit code = %d, want 2", code)
	}
}

func writeFile(t *testing.T, path, data string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(data), 0o644); err != nil {
		t.Fatalf("write fixture: %v", err)
	}
}

func assertStrings(t *testing.T, got, want []string) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("slice len = %d, want %d: %#v", len(got), len(want), got)
	}
	for i := range got {
		if got[i] != want[i] {
			t.Fatalf("slice[%d] = %q, want %q (all=%#v)", i, got[i], want[i], got)
		}
	}
}

type fakeLLM struct {
	models  []llm.Model
	err     error
	loads   []string
	unloads []string
}

func (f *fakeLLM) List(context.Context) ([]llm.Model, error) {
	if f.err != nil {
		return nil, f.err
	}
	return f.models, nil
}

func (f *fakeLLM) Load(_ context.Context, model string) error {
	if f.err != nil {
		return f.err
	}
	if model == "fail" {
		return errors.New("load failed")
	}
	f.loads = append(f.loads, model)
	return nil
}

func (f *fakeLLM) Unload(_ context.Context, model string) error {
	if f.err != nil {
		return f.err
	}
	f.unloads = append(f.unloads, model)
	return nil
}
