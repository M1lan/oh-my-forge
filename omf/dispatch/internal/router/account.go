package router

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"omf/dispatch/internal/manifest"
)

const (
	PrivateHome        = "/Users/milan.santosi"
	PrivateForgeConfig = "/Users/milan.santosi/forge/.forge.toml"
	WorkHome           = "/Users/milan.santosi-work"
	WorkForgeConfig    = "/Users/milan.santosi-work/forge/.forge.toml"
)

type SecurityError struct{ Message string }

func (e SecurityError) Error() string { return e.Message }

func IsSecurityError(err error) bool {
	var security SecurityError
	return errors.As(err, &security)
}

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

func assertCompiledAccountTable(opts Options) error {
	home := opts.HomeDir
	if home == "" {
		var err error
		home, err = os.UserHomeDir()
		if err != nil {
			home = ""
		}
	}
	if home == PrivateHome || home == WorkHome {
		return nil
	}

	pathExists := opts.PathExists
	if pathExists == nil {
		pathExists = dirExists
	}
	if pathExists(PrivateHome) || pathExists(WorkHome) {
		return nil
	}
	return SecurityError{Message: fmt.Sprintf("compiled account table does not match this host: HOME=%q private=%q work=%q", home, PrivateHome, WorkHome)}
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func assertRoutingBoundary(r manifest.Routing, account accountRoute) error {
	switch r {
	case manifest.RoutingWork:
		if account.Home != WorkHome || samePathOrWithin(account.Home, PrivateHome) {
			return SecurityError{Message: fmt.Sprintf("work route resolved forbidden HOME %q", account.Home)}
		}
	case manifest.RoutingPrivate:
		if account.Home != PrivateHome || samePathOrWithin(account.Home, WorkHome) {
			return SecurityError{Message: fmt.Sprintf("private route resolved forbidden HOME %q", account.Home)}
		}
	}
	return nil
}

func samePathOrWithin(path, root string) bool {
	path = filepath.Clean(path)
	root = filepath.Clean(root)
	if path == root {
		return true
	}
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return false
	}
	return rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

func buildEnv(backend manifest.Backend, environ map[string]string) (map[string]string, error) {
	env := make(map[string]string)
	for _, name := range backend.EnvAllowlist {
		if isRoutingManagedEnv(name) {
			continue
		}
		if val, ok := environ[name]; ok {
			env[name] = val
		}
	}
	if account, ok := routeAccount(backend.Routing); ok {
		if err := assertRoutingBoundary(backend.Routing, account); err != nil {
			return nil, err
		}
		env["HOME"] = account.Home
		env["FORGE_CONFIG"] = account.ForgeConfig
	}
	return env, nil
}

func isRoutingManagedEnv(name string) bool {
	return name == "HOME" || name == "FORGE_CONFIG"
}
