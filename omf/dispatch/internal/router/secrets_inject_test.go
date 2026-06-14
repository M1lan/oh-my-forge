package router

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"omf/dispatch/internal/manifest"
)

type fakeSecrets struct {
	called   bool
	gotAllow []string
	gotAcct  string
	out      map[string]string
	err      error
}

func (f *fakeSecrets) SecretsEnv(_ context.Context, allow []string, opAccount string) (map[string]string, error) {
	f.called = true
	f.gotAllow = append([]string(nil), allow...)
	f.gotAcct = opAccount
	return f.out, f.err
}

func privateForge(allow []string) manifest.Manifest {
	return manifest.Manifest{Backends: []manifest.Backend{{
		Name:         "forge",
		Kind:         manifest.KindForge,
		Routing:      manifest.RoutingPrivate,
		Interactive:  []string{"forge"},
		EnvAllowlist: allow,
	}}}
}

func privateOpts(env map[string]string, provider SecretsProvider, warnf func(string, ...any)) Options {
	return Options{
		Environ:         env,
		HomeDir:         PrivateHome,
		PathExists:      func(string) bool { return false },
		SecretsProvider: provider,
		Warnf:           warnf,
	}
}

func TestPrivateRouteInjectsCredentialsFromVaultNotAmbient(t *testing.T) {
	fake := &fakeSecrets{out: map[string]string{"GH_TOKEN": "from-vault"}}
	m := privateForge([]string{"PATH", "GH_TOKEN"})
	plan, err := ResolveProfile(m, []string{"forge"}, privateOpts(map[string]string{
		"PATH":     "/usr/bin:/bin",
		"GH_TOKEN": "from-ambient",
	}, fake, nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if got := plan.Env["GH_TOKEN"]; got != "from-vault" {
		t.Fatalf("GH_TOKEN = %q, want vault value (ambient must be stripped, vault injected)", got)
	}
	if !fake.called {
		t.Fatal("secrets provider was not invoked for a private route")
	}
	if want := []string{"GH_TOKEN"}; !reflect.DeepEqual(fake.gotAllow, want) {
		t.Fatalf("provider allow = %#v, want %#v (only credential-shaped names)", fake.gotAllow, want)
	}
}

func TestWorkRouteNeverInvokesSecretsProvider(t *testing.T) {
	fake := &fakeSecrets{out: map[string]string{"GH_TOKEN": "from-vault"}}
	m := manifest.Manifest{Backends: []manifest.Backend{{
		Name:         "work-forge",
		Kind:         manifest.KindForge,
		Routing:      manifest.RoutingWork,
		Interactive:  []string{"forge"},
		EnvAllowlist: []string{"PATH", "GH_TOKEN"},
	}}}
	opts := Options{
		Environ:         map[string]string{"PATH": "/usr/bin", "GH_TOKEN": "from-ambient"},
		HomeDir:         WorkHome,
		PathExists:      func(string) bool { return false },
		SecretsProvider: fake,
	}
	plan, err := ResolveProfile(m, []string{"work-forge"}, opts)
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if fake.called {
		t.Fatal("secrets provider invoked for a work route; private vault must never reach work")
	}
	if _, ok := plan.Env["GH_TOKEN"]; ok {
		t.Fatalf("GH_TOKEN leaked into work route: %#v", plan.Env)
	}
}

func TestSecretsInjectionIsNonFatalOnProviderError(t *testing.T) {
	var warned bool
	fake := &fakeSecrets{err: errors.New("cold keychain")}
	m := privateForge([]string{"PATH", "GH_TOKEN"})
	plan, err := ResolveProfile(m, []string{"forge"}, privateOpts(map[string]string{
		"PATH": "/usr/bin",
	}, fake, func(string, ...any) { warned = true }))
	if err != nil {
		t.Fatalf("provider error should be non-fatal, got: %v", err)
	}
	if !warned {
		t.Fatal("provider error did not emit a warning")
	}
	if _, ok := plan.Env["GH_TOKEN"]; ok {
		t.Fatalf("GH_TOKEN present despite provider failure: %#v", plan.Env)
	}
}

func TestInjectedSecretCannotOverrideRoutingManagedEnv(t *testing.T) {
	// A compromised/buggy provider returning HOME must not move the routed HOME.
	fake := &fakeSecrets{out: map[string]string{"HOME": "/Users/evil", "GH_TOKEN": "ok"}}
	m := privateForge([]string{"GH_TOKEN"})
	plan, err := ResolveProfile(m, []string{"forge"}, privateOpts(map[string]string{}, fake, nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != PrivateHome {
		t.Fatalf("HOME = %q, want %q (injected secret overrode routing-managed env)", plan.Env["HOME"], PrivateHome)
	}
}

func TestPrivateRouteWithNoCredentialNamesSkipsProvider(t *testing.T) {
	fake := &fakeSecrets{out: map[string]string{"GH_TOKEN": "x"}}
	// Only routed-safe + routing-managed names: nothing credential-shaped to source.
	m := privateForge([]string{"PATH", "TERM", "HOME"})
	if _, err := ResolveProfile(m, []string{"forge"}, privateOpts(map[string]string{
		"PATH": "/usr/bin",
		"TERM": "xterm",
	}, fake, nil)); err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if fake.called {
		t.Fatal("provider invoked with an empty credential allowlist")
	}
}
