package router

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
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

type RouteHomeMismatchError struct {
	Message      string
	BackendName  string
	Routing      manifest.Routing
	CurrentHome  string
	ExpectedHome string
}

func (e RouteHomeMismatchError) Error() string { return e.Message }

func (e RouteHomeMismatchError) Unwrap() error { return SecurityError{Message: e.Message} }

func IsSecurityError(err error) bool {
	var security SecurityError
	return errors.As(err, &security)
}

func IsRouteHomeMismatchError(err error) bool {
	var mismatch RouteHomeMismatchError
	return errors.As(err, &mismatch)
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

func RouteHome(backend manifest.Backend) (string, bool, error) {
	account, routed, err := backendAccountRoute(backend)
	if err != nil || !routed {
		return "", routed, err
	}
	return account.Home, true, nil
}

func StrippedRoutedEnvAllowlist(backend manifest.Backend) []string {
	_, routed := routeAccount(backend.Routing)
	if !routed {
		return nil
	}
	var stripped []string
	for _, name := range backend.EnvAllowlist {
		if isRoutingManagedEnv(name) {
			continue
		}
		if !isRoutedSafeEnvName(name) {
			stripped = append(stripped, name)
		}
	}
	return stripped
}

func CheckRouteHome(backend manifest.Backend, opts Options) error {
	account, routed, err := backendAccountRoute(backend)
	if err != nil || !routed {
		return err
	}
	current := currentHomeDir(opts)
	if current != "" && sameHostPath(current, account.Home) {
		return nil
	}
	message := fmt.Sprintf(
		"backend %q route %q requires login HOME %q, current login HOME %q; launch from the matching OS account",
		backend.Name,
		backend.Routing,
		account.Home,
		current,
	)
	return RouteHomeMismatchError{
		Message:      message,
		BackendName:  backend.Name,
		Routing:      backend.Routing,
		CurrentHome:  current,
		ExpectedHome: account.Home,
	}
}

func backendAccountRoute(backend manifest.Backend) (accountRoute, bool, error) {
	account, routed := routeAccount(backend.Routing)
	if !routed && manifest.RequiresAccountRouting(backend.Kind) {
		return accountRoute{}, false, SecurityError{Message: fmt.Sprintf("backend %q kind %q requires account routing", backend.Name, backend.Kind)}
	}
	if routed {
		if err := assertRoutingBoundary(backend.Routing, account); err != nil {
			return accountRoute{}, false, err
		}
	}
	return account, routed, nil
}

func assertCompiledAccountTable(opts Options) error {
	home := currentHomeDir(opts)
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

func currentHomeDir(opts Options) string {
	if opts.HomeDir != "" {
		return opts.HomeDir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return home
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
		if account.ForgeConfig != WorkForgeConfig || samePathOrWithin(account.ForgeConfig, PrivateHome) {
			return SecurityError{Message: fmt.Sprintf("work route resolved forbidden FORGE_CONFIG %q", account.ForgeConfig)}
		}
	case manifest.RoutingPrivate:
		if account.Home != PrivateHome || samePathOrWithin(account.Home, WorkHome) {
			return SecurityError{Message: fmt.Sprintf("private route resolved forbidden HOME %q", account.Home)}
		}
		if account.ForgeConfig != PrivateForgeConfig || samePathOrWithin(account.ForgeConfig, WorkHome) {
			return SecurityError{Message: fmt.Sprintf("private route resolved forbidden FORGE_CONFIG %q", account.ForgeConfig)}
		}
	}
	return nil
}

func samePathOrWithin(path, root string) bool {
	path = cleanPathForHostCompare(path)
	root = cleanPathForHostCompare(root)
	if path == root {
		return true
	}
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return false
	}
	return rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

func sameHostPath(a, b string) bool {
	return cleanPathForHostCompare(a) == cleanPathForHostCompare(b)
}

func cleanPathForHostCompare(path string) string {
	path = filepath.Clean(path)
	if runtime.GOOS == "darwin" {
		return strings.ToLower(path)
	}
	return path
}

func buildEnv(backend manifest.Backend, environ map[string]string) (map[string]string, error) {
	env := make(map[string]string)
	account, routed, err := backendAccountRoute(backend)
	if err != nil {
		return nil, err
	}
	for _, name := range backend.EnvAllowlist {
		if isRoutingManagedEnv(name) {
			continue
		}
		if routed && !isRoutedSafeEnvName(name) {
			continue
		}
		if val, ok := environ[name]; ok {
			if routed {
				sanitized, keep := sanitizeRoutedEnvValue(backend.Routing, name, val)
				if !keep {
					continue
				}
				env[name] = sanitized
				continue
			}
			env[name] = val
		}
	}
	if routed {
		env["HOME"] = account.Home
		env["FORGE_CONFIG"] = account.ForgeConfig
	}
	return env, nil
}

func isRoutingManagedEnv(name string) bool {
	return name == "HOME" || name == "FORGE_CONFIG"
}

func isRoutedSafeEnvName(name string) bool {
	switch name {
	case "PATH", "TERM", "LANG", "TZ", "COLORTERM", "HTTPS_PROXY", "NO_PROXY", "TMPDIR":
		return true
	case "LC_ALL", "LC_COLLATE", "LC_CTYPE", "LC_MESSAGES", "LC_MONETARY", "LC_NUMERIC", "LC_TIME",
		"LC_ADDRESS", "LC_IDENTIFICATION", "LC_MEASUREMENT", "LC_NAME", "LC_PAPER", "LC_TELEPHONE":
		return true
	default:
		return false
	}
}

func sanitizeRoutedEnvValue(route manifest.Routing, name, value string) (string, bool) {
	if name == "PATH" {
		return sanitizeRoutedPath(route, value)
	}
	if envValueReferencesSiblingHome(route, value) {
		return "", false
	}
	return value, true
}

func sanitizeRoutedPath(route manifest.Routing, value string) (string, bool) {
	forbidden := forbiddenSiblingHome(route)
	if forbidden == "" {
		return value, true
	}
	parts := strings.Split(value, string(os.PathListSeparator))
	kept := make([]string, 0, len(parts))
	for _, part := range parts {
		if samePathOrWithin(part, forbidden) {
			continue
		}
		kept = append(kept, part)
	}
	if len(kept) == 0 {
		return "", false
	}
	return strings.Join(kept, string(os.PathListSeparator)), true
}

func envValueReferencesSiblingHome(route manifest.Routing, value string) bool {
	forbidden := forbiddenSiblingHome(route)
	return forbidden != "" && valueHasPathPrefix(value, forbidden)
}

func forbiddenSiblingHome(route manifest.Routing) string {
	switch route {
	case manifest.RoutingWork:
		return PrivateHome
	case manifest.RoutingPrivate:
		return WorkHome
	default:
		return ""
	}
}

func valueHasPathPrefix(value, root string) bool {
	if root == "" || value == "" {
		return false
	}
	if samePathOrWithin(value, root) {
		return true
	}
	for _, segment := range strings.FieldsFunc(value, pathListOrShellSeparator) {
		if samePathOrWithin(segment, root) {
			return true
		}
	}
	return false
}

func pathListOrShellSeparator(r rune) bool {
	switch r {
	case ':', ' ', '\t', '\n', '"', '\'', '=', ',':
		return true
	default:
		return false
	}
}
