// Package subagent (app/subagent) is the service layer for the Subagent
// system tool. Owns the SubagentType registry, the SubagentRun ledger,
// and the Spawn → loop.Run → terminal-write lifecycle.
//
// V1.2 architecture (subagent.md §6): chat and subagent both consume the
// shared internal/app/loop ReAct engine. Service.Spawn constructs a
// subagentHost (loop.Host implementation) and calls loop.Run directly —
// no SubRunner port, no chat ↔ subagent cross-imports.
//
// Recursion defense is two-layered:
//
//   - structural — Spawn filters the tool list to drop SubagentTool itself
//     before calling loop.Run, so the sub-LLM physically cannot see the
//     "Subagent" tool name and cannot call it
//   - runtime — SubagentTool.Execute checks reqctxpkg.GetSubagentDepth(ctx);
//     ≥ 1 means we're already inside a sub-run, return ErrRecursionAttempt
//
// Per subagent.md §8.5: every spawn gets a 5 min total-timeout context
// (defends against stuck tool calls), a panic recover in the sub-runner
// so a tool implementation crash flips the run to status=failed instead
// of leaving it stuck running, and a parent-ctx cancel cascades naturally
// because subCtx is derived from parentCtx.
//
// Package subagent (app/subagent) 是 Subagent system tool 的 service 层。
// 持有 SubagentType 注册表、SubagentRun 总账、Spawn → loop.Run → 终态写入
// 生命周期。chat 与 subagent 都用共享 internal/app/loop ReAct 引擎；
// 防递归双保险（结构性 tool 过滤 + 运行时 ctx 深度检查）；每次 spawn 5min
// 总超时 + panic recover + parent ctx cancel 自动级联。
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
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// defaultRunTimeout caps a single Spawn — defends against stuck tool calls
// (e.g. an MCP server that never returns) holding a sub-runner forever
// and burning tokens. Per subagent.md §8.5; can be overridden per-type
// via a future SubagentType.MaxRunDuration field.
//
// defaultRunTimeout 限定单次 Spawn——防止 stuck tool（如不响应的 MCP server）
// 让 sub-runner 永挂 + 烧 token。详 subagent.md §8.5；未来按类型 override。
const defaultRunTimeout = 5 * time.Minute

// SpawnOpts overrides per-call. Empty fields fall back to the type's defaults.
//
// SpawnOpts per-call 覆盖。空字段回落到类型默认。
type SpawnOpts struct {
	MaxTurns int    // 0 = use type.DefaultMaxTurns
	Model    string // "" = type.DefaultModel ?? PickForChat (V2: per-type model targeting)
}

// SpawnResult is what Service.Spawn hands back. Run carries the persisted
// row (terminal status, totals, ID); Result is the last assistant text the
// SubagentTool returns to the parent LLM as its tool_result.
//
// SpawnResult 是 Service.Spawn 的回执。Run 是落库行；Result 是 SubagentTool
// 返父 LLM 的最后 assistant 文本。
type SpawnResult struct {
	Run    *subagentdomain.SubagentRun
	Result string
}

// Service ties the registry / store / chat-shared infra together. Spawn is
// the only mutating entry point; the rest are query helpers.
//
// Service 把 registry / store / chat 共享 infra 串起来。Spawn 是唯一变更
// 入口；其余是查询 helper。
type Service struct {
	repo        subagentdomain.Repository
	registry    *Registry
	tools       []toolapp.Tool // global tool registry; filtered per-spawn (see Spawn)
	bridge      eventsdomain.Bridge
	modelPicker modeldomain.ModelPicker
	keyProvider apikeydomain.KeyProvider
	llmFactory  *llminfra.Factory
	log         *zap.Logger

	// activeRunsMu serializes Cancel + Spawn registration so a Cancel
	// arriving mid-Spawn can find the cancel func once the run row is
	// committed. activeRuns maps RunID → cancel func; entries removed
	// on Spawn return.
	//
	// activeRunsMu 串化 Cancel + Spawn 注册，让 Cancel 在 Spawn 中途到达时
	// 也能在 run row 写完后找到 cancel func。activeRuns runID → cancel；
	// Spawn 返回时清条目。
	activeRunsMu sync.Mutex
	activeRuns   map[string]context.CancelFunc
}

