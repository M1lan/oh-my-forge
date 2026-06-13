package router

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

type ExecFunc func(argv []string, env map[string]string) error

type Runner struct {
	ExecReplace   ExecFunc
	RunSubprocess ExecFunc
	RunSupervisor ExecFunc
}

func (r Runner) Execute(plan Plan) error {
	switch plan.Mode {
	case ModeExecReplace:
		fn := r.ExecReplace
		if fn == nil {
			fn = syscallExecReplace
		}
		return fn(plan.Argv, plan.Env)
	case ModeWrappedSubprocess:
		fn := r.RunSubprocess
		if fn == nil {
			fn = runSubprocess
		}
		return fn(plan.Argv, plan.Env)
	case ModeSupervisor:
		fn := r.RunSupervisor
		if fn == nil {
			fn = runSubprocess
		}
		return fn(plan.Argv, plan.Env)
	default:
		return fmt.Errorf("unsupported execution mode %q", plan.Mode)
	}
}

func syscallExecReplace(argv []string, env map[string]string) error {
	if len(argv) == 0 {
		return UsageError{Message: "empty argv"}
	}
	path, err := exec.LookPath(argv[0])
	if err != nil {
		return err
	}
	return syscall.Exec(path, argv, envList(env))
}

func runSubprocess(argv []string, env map[string]string) error {
	if len(argv) == 0 {
		return UsageError{Message: "empty argv"}
	}
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Env = envList(env)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func envList(env map[string]string) []string {
	if env == nil {
		return os.Environ()
	}
	out := make([]string, 0, len(env))
	for k, v := range env {
		out = append(out, k+"="+v)
	}
	return out
}
