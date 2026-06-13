package app

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"omf/dispatch/internal/llm"
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
	LLM          LLMClient
	Environ      map[string]string
	HomeDir      string
	PathExists   func(string) bool
	Stdout       io.Writer
	Stderr       io.Writer
}

type LLMClient interface {
	List(context.Context) ([]llm.Model, error)
	Load(context.Context, string) error
	Unload(context.Context, string) error
}

func (a App) Run(args []string) int {
	if len(args) == 0 {
		a.errorf("usage: omf <profile> [args...]\n")
		return ExitUsage
	}
	if args[0] == "llm" {
		return a.runLLM(args[1:])
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
	plan, err := router.ResolveProfile(m, args, router.Options{Environ: a.effectiveEnv(), HomeDir: a.HomeDir, PathExists: a.PathExists})
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

func (a App) runLLM(args []string) int {
	verb := "list"
	if len(args) > 0 {
		verb = args[0]
	}
	client := a.llmClient()
	ctx := context.Background()

	switch verb {
	case "list":
		if len(args) > 1 {
			a.errorf("usage: omf llm [list]\n")
			return ExitUsage
		}
		models, err := client.List(ctx)
		if err != nil {
			a.errorf("omf llm: list: %v\n", err)
			return ExitError
		}
		for _, model := range models {
			_, _ = fmt.Fprintf(a.stdout(), "%s\t%s\n", model.Name, model.Source)
		}
		return ExitOK
	case "load":
		if len(args) != 2 {
			a.errorf("usage: omf llm load <model>\n")
			return ExitUsage
		}
		if err := client.Load(ctx, args[1]); err != nil {
			a.errorf("omf llm: load: %v\n", err)
			return ExitError
		}
		return ExitOK
	case "unload":
		if len(args) != 2 {
			a.errorf("usage: omf llm unload <model>\n")
			return ExitUsage
		}
		if err := client.Unload(ctx, args[1]); err != nil {
			a.errorf("omf llm: unload: %v\n", err)
			return ExitError
		}
		return ExitOK
	default:
		a.errorf("usage: omf llm [list|load|unload]\n")
		return ExitUsage
	}
}

func (a App) llmClient() LLMClient {
	if a.LLM != nil {
		return a.LLM
	}
	return llm.NewClient(llm.Config{})
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

func (a App) stdout() io.Writer {
	if a.Stdout != nil {
		return a.Stdout
	}
	return os.Stdout
}

func defaultManifestPath() string {
	return "../omf.toml"
}
