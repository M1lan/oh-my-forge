package router

import (
	"testing"

	"omf/dispatch/internal/manifest"
)

func TestRoutingBoundaryRejectsWorkBackendResolvingPrivateHome(t *testing.T) {
	err := assertRoutingBoundary(manifest.RoutingWork, accountRoute{Home: PrivateHome, ForgeConfig: WorkForgeConfig})
	if err == nil {
		t.Fatal("work route resolved private HOME without failing closed")
	}
	if !IsSecurityError(err) {
		t.Fatalf("err = %T %[1]v, want security error", err)
	}
}

func TestRoutingBoundaryRejectsPrivateBackendResolvingWorkHome(t *testing.T) {
	err := assertRoutingBoundary(manifest.RoutingPrivate, accountRoute{Home: WorkHome, ForgeConfig: PrivateForgeConfig})
	if err == nil {
		t.Fatal("private route resolved work HOME without failing closed")
	}
	if !IsSecurityError(err) {
		t.Fatalf("err = %T %[1]v, want security error", err)
	}
}

func TestResolveProfileAllowsPrivateBackendResolvingPrivateHome(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "private-forge", Kind: manifest.KindForge, Routing: manifest.RoutingPrivate, Interactive: []string{"forge"}}}}
	plan, err := ResolveProfile(m, []string{"private-forge"}, Options{})
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != PrivateHome {
		t.Fatalf("HOME = %q, want private home", plan.Env["HOME"])
	}
}

func TestResolveProfileAllowsWorkBackendResolvingWorkHome(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "work-forge", Kind: manifest.KindForge, Routing: manifest.RoutingWork, Interactive: []string{"forge"}}}}
	plan, err := ResolveProfile(m, []string{"work-forge"}, Options{})
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != WorkHome {
		t.Fatalf("HOME = %q, want work home", plan.Env["HOME"])
	}
}

func TestLocalLLMBackendDoesNotResolveAccountHome(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "llm", Kind: manifest.KindLocalLLM, Routing: manifest.RoutingNone, Interactive: []string{"omf", "llm", "list"}}}}
	plan, err := ResolveProfile(m, []string{"llm"}, Options{Environ: map[string]string{"HOME": PrivateHome, "FORGE_CONFIG": PrivateForgeConfig}})
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if _, ok := plan.Env["HOME"]; ok {
		t.Fatalf("routing=none unexpectedly resolved HOME: %#v", plan.Env)
	}
	if _, ok := plan.Env["FORGE_CONFIG"]; ok {
		t.Fatalf("routing=none unexpectedly resolved FORGE_CONFIG: %#v", plan.Env)
	}
}

func TestRoutingInvariantUsesCompiledLiteralTableNotCallerEnvironment(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "work-forge", Kind: manifest.KindForge, Routing: manifest.RoutingWork, Interactive: []string{"forge"}, EnvAllowlist: []string{"HOME", "FORGE_CONFIG"}}}}
	plan, err := ResolveProfile(m, []string{"work-forge"}, Options{Environ: map[string]string{"HOME": PrivateHome, "FORGE_CONFIG": PrivateForgeConfig}})
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != WorkHome || plan.Env["FORGE_CONFIG"] != WorkForgeConfig {
		t.Fatalf("caller env overrode compiled route table: %#v", plan.Env)
	}
}
