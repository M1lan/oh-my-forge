package manifest

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadManifestParsesBackendRowsWithArgvArrays(t *testing.T) {
	txt := `
schema_version = 0

[[backend]]
name = "forge"
kind = "forge"
routing = "private"
interactive = ["forge"]
oneshot = ["forge", "-p"]
env_allowlist = ["PATH", "TERM", "LANG"]
danger_allowed = false

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
`

	m, err := Parse([]byte(txt))
	if err != nil {
		t.Fatalf("Parse returned error: %v", err)
	}
	if m.SchemaVersion != 0 {
		t.Fatalf("schema version = %d, want 0", m.SchemaVersion)
	}
	if len(m.Backends) != 2 {
		t.Fatalf("backends len = %d, want 2", len(m.Backends))
	}

	b := m.Backends[0]
	if b.Name != "forge" || b.Kind != KindForge || b.Routing != RoutingPrivate {
		t.Fatalf("unexpected backend: %#v", b)
	}
	assertStrings(t, b.Interactive, []string{"forge"})
	assertStrings(t, b.Oneshot, []string{"forge", "-p"})
	assertStrings(t, b.EnvAllowlist, []string{"PATH", "TERM", "LANG"})
	if b.DangerAllowed {
		t.Fatal("danger_allowed default/parse = true, want false")
	}

	llm := m.Backends[1]
	if llm.Limits == nil {
		t.Fatal("local llm limits nil")
	}
	if *llm.Limits != (Limits{WiredGiB: 14, MemoryGiB: 18, CacheGiB: 2}) {
		t.Fatalf("limits = %#v", *llm.Limits)
	}
}

func TestParseRejectsBackendWithMissingRouting(t *testing.T) {
	txt := `
schema_version = 0

[[backend]]
name = "forge"
kind = "forge"
interactive = ["forge"]
`
	_, err := Parse([]byte(txt))
	if err == nil {
		t.Fatal("Parse accepted backend with missing routing")
	}
	if !strings.Contains(err.Error(), "missing routing") {
		t.Fatalf("err = %v, want missing routing validation failure", err)
	}
}

func TestParseRejectsCredentialKindWithRoutingNone(t *testing.T) {
	for _, kind := range []Kind{KindClaude, KindCodex, KindGemini, KindCopilot, KindForge, KindOmc, KindOmx} {
		t.Run(string(kind), func(t *testing.T) {
			txt := `
schema_version = 0

[[backend]]
name = "leaky"
kind = "` + string(kind) + `"
routing = "none"
interactive = ["tool"]
`
			_, err := Parse([]byte(txt))
			if err == nil {
				t.Fatalf("Parse accepted credential-bearing kind %s with routing=none", kind)
			}
			if !strings.Contains(err.Error(), "routing=none") {
				t.Fatalf("err = %v, want routing=none validation failure", err)
			}
		})
	}
}

func TestParseAllowsExplicitRoutingNoneForNonCredentialKind(t *testing.T) {
	txt := `
schema_version = 0

[[backend]]
name = "vendor-tool"
kind = "vendor"
routing = "none"
interactive = ["vendor-tool"]
`
	if _, err := Parse([]byte(txt)); err != nil {
		t.Fatalf("Parse rejected explicit routing=none for non-credential kind: %v", err)
	}
}

func TestRepositoryManifestRoutesQwenMLXExplicitly(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "omf.toml"))
	if err != nil {
		t.Fatalf("read repository omf.toml: %v", err)
	}
	m, err := Parse(data)
	if err != nil {
		t.Fatalf("repository omf.toml did not parse: %v", err)
	}
	for _, b := range m.Backends {
		if b.Name == "qwen36-mlx" {
			if b.Routing == RoutingNone {
				t.Fatalf("qwen36-mlx routing = %q, want explicit account route", b.Routing)
			}
			return
		}
	}
	t.Fatal("qwen36-mlx backend missing from repository omf.toml")
}

func TestParseRejectsCommandTemplateShellString(t *testing.T) {
	txt := `
schema_version = 0

[[backend]]
name = "bad"
kind = "forge"
routing = "private"
interactive = "forge -p unsafe"
`
	if _, err := Parse([]byte(txt)); err == nil {
		t.Fatal("Parse accepted shell-string command template; want error")
	}
}

func TestParseRejectsRoutingManagedEnvironmentAllowlist(t *testing.T) {
	txt := `
schema_version = 0

[[backend]]
name = "bad"
kind = "local-llm"
routing = "none"
interactive = ["omf", "llm", "list"]
env_allowlist = ["HOME"]
`
	if _, err := Parse([]byte(txt)); err == nil {
		t.Fatal("Parse accepted routing-managed HOME in env_allowlist; want error")
	}

	txt = `
schema_version = 0

[[backend]]
name = "bad"
kind = "forge"
routing = "private"
interactive = ["forge"]
env_allowlist = ["FORGE_CONFIG"]
`
	if _, err := Parse([]byte(txt)); err == nil {
		t.Fatal("Parse accepted routing-managed FORGE_CONFIG in env_allowlist; want error")
	}
}

func TestParseRejectsDuplicateBackendNames(t *testing.T) {
	txt := `
schema_version = 0

[[backend]]
name = "dup"
kind = "forge"
interactive = ["forge"]

[[backend]]
name = "dup"
kind = "codex"
interactive = ["codex"]
`
	if _, err := Parse([]byte(txt)); err == nil {
		t.Fatal("Parse accepted duplicate backend names")
	}
}

func TestClampManifestLimitsKeepsStricterValues(t *testing.T) {
	m := Manifest{Backends: []Backend{{Name: "small", Limits: &Limits{WiredGiB: 8, MemoryGiB: 10, CacheGiB: 1}}}}
	logs := m.ClampAll()
	if len(logs) != 0 {
		t.Fatalf("logs len = %d, want 0: %#v", len(logs), logs)
	}
	got := *m.Backends[0].Limits
	want := Limits{WiredGiB: 8, MemoryGiB: 10, CacheGiB: 1}
	if got != want {
		t.Fatalf("limits = %#v, want %#v", got, want)
	}
}

func TestClampManifestLimitsClampsLooserValuesToFloor(t *testing.T) {
	m := Manifest{Backends: []Backend{{Name: "large", Limits: &Limits{WiredGiB: 99, MemoryGiB: 99, CacheGiB: 99}}}}
	logs := m.ClampAll()
	if len(logs) != 3 {
		t.Fatalf("logs len = %d, want 3: %#v", len(logs), logs)
	}
	got := *m.Backends[0].Limits
	want := Limits{WiredGiB: 14, MemoryGiB: 18, CacheGiB: 2}
	if got != want {
		t.Fatalf("limits = %#v, want %#v", got, want)
	}
	if logs[0].Backend != "large" || logs[0].Requested != 99 {
		t.Fatalf("unexpected first clamp log: %#v", logs[0])
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
