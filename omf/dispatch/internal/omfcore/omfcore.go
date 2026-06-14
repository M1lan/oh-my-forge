// Package omfcore is the Go client for the compiled omf-core security floor.
//
// omf-core (omf/core, Rust) is a separate, small, audited binary. The
// dispatcher shells out to it over a stable argv/exit-code contract and never
// links it -- so the safety-critical secrets + memory-guard logic lives in one
// reviewed place. This package is the only Go caller of that contract.
//
// Exit-code contract (mirrors core/src/lib.rs exit::*):
//
//	0 OK   1 ERR   2 USAGE   3 REFUSED
//
// REFUSED (3) is a first-class, expected outcome (work-account refusal, no
// keychain cache, over-budget non-MLX admission) and is surfaced as ErrRefused
// rather than a generic failure.
package omfcore

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"omf/dispatch/internal/manifest"
)

// Exit codes mirrored from omf-core (core/src/lib.rs exit::*).
const (
	exitOK      = 0
	exitRefused = 3
)

// PrivateOpAccount is the only 1Password account omf-core reads for a private
// route. Mirrors secrets.rs PRIVATE_OP_ACCOUNT; omf-core itself refuses the
// work account, this constant just spares callers from hardcoding it.
const PrivateOpAccount = "my.1password.eu"

// EnvVar overrides binary discovery with an explicit path.
const EnvVar = "OMF_CORE_BIN"

// ErrUnavailable means the omf-core binary could not be located. Callers in
// non-critical paths (secrets injection, doctor) treat this as "skip", not a
// hard failure, so a host without omf-core installed still runs.
var ErrUnavailable = errors.New("omf-core binary not found")

// ErrRefused maps omf-core exit code 3 (REFUSED).
var ErrRefused = errors.New("omf-core refused")

// Caps are the MLX memory-floor constants reported by `guard caps`.
type Caps struct {
	WiredGiB  uint64
	MemoryGiB uint64
	CacheGiB  uint64
}

type runResult struct {
	stdout []byte
	stderr []byte
	code   int
}

// Client invokes the omf-core binary.
type Client struct {
	// Bin is the omf-core path. Empty => Locate() resolves it lazily.
	Bin string
	// run is injectable for tests. nil => execRun (real subprocess).
	run func(ctx context.Context, bin string, args []string) (runResult, error)
}

// New returns a Client that resolves omf-core lazily via Locate().
func New() *Client { return &Client{} }

// Locate resolves the omf-core binary: $OMF_CORE_BIN, then $PATH, then
// $HOME/.local/bin/omf-core. Returns ErrUnavailable when none is executable.
func Locate() (string, error) {
	if p := os.Getenv(EnvVar); p != "" && fileExecutable(p) {
		return p, nil
	}
	if p, err := exec.LookPath("omf-core"); err == nil {
		return p, nil
	}
	if home := manifest.HomeDir(); home != "" {
		cand := filepath.Join(home, ".local", "bin", "omf-core")
		if fileExecutable(cand) {
			return cand, nil
		}
	}
	return "", ErrUnavailable
}

func fileExecutable(p string) bool {
	info, err := os.Stat(p)
	return err == nil && !info.IsDir() && info.Mode()&0o111 != 0
}

func (c *Client) bin() (string, error) {
	if c.Bin != "" {
		return c.Bin, nil
	}
	return Locate()
}

func (c *Client) exec(ctx context.Context, args []string) (runResult, error) {
	bin, err := c.bin()
	if err != nil {
		return runResult{}, err
	}
	runner := c.run
	if runner == nil {
		runner = execRun
	}
	return runner(ctx, bin, args)
}

// execRun runs omf-core. A non-zero exit is a normal result (the contract uses
// exit codes for REFUSED etc.), not a Go error; only a spawn failure errors.
func execRun(ctx context.Context, bin string, args []string) (runResult, error) {
	cmd := exec.CommandContext(ctx, bin, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	res := runResult{stdout: stdout.Bytes(), stderr: stderr.Bytes()}
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			res.code = ee.ExitCode()
			return res, nil
		}
		return runResult{}, err
	}
	return res, nil
}

