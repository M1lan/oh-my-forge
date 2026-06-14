package doctor

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"omf/dispatch/internal/mlx"
	"omf/dispatch/internal/omfcore"
	"omf/dispatch/internal/router"
)

func TestDoctorRunsManifestDiscoveryProfilesDepsAndThreeMLXChecks(t *testing.T) {
	manifestPath := writeManifest(t, `
schema_version = 0

[[backend]]
name = "forge"
kind = "forge"
routing = "private"
interactive = ["forge"]
oneshot = ["forge", "-p"]
env_allowlist = ["PATH"]

[[backend]]
name = "qwen36-mlx"
kind = "local-llm"
routing = "none"
interactive = ["omf", "llm", "mlx", "qwen36-mlx"]
env_allowlist = ["PATH"]

[backend.limits]
wired_gib = 14
memory_gib = 18
cache_gib = 2
`)
	runner := Runner{
		ManifestPath: manifestPath,
		Environ:      map[string]string{"PATH": "/bin"},
		HomeDir:      router.PrivateHome,
		PathExists: func(path string) bool {
			return path == router.PrivateForgeConfig
		},
		LookPath: func(name string) (string, error) {
			return "/bin/" + name, nil
		},
		MLX: fakeMLXInspector{report: mlx.Report{
			WrapperPath:       mlx.DefaultWrapperPath,
			ModelID:           mlx.DefaultModelID,
			Caps:              mlx.Caps{WiredGiB: 14, MemoryGiB: 18, CacheGiB: 2},
			UsesWrapper:       true,
			GroupSwap:         true,
			GroupExclusive:    true,
			GroupMember:       true,
			PromptCacheBytes:  1 << 30,
			HasNoSuspension:   true,
			CheckEndpoint:     "/v1/models",
			LlamaSwapModelCmd: "${mlx-server}",
		}},
		CoreLocate: func() (string, error) { return "/fake/omf-core", nil },
		CoreCaps: func(context.Context) (omfcore.Caps, error) {
			return omfcore.Caps{WiredGiB: 14, MemoryGiB: 18, CacheGiB: 2}, nil
		},
	}

	report, err := runner.Run(context.Background())
	if err != nil {
		t.Fatalf("Run returned error: %v", err)
	}
	assertCheckOK(t, report, "manifest validate")
	assertCheckOK(t, report, "backend discovery")
	assertCheckOK(t, report, "profile forge")
	assertCheckOK(t, report, "dep forge")
	assertCheckOK(t, report, "mlx wrapper caps")
	assertCheckOK(t, report, "mlx llama-swap entry")
	assertCheckOK(t, report, "mlx runtime safety")
	assertCheckOK(t, report, "omf-core floor")
}

func TestDoctorRejectsManifestThatFailsGoValidation(t *testing.T) {
	manifestPath := writeManifest(t, `
schema_version = 0

[[backend]]
name = "leaky"
kind = "forge"
routing = "private"
interactive = ["forge"]
env_allowlist = ["HOME"]
`)
	report, err := (Runner{ManifestPath: manifestPath}).Run(context.Background())
	if err == nil {
		t.Fatal("Run accepted manifest with routing-managed env allowlist")
	}
	assertCheckFailed(t, report, "manifest validate")
	if !strings.Contains(err.Error(), "routing-managed") {
		t.Fatalf("err = %v, want routing-managed validation failure", err)
	}
}

func TestDoctorWarnsOnRouteHomeMismatch(t *testing.T) {
	manifestPath := writeManifest(t, `
schema_version = 0

[[backend]]
name = "work-forge"
kind = "forge"
routing = "work"
interactive = ["forge"]
env_allowlist = ["PATH"]
`)
	report, err := (Runner{
		ManifestPath: manifestPath,
		Environ:      map[string]string{"PATH": "/bin"},
		HomeDir:      router.PrivateHome,
		LookPath: func(name string) (string, error) {
			return "/bin/" + name, nil
		},
		CoreLocate: func() (string, error) { return "", omfcore.ErrUnavailable },
	}).Run(context.Background())
	if err != nil {
		t.Fatalf("Run returned error for route mismatch warning: %v", err)
	}
	check := findCheck(t, report, "route home work-forge")
	if check.Status != StatusWarn {
		t.Fatalf("route home check = %#v, want warn", check)
	}
	if !strings.Contains(check.Message, router.WorkHome) || !strings.Contains(check.Message, router.PrivateHome) {
		t.Fatalf("route home warning message = %q, want expected and current homes", check.Message)
	}
	assertCheckOK(t, report, "profile work-forge")
}

