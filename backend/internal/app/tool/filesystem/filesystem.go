// Package filesystem provides the three local-filesystem system tools (Read /
// Write / Edit) for the LLM. They share an injected PathGuard (read denies and
// write-only extras like .git/) and cooperate through ctx-carried AgentState to
// enforce the write-before-read invariant — a Write or Edit on a path the LLM
// has not Read this run is refused.
//
// The package is a leaf tool adapter: no domain, no store, no handler. The host
// (chat / agent / subagent / scheduler) seeds the AgentState into ctx before
// invoking the loop; tools here just read it.
//
// Package filesystem 提供本机文件系统的三件 system tool（Read / Write / Edit）。三者共享注入的
// PathGuard（读 deny 与 .git/ 等写专属 extras）并通过 ctx 携带的 AgentState 协作执行写前必读
// 不变式——本次运行内 LLM 没 Read 过的路径，Write/Edit 拒绝。
//
// 本包是叶子工具适配器：无 domain / store / handler。host（chat / agent / subagent / scheduler）
// 跑 loop 前把 AgentState 埋进 ctx，本包工具读取即可。
package filesystem

import (
	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
	pathguardpkg "github.com/sunweilin/foryx/backend/internal/pkg/pathguard"
)

// FilesystemTools constructs the three file-operation tools wired with their
// shared PathGuard.
//
// FilesystemTools 用共享 PathGuard 装配三件文件操作 tool。
func FilesystemTools(pathGuard pathguardpkg.PathGuard) []toolapp.Tool {
	return []toolapp.Tool{
		&Read{pathGuard: pathGuard},
		&Write{pathGuard: pathGuard},
		&Edit{pathGuard: pathGuard},
	}
}
