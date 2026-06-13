package app

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"omf/dispatch/internal/doctor"
	"omf/dispatch/internal/llm"
	"omf/dispatch/internal/manifest"
	"omf/dispatch/internal/mlx"
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
	MLX          MLXClient
	Doctor       DoctorRunner
	Environ      map[string]string
	HomeDir      string
	PathExists   func(string) bool
	LLMTimeout   time.Duration
	Stdout       io.Writer
	Stderr       io.Writer
}

type LLMClient interface {
	List(context.Context) ([]llm.Model, error)
	Load(context.Context, string) error
	Unload(context.Context, string) error
}

type MLXClient interface {
	Inspect(context.Context, string) (mlx.Report, error)
	Load(context.Context, string) (mlx.Report, error)
}

type DoctorRunner interface {
	Run(context.Context) (doctor.Report, error)
}

func (a App) Run(args []string) int {
	if len(args) == 0 {
		a.errorf("usage: omf <profile> [args...]\n")
		return ExitUsage
	}
	if args[0] == "doctor" {
		if len(args) != 1 {
			a.errorf("usage: omf doctor\n")
			return ExitUsage
		}
		return a.runDoctor()
	}
	if args[0] == "llm" {
		return a.runLLM(args[1:])
	}
	if args[0] == "resume" {
		return a.runResume(args[1:])
	}
	if args[0] == "hist" {
		return a.runHist(args[1:])
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

func (a App) runResume(args []string) int {
	if len(args) != 0 {
		a.errorf("usage: omf resume\n")
		return ExitUsage
	}
	return a.execAdapter("resume.bash", nil)
}

func (a App) runHist(args []string) int {
	return a.execAdapter("hist.bash", args)
}

func (a App) execAdapter(script string, args []string) int {
	argv := append([]string{filepath.Join(defaultAdapterDir(), script)}, args...)
	plan := router.Plan{Mode: router.ModeExecReplace, Argv: argv, Env: a.effectiveEnv()}
	if err := a.Runner.Execute(plan); err != nil {
		a.errorf("omf: adapter: %v\n", err)
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
	ctx, cancel := context.WithTimeout(context.Background(), a.llmTimeout())
	defer cancel()

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
	case "mlx":
		return a.runLLMMLX(ctx, args[1:])
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
		a.errorf("usage: omf llm [list|load|unload|mlx]\n")
		return ExitUsage
	}
}

func (a App) runLLMMLX(ctx context.Context, args []string) int {
	manager := a.mlxClient()
	model := mlx.DefaultModelAlias
	load := false
	switch len(args) {
	case 0:
	case 1:
		model = args[0]
		load = true
	default:
		a.errorf("usage: omf llm mlx [model]\n")
		return ExitUsage
	}

	var report mlx.Report
	var err error
	if load {
		report, err = manager.Load(ctx, model)
	} else {
		report, err = manager.Inspect(ctx, model)
	}
	if err != nil {
		a.errorf("omf llm mlx: %v\n", err)
		return ExitError
	}
	a.printMLXReport(report)
	return ExitOK
}

func (a App) printMLXReport(report mlx.Report) {
	_, _ = fmt.Fprintf(
		a.stdout(),
		"mlx\t%s\t%s\twired<=%dGiB memory<=%dGiB cache<=%dGiB\n",
		report.WrapperPath,
		report.ModelID,
		report.Caps.WiredGiB,
		report.Caps.MemoryGiB,
		report.Caps.CacheGiB,
	)
}

func (a App) runDoctor() int {
	ctx, cancel := context.WithTimeout(context.Background(), a.llmTimeout())
	defer cancel()
	report, err := a.doctorRunner().Run(ctx)
	a.printDoctorReport(report)
	if err != nil || !report.OK() {
		if err != nil {
			a.errorf("omf doctor: %v\n", err)
		}
		return ExitError
	}
	return ExitOK
}

func (a App) printDoctorReport(report doctor.Report) {
	for _, check := range report.Checks {
		if check.Message == "" {
			_, _ = fmt.Fprintf(a.stdout(), "%s\t%s\n", check.Status, check.Name)
			continue
		}
		_, _ = fmt.Fprintf(a.stdout(), "%s\t%s\t%s\n", check.Status, check.Name, check.Message)
	}
}

func (a App) llmClient() LLMClient {
	if a.LLM != nil {
		return a.LLM
	}
	return llm.NewClient(llm.Config{})
}

func (a App) mlxClient() MLXClient {
	if a.MLX != nil {
		return a.MLX
	}
	return mlx.Manager{LLM: a.llmClient()}
}

func (a App) doctorRunner() DoctorRunner {
	if a.Doctor != nil {
		return a.Doctor
	}
	path := a.ManifestPath
	if path == "" {
		path = defaultManifestPath()
	}
	return doctor.Runner{
		ManifestPath: path,
		Environ:      a.effectiveEnv(),
		HomeDir:      a.HomeDir,
		PathExists:   a.PathExists,
		MLX:          a.mlxClient(),
	}
}

func (a App) llmTimeout() time.Duration {
	if a.LLMTimeout > 0 {
		return a.LLMTimeout
	}
	return 5 * time.Minute
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

func defaultAdapterDir() string {
	return filepath.Join("..", "adapters")
}
