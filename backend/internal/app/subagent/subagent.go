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
// Package subagent (app/subagent) 是 Subagent system tool 的 service 层。
// 持有 SubagentType 注册表 + Spawn → loop.Run → 终态写入生命周期。
//
// Sub-run 数据模型（事件日志统一后）：sub-run 是一条 `messages` 行
// （role=assistant，parent_block_id=msg-block 占位，attrs.kind=subagent_run
// + type/runId/maxTurns）。Sub-run 转录是该 message 在 `message_blocks`
// 的 blocks——经 emit 实时写。无 subagent_runs / subagent_messages 表。
package subagent

import (
	"context"
	"fmt"
	"sync"
	"time"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// defaultRunTimeout caps a single Spawn — defends against stuck tool
// calls (e.g. an MCP server that never returns) holding a sub-runner
// forever and burning tokens.
//
// defaultRunTimeout 限定单次 Spawn——防止 stuck tool 让 sub-runner 永挂。
const defaultRunTimeout = 5 * time.Minute

// Sub-run terminal status values returned in SpawnResult.Status. Distinct
// from chatdomain.Status* — these reflect subagent-specific outcomes
// (max_turns is its own bucket, separate from a generic "error").
//
// Sub-run 终态 status 值，返 SpawnResult.Status。与 chatdomain.Status*
// 区分——max_turns 是独立桶，不归"通用 error"。
const (
	StatusCompleted = "completed"
	StatusMaxTurns  = "max_turns"
	StatusCancelled = "cancelled"
	StatusFailed    = "failed"
)

// SpawnOpts overrides per-call. Empty fields fall back to the type's
// defaults.
//
// SpawnOpts per-call 覆盖。空字段回落到类型默认。
type SpawnOpts struct {
	MaxTurns int    // 0 = use type.DefaultMaxTurns
	Model    string // "" = type.DefaultModel ?? PickForChat
}

// SpawnResult is what Service.Spawn hands back. RunID = the sub-Message
// ID (which doubles as the LLM-visible "subagent run id"). Result is the
// last assistant text returned as the tool_result to the parent LLM.
//
// SpawnResult 是 Service.Spawn 的回执。RunID = sub-Message ID（兼作
// LLM 可见的 "subagent run id"）。Result 是返父 LLM 作 tool_result 的
// 最后 assistant 文本。
type SpawnResult struct {
	RunID     string // = sub-Message.ID (msg_<16hex>)
	Type      string // subagent type name (researcher / reviewer / ...)
	Status    string // StatusCompleted | StatusMaxTurns | StatusCancelled | StatusFailed
	ErrorMsg  string // populated when Status == StatusFailed
	Result    string // last assistant text — what the parent LLM sees as tool_result
	TokensIn  int
	TokensOut int
	StepsUsed int
}

// Service ties registry + chat repo (for sub-Message persistence) +
// shared infra together. Spawn is the only mutating entry point;
// Cancel preempts an in-flight spawn.
//
// Service 把 registry + chat repo（sub-Message 持久化用）+ 共享 infra
// 串起来。Spawn 是唯一变更入口；Cancel 抢占进行中的 spawn。
type Service struct {
	chatRepo    chatdomain.Repository // for sub-Message writes (no subagent_runs/messages tables anymore)
	registry    *Registry
	tools       []toolapp.Tool
	modelPicker modeldomain.ModelPicker
	keyProvider apikeydomain.KeyProvider
	llmFactory  *llminfra.Factory
	log         *zap.Logger

	activeRunsMu sync.Mutex
	activeRuns   map[string]context.CancelFunc
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
		activeRuns:  make(map[string]context.CancelFunc),
	}
}

// SetTools injects the registered global tool list (called after main.go
// builds the slice that includes SubagentTool itself).
//
// SetTools 注入全局 tool 列表（main.go 含 SubagentTool 的 slice 建好后调）。
func (s *Service) SetTools(tools []toolapp.Tool) {
	s.tools = tools
}

