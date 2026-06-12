//go:build unix

package shell

import (
	"os/exec"
	"syscall"
)

// setProcessGroup puts the child in its own process group, so killProcessTree can take out
// grandchildren too (sh -c pipelines / daemons keep running — and keep the stdout pipe open —
// if only sh itself is killed).
//
// setProcessGroup 让子进程自成进程组，使 killProcessTree 能连孙进程一起杀（sh -c 的管道 /
// daemon 在只杀 sh 时会继续跑——还攥着 stdout 管道不放）。
func setProcessGroup(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
}

// killProcessTree SIGKILLs the whole process group (negative pid), falling back to killing
// just the direct child when the group is already gone.
//
// killProcessTree 对整个进程组（负 pid）发 SIGKILL，组已不存在时退化为只杀直接子进程。
func killProcessTree(cmd *exec.Cmd) error {
	if cmd == nil || cmd.Process == nil {
		return nil
	}
	if err := syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL); err == nil {
		return nil
	}
	return cmd.Process.Kill()
}
