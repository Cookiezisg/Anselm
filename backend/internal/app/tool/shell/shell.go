// Package shell provides the shell-execution system tools the LLM uses
// to run commands on the user's machine: Bash (foreground or background
// process spawn), BashOutput (poll a background process for new output),
// and KillShell (terminate a background process).
//
// Imported as `shelltool` per §S13 nested sub-package alias rule.
//
// Forgify is a local single-user app, so we deliberately DO NOT carry
// Claude Code's banned-command list — the user runs commands they
// authored against their own machine. The risk model is "what the user
// would have typed in their terminal anyway."
//
// Background subsystem: ProcessManager keeps a registry of long-running
// children keyed by `bsh_<16hex>` ID. Output is captured into a per-
// process ring buffer (256 KB) with read-cursor tracking so BashOutput
// can return only new bytes per poll. Children are best-effort killed on
// backend shutdown via Stop().
//
// cwd state machine: AgentState (pkg/agentstate) carries a per-conversation
// cwd. The Bash tool detects an entire-command `cd <path>` and updates
// it; subsequent commands run with that cwd. Chained `cd && other` is
// NOT tracked — the documented limitation, matching how a normal shell
// shows users "your subshell exited and the parent's cwd is unchanged."
//
// Package shell 提供 shell 执行系统工具：Bash（前台或后台进程）、
// BashOutput（轮询后台进程新输出）、KillShell（终止后台进程）。
//
// 按 §S13 嵌套子包别名规则导入为 `shelltool`。
//
// Forgify 是本地单用户应用，故意不带 Claude Code 那张 banned-command 表
// ——用户在自己机器上跑自己写的命令；风险模型即"用户本来就会在终端敲的"。
//
// 后台子系统：ProcessManager 按 `bsh_<16hex>` ID 注册长跑子进程。每进程
// 256 KB 环形输出缓冲 + 读游标，BashOutput 每次只返新字节。后端关停时
// Stop() 尽力杀子。
//
// cwd 状态机：AgentState（pkg/agentstate）携带对话级 cwd；Bash 识别整条
// 命令为 `cd <path>` 时更新；后续命令在新 cwd 跑。链式 `cd && other`
// 不追踪——这是文档化局限，对应"子 shell 退出后父 shell cwd 不变"。
package shell

import (
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// ShellTools constructs the shell system tools sharing one ProcessManager.
// The manager is exposed on the returned struct so cmd/server can call
// Stop() during graceful shutdown.
//
// ShellTools 构造共享一份 ProcessManager 的 shell system tool 集合。
// 返回结构体把 manager 暴露出去，让 cmd/server 优雅关停时调 Stop()。
type ShellTools struct {
	Manager *ProcessManager
	Tools   []toolapp.Tool
}

// NewShellTools wires Bash + BashOutput + KillShell against a fresh
// ProcessManager. The caller owns the manager and should call Stop()
// during shutdown.
//
// NewShellTools 用一个新建的 ProcessManager 装配 Bash + BashOutput + KillShell。
// 调用方拥有 manager，关停时应调 Stop()。
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
