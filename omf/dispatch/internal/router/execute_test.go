package router

import (
	"io"
	"os"
	"sort"
	"strings"
	"testing"
)

func TestExecutePlanUsesExecReplaceForInteractive(t *testing.T) {
	var called bool
	r := Runner{
		ExecReplace: func(argv []string, env map[string]string) error {
			called = true
			assertStrings(t, argv, []string{"forge"})
			return nil
		},
	}
	if err := r.Execute(Plan{Mode: ModeExecReplace, Argv: []string{"forge"}}); err != nil {
		t.Fatalf("Execute returned error: %v", err)
	}
	if !called {
		t.Fatal("ExecReplace was not called")
	}
}

func TestExecutePlanUsesWrappedSubprocessForOneshot(t *testing.T) {
	var called bool
	r := Runner{
		RunSubprocess: func(argv []string, env map[string]string) error {
			called = true
			assertStrings(t, argv, []string{"forge", "-p", "hello"})
			return nil
		},
	}
	if err := r.Execute(Plan{Mode: ModeWrappedSubprocess, Argv: []string{"forge", "-p", "hello"}}); err != nil {
		t.Fatalf("Execute returned error: %v", err)
	}
	if !called {
		t.Fatal("RunSubprocess was not called")
	}
}

func TestExecutePlanUsesSupervisorForLocalLLM(t *testing.T) {
	var called bool
	r := Runner{
		RunSupervisor: func(argv []string, env map[string]string) error {
			called = true
			assertStrings(t, argv, []string{"omf", "llm", "list"})
			return nil
		},
	}
	if err := r.Execute(Plan{Mode: ModeSupervisor, Argv: []string{"omf", "llm", "list"}}); err != nil {
		t.Fatalf("Execute returned error: %v", err)
	}
	if !called {
		t.Fatal("RunSupervisor was not called")
	}
}

func TestEnvListNilFailsClosed(t *testing.T) {
	if got := envList(nil); len(got) != 0 {
		t.Fatalf("envList(nil) len = %d, want 0: %#v", len(got), got)
	}
}

func TestRunSubprocessPassesOnlyResolvedEnvironmentToRealChild(t *testing.T) {
	const childArg = "--omf-printenv-child"
	if hasArg(childArg) {
		env := os.Environ()
		sort.Strings(env)
		_, _ = os.Stdout.WriteString(strings.Join(env, "\n"))
		os.Exit(0)
	}

	t.Setenv("OMF_AMBIENT_SECRET", "must-not-leak")
	exe, err := os.Executable()
	if err != nil {
		t.Fatalf("os.Executable: %v", err)
	}

	resolved := map[string]string{
		"HOME":         PrivateHome,
		"FORGE_CONFIG": PrivateForgeConfig,
		"PATH":         "/usr/bin:/bin",
		"TERM":         "xterm-256color",
	}
	restore, err := captureStdout()
	if err != nil {
		t.Fatalf("capture stdout: %v", err)
	}
	err = runSubprocess([]string{exe, "-test.run=TestRunSubprocessPassesOnlyResolvedEnvironmentToRealChild", "--", childArg}, resolved)
	out, readErr := restore()
	if err != nil {
		t.Fatalf("runSubprocess returned error: %v", err)
	}
	if readErr != nil {
		t.Fatalf("read child stdout: %v", readErr)
	}
	got := splitEnvLines(out)
	want := []string{
		"FORGE_CONFIG=" + PrivateForgeConfig,
		"HOME=" + PrivateHome,
		"PATH=/usr/bin:/bin",
		"TERM=xterm-256color",
	}
	sort.Strings(want)
	assertStrings(t, got, want)
	for _, kv := range got {
		if strings.HasPrefix(kv, "OMF_AMBIENT_SECRET=") {
			t.Fatalf("ambient env leaked into real child: %#v", got)
		}
	}
}

func hasArg(want string) bool {
	for _, arg := range os.Args[1:] {
		if arg == want {
			return true
		}
	}
	return false
}

func captureStdout() (func() (string, error), error) {
	old := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		return nil, err
	}
	os.Stdout = w
	restore := func() (string, error) {
		os.Stdout = old
		_ = w.Close()
		data, readErr := io.ReadAll(r)
		_ = r.Close()
		return string(data), readErr
	}
	return restore, nil
}

func splitEnvLines(out string) []string {
	out = strings.TrimSpace(out)
	if out == "" {
		return nil
	}
	lines := strings.Split(out, "\n")
	sort.Strings(lines)
	return lines
}
