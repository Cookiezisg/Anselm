// Package subagent (app/subagent) is the service layer for the Subagent
// system tool. Owns the SubagentType registry and the Spawn → loop.Run
// → terminal-write lifecycle.
//
// Sub-run data model (post event-log unification): a sub-run is a
// `messages` row (role=assistant, parent_block_id=msg-block placeholder,
// attrs.kind=subagent_run + type/runId/maxTurns). Sub-run transcript
// is the blocks of that message in `message_blocks` — written real-time
// via emit. There are NO subagent_runs / subagent_messages tables.
//
// V1.2 architecture: chat and subagent both consume the shared
// internal/app/loop ReAct engine. Service.Spawn constructs a
// subagentHost (loop.Host implementation) and calls loop.Run directly.
//
// Recursion defense: structural — Spawn filters the tool list to drop
// SubagentTool itself before calling loop.Run, so the sub-LLM physically
// cannot see the "Subagent" tool name. Runtime — SubagentTool.Execute
// checks reqctxpkg.GetSubagentDepth(ctx); ≥ 1 returns ErrRecursionAttempt.
//
// Per-spawn defenses: 5 min total-timeout context, panic recover so a
// tool implementation crash flips the run to status=failed instead of
// leaving it stuck running, parent-ctx cancel cascades naturally
// because subCtx is derived from parentCtx.
//
// Files:
//
//	subagent.go  — Service struct + New + SetTools + filterTools + composeSystemPrompt
//	spawn.go     — SpawnOpts + SpawnResult + Spawn lifecycle + status constants
//	host.go      — subagentHost (loop.Host implementation)
//	registry.go  — SubagentType registry
//
// Package subagent (app/subagent) 是 Subagent system tool 的 service 层。
// 持有 SubagentType 注册表 + Spawn → loop.Run → 终态写入生命周期。
//
// Sub-run 数据模型（事件日志统一后）：sub-run 是一条 `messages` 行
// （role=assistant，parent_block_id=msg-block 占位，attrs.kind=subagent_run
// + type/runId/maxTurns）。Sub-run 转录是该 message 在 `message_blocks`
// 的 blocks——经 emit 实时写。无 subagent_runs / subagent_messages 表。
package subagent

import (
	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Service ties registry + chat repo (for sub-Message persistence) +
// shared infra together. Spawn (in spawn.go) is the only mutating entry
// point. Parent-cancel cascades naturally via ctx derivation; no
// external cancel API is exposed.
//
// Service 把 registry + chat repo（sub-Message 持久化用）+ 共享 infra
// 串起来。Spawn（spawn.go）是唯一变更入口。父 ctx cancel 经派生自然级联；
// 无外部 cancel API。
type Service struct {
	chatRepo    chatdomain.Repository // for sub-Message writes (no subagent_runs/messages tables anymore)
	registry    *Registry
	tools       []toolapp.Tool
	modelPicker modeldomain.ModelPicker
	keyProvider apikeydomain.KeyProvider
	llmFactory  *llminfra.Factory
	log         *zap.Logger
}

// New constructs a Service. tools may be nil at construction time; call
// SetTools after the global tool list is built (the standard DI pattern
// also used by chat.NewService).
//
// New 构造 Service。tools 可在构造时为 nil；全局 tool 列表建好后调
// SetTools（与 chat.NewService 同模式）。
func New(
	chatRepo chatdomain.Repository,
	registry *Registry,
	modelPicker modeldomain.ModelPicker,
	keyProvider apikeydomain.KeyProvider,
	llmFactory *llminfra.Factory,
	log *zap.Logger,
) *Service {
	if log == nil {
		panic("subagent.New: logger is nil")
	}
	return &Service{
		chatRepo:    chatRepo,
		registry:    registry,
		modelPicker: modelPicker,
		keyProvider: keyProvider,
		llmFactory:  llmFactory,
		log:         log,
	}
}

// SetTools injects the registered global tool list (called after main.go
// builds the slice that includes SubagentTool itself).
//
// SetTools 注入全局 tool 列表（main.go 含 SubagentTool 的 slice 建好后调）。
func (s *Service) SetTools(tools []toolapp.Tool) {
	s.tools = tools
}

// filterTools drops SubagentTool itself (recursion defense — structural)
// and any tools NOT listed in typ.AllowedTools (when AllowedTools is set).
// AllowedTools=nil means "all tools except Subagent allowed".
//
// filterTools 过滤掉 SubagentTool 自身（结构防递归）+ 非 typ.AllowedTools
// 内的工具（AllowedTools 设了时）。AllowedTools=nil 表"除 Subagent 外
// 全部允许"。
func (s *Service) filterTools(typ subagentdomain.SubagentType) []toolapp.Tool {
	if len(s.tools) == 0 {
		return nil
	}
	var allowed map[string]struct{}
	if len(typ.AllowedTools) > 0 {
		allowed = make(map[string]struct{}, len(typ.AllowedTools))
		for _, name := range typ.AllowedTools {
			allowed[name] = struct{}{}
		}
	}
	out := make([]toolapp.Tool, 0, len(s.tools))
	for _, t := range s.tools {
		if t.Name() == "Subagent" {
			continue
		}
		if allowed != nil {
			if _, ok := allowed[t.Name()]; !ok {
				continue
			}
		}
		out = append(out, t)
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// composeSystemPrompt prepends the standard Forgify subagent preamble
// + appends a locale hint (zh-CN only) to the type's system prompt.
//
// composeSystemPrompt 给 type 的 system prompt 前置标准 Forgify subagent
// 序文 + 后接 locale 提示（仅 zh-CN）。
func composeSystemPrompt(typeSystemPrompt string, locale reqctxpkg.Locale) string {
	const preamble = "You are a Forgify subagent — a focused sub-task LLM spawned by the main conversation. " +
		"Stay narrowly on your assigned task; return a concise summary suitable for the parent LLM."
	out := preamble + "\n\n" + typeSystemPrompt
	if locale == reqctxpkg.LocaleZhCN {
		out += "\n\nPlease respond in Chinese (Simplified)."
	}
	return out
}
