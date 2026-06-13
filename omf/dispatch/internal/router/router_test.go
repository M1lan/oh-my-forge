package router

import (
	"testing"

	"omf/dispatch/internal/manifest"
)

func TestResolveProfileBuildsInteractiveExecPlan(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "forge", Kind: manifest.KindForge, Routing: manifest.RoutingPrivate, Interactive: []string{"forge"}}}}
	plan, err := ResolveProfile(m, []string{"forge"}, testOptions(nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Mode != ModeExecReplace {
		t.Fatalf("mode = %s, want %s", plan.Mode, ModeExecReplace)
	}
	assertStrings(t, plan.Argv, []string{"forge"})
}

func TestResolveProfileBuildsOneshotSubprocessPlanWhenPromptFlagPresent(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "forge", Kind: manifest.KindForge, Routing: manifest.RoutingPrivate, Oneshot: []string{"forge", "-p"}}}}
	plan, err := ResolveProfile(m, []string{"forge", "-p", "hello world"}, testOptions(nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Mode != ModeWrappedSubprocess {
		t.Fatalf("mode = %s, want %s", plan.Mode, ModeWrappedSubprocess)
	}
	assertStrings(t, plan.Argv, []string{"forge", "-p", "hello world"})
}

func TestResolveProfileBuildsSupervisorPlanForLocalLLM(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "qwen36-mlx", Kind: manifest.KindLocalLLM, Routing: manifest.RoutingNone, Interactive: []string{"omf", "llm", "mlx", "qwen36-mlx"}}}}
	plan, err := ResolveProfile(m, []string{"qwen36-mlx"}, testOptions(nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Mode != ModeSupervisor {
		t.Fatalf("mode = %s, want %s", plan.Mode, ModeSupervisor)
	}
	assertStrings(t, plan.Argv, []string{"omf", "llm", "mlx", "qwen36-mlx"})
}

func TestUnknownProfileReturnsUsageError(t *testing.T) {
	_, err := ResolveProfile(manifest.Manifest{}, []string{"missing"}, testOptions(nil))
	if err == nil {
		t.Fatal("ResolveProfile succeeded for missing profile")
	}
	if !IsUsageError(err) {
		t.Fatalf("err = %T %[1]v, want usage error", err)
	}
}

func TestDispatcherNeverReimplementsUpstreamSubcommand(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "forge", Kind: manifest.KindForge, Routing: manifest.RoutingPrivate, Interactive: []string{"forge"}}}}
	plan, err := ResolveProfile(m, []string{"forge", "list", "agent", "--json"}, testOptions(nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	assertStrings(t, plan.Argv, []string{"forge", "list", "agent", "--json"})
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
