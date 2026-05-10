// Package subagent is the domain layer for the Subagent system tool —
// Forgify's "spawn an isolated LLM loop" primitive. The LLM sees one
// tool, Subagent(prompt, type), which boots a sub-runner with its own
// context window, a curated tool list (filtered to the type's whitelist
// + the Subagent tool itself physically removed to prevent recursion),
// and bounded turns. The sub-runner returns its last assistant message
// as the parent LLM's tool_result.
//
// Sub-run data model (post event-log unification): a sub-run is a row
// in the unified `messages` table (role=assistant, parent_block_id=
// msg-block placeholder, attrs.kind=subagent_run + type/runId/maxTurns).
// Sub-run transcript is the blocks of that message in `message_blocks`,
// written real-time via the eventlog Emitter. There are NO
// subagent_runs / subagent_messages tables.
//
// This package only carries the SubagentType registry shape + the
// recursion-defense sentinel. The Service / Spawn / Cancel APIs live
// in app/subagent.
//
// Package subagent 是 Subagent system tool 的 domain 层。LLM 看到一个
// 工具 Subagent(prompt, type)，启 sub-runner（独立 context window、
// 经类型白名单过滤的 tool 列表、Subagent 工具自身物理排除以防递归、
// 有界 turns）；sub-runner 跑完把 last assistant message 当 tool_result
// 返父 LLM。
//
// Sub-run 数据模型（事件日志统一后）：sub-run 是统一 `messages` 表的
// 一行（role=assistant，parent_block_id=msg-block 占位，attrs.kind=
// subagent_run + type/runId/maxTurns）。Sub-run 转录是该 message 在
// `message_blocks` 的 blocks——经 eventlog Emitter 实时写。无
// subagent_runs / subagent_messages 表。
//
// 本包仅承载 SubagentType 注册表形状 + 防递归 sentinel。Service /
// Spawn / Cancel API 在 app/subagent。
package subagent

import "errors"

// ── SubagentType (registry entry) ────────────────────────────────────

// SubagentType is one entry in the in-memory registry the LLM sees as
// the legal `subagent_type` argument values. AllowedTools is matched
// against Tool.Name() at spawn time; an empty slice means "inherit
// the parent registry minus the Subagent tool itself" (general-purpose
// uses this; explicit types use a whitelist).
//
// SubagentType 是内存注册表中的一项；LLM 把它当 `subagent_type` 合法值。
// AllowedTools 在 spawn 时按 Tool.Name() 匹配；空 slice = "继承父注册表
// 但去掉 Subagent 工具本身"（general-purpose 用这条；显式类型用白名单）。
type SubagentType struct {
	Name            string   `json:"name"`
	SystemPrompt    string   `json:"systemPrompt"`
	AllowedTools    []string `json:"allowedTools"`
	DefaultMaxTurns int      `json:"defaultMaxTurns"`
}

// ── Sentinels ────────────────────────────────────────────────────────

// ErrTypeNotFound is returned by Service.Spawn when the requested
// type name doesn't match any registered SubagentType.
//
// ErrTypeNotFound 由 Service.Spawn 在请求 type name 不匹配任何注册
// SubagentType 时返。
var ErrTypeNotFound = errors.New("subagent: type not found")

// ErrRecursionAttempt is returned by SubagentTool.Execute when a sub-run
// tries to call Subagent again (depth check via reqctx). Belt-and-suspenders
// behind the structural defense (Service.filterTools strips SubagentTool
// from sub-run's tool list — sub-LLM physically can't see it).
//
// ErrRecursionAttempt 由 SubagentTool.Execute 在 sub-run 试图再调
// Subagent 时返（reqctx depth 检查）。结构性防御（Service.filterTools
// 在 sub-run 工具列表里剥掉 SubagentTool——sub-LLM 物理看不到）的双
// 保险。
var ErrRecursionAttempt = errors.New("subagent: nested spawn not allowed")
