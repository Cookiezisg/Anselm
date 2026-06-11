//go:build windows

package shell

import "os/exec"

// setProcessGroup is a no-op on Windows (no POSIX process groups; cmd.exe children are not
// reparented the way Unix daemons are, and WaitDelay still bounds any pipe-holder hang).
//
// setProcessGroup 在 Windows 上是 no-op（无 POSIX 进程组；cmd.exe 子进程不像 Unix daemon 那样
// 转挂，且 WaitDelay 仍兜住任何管道持有者导致的挂死）。
func setProcessGroup(*exec.Cmd) {}

// killProcessTree kills the direct child only.
//
// killProcessTree 只杀直接子进程。
func killProcessTree(cmd *exec.Cmd) error {
	if cmd == nil || cmd.Process == nil {
		return nil
	}
	return cmd.Process.Kill()
}
