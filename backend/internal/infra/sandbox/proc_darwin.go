//go:build darwin

package sandbox

import (
	"os/exec"
	"syscall"
)

// setupProcessGroup puts cmd's child in its own process group; call before Start.
//
// setupProcessGroup 让 cmd 的 child 在独立进程组；必须在 Start 前调。
func setupProcessGroup(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
}

// killProcessGroup sends SIGKILL to the entire process group via -pid.
//
// killProcessGroup 给整个进程组发 SIGKILL（负 pid）。
func killProcessGroup(cmd *exec.Cmd) error {
	if cmd.Process == nil {
		return nil
	}
	if err := syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL); err == nil {
		return nil
	}
	// The group leader may already be gone while a runtime wrapper has changed the
	// group shape. Match the shell reaper: fall back to the direct child rather than
	// turning an idempotent cleanup into a health warning.
	return cmd.Process.Kill()
}
