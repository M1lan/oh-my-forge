package router

import (
	"errors"
	"fmt"

	"omf/dispatch/internal/manifest"
)

type Mode string

const (
	ModeExecReplace       Mode = "exec-replace"
	ModeWrappedSubprocess Mode = "wrapped-subprocess"
	ModeSupervisor        Mode = "supervisor"
)

type Options struct {
	Environ    map[string]string
	HomeDir    string
	PathExists func(string) bool
}

type Plan struct {
	Backend manifest.Backend
	Mode    Mode
	Argv    []string
	Env     map[string]string
}

type UsageError struct{ Message string }

func (e UsageError) Error() string { return e.Message }

func IsUsageError(err error) bool {
	var usage UsageError
	return errors.As(err, &usage)
}

func ResolveProfile(m manifest.Manifest, args []string, opts Options) (Plan, error) {
	if err := assertCompiledAccountTable(opts); err != nil {
		return Plan{}, err
	}
	if len(args) == 0 {
		return Plan{}, UsageError{Message: "missing profile"}
	}
	profile := args[0]
	backend, ok := findBackend(m, profile)
	if !ok {
		return Plan{}, UsageError{Message: fmt.Sprintf("unknown profile %q", profile)}
	}

	extra := append([]string(nil), args[1:]...)
	if backend.Kind == manifest.KindLocalLLM {
		env, err := buildEnv(backend, opts.Environ)
		if err != nil {
			return Plan{}, err
		}
		argv := append([]string(nil), backend.Interactive...)
		argv = append(argv, extra...)
		return Plan{Backend: backend, Mode: ModeSupervisor, Argv: argv, Env: env}, nil
	}

	if len(extra) > 0 && extra[0] == "-p" {
		if len(backend.Oneshot) == 0 {
			return Plan{}, UsageError{Message: fmt.Sprintf("profile %q does not support oneshot", profile)}
		}
		env, err := buildEnv(backend, opts.Environ)
		if err != nil {
			return Plan{}, err
		}
		argv := append([]string(nil), backend.Oneshot...)
		argv = append(argv, extra[1:]...)
		return Plan{Backend: backend, Mode: ModeWrappedSubprocess, Argv: argv, Env: env}, nil
	}

	if len(backend.Interactive) == 0 {
		return Plan{}, UsageError{Message: fmt.Sprintf("profile %q does not support interactive", profile)}
	}
	env, err := buildEnv(backend, opts.Environ)
	if err != nil {
		return Plan{}, err
	}
	argv := append([]string(nil), backend.Interactive...)
	argv = append(argv, extra...)
	return Plan{Backend: backend, Mode: ModeExecReplace, Argv: argv, Env: env}, nil
}

func findBackend(m manifest.Manifest, name string) (manifest.Backend, bool) {
	for _, b := range m.Backends {
		if b.Name == name {
			return b, true
		}
	}
	return manifest.Backend{}, false
}
