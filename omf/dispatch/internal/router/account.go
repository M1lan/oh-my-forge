package router

import "omf/dispatch/internal/manifest"

const (
	PrivateHome        = "/Users/milan.santosi"
	PrivateForgeConfig = "/Users/milan.santosi/forge/.forge.toml"
	WorkHome           = "/Users/milan.santosi-work"
	WorkForgeConfig    = "/Users/milan.santosi-work/forge/.forge.toml"
)

type accountRoute struct {
	Home        string
	ForgeConfig string
}

func routeAccount(r manifest.Routing) (accountRoute, bool) {
	switch r {
	case manifest.RoutingPrivate:
		return accountRoute{Home: PrivateHome, ForgeConfig: PrivateForgeConfig}, true
	case manifest.RoutingWork:
		return accountRoute{Home: WorkHome, ForgeConfig: WorkForgeConfig}, true
	default:
		return accountRoute{}, false
	}
}

func buildEnv(backend manifest.Backend, environ map[string]string) map[string]string {
	env := make(map[string]string)
	for _, name := range backend.EnvAllowlist {
		if val, ok := environ[name]; ok {
			env[name] = val
		}
	}
	if account, ok := routeAccount(backend.Routing); ok {
		env["HOME"] = account.Home
		env["FORGE_CONFIG"] = account.ForgeConfig
	}
	return env
}
