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
	plan, err := ResolveProfile(m, []string{"private-forge"}, testOptions(nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != PrivateHome {
		t.Fatalf("HOME = %q, want private home", plan.Env["HOME"])
	}
}

func TestResolveProfileAllowsWorkBackendResolvingWorkHome(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "work-forge", Kind: manifest.KindForge, Routing: manifest.RoutingWork, Interactive: []string{"forge"}}}}
	plan, err := ResolveProfile(m, []string{"work-forge"}, testOptions(nil))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != WorkHome {
		t.Fatalf("HOME = %q, want work home", plan.Env["HOME"])
	}
}

func TestRoutingNoneBackendCannotLeakCallerManagedEnv(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "llm", Kind: manifest.KindLocalLLM, Routing: manifest.RoutingNone, Interactive: []string{"omf", "llm", "list"}, EnvAllowlist: []string{"HOME", "FORGE_CONFIG", "PATH"}}}}
	plan, err := ResolveProfile(m, []string{"llm"}, testOptions(map[string]string{"HOME": PrivateHome, "FORGE_CONFIG": PrivateForgeConfig, "PATH": "/bin"}))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if _, ok := plan.Env["HOME"]; ok {
		t.Fatalf("routing=none unexpectedly resolved HOME: %#v", plan.Env)
	}
	if _, ok := plan.Env["FORGE_CONFIG"]; ok {
		t.Fatalf("routing=none unexpectedly resolved FORGE_CONFIG: %#v", plan.Env)
	}
	if plan.Env["PATH"] != "/bin" {
		t.Fatalf("non-managed allowlisted env missing: %#v", plan.Env)
	}
}

func TestRoutedBackendStripsConfigRedirectEnvironment(t *testing.T) {
	names := []string{
		"XDG_CONFIG_HOME",
		"GNUPGHOME",
		"GH_CONFIG_DIR",
		"GIT_CONFIG_GLOBAL",
		"CLAUDE_CONFIG_DIR",
		"npm_config_userconfig",
	}
	env := map[string]string{"PATH": "/bin"}
	for _, name := range names {
		env[name] = PrivateHome + "/private-config/" + name
	}
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "work-forge", Kind: manifest.KindForge, Routing: manifest.RoutingWork, Interactive: []string{"forge"}, EnvAllowlist: append([]string{"PATH"}, names...)}}}
	plan, err := ResolveProfile(m, []string{"work-forge"}, testOptions(env))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["PATH"] != "/bin" {
		t.Fatalf("PATH missing from env: %#v", plan.Env)
	}
	for _, name := range names {
		if _, ok := plan.Env[name]; ok {
			t.Fatalf("routed backend leaked config redirect %s: %#v", name, plan.Env)
		}
	}
}

func TestRoutedBackendUsesFailClosedSafeEnvironmentAllowlist(t *testing.T) {
	dangerous := []string{
		"AWS_ACCESS_KEY_ID",
		"AWS_SECRET_ACCESS_KEY",
		"AWS_SESSION_TOKEN",
		"AWS_PROFILE",
		"OP_SERVICE_ACCOUNT_TOKEN",
		"GOOGLE_APPLICATION_CREDENTIALS",
		"CLOUDSDK_CONFIG",
		"AZURE_CONFIG_DIR",
		"CARGO_HOME",
		"RUSTUP_HOME",
		"GOPATH",
		"GOMODCACHE",
		"GH_TOKEN",
		"GITHUB_TOKEN",
		"VAULT_TOKEN",
		"SSH_AUTH_SOCK",
		"GIT_SSH_COMMAND",
		"GIT_CONFIG_SYSTEM",
		"GIT_CONFIG_COUNT",
		"GIT_CONFIG_KEY_0",
		"GIT_CONFIG_VALUE_0",
		"NPM_TOKEN",
		"NODE_AUTH_TOKEN",
		"PIP_CONFIG_FILE",
		"PYTHONPATH",
	}
	allowlist := []string{"PATH", "TERM", "LANG", "LC_ALL", "LC_CTYPE", "TZ", "COLORTERM"}
	allowlist = append(allowlist, dangerous...)

	env := map[string]string{
		"PATH":      "/opt/homebrew/bin:/usr/bin:/bin",
		"TERM":      "tmux-256color",
		"LANG":      "en_US.UTF-8",
		"LC_ALL":    "C.UTF-8",
		"LC_CTYPE":  "C.UTF-8",
		"TZ":        "Europe/Berlin",
		"COLORTERM": "truecolor",
	}
	for _, name := range dangerous {
		env[name] = PrivateHome + "/private-config/" + name
	}

	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "work-forge", Kind: manifest.KindForge, Routing: manifest.RoutingWork, Interactive: []string{"forge"}, EnvAllowlist: allowlist}}}
	plan, err := ResolveProfile(m, []string{"work-forge"}, testOptions(env))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	for _, name := range []string{"PATH", "TERM", "LANG", "LC_ALL", "LC_CTYPE", "TZ", "COLORTERM"} {
		if plan.Env[name] != env[name] {
			t.Fatalf("safe env %s = %q, want %q (all=%#v)", name, plan.Env[name], env[name], plan.Env)
		}
	}
	for _, name := range dangerous {
		if _, ok := plan.Env[name]; ok {
			t.Fatalf("routed backend leaked dangerous env %s: %#v", name, plan.Env)
		}
	}
}

