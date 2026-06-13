package app

import (
	"os"
	"path/filepath"
	"testing"

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
