package app

import (
	"fmt"
	"os"
	"strings"

	"omf/dispatch/internal/manifest"
	"omf/dispatch/internal/router"
)

const (
	ExitOK    = 0
	ExitError = 1
	ExitUsage = 2
)

type App struct {
	ManifestPath string
	Runner       router.Runner
	Environ      map[string]string
	Stderr       *os.File
}

func (a App) Run(args []string) int {
	if len(args) == 0 {
		a.errorf("usage: omf <profile> [args...]\n")
		return ExitUsage
	}
	path := a.ManifestPath
	if path == "" {
		path = defaultManifestPath()
	}
	m, logs, err := manifest.LoadFile(path)
	if err != nil {
		a.errorf("omf: load manifest: %v\n", err)
		return ExitError
	}
	for _, log := range logs {
		a.errorf("omf: clamped %s.%s from %d to %d\n", log.Backend, log.Field, log.Requested, log.ClampedTo)
	}
	plan, err := router.ResolveProfile(m, args, router.Options{Environ: a.effectiveEnv()})
	if err != nil {
		a.errorf("omf: %v\n", err)
		if router.IsUsageError(err) {
			return ExitUsage
		}
		return ExitError
	}
	if err := a.Runner.Execute(plan); err != nil {
		a.errorf("omf: execute: %v\n", err)
		return ExitError
	}
	return ExitOK
}

func (a App) effectiveEnv() map[string]string {
	if a.Environ != nil {
		return a.Environ
	}
	env := make(map[string]string)
	for _, item := range os.Environ() {
		k, v, ok := strings.Cut(item, "=")
		if ok {
			env[k] = v
		}
	}
	return env
}

func (a App) errorf(format string, args ...any) {
	w := a.Stderr
	if w == nil {
		w = os.Stderr
	}
	_, _ = fmt.Fprintf(w, format, args...)
}

func defaultManifestPath() string {
	return "../omf.toml"
}
