package omfcore

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"
)

// fakeRun records the args omf-core was called with and returns a canned result.
func fakeRun(out, errOut string, code int) (func(context.Context, string, []string) (runResult, error), *[]string) {
	var gotArgs []string
	fn := func(_ context.Context, _ string, args []string) (runResult, error) {
		gotArgs = args
		return runResult{stdout: []byte(out), stderr: []byte(errOut), code: code}, nil
	}
	return fn, &gotArgs
}

func TestSecretsEnvParsesNulDelimitedStream(t *testing.T) {
	// Values intentionally contain =, newline, and shell metachars to prove
	// NUL-delimiting (not line-splitting) is used.
	run, gotArgs := fakeRun("GH_TOKEN=ghp_x=y\nz\x00OP_KEY=$(whoami)`\x00", "", exitOK)
	c := &Client{Bin: "/fake/omf-core", run: run}

	env, err := c.SecretsEnv(context.Background(), []string{"GH_TOKEN", "OP_KEY"}, "")
	if err != nil {
		t.Fatalf("SecretsEnv error: %v", err)
	}
	want := map[string]string{"GH_TOKEN": "ghp_x=y\nz", "OP_KEY": "$(whoami)`"}
	if !reflect.DeepEqual(env, want) {
		t.Fatalf("env = %#v, want %#v", env, want)
	}
	wantArgs := []string{"secrets", "env", "--allow", "GH_TOKEN,OP_KEY", "--op-account", PrivateOpAccount}
	if !reflect.DeepEqual(*gotArgs, wantArgs) {
		t.Fatalf("args = %#v, want %#v", *gotArgs, wantArgs)
	}
}

func TestSecretsEnvEmptyAllowIsNoSubprocess(t *testing.T) {
	called := false
	c := &Client{Bin: "/fake/omf-core", run: func(context.Context, string, []string) (runResult, error) {
		called = true
		return runResult{}, nil
	}}
	env, err := c.SecretsEnv(context.Background(), nil, "")
	if err != nil {
		t.Fatalf("SecretsEnv error: %v", err)
	}
	if called {
		t.Fatal("empty allow list must not spawn omf-core")
	}
	if len(env) != 0 {
		t.Fatalf("env = %#v, want empty", env)
	}
}

func TestSecretsEnvRefusedMapsToErrRefused(t *testing.T) {
	run, _ := fakeRun("", "no keychain cache -- refusing", exitRefused)
	c := &Client{Bin: "/fake/omf-core", run: run}
	_, err := c.SecretsEnv(context.Background(), []string{"GH_TOKEN"}, "")
	if !errors.Is(err, ErrRefused) {
		t.Fatalf("err = %v, want ErrRefused", err)
	}
}

func TestSecretsEnvUnavailableWhenBinaryMissing(t *testing.T) {
	t.Setenv(EnvVar, filepath.Join(t.TempDir(), "does-not-exist"))
	t.Setenv("PATH", t.TempDir()) // ensure exec.LookPath fails
	t.Setenv("HOME", t.TempDir()) // ensure ~/.local/bin/omf-core fails
	c := New()
	_, err := c.SecretsEnv(context.Background(), []string{"GH_TOKEN"}, "")
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v, want ErrUnavailable", err)
	}
}

func TestGuardCapsParsesKeyValues(t *testing.T) {
	run, _ := fakeRun("wired_gib=14\nmemory_gib=18\ncache_gib=2\n", "", exitOK)
	c := &Client{Bin: "/fake/omf-core", run: run}
	caps, err := c.GuardCaps(context.Background())
	if err != nil {
		t.Fatalf("GuardCaps error: %v", err)
	}
	if caps != (Caps{WiredGiB: 14, MemoryGiB: 18, CacheGiB: 2}) {
		t.Fatalf("caps = %#v", caps)
	}
}

func TestGuardAdmitOKAndRefused(t *testing.T) {
	okRun, gotArgs := fakeRun("admit\n", "", exitOK)
	c := &Client{Bin: "/fake/omf-core", run: okRun}
	if err := c.GuardAdmit(context.Background(), 10, 18, true); err != nil {
		t.Fatalf("admit error: %v", err)
	}
	wantArgs := []string{"guard", "admit", "--peak", "10", "--budget", "18", "--mlx"}
	if !reflect.DeepEqual(*gotArgs, wantArgs) {
		t.Fatalf("args = %#v, want %#v", *gotArgs, wantArgs)
	}

	refuseRun, _ := fakeRun("", "refuse: peak 20 exceeds budget 18", exitRefused)
	c = &Client{Bin: "/fake/omf-core", run: refuseRun}
	if err := c.GuardAdmit(context.Background(), 20, 18, false); !errors.Is(err, ErrRefused) {
		t.Fatalf("err = %v, want ErrRefused", err)
	}
}

func TestGuardLockFree(t *testing.T) {
	freeRun, _ := fakeRun("free: /x\n", "", exitOK)
	c := &Client{Bin: "/fake/omf-core", run: freeRun}
	free, err := c.GuardLockFree(context.Background(), "")
	if err != nil || !free {
		t.Fatalf("free=%v err=%v, want true/nil", free, err)
	}

	heldRun, _ := fakeRun("", "held", exitRefused)
	c = &Client{Bin: "/fake/omf-core", run: heldRun}
	free, err = c.GuardLockFree(context.Background(), "/custom")
	if err != nil || free {
		t.Fatalf("free=%v err=%v, want false/nil", free, err)
	}
}

// TestEndToEndAgainstStubBinary exercises the real execRun path (subprocess,
// exit codes, NUL stream) against a tiny shell stub standing in for omf-core.
func TestEndToEndAgainstStubBinary(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("stub uses a POSIX shell")
	}
	dir := t.TempDir()
	stub := filepath.Join(dir, "omf-core")
	// Emits one NAME=value record NUL-terminated for `secrets env`, exit 3 for
	// `guard admit` to simulate a refusal.
	script := "#!/usr/bin/env bash\n" +
		"if [[ \"$1\" == secrets && \"$2\" == env ]]; then printf 'GH_TOKEN=abc\\0'; exit 0; fi\n" +
		"if [[ \"$1\" == guard && \"$2\" == caps ]]; then printf 'wired_gib=14\\nmemory_gib=18\\ncache_gib=2\\n'; exit 0; fi\n" +
		"if [[ \"$1\" == guard && \"$2\" == admit ]]; then echo 'refuse' >&2; exit 3; fi\n" +
		"exit 2\n"
	if err := os.WriteFile(stub, []byte(script), 0o755); err != nil {
		t.Fatalf("write stub: %v", err)
	}
	c := &Client{Bin: stub}

	env, err := c.SecretsEnv(context.Background(), []string{"GH_TOKEN"}, "")
	if err != nil || env["GH_TOKEN"] != "abc" {
		t.Fatalf("SecretsEnv stub: env=%#v err=%v", env, err)
	}
	caps, err := c.GuardCaps(context.Background())
	if err != nil || caps != (Caps{14, 18, 2}) {
		t.Fatalf("GuardCaps stub: caps=%#v err=%v", caps, err)
	}
	if err := c.GuardAdmit(context.Background(), 20, 18, false); !errors.Is(err, ErrRefused) {
		t.Fatalf("GuardAdmit stub err = %v, want ErrRefused", err)
	}
}

func TestLocatePrefersEnvVar(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "omf-core")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatalf("write: %v", err)
	}
	t.Setenv(EnvVar, bin)
	got, err := Locate()
	if err != nil || got != bin {
		t.Fatalf("Locate = %q, %v; want %q", got, err, bin)
	}
}
