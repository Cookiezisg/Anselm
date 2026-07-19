//go:build windows

package shell

import (
	"os"
	"os/exec"
)

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

// groupAlive is always false on Windows (no POSIX process groups): the crash-recovery record's
// lifetime ends with the direct child, matching the single-pid live kill path above.
//
// groupAlive 在 Windows 恒为 false（无 POSIX 进程组）：崩溃恢复记录随直接子进程一起了结，
// 与上面单 pid 的活杀路径对齐。
func groupAlive(int) bool { return false }

// reapStaleGroup best-effort kills the single recorded pid — mirrors the sandbox boot reaper's
// Windows half (app/sandbox/reap_windows.go): no pgroups, no leadership check, best-effort.
//
// reapStaleGroup best-effort 杀记录的单个 pid——对标 sandbox boot 回收器的 Windows 半
// （app/sandbox/reap_windows.go）：无进程组、无组长校验、尽力而为。
func reapStaleGroup(pid int) bool {
	if pid <= 0 {
		return false
	}
	p, err := os.FindProcess(pid) // Windows: errors when the pid no longer exists. Windows 上 pid 不存在时报错。
	if err != nil {
		return false
	}
	return p.Kill() == nil
}
