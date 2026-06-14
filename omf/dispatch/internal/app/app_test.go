package app

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"omf/dispatch/internal/doctor"
	"omf/dispatch/internal/llm"
	"omf/dispatch/internal/mlx"
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

func TestRunRefusesRouteHomeMismatchBeforeExecute(t *testing.T) {
	dir := t.TempDir()
	manifestPath := filepath.Join(dir, "omf.toml")
	writeFile(t, manifestPath, `
schema_version = 0

[[backend]]
name = "work-forge"
kind = "forge"
routing = "work"
interactive = ["forge"]
env_allowlist = ["PATH"]
`)

	var executed bool
	var stderr strings.Builder
	a := App{
		ManifestPath: manifestPath,
		Runner: router.Runner{ExecReplace: func(argv []string, env map[string]string) error {
			executed = true
			return nil
		}},
		Environ: map[string]string{"PATH": "/bin"},
		HomeDir: router.PrivateHome,
		Stderr:  &stderr,
	}
	if code := a.Run([]string{"work-forge"}); code != ExitError {
		t.Fatalf("Run exit code = %d, want %d", code, ExitError)
	}
	if executed {
		t.Fatal("App.Run executed route with mismatched login HOME")
	}
	if !strings.Contains(stderr.String(), router.WorkHome) || !strings.Contains(stderr.String(), router.PrivateHome) {
		t.Fatalf("stderr = %q, want route-home mismatch details", stderr.String())
	}
}

func TestRunReturnsUsageForMissingProfile(t *testing.T) {
	a := App{ManifestPath: filepath.Join(t.TempDir(), "missing.toml")}
	if code := a.Run(nil); code != 2 {
		t.Fatalf("Run exit code = %d, want 2", code)
	}
}

func TestRunResumeExecsResumeAdapter(t *testing.T) {
	var got router.Plan
	a := App{
		AdapterDir: filepath.Join("..", "adapters"),
		Runner: router.Runner{ExecReplace: func(argv []string, env map[string]string) error {
			got = router.Plan{Mode: router.ModeExecReplace, Argv: argv, Env: env}
			return nil
		}},
		Environ: map[string]string{"PATH": "/bin", "OMF_FCR_SNIPPET": "/tmp/fcr.zsh"},
	}
	if code := a.Run([]string{"resume"}); code != 0 {
		t.Fatalf("Run exit code = %d, want 0", code)
	}
	assertStrings(t, got.Argv, []string{filepath.Join("..", "adapters", "resume.bash")})
	if got.Env["PATH"] != "/bin" || got.Env["OMF_FCR_SNIPPET"] != "/tmp/fcr.zsh" {
		t.Fatalf("adapter env = %#v", got.Env)
	}
}

func TestRunHistExecsHistAdapterWithArgs(t *testing.T) {
	var got router.Plan
	a := App{
		AdapterDir: filepath.Join("..", "adapters"),
		Runner: router.Runner{ExecReplace: func(argv []string, env map[string]string) error {
			got = router.Plan{Mode: router.ModeExecReplace, Argv: argv, Env: env}
			return nil
		}},
		Environ: map[string]string{"PATH": "/bin"},
	}
	if code := a.Run([]string{"hist", "-a", "-n", "20", "moe"}); code != 0 {
		t.Fatalf("Run exit code = %d, want 0", code)
	}
	assertStrings(t, got.Argv, []string{filepath.Join("..", "adapters", "hist.bash"), "-a", "-n", "20", "moe"})
}

func TestRunResumeRejectsArgs(t *testing.T) {
	a := App{Runner: router.Runner{ExecReplace: func([]string, map[string]string) error {
		t.Fatal("resume with args should not exec adapter")
		return nil
	}}}
	if code := a.Run([]string{"resume", "extra"}); code != ExitUsage {
		t.Fatalf("Run exit code = %d, want %d", code, ExitUsage)
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

func TestRunLLMUsesBoundedContext(t *testing.T) {
	fake := &deadlineLLM{}
	a := App{LLM: fake, LLMTimeout: time.Second}
	if code := a.Run([]string{"llm", "list"}); code != 0 {
		t.Fatalf("Run exit code = %d, want 0", code)
	}
	if !fake.sawDeadline {
		t.Fatal("llm command ran without a context deadline")
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

func TestRunLLMMLXLoadsThroughExistingWrapperManager(t *testing.T) {
	var out strings.Builder
	fake := &fakeMLX{report: mlx.Report{WrapperPath: mlx.DefaultWrapperPath, ModelID: mlx.DefaultModelID, Caps: mlx.Caps{WiredGiB: 14, MemoryGiB: 18, CacheGiB: 2}}}
	a := App{MLX: fake, Stdout: &out}
	if code := a.Run([]string{"llm", "mlx", "qwen36-mlx"}); code != 0 {
		t.Fatalf("Run exit code = %d, want 0", code)
	}
	assertStrings(t, fake.loads, []string{"qwen36-mlx"})
	if got := out.String(); !strings.Contains(got, mlx.DefaultWrapperPath) || !strings.Contains(got, mlx.DefaultModelID) {
		t.Fatalf("stdout = %q, want wrapper and model id", got)
	}
}

func TestRunDoctorPrintsCheckReport(t *testing.T) {
	var out strings.Builder
	a := App{Doctor: fakeDoctor{report: doctor.Report{Checks: []doctor.Check{{Name: "manifest validate", Status: doctor.StatusOK}}}}, Stdout: &out}
	if code := a.Run([]string{"doctor"}); code != 0 {
		t.Fatalf("Run exit code = %d, want 0", code)
	}
	if got := out.String(); got != "ok\tmanifest validate\n" {
		t.Fatalf("stdout = %q", got)
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

type fakeMLX struct {
	report mlx.Report
	err    error
	loads  []string
}

func (f *fakeMLX) Inspect(context.Context, string) (mlx.Report, error) {
	return f.report, f.err
}

func (f *fakeMLX) Load(_ context.Context, model string) (mlx.Report, error) {
	if f.err != nil {
		return mlx.Report{}, f.err
	}
	f.loads = append(f.loads, model)
	return f.report, nil
}

type fakeDoctor struct {
	report doctor.Report
	err    error
}

func (f fakeDoctor) Run(context.Context) (doctor.Report, error) {
	return f.report, f.err
}

type deadlineLLM struct{ sawDeadline bool }

func (d *deadlineLLM) List(ctx context.Context) ([]llm.Model, error) {
	_, d.sawDeadline = ctx.Deadline()
	return nil, nil
}

func (d *deadlineLLM) Load(context.Context, string) error { return nil }

func (d *deadlineLLM) Unload(context.Context, string) error { return nil }