// New constructs a Service. tools may be nil at construction time; call
// SetTools after the global tool list is built (the standard DI pattern
// also used by chat.NewService — tools include SubagentTool which holds
// a *Service back-ref, so the cycle is broken via post-injection).
//
// New 构造 Service。tools 可在构造时为 nil；全局 tool 列表建好后调
// SetTools（与 chat.NewService 同模式——tools 含 SubagentTool 持
// *Service 反向引用，循环靠 post-injection 打破）。
func New(
	repo subagentdomain.Repository,
	registry *Registry,
	bridge eventsdomain.Bridge,
	modelPicker modeldomain.ModelPicker,
	keyProvider apikeydomain.KeyProvider,
	llmFactory *llminfra.Factory,
	log *zap.Logger,
) *Service {
	if log == nil {
		panic("subagent.New: logger is nil")
	}
	return &Service{
		repo:        repo,
		registry:    registry,
		bridge:      bridge,
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
// SetTools 注入注册的全局 tool 列表（main.go 把含 SubagentTool 的 slice 建好后调）。
func (s *Service) SetTools(tools []toolapp.Tool) {
	s.tools = tools
}

// Spawn boots one sub-run end-to-end. See subagent.md §6 for the full
// flow; in short: resolve type → filter tools → resolve LLM → create
// run row → inject ctx (RunID + Depth+1) → 5-min timeout → register
// cancel → defer recover → loop.Run via subagentHost → write terminal
// status + agentstate token log → return SpawnResult.
//
// Spawn 一站式启 sub-run。完整流程见 subagent.md §6；要点：解类型 →
// 过滤 tools → 解 LLM → 落 run row → 注 ctx（RunID + Depth+1）→ 5min
// 超时 → 注册 cancel → defer recover → 经 subagentHost 调 loop.Run →
// 写终态 + agentstate token log → 返 SpawnResult。
func (s *Service) Spawn(parentCtx context.Context, typeName, prompt string, opts SpawnOpts) (*SpawnResult, error) {
	typ, ok := s.registry.Get(typeName)
	if !ok {
		return nil, fmt.Errorf("subagentapp.Spawn: %w: %q", subagentdomain.ErrTypeNotFound, typeName)
	}

	convID, _ := reqctxpkg.GetConversationID(parentCtx)
	parentMsgID, _ := reqctxpkg.GetMessageID(parentCtx)
	parentToolCallID, _ := reqctxpkg.GetToolCallID(parentCtx)

	// Resolve LLM bundle via the standard chat-scenario picker. V2 will
	// honor SubagentType.DefaultModel when set; V1 always falls through.
	//
	// 走标准 chat 场景 picker 解 LLM bundle。V2 会用 SubagentType.DefaultModel；
	// V1 总是落到 chat。
	bundle, err := llmclientpkg.Resolve(parentCtx, s.modelPicker, s.keyProvider, s.llmFactory)
	if err != nil {
		return nil, fmt.Errorf("subagentapp.Spawn resolve LLM: %w", err)
	}

	maxTurns := opts.MaxTurns
	if maxTurns <= 0 {
		maxTurns = typ.DefaultMaxTurns
	}

	now := time.Now().UTC()
	run := &subagentdomain.SubagentRun{
		ID:                   idgenpkg.New("sar"),
		ParentConversationID: convID,
		ParentMessageID:      parentMsgID,
		ParentToolCallID:     parentToolCallID,
		Type:                 typ.Name,
		Prompt:               prompt,
		Status:               subagentdomain.StatusRunning,
		Model:                bundle.ModelID,
		StartedAt:            now,
		CreatedAt:            now,
		UpdatedAt:            now,
	}
	if err := s.repo.CreateRun(parentCtx, run); err != nil {
		return nil, fmt.Errorf("subagentapp.Spawn persist run: %w", err)
	}

	// Event-log dual-write (Phase 2B): nest the sub-run in the parent's
	// recursive tree. Mint a sub-msgID + a placeholder message-block (per
	// event-log-protocol.md §2/§3 the sub message attaches via a
	// type=message block under the parent tool_call). EmitBlockStart for
	// the placeholder; EmitMessageStart for the sub message itself; the
	// loop's stream.go will emit text/reasoning/tool_call blocks under
	// sub-msgID. WriteFinalize closes the sub message; we close the
	// placeholder block after loop.Run returns.
	//
	// 事件日志 dual-write（Phase 2B）：把 sub-run 嵌进父递归树。铸 sub-msgID
	// + 占位 message-block（详 event-log-protocol.md §2/§3，sub message 经
	// 父 tool_call 下的 type=message block 挂入）。EmitBlockStart 占位；
	// EmitMessageStart sub 消息本身；loop 的 stream.go 在 sub-msgID 下推
	// text/reasoning/tool_call 块。WriteFinalize 关 sub 消息；loop.Run 返
	// 后关占位 block。
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
				"runId":     run.ID,
			})
		em.EmitMessageStart(parentCtx, subMsgID, chatdomain.RoleAssistant, msgBlockID,
			map[string]any{
				"kind":     "subagent_run",
				"type":     typ.Name,
				"runId":    run.ID,
				"maxTurns": maxTurns,
			})
	}

	// Compose sub-runner ctx: RunID + bumped depth + total timeout +
	// register cancel so external Cancel(runID) can preempt.
	//
	// 组装 sub-runner ctx：RunID + 加深度 + 加总超时 + 注册 cancel 让外部
	// Cancel(runID) 可抢占。
	subCtx := reqctxpkg.WithSubagentRunID(parentCtx, run.ID)
	subCtx = reqctxpkg.WithSubagentDepth(subCtx, reqctxpkg.GetSubagentDepth(parentCtx)+1)
	subCtx = reqctxpkg.WithMessageID(subCtx, subMsgID)
	// Reset ParentBlockID so streamLLM falls back to using sub-msgID as
	// the parent of top-level sub blocks (instead of inheriting the parent
	// chat's ParentBlockID, which was the spawn_subagent tool_call).
	//
	// 清 ParentBlockID 让 streamLLM 回退用 sub-msgID 作 sub 顶层 block 的
	// parent（不要继承 parent chat 的 spawn_subagent tool_call ParentBlockID）。
	subCtx = reqctxpkg.WithParentBlockID(subCtx, "")
	subCtx, cancel := context.WithTimeout(subCtx, defaultRunTimeout)
	defer cancel()

	s.activeRunsMu.Lock()
	s.activeRuns[run.ID] = cancel
	s.activeRunsMu.Unlock()
	defer func() {
		s.activeRunsMu.Lock()
		delete(s.activeRuns, run.ID)
		s.activeRunsMu.Unlock()
	}()

	host := &subagentHost{
		svc:           s,
		run:           run,
		tools:         s.filterTools(typ),
		userPrompt:    prompt,
		systemPrompt:  composeSystemPrompt(typ.SystemPrompt, reqctxpkg.GetLocale(parentCtx)),
		eventLogMsgID: subMsgID,
	}

	baseReq := llminfra.Request{
		ModelID: bundle.ModelID,
		Key:     bundle.Key,
		BaseURL: bundle.BaseURL,
		System:  host.systemPrompt,
	}

	// Defer-recover: if a tool implementation panics inside loop.Run we
	// flip the run to failed + record the panic value, instead of leaving
	// status=running forever (S3: errors don't disappear).
	//
	// Defer-recover：tool 实现在 loop.Run 内 panic 时翻 run 为 failed 并记
	// panic 值，不留 status=running（S3：错误不消失）。
	var (
		result loopapp.Result
		runErr error
	)
	func() {
		defer func() {
			if r := recover(); r != nil {
				runErr = fmt.Errorf("subagent panic: %v", r)
				s.log.Error("subagent run panicked",
					zap.String("run_id", run.ID), zap.Any("panic", r))
			}
		}()
		result = loopapp.Run(subCtx, host, bundle.Client, baseReq, maxTurns, s.log)
	}()

	end := time.Now().UTC()
	run.EndedAt = &end
	run.UpdatedAt = end

	if runErr != nil {
		run.Status = subagentdomain.StatusFailed
		run.ErrorMsg = runErr.Error()
	} else {
		// Map loop.Result back to SubagentRun.Status. loop returns
		// chatdomain.Status* + StopReason*; cancelled + max-tokens get
		// re-mapped to subagent terminal vocab.
		//
		// 映射 loop.Result 到 SubagentRun.Status；cancelled + max-tokens
		// 重映射到 subagent 终态词汇。
		switch {
		case result.StopReason == chatdomain.StopReasonCancelled:
			run.Status = subagentdomain.StatusCancelled
		case result.StopReason == chatdomain.StopReasonMaxTokens:
			run.Status = subagentdomain.StatusMaxTurns
		case result.Status == chatdomain.StatusError:
			run.Status = subagentdomain.StatusFailed
			run.ErrorMsg = result.StopReason
		default:
			run.Status = subagentdomain.StatusCompleted
		}
		run.Result = result.LastMessage
		run.TotalTokensIn = result.TokensIn
		run.TotalTokensOut = result.TokensOut
		run.StepsUsed = result.Steps
	}

	// Persist terminal state on a detached ctx — a cancelled parent
	// (especially via the 5-min timeout firing) must not block writing
	// the terminal row, otherwise the UI would see "running" forever.
	//
	// 终态用 detached ctx 写——已取消的父 ctx（尤其 5min 超时触发）不能挡
	// 终态写入，否则 UI 永远看到 "running"。
	saveCtx := context.Background()
	if uid, err := reqctxpkg.RequireUserID(parentCtx); err == nil {
		saveCtx = reqctxpkg.SetUserID(saveCtx, uid)
	}
	if err := s.repo.UpdateRun(saveCtx, run); err != nil {
		s.log.Error("CRITICAL: subagent terminal write failed",
			zap.String("run_id", run.ID), zap.Error(err))
	}

	// Event-log: close the placeholder message-block after the sub run
	// terminates. The sub message_stop is emitted by subagentHost.
	// WriteFinalize (which loop.Run already triggered above).
	//
	// 事件日志：sub run 终止后关占位 message-block。sub message_stop 由
	// subagentHost.WriteFinalize 发（loop.Run 已上面触发）。
	if msgBlockID != "" {
		closeStatus := eventlogdomain.StatusCompleted
		switch run.Status {
		case subagentdomain.StatusFailed:
			closeStatus = eventlogdomain.StatusError
		case subagentdomain.StatusCancelled:
			closeStatus = eventlogdomain.StatusCancelled
		}
		em.StopBlock(parentCtx, msgBlockID, closeStatus, nil)
	}

	// Append to the per-conversation token log (UI cost panel).
	// 追加到对话级 token log（UI 成本面板）。
	if state, ok := reqctxpkg.GetAgentState(parentCtx); ok && state != nil {
		state.AddSubagentTokens(run.ID, run.Type, run.TotalTokensIn, run.TotalTokensOut)
	}

	s.log.Info("subagent run terminated",
		zap.String("run_id", run.ID),
		zap.String("type", run.Type),
		zap.String("status", run.Status),
		zap.Int("tokens_in", run.TotalTokensIn),
		zap.Int("tokens_out", run.TotalTokensOut),
		zap.Int("steps", run.StepsUsed),
		zap.Int64("duration_ms", end.Sub(run.StartedAt).Milliseconds()))

	return &SpawnResult{Run: run, Result: run.Result}, runErr
}

