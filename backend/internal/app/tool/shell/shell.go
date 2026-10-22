// Package shell provides the shell-execution system tools — Bash / BashOutput /
// KillShell — sharing one ProcessManager for background jobs. These are leaf tool
// adapters (no domain / store / handler / DDL / HTTP) implementing the app/tool 5-method
// contract; they belong in Toolset.Resident (high-frequency, always available).
//
// Two facts about where commands run:
//   - The cwd is the CONVERSATION's, and only when the user mounted one. A thread may carry a work
//     dir (its "residency", conversations.work_dir); when it does, Bash sets cmd.Dir to it so `ls`
//     and every relative path in the command mean what the user means by "here". Unmounted — the
//     default — nothing is set and the child inherits the backend process's directory, so absolute
//     paths (or a leading "cd /abs && …") remain the way to target a directory. Either way cd never
//     carries across calls: this package still keeps NO state of its own about directories, it just
//     reads the one the turn's ctx hands it (reqctx.GetWorkDir).
//   - NO per-conversation sandbox auto-route here. Routing python/node commands into a
//     conversation scratch env needs the conversation lifecycle; this package runs the
//     plain system shell and takes no sandbox dependency.
//
// Danger is the LLM's per-call self-report (framework-injected); there is no allow/deny
// list. Two small nets sit under it: danger.go hard-blocks a handful of catastrophic unattended
// accidents (rm -rf /, sudo, mkfs, …), and callfloor.go forces the human gate for an HTTP DELETE or
// a destructive file operation aimed outside the residency, because the self-report alone was
// measured to be bypassable (docs/working/eval-benchmark, S11).
//
// Package shell 提供 shell 执行系统工具——Bash / BashOutput / KillShell——共享一个
// ProcessManager 管理后台任务。它们是叶子工具适配器（无 domain/store/handler/DDL/HTTP），
// 实现 app/tool 的 5 方法契约；归 Toolset.Resident（高频常驻）。
//
// 关于命令在哪里跑的两个事实：① cwd 是**对话的**，且仅在用户挂了它时才有——线程可以带一个工作目录
// （它的「驻地」，conversations.work_dir）；带了时 Bash 把 cmd.Dir 设为它，故 `ls` 与命令里每个相对
// 路径都表示用户所说的「这里」。未挂（默认）则什么都不设、子进程继承后端进程的目录，故定位目录仍靠
// 绝对路径（或开头的 "cd /abs && …"）。两种情形下 cd 都不跨调用留存：本包**仍然**不自持任何关于目录
// 的状态，它只是读回合 ctx 递给它的那一个（reqctx.GetWorkDir）；
// ② 此处不做 per-conversation sandbox auto-route——把 python/node 路由进对话 scratch env
// 需 conversation 生命周期，本包跑 plain 系统 shell、不依赖 sandbox。
//
// danger 由 LLM 每次自报（framework 注入），没有 allow/deny 名单。自报之下垫两张小网：danger.go 硬拦截
// 极少数灾难命令（rm -rf /、sudo、mkfs…）；callfloor.go 对 HTTP DELETE 与指向驻地之外的破坏性文件操作
// 强制开人闸——因为单靠自报被实测证明可绕过（docs/working/eval-benchmark，S11）。
package shell

import (
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

// ShellTools bundles the shell system tools sharing one ProcessManager. The caller (host
// assembly) must call Manager.Stop() on shutdown to reap background children, and
// Manager.ReapStaleOnBoot() at boot to reap groups a prior ungraceful exit orphaned.
//
// ShellTools 是共享一个 ProcessManager 的 shell 工具集。调用方（host 装配）关停时须调
// Manager.Stop() 回收后台子进程，boot 时须调 Manager.ReapStaleOnBoot() 回收上次非优雅
// 退出留下的孤儿进程组。
type ShellTools struct {
	Manager *ProcessManager
	Tools   []toolapp.Tool
}

// NewShellTools wires Bash + BashOutput + KillShell over a fresh ProcessManager whose
// crash-recovery pid manifest lives under pidDir ("" disables persistence).
//
// NewShellTools 在一个新 ProcessManager 上装配 Bash + BashOutput + KillShell；崩溃恢复
// pid 清单落在 pidDir（"" 关闭持久化）。
func NewShellTools(pidDir string) *ShellTools {
	mgr := NewProcessManager(pidDir)
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
