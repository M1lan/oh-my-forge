package doctor

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"omf/dispatch/internal/manifest"
	"omf/dispatch/internal/mlx"
	"omf/dispatch/internal/omfcore"
	"omf/dispatch/internal/router"
)

// DefaultManifestPath is the resolved default location of the omf manifest,
// shared with the dispatcher via manifest.DefaultPath() so doctor and
// `omf <profile>` can never validate different manifests.
var DefaultManifestPath = manifest.DefaultPath() //nolint:gochecknoglobals

type Status string

const (
	StatusOK     Status = "ok"
	StatusFailed Status = "failed"
	StatusWarn   Status = "warn"
)

type Check struct {
	Name    string
	Status  Status
	Message string
}

type Report struct {
	Checks []Check
}

func (r Report) OK() bool {
	for _, check := range r.Checks {
		if check.Status == StatusFailed {
			return false
		}
	}
	return true
}

type MLXInspector interface {
	Inspect(context.Context, string) (mlx.Report, error)
}

type Runner struct {
	ManifestPath string
	Environ      map[string]string
	HomeDir      string
	PathExists   func(string) bool
	LookPath     func(string) (string, error)
	MLX          MLXInspector
	// CoreLocate / CoreCaps probe the compiled omf-core floor; nil => the live
	// omfcore client. Injected in tests so doctor runs without the binary.
	CoreLocate func() (string, error)
	CoreCaps   func(context.Context) (omfcore.Caps, error)
}

func (r Runner) Run(ctx context.Context) (Report, error) {
	var report Report
	path := r.ManifestPath
	if path == "" {
		path = manifest.DefaultPath()
	}

	m, logs, err := manifest.LoadFile(path)
	if err != nil {
		report.add(Check{Name: "manifest validate", Status: StatusFailed, Message: err.Error()})
		return report, err
	}
	if err := m.Validate(); err != nil {
		report.add(Check{Name: "manifest validate", Status: StatusFailed, Message: err.Error()})
		return report, err
	}
	if len(logs) == 0 {
		report.add(Check{Name: "manifest validate", Status: StatusOK, Message: path})
	} else {
		report.add(Check{Name: "manifest validate", Status: StatusWarn, Message: clampSummary(logs)})
	}

	if err := validateBackends(m); err != nil {
		report.add(Check{Name: "backend discovery", Status: StatusFailed, Message: err.Error()})
		return report, err
	}
	report.add(Check{Name: "backend discovery", Status: StatusOK, Message: fmt.Sprintf("%d backend(s)", len(m.Backends))})

	if err := r.checkRouteHomes(&report, m); err != nil {
		return report, err
	}
	r.checkEnvAllowlists(&report, m)
	if err := r.checkProfiles(&report, m); err != nil {
		return report, err
	}
	if err := r.checkDependencies(&report, m); err != nil {
		return report, err
	}
	if err := r.checkMLX(ctx, &report, m); err != nil {
		return report, err
	}
	r.checkCore(ctx, &report)
	return report, nil
}

func (r *Report) add(check Check) {
	r.Checks = append(r.Checks, check)
}

func validateBackends(m manifest.Manifest) error {
	if len(m.Backends) == 0 {
		return fmt.Errorf("manifest has no backends")
	}
	for _, backend := range m.Backends {
		if len(backend.Interactive) == 0 && len(backend.Oneshot) == 0 {
			return fmt.Errorf("backend %q has no interactive or oneshot argv", backend.Name)
		}
	}
	return nil
}

func (r Runner) checkRouteHomes(report *Report, m manifest.Manifest) error {
	opts := router.Options{
		HomeDir:    r.HomeDir,
		PathExists: r.PathExists,
	}
	for _, backend := range m.Backends {
		home, routed, err := router.RouteHome(backend)
		if err != nil {
			report.add(Check{Name: "route home " + backend.Name, Status: StatusFailed, Message: err.Error()})
			return err
		}
		if !routed {
			continue
		}
		if err := router.CheckRouteHome(backend, opts); err != nil {
			if router.IsRouteHomeMismatchError(err) {
				report.add(Check{Name: "route home " + backend.Name, Status: StatusWarn, Message: err.Error()})
				continue
			}
			report.add(Check{Name: "route home " + backend.Name, Status: StatusFailed, Message: err.Error()})
			return err
		}
		report.add(Check{Name: "route home " + backend.Name, Status: StatusOK, Message: home})
	}
	return nil
}

