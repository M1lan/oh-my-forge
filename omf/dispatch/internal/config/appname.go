package config

import "os"

// DefaultAppName is the default application name. It can be overridden at build
// time via `-ldflags -X 'omf/dispatch/internal/config.DefaultAppName=omf'`.
var DefaultAppName = "forge"

// AppName returns the current application name, which controls path resolution
// for manifests and adapters. It checks the OMF_APP_NAME environment variable
// first, falling back to DefaultAppName. This single point of configuration
// allows the dispatch layer to swap between forge, omf, and future names without
// structural changes to paths or manifests.
func AppName() string {
	if name := os.Getenv("OMF_APP_NAME"); name != "" {
		return name
	}
	return DefaultAppName
}
