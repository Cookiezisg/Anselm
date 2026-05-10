// spawn.go — Service.Spawn lifecycle: resolve type / filter tools /
// resolve LLM / mint sub-msgID + placeholder message-block / inject
// ctx / defer recover / loop.Run via subagentHost / emit BlockStop on
// placeholder / map loop.Result → SpawnResult.
//
// spawn.go ——Service.Spawn 全生命周期：解类型 / 过滤 tools / 解 LLM /
// 铸 sub-msgID + 占位 message-block / 注 ctx / defer recover / 经
// subagentHost 调 loop.Run / 推占位 BlockStop / 映 loop.Result → SpawnResult。
package subagent

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// defaultRunTimeout caps a single Spawn — the sole preemption mechanism
// for sub-runs. Defends against stuck tool calls (e.g. an MCP server
// that never returns) holding a sub-runner forever and burning tokens.
// Parent-ctx cancel cascades naturally via ctx derivation; no external
// cancel API exists.
//
// defaultRunTimeout 限定单次 Spawn——sub-run 唯一的抢占机制。防止 stuck
// tool 让 sub-runner 永挂。父 ctx cancel 经派生自然级联；无外部 cancel API。
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
	MaxTurns int // 0 = use type.DefaultMaxTurns
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

// Spawn boots one sub-run end-to-end. See file header for full
// lifecycle. Never returns a partial SpawnResult — on any error a
// SpawnResult with Status=StatusFailed + ErrorMsg is returned (plus
// the error for the caller to propagate / log).
//
// Spawn 一站式启 sub-run。完整生命周期见文件头。从不返部分 SpawnResult
// ——任何错误都返 Status=StatusFailed + ErrorMsg 的 SpawnResult（同时返
// error 让调用方上抛 / log）。
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

	// Compose sub-runner ctx: sub-msgID for emit parent linkage + bumped
	// depth + total timeout. Re-stamp the emitter explicitly (it's also
	// inherited via the WithValue chain from parentCtx, but the explicit
	// With makes the emit lineage robust to future ctx refactors that
	// might break the implicit chain).
	//
	// 组装 sub-runner ctx：sub-msgID 给 emit 父链 + 加深度 + 加超时。emitter
	// 显式再挂一遍（虽经 WithValue 链从 parentCtx 隐式继承也能用，但显式
	// 让 emit 血统对未来 ctx 重构更鲁棒）。
	subCtx := reqctxpkg.WithSubagentDepth(parentCtx, reqctxpkg.GetSubagentDepth(parentCtx)+1)
	subCtx = reqctxpkg.WithMessageID(subCtx, subMsgID)
	subCtx = reqctxpkg.WithParentBlockID(subCtx, "") // sub blocks attach under sub-msgID
	subCtx = eventlogpkg.With(subCtx, em)
	subCtx, cancel := context.WithTimeout(subCtx, defaultRunTimeout)
	defer cancel()

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

	// Reconcile sub-Message row's status with the subagent-bucket
	// re-mapping (loop.Run wrote the chatdomain.Status* version via
	// host.WriteFinalize before we re-mapped to StatusMaxTurns / Failed
	// / Cancelled here). Use a detached ctx with uid + convID so a
	// cancelled parent doesn't drop the reconcile.
	//
	// 重对齐 sub-Message 行的 status 与 subagent 桶映射（loop.Run 在我们
	// 这里 re-map 到 MaxTurns/Failed/Cancelled 前已经经 host.WriteFinalize
	// 写入了 chatdomain.Status* 版本）。用 detached ctx 含 uid + convID 防
	// parent cancel 丢更新。
	if spawn.Status != StatusCompleted {
		reconcileCtx := reqctxpkg.SetUserID(context.Background(), uid)
		reconcileCtx = reqctxpkg.WithConversationID(reconcileCtx, parentConvID)
		if existing, err := s.chatRepo.GetMessage(reconcileCtx, subMsgID); err == nil && existing != nil {
			existing.Status = spawn.Status
			if spawn.ErrorMsg != "" {
				existing.ErrorMessage = spawn.ErrorMsg
			}
			if err := s.chatRepo.SaveMessage(reconcileCtx, existing); err != nil {
				s.log.Warn("subagent status reconcile write failed",
					zap.String("sub_msg_id", subMsgID),
					zap.String("status", spawn.Status),
					zap.Error(err))
			}
		}
	}

	// Close placeholder message-block on the parent's eventlog. Use
	// detached ctx (uid + convID) so a parent cancel between the sub-
	// run finishing and this StopBlock emit doesn't leave the frontend
	// with a dangling block_start (§S21 invariant violation). Same
	// reasoning as the reconcileCtx above + chat/host.go::StopMessage
	// fix from commit f272503.
	//
	// 关父对话 eventlog 上的占位 message-block。用 detached ctx（uid + convID）
	// 防 parent 在 sub-run 结束到 StopBlock emit 之间 cancel——否则前端
	// 留 dangling block_start (§S21 违规)。同上方 reconcileCtx + chat/host.go
	// commit f272503 的逻辑。
	if msgBlockID != "" {
		closeStatus := eventlogdomain.StatusCompleted
		switch spawn.Status {
		case StatusFailed:
			closeStatus = eventlogdomain.StatusError
		case StatusCancelled:
			closeStatus = eventlogdomain.StatusCancelled
		}
		stopCtx := reqctxpkg.SetUserID(context.Background(), uid)
		stopCtx = reqctxpkg.WithConversationID(stopCtx, parentConvID)
		em.StopBlock(stopCtx, msgBlockID, closeStatus, nil)
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
