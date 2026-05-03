// Package filesystem provides the local-filesystem system tools the LLM
// uses to read, write, and edit files on the user's machine: Read / Write
// / Edit (Phase 5 file-ops batch).
//
// Imported as `fstool` per §S13 nested sub-package alias rule. Distinguish
// from any future `fileapp` (no such app domain currently exists; mentioned
// here only to avoid future confusion).
//
// Path safety: every tool accepts only absolute paths and routes them
// through `pkg/pathguard` to deny known-sensitive locations (~/.ssh,
// ~/.aws, /etc/, Forgify's own state dir, etc.). See decision D5 in
// 02-tools-deep/03-shell.md for why we use a thin deny-list rather than
// OS-level sandboxing.
//
// Cross-tool state: Read / Write / Edit share an `AgentState.SeenFiles`
// map injected via `pkg/reqctx` so Edit and Write can enforce
// must-Read-first. The map is per-conversation and lives on the chat
// layer's convQueue.
//
// Package filesystem 提供 LLM 操作用户本机文件系统的 system tool：
// Read / Write / Edit（Phase 5 file-ops 批次）。
//
// 调用方按 §S13 嵌套子包别名规则导入为 `fstool`。
//
// 路径安全：每个 tool 仅接受绝对路径，并通过 `pkg/pathguard` 拒绝已知敏感
// 位置（~/.ssh、~/.aws、/etc/、Forgify 自家状态目录等）。为何用薄黑名单
// 而非 OS-level sandbox，见 02-tools-deep/03-shell.md 决策 D5。
//
// 跨 tool 状态：Read / Write / Edit 共享 `AgentState.SeenFiles` map，通过
// `pkg/reqctx` 注入到 ctx，让 Edit 和 Write 能强制 must-Read-first。该 map
// per-conversation，挂在 chat 层的 convQueue 上。
package filesystem

import (
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	pathguardpkg "github.com/sunweilin/forgify/backend/internal/pkg/pathguard"
)

// FilesystemTools constructs the file-operation system tools wired with
// their dependencies. Returns []toolapp.Tool because the chat ReAct loop
// consumes the abstract Tool interface.
//
// FilesystemTools 构造装配好依赖的文件操作 system tool。返回
// []toolapp.Tool——chat ReAct 循环消费的是抽象 Tool 接口。
func FilesystemTools(pathGuard pathguardpkg.PathGuard) []toolapp.Tool {
	return []toolapp.Tool{
		&Read{pathGuard: pathGuard},
		&Write{pathGuard: pathGuard},
		&Edit{pathGuard: pathGuard},
	}
}