func TestDoctorWarnsWhenRoutedEnvAllowlistEntriesAreStripped(t *testing.T) {
	manifestPath := writeManifest(t, `
schema_version = 0

[[backend]]
name = "work-forge"
kind = "forge"
routing = "work"
interactive = ["forge"]
env_allowlist = ["PATH", "HTTPS_PROXY", "NO_PROXY", "TMPDIR", "XDG_CONFIG_HOME", "GH_TOKEN"]
`)
	report, err := (Runner{
		ManifestPath: manifestPath,
		Environ: map[string]string{
			"PATH":            "/bin",
			"HTTPS_PROXY":     "http://proxy.local:8080",
			"NO_PROXY":        "localhost,127.0.0.1",
			"TMPDIR":          router.WorkHome + "/tmp",
			"XDG_CONFIG_HOME": router.WorkHome + "/.config",
			"GH_TOKEN":        "secret",
		},
		HomeDir: router.WorkHome,
		LookPath: func(name string) (string, error) {
			return "/bin/" + name, nil
		},
		CoreLocate: func() (string, error) { return "", omfcore.ErrUnavailable },
	}).Run(context.Background())
	if err != nil {
		t.Fatalf("Run returned error for stripped env warning: %v", err)
	}
	check := findCheck(t, report, "env allowlist work-forge")
	if check.Status != StatusWarn {
		t.Fatalf("env allowlist check = %#v, want warn", check)
	}
	for _, name := range []string{"XDG_CONFIG_HOME", "GH_TOKEN"} {
		if !strings.Contains(check.Message, name) {
			t.Fatalf("env allowlist warning = %q, want stripped %s", check.Message, name)
		}
	}
	for _, name := range []string{"HTTPS_PROXY", "NO_PROXY", "TMPDIR"} {
		if strings.Contains(check.Message, name) {
			t.Fatalf("env allowlist warning = %q, did not expect reviewed runtime var %s", check.Message, name)
		}
	}
	assertCheckOK(t, report, "profile work-forge")
}

func writeManifest(t *testing.T, data string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "omf.toml")
	if err := os.WriteFile(path, []byte(data), 0o644); err != nil {
		t.Fatalf("write manifest fixture: %v", err)
	}
	return path
}

func assertCheckOK(t *testing.T, report Report, name string) {
	t.Helper()
	check := findCheck(t, report, name)
	if check.Status != StatusOK {
		t.Fatalf("check %q = %#v, want ok", name, check)
	}
}

func assertCheckFailed(t *testing.T, report Report, name string) {
	t.Helper()
	check := findCheck(t, report, name)
	if check.Status != StatusFailed {
		t.Fatalf("check %q = %#v, want failed", name, check)
	}
}

func findCheck(t *testing.T, report Report, name string) Check {
	t.Helper()
	for _, check := range report.Checks {
		if check.Name == name {
			return check
		}
	}
	t.Fatalf("check %q missing from %#v", name, report.Checks)
	return Check{}
}

type fakeMLXInspector struct{ report mlx.Report }

func (f fakeMLXInspector) Inspect(context.Context, string) (mlx.Report, error) {
	return f.report, nil
}

func coreRunner(t *testing.T, locate func() (string, error), caps func(context.Context) (omfcore.Caps, error)) Runner {
	t.Helper()
	path := writeManifest(t, `
schema_version = 0

[[backend]]
name = "forge"
kind = "forge"
routing = "private"
interactive = ["forge"]
env_allowlist = ["PATH"]
`)
	return Runner{
		ManifestPath: path,
		Environ:      map[string]string{"PATH": "/bin"},
		HomeDir:      router.PrivateHome,
		PathExists:   func(p string) bool { return p == router.PrivateForgeConfig },
		LookPath:     func(name string) (string, error) { return "/bin/" + name, nil },
		CoreLocate:   locate,
		CoreCaps:     caps,
	}
}

func TestDoctorWarnsWhenCoreAbsent(t *testing.T) {
	runner := coreRunner(t,
		func() (string, error) { return "", omfcore.ErrUnavailable },
		nil)
	report, err := runner.Run(context.Background())
	if err != nil {
		t.Fatalf("Run returned error: %v", err)
	}
	check := findCheck(t, report, "omf-core floor")
	if check.Status != StatusWarn {
		t.Fatalf("omf-core floor = %#v, want warn when binary absent", check)
	}
	if !report.OK() {
		t.Fatal("absent floor made doctor fail; absence must be a warning, not a failure")
	}
	if !strings.Contains(check.Message, "not installed") {
		t.Fatalf("warn message = %q, want 'not installed' guidance", check.Message)
	}
}

func TestDoctorFailsOnCoreCapDrift(t *testing.T) {
	runner := coreRunner(t,
		func() (string, error) { return "/fake/omf-core", nil },
		func(context.Context) (omfcore.Caps, error) {
			return omfcore.Caps{WiredGiB: 99, MemoryGiB: 18, CacheGiB: 2}, nil
		})
	report, err := runner.Run(context.Background())
	if err != nil {
		t.Fatalf("Run returned error: %v", err)
	}
	assertCheckFailed(t, report, "omf-core floor")
	if report.OK() {
		t.Fatal("cap drift between dispatcher and floor must fail doctor")
	}
}

func TestDoctorFailsWhenCoreCapsErrors(t *testing.T) {
	runner := coreRunner(t,
		func() (string, error) { return "/fake/omf-core", nil },
		func(context.Context) (omfcore.Caps, error) {
			return omfcore.Caps{}, errors.New("spawn failed")
		})
	report, err := runner.Run(context.Background())
	if err != nil {
		t.Fatalf("Run returned error: %v", err)
	}
	check := findCheck(t, report, "omf-core floor")
	if check.Status != StatusFailed {
		t.Fatalf("omf-core floor = %#v, want failed when caps probe errors", check)
	}
}
