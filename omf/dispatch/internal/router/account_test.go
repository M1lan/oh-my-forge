package router

import (
	"testing"

	"omf/dispatch/internal/manifest"
)

func TestResolveProfileSetsForgeConfigForPrivateRoute(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{
		Name:         "forge",
		Kind:         manifest.KindForge,
		Routing:      manifest.RoutingPrivate,
		Interactive:  []string{"forge"},
		EnvAllowlist: []string{"PATH", "TERM"},
	}}}
	plan, err := ResolveProfile(m, []string{"forge"}, Options{Environ: map[string]string{"PATH": "/bin", "TERM": "xterm", "SECRET": "nope"}})
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != PrivateHome {
		t.Fatalf("HOME = %q, want private home %q", plan.Env["HOME"], PrivateHome)
	}
	if plan.Env["FORGE_CONFIG"] != PrivateForgeConfig {
		t.Fatalf("FORGE_CONFIG = %q, want %q", plan.Env["FORGE_CONFIG"], PrivateForgeConfig)
	}
	if plan.Env["PATH"] != "/bin" || plan.Env["TERM"] != "xterm" {
		t.Fatalf("allowlisted env missing: %#v", plan.Env)
	}
	if _, ok := plan.Env["SECRET"]; ok {
		t.Fatalf("non-allowlisted secret leaked into env: %#v", plan.Env)
	}
}