// Cancel preempts a running sub-run via its registered cancel func. No-op
// when the run isn't found (already terminated; race with finish).
//
// Cancel 通过注册的 cancel func 抢占运行中的 sub-run。run 找不到时空操作
// （已终止；与 finish 竞态）。
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

// Get returns one run by id.
//
// Get 按 id 取 run。
func (s *Service) Get(ctx context.Context, runID string) (*subagentdomain.SubagentRun, error) {
	r, err := s.repo.GetRun(ctx, runID)
	if err != nil {
		return nil, fmt.Errorf("subagentapp.Get: %w", err)
	}
	return r, nil
}

// ListTypes returns the built-in registry contents in stable order.
//
// ListTypes 按稳定顺序返内置注册表内容。
func (s *Service) ListTypes() []subagentdomain.SubagentType {
	return s.registry.List()
}

// ListByConversation returns all runs spawned from the given conversation.
//
// ListByConversation 返某对话发起的所有 run。
func (s *Service) ListByConversation(ctx context.Context, conversationID string) ([]*subagentdomain.SubagentRun, error) {
	rows, err := s.repo.ListRunsByConversation(ctx, conversationID)
	if err != nil {
		return nil, fmt.Errorf("subagentapp.ListByConversation: %w", err)
	}
	return rows, nil
}

