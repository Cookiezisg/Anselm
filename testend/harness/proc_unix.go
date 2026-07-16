//go:build unix

// Process-containment primitives, unix flavour. testend is unix-only in practice — the scenarios
// already reach straight for syscall.Kill / lsof / sqlite3 — so there is deliberately no windows
// twin: an implementation we never run would be fiction, not portability.
//
// 进程收容原语（unix）。testend 实际只跑 unix（scenarios 本就直接用 syscall.Kill / lsof / sqlite3），
// 故刻意不设 windows 孪生——造一个从不运行的实现是虚构、不是可移植性。
package harness

import (
	"os"
	"os/exec"
	"syscall"
)

// stopSignals are the interruptions a `go test` run actually receives: Ctrl-C at the terminal, or a
// supervisor's kill.
//
// stopSignals 是 `go test` 真会收到的中断：终端 Ctrl-C，或上级进程的 kill。
var stopSignals = []os.Signal{os.Interrupt, syscall.SIGTERM}

// setupProcessGroup puts the backend in its OWN process group (pgid == its pid); call before Start.
// Mirrors backend's infra/sandbox/proc_darwin.go — restated rather than imported (black-box rule).
//
// Two consequences, both wanted: (a) one negative-pid signal reaches the server AND every process it
// spawned that did not set its own group — notably the resident llama-server embedder, spawned with a
// bare exec.Command; (b) the sweep can never touch the test process itself, which stays in its own
// separate group.
//
// setupProcessGroup 让 backend 进入**自己的**进程组（pgid == 其 pid）；须在 Start 前调。对标 backend 的
// infra/sandbox/proc_darwin.go——复述而非 import（黑盒铁律）。两个后果都是想要的：(a) 一个负 pid 信号即可
// 触达 server 及其所有未自设进程组的子孙——尤其是裸 exec.Command 起的常驻 llama-server embedder；(b) 清扫
// 永远碰不到测试进程自己（它留在另一个组里）。
func setupProcessGroup(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
}

// terminate asks ONE process to stop gracefully. SIGTERM — not os.Process.Kill, which is an
// uncatchable SIGKILL — is what the backend's signal.NotifyContext actually listens for.
//
// terminate 请求**单个**进程优雅停止。backend 的 signal.NotifyContext 监听的是 SIGTERM，而非
// os.Process.Kill（那是不可捕获的 SIGKILL）。
func terminate(p *os.Process) error { return p.Signal(syscall.SIGTERM) }

// killProcessGroup SIGKILLs every member of pgid.
//
// killProcessGroup 给 pgid 的所有成员发 SIGKILL。
func killProcessGroup(pgid int) { _ = syscall.Kill(-pgid, syscall.SIGKILL) }

// processGroupAlive reports whether pgid still has any member (signal 0 = pure existence probe). A
// not-yet-reaped zombie still counts — so callers must poll, never sample once.
//
// processGroupAlive 报告 pgid 是否还有成员（signal 0 = 纯存在性探针）。尚未被收尸的僵尸也算——故调用方
// 必须轮询、不能只采样一次。
func processGroupAlive(pgid int) bool { return syscall.Kill(-pgid, syscall.Signal(0)) == nil }
