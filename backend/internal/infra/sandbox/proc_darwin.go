//go:build darwin

// proc_darwin.go: process tree management for macOS. Setpgid is the
// standard unix mechanism (works identically on darwin and linux); macOS
// has no kernel-level "kill children when parent dies" hook (no
// equivalent to Linux's PR_SET_PDEATHSIG), so crash-time leak prevention
// relies on:
//
//   - Layer A: Service.Shutdown() in the SIGTERM/SIGINT handler killing
//     all registered LongLived handles before main returns.
//   - Layer B: Sandbox boot scans the manifest for PIDs that were running
//     last time, kills any survivors, and clears the PID column.
//
// Catastrophic crash (kill -9 of the Forgify process itself) on macOS will
// still leak children. Documented in sandbox.md §17 Windows-vs-others
// risk matrix.
//
// proc_darwin.go：macOS 进程树管理。Setpgid 是标准 unix 机制
// （darwin 和 linux 行为一致）；macOS 无 "父死时杀 child" 的内核级 hook
// （无 Linux PR_SET_PDEATHSIG 等价物），crash 时 leak 防御靠：
//
//   - 层 A：SIGTERM/SIGINT handler 中调 Service.Shutdown() 在 main 返前杀
//     所有注册的 LongLived handle。
//   - 层 B：Sandbox 启动扫 manifest 找上次记录的 PID，活的杀掉清掉。
//
// 灾难性 crash（kill -9 Forgify 进程本身）在 macOS 仍会 leak child。
// 见 sandbox.md §17 Windows-vs-others 风险矩阵。

package sandbox

import (
	"os/exec"
	"syscall"
)

// setupProcessGroup configures cmd's child to live in its own process
// group. Must be called before cmd.Start().
//
// setupProcessGroup 配 cmd 让 child 跑在独立进程组。必须在 cmd.Start() 前调。
func setupProcessGroup(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
}

// killProcessGroup sends SIGKILL to cmd's entire process group via -pid.
// See proc_linux.go for the shared rationale.
//
// killProcessGroup 给 cmd 的整个进程组发 SIGKILL（负 pid）。
// 共同理由见 proc_linux.go。
func killProcessGroup(cmd *exec.Cmd) error {
	if cmd.Process == nil {
		return nil
	}
	return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
}