func TestRoutedBackendStripsSafeEnvValuesPointingAtSiblingHome(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{
		Name:         "work-forge",
		Kind:         manifest.KindForge,
		Routing:      manifest.RoutingWork,
		Interactive:  []string{"forge"},
		EnvAllowlist: []string{"PATH", "TERM", "LANG"},
	}}}
	plan, err := ResolveProfile(m, []string{"work-forge"}, testOptions(map[string]string{
		"PATH": "/opt/homebrew/bin:" + PrivateHome + "/bin:/usr/bin",
		"TERM": "tmux-256color",
		"LANG": PrivateHome + "/not-a-locale",
	}))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if _, ok := plan.Env["PATH"]; ok {
		t.Fatalf("PATH with private-home component leaked into work route: %#v", plan.Env)
	}
	if _, ok := plan.Env["LANG"]; ok {
		t.Fatalf("LANG with private-home prefix leaked into work route: %#v", plan.Env)
	}
	if plan.Env["TERM"] != "tmux-256color" {
		t.Fatalf("safe TERM stripped unexpectedly: %#v", plan.Env)
	}
}

func TestPrivateRoutedBackendStripsWorkHomeValues(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{
		Name:         "private-forge",
		Kind:         manifest.KindForge,
		Routing:      manifest.RoutingPrivate,
		Interactive:  []string{"forge"},
		EnvAllowlist: []string{"PATH", "TERM"},
	}}}
	plan, err := ResolveProfile(m, []string{"private-forge"}, testOptions(map[string]string{
		"PATH": "/usr/bin:" + WorkHome + "/bin",
		"TERM": "xterm-256color",
	}))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if _, ok := plan.Env["PATH"]; ok {
		t.Fatalf("PATH with work-home component leaked into private route: %#v", plan.Env)
	}
	if plan.Env["TERM"] != "xterm-256color" {
		t.Fatalf("safe TERM stripped unexpectedly: %#v", plan.Env)
	}
}

func TestRoutingNoneBackendMayKeepConfigRedirectEnvironment(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "tool", Kind: manifest.KindVendor, Routing: manifest.RoutingNone, Interactive: []string{"tool"}, EnvAllowlist: []string{"XDG_CONFIG_HOME"}}}}
	plan, err := ResolveProfile(m, []string{"tool"}, testOptions(map[string]string{"XDG_CONFIG_HOME": "/tmp/tool-config"}))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["XDG_CONFIG_HOME"] != "/tmp/tool-config" {
		t.Fatalf("routing=none stripped config redirect: %#v", plan.Env)
	}
}

func TestRoutingInvariantUsesCompiledLiteralTableNotCallerEnvironment(t *testing.T) {
	m := manifest.Manifest{Backends: []manifest.Backend{{Name: "work-forge", Kind: manifest.KindForge, Routing: manifest.RoutingWork, Interactive: []string{"forge"}, EnvAllowlist: []string{"HOME", "FORGE_CONFIG"}}}}
	plan, err := ResolveProfile(m, []string{"work-forge"}, testOptions(map[string]string{"HOME": PrivateHome, "FORGE_CONFIG": PrivateForgeConfig}))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != WorkHome || plan.Env["FORGE_CONFIG"] != WorkForgeConfig {
		t.Fatalf("caller env overrode compiled route table: %#v", plan.Env)
	}
}