// SecretsEnv asks omf-core to emit a scrubbed child env for the allowlisted
// names from the private-vault keychain cache. Returns only names present in
// the cache. ErrRefused when omf-core has no cache or the account is the work
// account; ErrUnavailable when omf-core is missing. An empty allow list is a
// no-op (no subprocess).
func (c *Client) SecretsEnv(ctx context.Context, allow []string, opAccount string) (map[string]string, error) {
	if len(allow) == 0 {
		return map[string]string{}, nil
	}
	if opAccount == "" {
		opAccount = PrivateOpAccount
	}
	res, err := c.exec(ctx, []string{
		"secrets", "env",
		"--allow", strings.Join(allow, ","),
		"--op-account", opAccount,
	})
	if err != nil {
		return nil, err
	}
	switch res.code {
	case exitOK:
		return parseNulEnv(res.stdout), nil
	case exitRefused:
		return nil, fmt.Errorf("%w: %s", ErrRefused, stderrMsg(res))
	default:
		return nil, fmt.Errorf("omf-core secrets env failed (exit %d): %s", res.code, stderrMsg(res))
	}
}

// parseNulEnv parses omf-core's NUL-delimited `NAME=value\0` stream. NUL
// delimiting lets values contain any byte except NUL (newlines, =, quotes).
func parseNulEnv(b []byte) map[string]string {
	out := make(map[string]string)
	for _, rec := range bytes.Split(b, []byte{0}) {
		if len(rec) == 0 {
			continue
		}
		k, v, ok := bytes.Cut(rec, []byte{'='})
		if !ok || len(k) == 0 {
			continue
		}
		out[string(k)] = string(v)
	}
	return out
}

// GuardCaps returns the MLX memory-floor constants compiled into omf-core, so
// the dispatcher/doctor can verify its own constants agree with the floor.
func (c *Client) GuardCaps(ctx context.Context) (Caps, error) {
	res, err := c.exec(ctx, []string{"guard", "caps"})
	if err != nil {
		return Caps{}, err
	}
	if res.code != exitOK {
		return Caps{}, fmt.Errorf("omf-core guard caps failed (exit %d): %s", res.code, stderrMsg(res))
	}
	var caps Caps
	for _, line := range strings.Split(string(res.stdout), "\n") {
		k, v, ok := strings.Cut(strings.TrimSpace(line), "=")
		if !ok {
			continue
		}
		n, perr := strconv.ParseUint(strings.TrimSpace(v), 10, 64)
		if perr != nil {
			continue
		}
		switch k {
		case "wired_gib":
			caps.WiredGiB = n
		case "memory_gib":
			caps.MemoryGiB = n
		case "cache_gib":
			caps.CacheGiB = n
		}
	}
	return caps, nil
}

// GuardAdmit asks omf-core whether a peak allocation fits the budget. Returns
// nil to proceed (admit, or MLX warn-but-proceed), ErrRefused when a non-MLX
// request is over budget.
func (c *Client) GuardAdmit(ctx context.Context, peakGiB, budgetGiB uint64, isMLX bool) error {
	args := []string{
		"guard", "admit",
		"--peak", strconv.FormatUint(peakGiB, 10),
		"--budget", strconv.FormatUint(budgetGiB, 10),
	}
	if isMLX {
		args = append(args, "--mlx")
	}
	res, err := c.exec(ctx, args)
	if err != nil {
		return err
	}
	switch res.code {
	case exitOK:
		return nil
	case exitRefused:
		return fmt.Errorf("%w: %s", ErrRefused, stderrMsg(res))
	default:
		return fmt.Errorf("omf-core guard admit failed (exit %d): %s", res.code, stderrMsg(res))
	}
}

// GuardLockFree probes the single-flight runtime lock. Returns true when free,
// false when another run holds it. omf-core releases the lock as it exits, so
// this is a best-effort preflight probe, not a held lock.
func (c *Client) GuardLockFree(ctx context.Context, path string) (bool, error) {
	args := []string{"guard", "lock"}
	if path != "" {
		args = append(args, "--path", path)
	}
	res, err := c.exec(ctx, args)
	if err != nil {
		return false, err
	}
	switch res.code {
	case exitOK:
		return true, nil
	case exitRefused:
		return false, nil
	default:
		return false, fmt.Errorf("omf-core guard lock failed (exit %d): %s", res.code, stderrMsg(res))
	}
}

func stderrMsg(res runResult) string {
	return strings.TrimSpace(string(res.stderr))
}
