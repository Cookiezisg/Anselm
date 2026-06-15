// Package shell provides the shell-execution system tools — Bash / BashOutput /
// KillShell — sharing one ProcessManager for background jobs. These are leaf tool
// adapters (no domain / store / handler / DDL / HTTP) implementing the app/tool 5-method
// contract; they belong in Toolset.Resident (high-frequency, always available).
//
// Two deliberate constraints:
//   - NO cwd. The desktop agent has no project root or "current directory"; Bash never
//     remembers a working directory. To target a dir, pass absolute paths or prefix a
//     single command with "cd /abs && ...". (The cwd concept is globally dropped.)
//   - NO per-conversation sandbox auto-route here. Routing python/node commands into a
//     conversation scratch env needs the conversation lifecycle; this package runs the
//     plain system shell and takes no sandbox dependency.
//
// Danger is the LLM's per-call self-report (framework-injected); there is no central
// gate. danger.go adds only a handful of hard blocks for catastrophic unattended
// accidents (rm -rf /, sudo, mkfs, …) — a backstop, not an allow/deny config system.
//
// Package shell 提供 shell 执行系统工具——Bash / BashOutput / KillShell——共享一个
// ProcessManager 管理后台任务。它们是叶子工具适配器（无 domain/store/handler/DDL/HTTP），
// 实现 app/tool 的 5 方法契约；归 Toolset.Resident（高频常驻）。
//
// 两处刻意约束：① 无 cwd——桌面 agent 无项目根/当前目录，
// Bash 不记忆工作目录，要定位目录用绝对路径或单条命令内 "cd /abs && ..."（cwd 概念全局废弃）；
// ② 此处不做 per-conversation sandbox auto-route——把 python/node 路由进对话 scratch env
// 需 conversation 生命周期，本包跑 plain 系统 shell、不依赖 sandbox。
//
// danger 由 LLM 每次自报（framework 注入），无中央门控；danger.go 只加极少数灾难命令硬拦截
// （rm -rf /、sudo、mkfs…）作为无人值守兜底，非 allow/deny 配置系统。
package shell

import (
	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
)

// ShellTools bundles the shell system tools sharing one ProcessManager. The caller (host
// assembly) must call Manager.Stop() on shutdown to reap background children.
//
// ShellTools 是共享一个 ProcessManager 的 shell 系统工具集。调用方（host 装配）关停时
// 须调 Manager.Stop() 回收后台子进程。
type ShellTools struct {
	Manager *ProcessManager
	Tools   []toolapp.Tool
}

// NewShellTools wires Bash + BashOutput + KillShell over a fresh ProcessManager.
//
// NewShellTools 在一个新 ProcessManager 上装配 Bash + BashOutput + KillShell。
func NewShellTools() *ShellTools {
	mgr := NewProcessManager()
	return &ShellTools{
		Manager: mgr,
		Tools: []toolapp.Tool{
			&Bash{mgr: mgr},
			&BashOutput{mgr: mgr},
			&KillShell{mgr: mgr},
		},
	}
}

var (
	_ toolapp.Tool = (*Bash)(nil)
	_ toolapp.Tool = (*BashOutput)(nil)
	_ toolapp.Tool = (*KillShell)(nil)
)