func (r Runner) checkEnvAllowlists(report *Report, m manifest.Manifest) {
	for _, backend := range m.Backends {
		stripped := router.StrippedRoutedEnvAllowlist(backend)
		if len(stripped) == 0 {
			continue
		}
		report.add(Check{Name: "env allowlist " + backend.Name, Status: StatusWarn, Message: "stripped routed env_allowlist entries: " + strings.Join(stripped, ", ")})
	}
}

func (r Runner) checkProfiles(report *Report, m manifest.Manifest) error {
	for _, backend := range m.Backends {
		if len(backend.Interactive) == 0 {
			continue
		}
		_, err := router.ResolveProfile(m, []string{backend.Name}, router.Options{
			Environ:                r.effectiveEnv(),
			HomeDir:                r.HomeDir,
			PathExists:             r.PathExists,
			AllowRouteHomeMismatch: true,
		})
		if err != nil {
			report.add(Check{Name: "profile " + backend.Name, Status: StatusFailed, Message: err.Error()})
			return err
		}
		report.add(Check{Name: "profile " + backend.Name, Status: StatusOK})
	}
	return nil
}

func (r Runner) checkDependencies(report *Report, m manifest.Manifest) error {
	seen := make(map[string]bool)
	for _, backend := range m.Backends {
		argv := firstCommand(backend)
		if len(argv) == 0 {
			continue
		}
		cmd := argv[0]
		if cmd == "omf" {
			report.add(Check{Name: "dep " + backend.Name, Status: StatusOK, Message: "internal omf command"})
			continue
		}
		if seen[cmd] {
			report.add(Check{Name: "dep " + backend.Name, Status: StatusOK, Message: cmd})
			continue
		}
		seen[cmd] = true
		if _, err := r.lookPath(cmd); err != nil {
			report.add(Check{Name: "dep " + backend.Name, Status: StatusFailed, Message: err.Error()})
			return err
		}
		report.add(Check{Name: "dep " + backend.Name, Status: StatusOK, Message: cmd})
	}
	return nil
}

func firstCommand(backend manifest.Backend) []string {
	if len(backend.Interactive) > 0 {
		return backend.Interactive
	}
	return backend.Oneshot
}

func (r Runner) checkMLX(ctx context.Context, report *Report, m manifest.Manifest) error {
	backend, ok := firstLocalLLMBackend(m)
	if !ok {
		report.add(Check{Name: "mlx wrapper caps", Status: StatusWarn, Message: "no local-llm backend"})
		report.add(Check{Name: "mlx llama-swap entry", Status: StatusWarn, Message: "no local-llm backend"})
		report.add(Check{Name: "mlx runtime safety", Status: StatusWarn, Message: "no local-llm backend"})
		return nil
	}
	inspector := r.MLX
	if inspector == nil {
		inspector = mlx.Manager{}
	}
	mlxReport, err := inspector.Inspect(ctx, backend.Name)
	if err != nil {
		report.add(Check{Name: "mlx wrapper caps", Status: StatusFailed, Message: err.Error()})
		report.add(Check{Name: "mlx llama-swap entry", Status: StatusFailed, Message: err.Error()})
		report.add(Check{Name: "mlx runtime safety", Status: StatusFailed, Message: err.Error()})
		return err
	}
	if mlxReport.Caps.WiredGiB <= manifest.MLXWiredLimitGiB && mlxReport.Caps.MemoryGiB <= manifest.MLXMemoryLimitGiB && mlxReport.Caps.CacheGiB <= manifest.MLXCacheLimitGiB {
		report.add(Check{Name: "mlx wrapper caps", Status: StatusOK, Message: fmt.Sprintf("wired<=%dGiB memory<=%dGiB cache<=%dGiB", mlxReport.Caps.WiredGiB, mlxReport.Caps.MemoryGiB, mlxReport.Caps.CacheGiB)})
	} else {
		report.add(Check{Name: "mlx wrapper caps", Status: StatusFailed, Message: "caps exceed floor"})
		return fmt.Errorf("mlx caps exceed floor")
	}
	if mlxReport.UsesWrapper && mlxReport.CheckEndpoint == "/v1/models" {
		report.add(Check{Name: "mlx llama-swap entry", Status: StatusOK, Message: mlxReport.ModelID})
	} else {
		report.add(Check{Name: "mlx llama-swap entry", Status: StatusFailed, Message: "model entry does not use safe wrapper"})
		return fmt.Errorf("mlx llama-swap entry drift")
	}
	if mlxReport.GroupSwap && mlxReport.GroupExclusive && mlxReport.GroupMember && mlxReport.HasNoSuspension && mlxReport.PromptCacheBytes <= manifest.MLXCacheLimitGiB<<30 {
		report.add(Check{Name: "mlx runtime safety", Status: StatusOK, Message: "swap+exclusive, no suspension, prompt cache within cap"})
		return nil
	}
	report.add(Check{Name: "mlx runtime safety", Status: StatusFailed, Message: "runtime safety drift"})
	return fmt.Errorf("mlx runtime safety drift")
}