func TestSamePathOrWithinContainmentTripwire(t *testing.T) {
	tests := []struct {
		name string
		path string
		root string
		want bool
	}{
		{name: "identical", path: "/Users/milan.santosi", root: "/Users/milan.santosi", want: true},
		{name: "short subpath", path: "/Users/milan.santosi/x", root: "/Users/milan.santosi", want: true},
		{name: "deep subpath", path: "/Users/milan.santosi/a/b/c", root: "/Users/milan.santosi", want: true},
		{name: "sibling", path: "/Users/milan.santosi-work", root: "/Users/milan.santosi", want: false},
		{name: "escape", path: "/Users/milan.santosi/../milan.santosi-work", root: "/Users/milan.santosi", want: false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := samePathOrWithin(tt.path, tt.root); got != tt.want {
				t.Fatalf("samePathOrWithin(%q, %q) = %v, want %v", tt.path, tt.root, got, tt.want)
			}
		})
	}
}

func TestRouteAccountCompiledTable(t *testing.T) {
	tests := []struct {
		routing    manifest.Routing
		wantOK     bool
		wantHome   string
		wantConfig string
	}{
		{routing: manifest.RoutingPrivate, wantOK: true, wantHome: PrivateHome, wantConfig: PrivateForgeConfig},
		{routing: manifest.RoutingWork, wantOK: true, wantHome: WorkHome, wantConfig: WorkForgeConfig},
		{routing: manifest.RoutingNone, wantOK: false},
	}
	for _, tt := range tests {
		got, ok := routeAccount(tt.routing)
		if ok != tt.wantOK {
			t.Fatalf("routeAccount(%s) ok = %v, want %v", tt.routing, ok, tt.wantOK)
		}
		if got.Home != tt.wantHome || got.ForgeConfig != tt.wantConfig {
			t.Fatalf("routeAccount(%s) = %#v", tt.routing, got)
		}
	}
}

func TestParseManifestThenResolvePrivateHome(t *testing.T) {
	m, err := manifest.Parse([]byte(`
schema_version = 0

[[backend]]
name = "forge"
kind = "forge"
routing = "private"
interactive = ["forge"]
env_allowlist = ["PATH"]
`))
	if err != nil {
		t.Fatalf("Parse returned error: %v", err)
	}
	plan, err := ResolveProfile(m, []string{"forge"}, testOptions(map[string]string{"PATH": "/bin", "HOME": WorkHome}))
	if err != nil {
		t.Fatalf("ResolveProfile returned error: %v", err)
	}
	if plan.Env["HOME"] != PrivateHome || plan.Env["FORGE_CONFIG"] != PrivateForgeConfig {
		t.Fatalf("resolved env = %#v", plan.Env)
	}
	if plan.Env["PATH"] != "/bin" {
		t.Fatalf("allowlisted PATH missing: %#v", plan.Env)
	}
}

func TestCompiledAccountTableGuardFailsOnAlienHost(t *testing.T) {
	err := assertCompiledAccountTable(Options{
		HomeDir: "/Users/someone-else",
		PathExists: func(string) bool {
			return false
		},
	})
	if err == nil {
		t.Fatal("compiled account table accepted an unrelated host")
	}
	if !IsSecurityError(err) {
		t.Fatalf("err = %T %[1]v, want security error", err)
	}
}

func TestCompiledAccountTableGuardAcceptsConfiguredHomeOrExistingDir(t *testing.T) {
	if err := assertCompiledAccountTable(Options{HomeDir: PrivateHome}); err != nil {
		t.Fatalf("guard rejected configured private home: %v", err)
	}
	err := assertCompiledAccountTable(Options{
		HomeDir: "/Users/someone-else",
		PathExists: func(path string) bool {
			return path == WorkHome
		},
	})
	if err != nil {
		t.Fatalf("guard rejected existing compiled work dir: %v", err)
	}
}
