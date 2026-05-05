//go:build linux

// proc_linux.go: process tree management for Linux. Two layers:
//
//   - Process group via Setpgid=true, so killProcessGroup can send a
//     signal to the entire group (forge → uv → pip → python descendants).
//   - PR_SET_PDEATHSIG=SIGTERM via Pdeathsig field, so children are
//     told by the kernel to receive SIGTERM the moment Forgify (their
//     parent) dies — defends against app crashes that bypass our
//     graceful Shutdown hook. Linux-only kernel feature; macOS has no
//     equivalent and falls back to A+B-only protection (see
//     sandbox.md §15.1 / §17 for the full leak-prevention plan).
//
// proc_linux.go：Linux 进程树管理。两层：
//
//   - 进程组（Setpgid=true）让 killProcessGroup 能给整组发信号
//     （forge → uv → pip → python 等后代）。
//   - PR_SET_PDEATHSIG=SIGTERM（Pdeathsig 字段）让 child 在 Forgify
//     （父进程）死的瞬间收到内核发的 SIGTERM——防 app crash 绕开我们
//     优雅 Shutdown hook 的场景。Linux 内核特性；macOS 无等价 fallback
//     到 A+B 兜底（见 sandbox.md §15.1 / §17 完整 leak 防御方案）。

package sandbox

import (
	"os/exec"
	"syscall"
)

// setupProcessGroup configures cmd's child to live in its own process
// group AND receive SIGTERM when Forgify (its parent) dies. Must be
// called before cmd.Start().
//
// setupProcessGroup 配 cmd 让 child 生活在独立进程组 + Forgify（父）死时
// 收 SIGTERM。必须在 cmd.Start() 前调。
func setupProcessGroup(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setpgid:   true,
		Pdeathsig: syscall.SIGTERM,
	}
}

// killProcessGroup sends SIGKILL to cmd's entire process group via -pid
// (negative pid targets the group rather than a single process). Used as
// the cmd.Cancel callback for ctx-cancel propagation. Returns nil if the
// process never started (cmd.Process == nil).
//
// killProcessGroup 给 cmd 的整个进程组发 SIGKILL（负 pid 指向进程组而非
// 单进程）。作 cmd.Cancel callback 传播 ctx 取消。进程未启动
// （cmd.Process == nil）返 nil。
func killProcessGroup(cmd *exec.Cmd) error {
	if cmd.Process == nil {
		return nil
	}
	return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
}