// checkCore probes the compiled omf-core security floor. Absence is a warning,
// not a failure: the dispatcher still runs without it (degraded -- no secret
// injection, no admission gate), and doctor is also run in environments where
// the floor is intentionally not installed. A cap disagreement between the Go
// dispatcher and the Rust floor IS a failure -- the two compiled constant sets
// must never drift, or admission decisions diverge from the clamp.
func (r Runner) checkCore(ctx context.Context, report *Report) {
	locate := r.CoreLocate
	if locate == nil {
		locate = omfcore.Locate
	}
	bin, err := locate()
	if err != nil {
		report.add(Check{Name: "omf-core floor", Status: StatusWarn, Message: "not installed -- secrets/guard floor inactive (run: just install-bin)"})
		return
	}
	caps := r.CoreCaps
	if caps == nil {
		caps = omfcore.New().GuardCaps
	}
	got, err := caps(ctx)
	if err != nil {
		report.add(Check{Name: "omf-core floor", Status: StatusFailed, Message: "guard caps failed: " + err.Error()})
		return
	}
	if got.WiredGiB != manifest.MLXWiredLimitGiB || got.MemoryGiB != manifest.MLXMemoryLimitGiB || got.CacheGiB != manifest.MLXCacheLimitGiB {
		report.add(Check{Name: "omf-core floor", Status: StatusFailed, Message: fmt.Sprintf(
			"cap drift: core wired=%d memory=%d cache=%d, dispatcher wired=%d memory=%d cache=%d",
			got.WiredGiB, got.MemoryGiB, got.CacheGiB,
			manifest.MLXWiredLimitGiB, manifest.MLXMemoryLimitGiB, manifest.MLXCacheLimitGiB)})
		return
	}
	report.add(Check{Name: "omf-core floor", Status: StatusOK, Message: fmt.Sprintf(
		"%s wired=%d memory=%d cache=%d", bin, got.WiredGiB, got.MemoryGiB, got.CacheGiB)})
}

func firstLocalLLMBackend(m manifest.Manifest) (manifest.Backend, bool) {
	for _, backend := range m.Backends {
		if backend.Kind == manifest.KindLocalLLM {
			return backend, true
		}
	}
	return manifest.Backend{}, false
}

func (r Runner) effectiveEnv() map[string]string {
	if r.Environ != nil {
		return r.Environ
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

func (r Runner) lookPath(name string) (string, error) {
	if r.LookPath != nil {
		return r.LookPath(name)
	}
	return exec.LookPath(name)
}

func clampSummary(logs []manifest.ClampLog) string {
	parts := make([]string, 0, len(logs))
	for _, log := range logs {
		parts = append(parts, fmt.Sprintf("%s.%s:%d->%d", log.Backend, log.Field, log.Requested, log.ClampedTo))
	}
	return strings.Join(parts, ", ")
}
