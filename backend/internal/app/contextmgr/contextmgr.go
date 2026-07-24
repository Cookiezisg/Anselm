// Package contextmgr is the conversation-compaction engine: when a thread approaches the
// model's context window it compacts older history so the conversation keeps fitting. It is the
// PRODUCE side — the consume side (loop.BlocksToAssistantLLM dropping archived/compaction +
// projecting warm/cold; chat.LoadHistory prepending the summary and dropping seq ≤ watermark) is
// already wired. A turn-boundary, two-step pipeline (gentle→aggressive, industry-standard):
//
//	① demote old tool_results (LLM-free): newest stay hot, then warm (preview), then cold
//	   (placeholder). Often enough on its own — tool outputs dominate token usage.
//	② if still over budget, summarize the oldest span once (utility model), fold it into the
//	   conversation summary incrementally, and advance the watermark.
//
// Trigger uses the last per-sampling prompt tokens persisted in message attrs (never the
// whole ReAct run's aggregate token charge); the step-① gate uses a cheap bytes/4 estimate.
// The watermark (summary_covers_up_to_seq) is the
// idempotency key: re-summarization only covers (watermark, …], and a crash between writing the
// summary and flipping the archived flag can't double-count (LoadHistory drops by watermark).
//
// Package contextmgr 是对话压缩引擎：线程逼近模型 context window 时压缩旧历史，使对话持续
// 装得下。它是**生产侧**——消费侧（loop.BlocksToAssistantLLM 丢 archived/compaction + 投影
// warm/cold；chat.LoadHistory 前置 summary + 丢 seq ≤ 水位）已接好。回合边界、两步管线
// （gentle→aggressive，业界标准）：① demote 旧 tool_result（免 LLM：最新留 hot、再 warm 预览、再
// cold 占位符；常就够——工具输出占 token 大头）；② 仍超预算则单次摘要最旧 span（utility 模型），增量
// 并入对话 summary、推进水位。触发用末回合 attrs 中**最后一次 sampling**的真实 input token（绝不拿整轮累计）；步①闸用
// bytes/4 廉价估算。水位（summary_covers_up_to_seq）是幂等键：重摘只覆盖 (水位, …]，写 summary 与翻
// archived 标记间崩溃也不重复计数（LoadHistory 按水位丢弃）。
package contextmgr

