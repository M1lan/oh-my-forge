package router

import (
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