// ListMessages returns all messages within one run, ordered by Seq. Used
// by the SubagentRun-detail UI to replay a sub-run's transcript.
//
// ListMessages 返单 run 内所有消息（按 Seq）。SubagentRun 详情 UI 回放
// 子运行的 transcript 用。
func (s *Service) ListMessages(ctx context.Context, runID string) ([]*subagentdomain.SubagentMessage, error) {
	rows, err := s.repo.ListMessagesByRun(ctx, runID)
	if err != nil {
		return nil, fmt.Errorf("subagentapp.ListMessages: %w", err)
	}
	return rows, nil
}

// filterTools applies the spawn-time recursion defense + type whitelist:
//
//   - "Subagent" itself is always dropped (structural recursion defense)
//   - if typ.AllowedTools is non-nil/non-empty, only tools in the whitelist
//     survive (Explore / Plan)
//   - nil/empty whitelist inherits the rest of the global registry
//     (general-purpose)
//
// filterTools 应用 spawn 时的递归防御 + 类型白名单。
func (s *Service) filterTools(typ subagentdomain.SubagentType) []toolapp.Tool {
	if len(s.tools) == 0 {
		return nil
	}
	var whitelist map[string]struct{}
	if len(typ.AllowedTools) > 0 {
		whitelist = make(map[string]struct{}, len(typ.AllowedTools))
		for _, n := range typ.AllowedTools {
			whitelist[n] = struct{}{}
		}
	}
	out := make([]toolapp.Tool, 0, len(s.tools))
	for _, t := range s.tools {
		if t.Name() == "Subagent" {
			continue
		}
		if whitelist != nil {
			if _, ok := whitelist[t.Name()]; !ok {
				continue
			}
		}
		out = append(out, t)
	}
	return out
}

// composeSystemPrompt prepends a small Forgify identity preamble + locale
// directive to the per-type prompt. Mirrors chat.buildSystemPrompt so
// sub-runners answer in the same language as the parent.
//
// composeSystemPrompt 在类型 prompt 前加 Forgify 身份引子 + locale 指令。
// 镜像 chat.buildSystemPrompt 让 sub-runner 与父对话语言一致。
func composeSystemPrompt(perType string, locale reqctxpkg.Locale) string {
	preamble := "You are Forgify, an AI assistant. You are running as a subagent — focused on a single delegated subtask.\n\n"
	out := preamble + perType
	if locale == reqctxpkg.LocaleZhCN {
		out += "\n\nPlease respond in Chinese (Simplified) unless the user writes in another language."
	}
	return out
}