import (
	"context"

	"go.uber.org/zap"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

const (
	// limitspkg.Current().Context.TriggerRatio compacts when the last successful
	// sampling prompt reaches this fraction of its active input budget. 0.80 sits
	// in the 75–90% quality band; the 20% slack is compaction headroom.
	//
	// limitspkg.Current().Context.TriggerRatio：最后一次成功 sampling prompt 达 active input
	// 预算此比例时压缩。0.80 在业界 75–90% 质量区间；20% 余量是压缩 headroom。

	// recentTurns most recent messages are never touched (verbatim floor — the actual current
	// task must always be present unsummarized).
	//
	// 最近 recentTurns 条 message 永不动（逐字底线——当前任务必须始终未摘要在场）。
	recentTurns = 2

	// Among non-protected tool_results (newest-first), the first recentTRHot stay hot, the next
	// warmZone become warm (truncated preview), the rest cold (placeholder). A tool_result only
	// ever ages hot→warm→cold (its newness rank only grows), so demotion never promotes.
	//
	// 非保护 tool_result 中（新→旧），前 recentTRHot 留 hot、接着 warmZone 个转 warm（截断预览）、其余
	// cold（占位符）。tool_result 只会 hot→warm→cold 老化（新近名次只增），故 demote 绝不升级。
	recentTRHot = 4
	warmZone    = 8

	// bytesPerToken is the cheap estimate ratio for the step-① gate only (the trigger uses real
	// tokens). ~4 bytes/token is the common heuristic; it under-counts the system prompt (absent
	// here), but the gate is self-correcting — if demotion wasn't enough, the next turn's real
	// usage re-triggers.
	//
	// bytesPerToken 仅供步①闸的廉价估算（触发用真实 token）。~4 字节/token 是通用近似；它漏算 system
	// prompt（此处无），但闸自校正——demote 不够则下回合真实用量再触发。
	bytesPerToken = 4

	// maxBlockExcerptBytes caps each block's contribution to the summary prompt (a single huge
	// block can't blow the summarizer's own context).
	//
	// maxBlockExcerptBytes 限每个 block 进摘要 prompt 的量（单个巨大 block 不能冲爆摘要器自己的上下文）。
	maxBlockExcerptBytes = 1500

	// warmPreviewBytes mirrors loop's warm projection, so the gate estimate matches what the LLM
	// will actually receive.
	//
	// warmPreviewBytes 镜像 loop 的 warm 投影，使闸估算与 LLM 实收一致。
	warmPreviewBytes = 200
)

// Bundle is a ready utility-model client + pre-filled base Request (self-contained — contextmgr
// doesn't import chatapp). The summary call sets Request.System + Messages and runs llm.Generate.
//
// Bundle 是即用 utility 模型 client + 预填 base Request（自包含——contextmgr 不引 chatapp）。摘要调用
// 设 Request.System + Messages 后跑 llm.Generate。
type Bundle struct {
	Client  llminfra.Client
	Request llminfra.Request
}

// ----- DIP ports -----

// ConversationSummary reads/writes a conversation's running summary + watermark. Narrow (no
// domain type leak); the bootstrap adapter wraps conversation.Service.
//
// ConversationSummary 读写一个对话的滚动 summary + 水位。窄口（不泄漏 domain 类型）；bootstrap 适配器
// 包 conversation.Service。
type ConversationSummary interface {
	GetSummary(ctx context.Context, conversationID string) (summary string, coversUpToSeq int64, err error)
	SetSummary(ctx context.Context, conversationID, summary string, coversUpToSeq int64) error
}

// UtilityResolver yields the workspace utility model (small/cheap) for the summary call (same
// model auto-title uses).
//
// UtilityResolver 给出 workspace utility 模型（小/廉价）供摘要调用（与 auto-title 同模型）。
type UtilityResolver interface {
	ResolveUtility(ctx context.Context) (Bundle, error)
}

// WindowResolver gives a model's context window + max output tokens (from llminfra.ModelInfo).
// (0, 0) when unknown → compaction is skipped (don't compact without a known budget).
//
// WindowResolver 给出一个模型的 context window + max output token（取自 llminfra.ModelInfo）。
// 未知时 (0, 0) → 跳过压缩（不知预算不压）。
type WindowResolver interface {
	ContextBudget(ctx context.Context, provider, modelID string) (window, maxOutput int)
}

// Deps are contextmgr's injected collaborators (DIP).
//
// Deps 是 contextmgr 注入的协作者（DIP）。
type Deps struct {
	Messages      messagesdomain.Repository
	Conversations ConversationSummary
	Resolver      UtilityResolver
	Windows       WindowResolver
}

// Service compacts conversations.
//
// Service 压缩对话。
type Service struct {
	deps Deps
	log  *zap.Logger
}

// New constructs the Service. nil log → no-op.
//
// New 构造 Service。nil log → no-op。
func NewService(deps Deps, log *zap.Logger) *Service {
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{deps: deps, log: log.Named("contextmgr")}
}

// MaybeCompact compacts when the last successful sampling prompt crossed the
// trigger, or when the loop performed an in-memory edit/recovery that should be
// made durable. Best-effort + idempotent: chat calls it on a detached context
// inside the conversation queue slot; errors are non-fatal. Under threshold /
// unknown budget / nothing to compact returns nil without writing.
//
// MaybeCompact 在最后一次成功 sampling prompt 越线，或 loop 已做内存编辑/恢复而需要
// durable 化时压缩。best-effort + 幂等：chat 在 conversation queue 槽内用 detached ctx 调；
// 错误非致命。未达阈值 / budget 未知 / 无可压 → 返 nil 不写。
func (s *Service) MaybeCompact(ctx context.Context, conversationID string) error {
	thread, err := s.deps.Messages.LoadThread(ctx, conversationID)
	if err != nil {
		return err
	}
	last, lastPromptTokens, inputBudget, promptEdited := lastContextMeasurement(thread)
	if last == nil {
		return nil // no turn carrying per-sampling context accounting yet
	}
	if inputBudget <= 0 {
		// Match the live loop's provider-authoritative policy: a catalog's
		// theoretical output ceiling is not an input reservation. A real overflow
		// is still recovered by the sampling loop before durable compaction runs.
		window, _ := s.deps.Windows.ContextBudget(ctx, last.Provider, last.ModelID)
		inputBudget = window
	}
	if inputBudget <= 0 {
		return nil // unknown budget — don't compact blind
	}
	if !promptEdited && lastPromptTokens < int(limitspkg.Current().Context.TriggerRatio*float64(inputBudget)) {
		return nil // under threshold
	}

	summary, watermark, err := s.deps.Conversations.GetSummary(ctx, conversationID)
	if err != nil {
		return err
	}
	protectedFrom := max(0, len(thread)-recentTurns)

	// ① demote old tool_results (LLM-free); mutates thread roles in place + persists.
	// ① demote 旧 tool_result（免 LLM）；原地改 thread 角色 + 落盘。
	s.demote(ctx, thread, protectedFrom)

	// Gate: if the projected size is now under the trigger, demotion sufficed — skip the LLM.
	// Native attachments deliberately bypass the bytes/4 estimate: their provider tokenization is
	// modal and a base64 transport string is not a text-token estimate. An old attachment still in
	// history therefore forces step ②, where its whole turn is folded under the watermark instead of
	// letting a falsely-small estimate postpone compaction forever.
	//
	// 闸：投影大小已低于触发线则 demote 足够——跳过 LLM。原生附件刻意不进 bytes/4 估算：其 token 化取决于
	// 模态，base64 传输串更不是文本 token 估算。历史中仍有旧附件时强制走步骤②，把整回合压到水位线之下，
	// 避免虚低估算无限推迟压缩。
	if !hasUncompactedAttachments(thread, protectedFrom, watermark) &&
		s.estimateTokens(thread, summary) < int(limitspkg.Current().Context.TriggerRatio*float64(inputBudget)) {
		return nil
	}

	// ② summarize the oldest non-protected span into the running summary.
	// ② 把最旧的非保护 span 摘要并入滚动 summary。
	return s.summarize(ctx, conversationID, thread, protectedFrom, summary, watermark)
}

// lastContextMeasurement returns the newest assistant turn carrying the
// contextUsage facts written per sampling request by loop.ContextObserver.
// Message.InputTokens is deliberately ignored: it is the aggregate billable
// input across every ReAct request in the whole visible turn.
func lastContextMeasurement(thread []*messagesdomain.Message) (*messagesdomain.Message, int, int, bool) {
	for i := len(thread) - 1; i >= 0; i-- {
		m := thread[i]
		if m.SubagentID != "" || m.Role != messagesdomain.RoleAssistant || m.Attrs == nil {
			continue
		}
		stats, ok := m.Attrs["contextUsage"].(map[string]any)
		if !ok {
			continue
		}
		input := numericInt(stats["lastPromptInputTokens"])
		if input > 0 {
			edited := numericInt(stats["compactions"]) > 0 ||
				numericInt(stats["recoveries"]) > 0 ||
				numericInt(stats["toolResultEdits"]) > 0
			return m, input, numericInt(stats["inputBudgetTokens"]), edited
		}
	}
	return nil, 0, 0, false
}

func numericInt(v any) int {
	switch n := v.(type) {
	case int:
		return n
	case int64:
		return int(n)
	case float64:
		return int(n)
	default:
		return 0
	}
}