// Spawn boots one sub-run end-to-end:
//
//   1. resolve type from registry
//   2. filter tools (drop SubagentTool itself for recursion defense)
//   3. resolve LLM bundle
//   4. mint sub-msgID + msg-block placeholder; emit BlockStart + MessageStart
//   5. inject ctx (sub-msgID + RunID + Depth+1) + 5min timeout + cancel
//   6. defer recover (panic → status=failed)
//   7. loop.Run via subagentHost (which writes the sub-Message row at
//      WriteFinalize + emits MessageStop)
//   8. emit BlockStop on the placeholder; record agentstate token log
//   9. return SpawnResult with mapped status / result / tokens
//
// Spawn 一站式启 sub-run：解类型 → 过滤 tools → 解 LLM → 铸 sub-msgID +
// 占位 msg-block + 推 BlockStart/MessageStart → 注 ctx + 超时 + cancel
// → defer recover → loop.Run（host.WriteFinalize 写 sub-Message + 发
// MessageStop）→ 推占位 block 的 BlockStop + 记 agentstate token log →
// 返 SpawnResult。
func (s *Service) Spawn(parentCtx context.Context, typeName, prompt string, opts SpawnOpts) (*SpawnResult, error) {
	typ, ok := s.registry.Get(typeName)
	if !ok {
		return nil, fmt.Errorf("subagentapp.Spawn: %w: %q", subagentdomain.ErrTypeNotFound, typeName)
	}

	parentMsgID, _ := reqctxpkg.GetMessageID(parentCtx)
	parentToolCallID, _ := reqctxpkg.GetToolCallID(parentCtx)
	parentConvID, _ := reqctxpkg.GetConversationID(parentCtx)
	uid, _ := reqctxpkg.GetUserID(parentCtx)

	bundle, err := llmclientpkg.Resolve(parentCtx, s.modelPicker, s.keyProvider, s.llmFactory)
	if err != nil {
		return nil, fmt.Errorf("subagentapp.Spawn resolve LLM: %w", err)
	}

	maxTurns := opts.MaxTurns
	if maxTurns <= 0 {
		maxTurns = typ.DefaultMaxTurns
	}

	// Mint sub-msgID + placeholder message-block. Emit BlockStart +
	// MessageStart so the parent conversation's recursive event tree
	// includes this sub-run inline.
	//
	// 铸 sub-msgID + 占位 message-block。推 BlockStart + MessageStart
	// 让父对话的递归事件树内联这个 sub-run。
	em := eventlogpkg.From(parentCtx)
	subMsgID := idgenpkg.New("msg")
	msgBlockID := ""
	if parentToolCallID != "" && parentMsgID != "" {
		msgBlockID = idgenpkg.New("blk")
		em.EmitBlockStart(parentCtx, msgBlockID, parentToolCallID, parentMsgID,
			eventlogdomain.BlockTypeMessage,
			map[string]any{
				"messageId": subMsgID,
				"type":      typ.Name,
			})
		em.EmitMessageStart(parentCtx, subMsgID, chatdomain.RoleAssistant, msgBlockID,
			map[string]any{
				"kind":     "subagent_run",
				"type":     typ.Name,
				"maxTurns": maxTurns,
			})
	}

	// Compose sub-runner ctx: sub-msgID for emit parent linkage + RunID
	// for tool ctx + bumped depth + total timeout + register cancel so
	// external Cancel(runID) can preempt.
	//
	// 组装 sub-runner ctx：sub-msgID 给 emit 父链 + RunID 给 tool ctx +
	// 加深度 + 加超时 + 注册 cancel 让外部 Cancel(runID) 可抢占。
	subCtx := reqctxpkg.WithSubagentRunID(parentCtx, subMsgID)
	subCtx = reqctxpkg.WithSubagentDepth(subCtx, reqctxpkg.GetSubagentDepth(parentCtx)+1)
	subCtx = reqctxpkg.WithMessageID(subCtx, subMsgID)
	subCtx = reqctxpkg.WithParentBlockID(subCtx, "") // sub blocks attach under sub-msgID
	subCtx, cancel := context.WithTimeout(subCtx, defaultRunTimeout)
	defer cancel()

	s.activeRunsMu.Lock()
	s.activeRuns[subMsgID] = cancel
	s.activeRunsMu.Unlock()
	defer func() {
		s.activeRunsMu.Lock()
		delete(s.activeRuns, subMsgID)
		s.activeRunsMu.Unlock()
	}()

	host := &subagentHost{
		svc:           s,
		subMsgID:      subMsgID,
		parentConvID:  parentConvID,
		parentBlockID: msgBlockID,
		uid:           uid,
		typeName:      typ.Name,
		maxTurns:      maxTurns,
		tools:         s.filterTools(typ),
		userPrompt:    prompt,
		systemPrompt:  composeSystemPrompt(typ.SystemPrompt, reqctxpkg.GetLocale(parentCtx)),
	}

	baseReq := llminfra.Request{
		ModelID: bundle.ModelID,
		Key:     bundle.Key,
		BaseURL: bundle.BaseURL,
		System:  host.systemPrompt,
	}

	var (
		result loopapp.Result
		runErr error
	)
	func() {
		defer func() {
			if r := recover(); r != nil {
				runErr = fmt.Errorf("subagent panic: %v", r)
				s.log.Error("subagent run panicked",
					zap.String("sub_msg_id", subMsgID), zap.Any("panic", r))
			}
		}()
		result = loopapp.Run(subCtx, host, bundle.Client, baseReq, maxTurns, s.log)
	}()

	// Map loop.Result → SpawnResult.Status. loop returns
	// chatdomain.Status* + StopReason*; we re-map cancelled / max-tokens
	// to subagent-specific buckets.
	//
	// 映射 loop.Result → SpawnResult.Status。
	spawn := &SpawnResult{
		RunID:     subMsgID,
		Type:      typ.Name,
		Result:    result.LastMessage,
		TokensIn:  result.TokensIn,
		TokensOut: result.TokensOut,
		StepsUsed: result.Steps,
	}
	switch {
	case runErr != nil:
		spawn.Status = StatusFailed
		spawn.ErrorMsg = runErr.Error()
	case result.StopReason == chatdomain.StopReasonCancelled:
		spawn.Status = StatusCancelled
	case result.StopReason == chatdomain.StopReasonMaxTokens:
		spawn.Status = StatusMaxTurns
	case result.Status == chatdomain.StatusError:
		spawn.Status = StatusFailed
		spawn.ErrorMsg = result.StopReason
	default:
		spawn.Status = StatusCompleted
	}

	// Close placeholder message-block on the parent's eventlog.
	// 关父对话 eventlog 上的占位 message-block。
	if msgBlockID != "" {
		closeStatus := eventlogdomain.StatusCompleted
		switch spawn.Status {
		case StatusFailed:
			closeStatus = eventlogdomain.StatusError
		case StatusCancelled:
			closeStatus = eventlogdomain.StatusCancelled
		}
		em.StopBlock(parentCtx, msgBlockID, closeStatus, nil)
	}

	// Append to per-conversation token log (UI cost panel).
	// 追加对话级 token log（UI 成本面板）。
	if state, ok := reqctxpkg.GetAgentState(parentCtx); ok && state != nil {
		state.AddSubagentTokens(subMsgID, typ.Name, spawn.TokensIn, spawn.TokensOut)
	}

	s.log.Info("subagent run terminated",
		zap.String("sub_msg_id", subMsgID),
		zap.String("type", typ.Name),
		zap.String("status", spawn.Status),
		zap.Int("tokens_in", spawn.TokensIn),
		zap.Int("tokens_out", spawn.TokensOut),
		zap.Int("steps", spawn.StepsUsed))

	return spawn, runErr
}

// Cancel preempts a running sub-run via its registered cancel func. No-op
// when the run isn't found (already terminated; race with finish).
//
// Cancel 通过注册的 cancel func 抢占运行中的 sub-run。run 找不到时空操作。
func (s *Service) Cancel(_ context.Context, runID string) error {
	s.activeRunsMu.Lock()
	cancel, ok := s.activeRuns[runID]
	s.activeRunsMu.Unlock()
	if !ok {
		return nil
	}
	cancel()
	return nil
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
