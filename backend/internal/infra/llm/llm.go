// Package llm is a provider-agnostic LLM streaming client built on iter.Seq.
// It speaks each provider's wire dialect with the standard library only (no SDKs),
// exposing one Client.Stream contract upward. Errors that reach the wire use the
// structured domain error types so transport maps them via statusForKind.
//
// Package llm 是基于 iter.Seq 的 provider-agnostic LLM 流式客户端。仅用标准库
// （无 SDK）讲各家 wire 方言，对上暴露统一的 Client.Stream 契约。会上线缆的错误用
// 结构化 domain error，使 transport 经 statusForKind 映射。
package llm

import (
	"context"
	"errors"
	"iter"
	"strings"
	"time"

	"encoding/json"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// LLM upstream failures, classified by HTTP status (see classifyHTTPError). These are
// structured domain errors so a failure surfaced through Stream maps to the right HTTP
// status at transport with no special case.
//
// LLM upstream 失败，按 HTTP 状态分类（见 classifyHTTPError）。均为结构化 domain 错误，
// 经 Stream 冒泡后 transport 零特例映射到正确 HTTP 状态。
var (
	ErrAuthFailed    = errorspkg.New(errorspkg.KindUnauthorized, "LLM_AUTH_FAILED", "llm: authentication failed")
	ErrRateLimited   = errorspkg.New(errorspkg.KindRateLimited, "LLM_RATE_LIMITED", "llm: rate limited")
	ErrBadRequest    = errorspkg.New(errorspkg.KindInvalid, "LLM_BAD_REQUEST", "llm: bad request")
	ErrModelNotFound = errorspkg.New(errorspkg.KindNotFound, "LLM_MODEL_NOT_FOUND", "llm: model not found")
	ErrProviderError = errorspkg.New(errorspkg.KindBadGateway, "LLM_PROVIDER_ERROR", "llm: provider error")

	// ErrQuotaExhausted is the free-tier gateway's "monthly quota exhausted" signal (gateway 402
	// / in-stream error.code BUDGET_EXHAUSTED). A DISTINCT sentinel with its own Code so errors.Is
	// (which matches by Code) never conflates it with ErrRateLimited — quota exhaustion is a hard
	// wall, NOT retryable (a retry just re-hits the same 402), unlike a transient 429. Kind
	// RateLimited → HTTP 429 at transport. It must NEVER mark the install identity invalid (the
	// identity is valid, just out of budget; it recovers at the monthly reset).
	//
	// ErrQuotaExhausted 是免费档网关「本月额度耗尽」信号（网关 402 / 流内 error.code BUDGET_EXHAUSTED）。
	// 独立 sentinel、自有 Code，故 errors.Is（按 Code 匹配）绝不与 ErrRateLimited 混淆——额度耗尽是硬墙、
	// 不可重试（重试只是再撞同一个 402），区别于短暂 429。Kind RateLimited → transport 映射 HTTP 429。
	// 绝不可据此标记 install 身份失效（身份有效、只是没额度，按月重置自恢复）。
	ErrQuotaExhausted = errorspkg.New(errorspkg.KindRateLimited, "LLM_QUOTA_EXHAUSTED", "llm: free-tier quota exhausted")
)

// StreamEventType identifies a Client.Stream event variant.
//
// StreamEventType 标识 Client.Stream 输出的事件类型。
type StreamEventType string

const (
	EventText      StreamEventType = "text"
	EventReasoning StreamEventType = "reasoning"
	EventToolStart StreamEventType = "tool_start"
	EventToolDelta StreamEventType = "tool_delta"
	EventFinish    StreamEventType = "finish"
	EventError     StreamEventType = "error"
)

// StreamEvent is one typed event from Client.Stream; field set varies by Type.
//
// StreamEvent 是 Client.Stream 的类型化事件；字段集随 Type 而异。
type StreamEvent struct {
	Type StreamEventType

	Delta string
	// Signature carries the Anthropic-issued opaque signature for a completed thinking
	// block. Set on the final EventReasoning event so the round-trip can echo it verbatim.
	//
	// Signature 是 Anthropic 颁发的不透明签名，随最后一个 thinking block 的
	// EventReasoning 事件到达，多轮对话时必须原样回传。
	Signature string

	ToolIndex int
	ToolID    string
	ToolName  string
	ArgsDelta string

	FinishReason string
	InputTokens  int
	OutputTokens int

	Err error
}

// Role is the speaker role on a conversation turn (LLM wire role, includes tool).
//
// Role 是对话回合中的发言方角色（LLM wire 角色，含 tool）。
type Role string

const (
	RoleUser      Role = "user"
	RoleAssistant Role = "assistant"
	RoleTool      Role = "tool"
)

// LLMMessage is a provider-agnostic conversation turn sent to the LLM.
//
// LLMMessage 是发给 LLM 的、与 provider 无关的对话回合。
type LLMMessage struct {
	Role             Role
	Content          string
	Parts            []ContentPart
	ToolCalls        []LLMToolCall
	ToolCallID       string
	ReasoningContent string
	// ReasoningSignature is the opaque Anthropic-issued signature echoed verbatim with
	// the thinking block in subsequent requests. Empty for non-Anthropic / non-thinking.
	//
	// ReasoningSignature 是 Anthropic 颁发的不透明签名，后续请求必须原样随 thinking
	// block 回传；非 Anthropic / 无 thinking 响应留空。
	ReasoningSignature string
}

// ContentPart is one element of a multi-modal user message. Type selects the shape:
//   - PartText       → Text
//   - PartImageURL   → ImageURL holds a data-URL ("data:<mime>;base64,<data>") for a local
//     attachment, or a remote https URL. Each provider parses/forwards it natively.
//   - PartVideoURL   → VideoURL holds an inline video data-URL.
//   - PartInputAudio → MediaType + base64 Data carry an inline audio clip. The provider owns the
//     final wire vocabulary (for example OpenAI-compatible input_audio.format).
//   - PartFile       → MediaType + base64 Data + Filename, for a document (PDF) sent inline.
//
// Each provider renders these into its own wire (no shared base — infra/llm keeps every
// provider self-contained; a provider that can't carry a part type degrades on its own).
//
// ContentPart 是多模态 user 消息的一个元素。Type 选形态：PartText→Text；PartImageURL→ImageURL 为
// data-URL（本地附件）或远程 https URL；PartVideoURL→VideoURL 为内联视频 data-URL；PartInputAudio
// →MediaType + base64 Data 为内联音频；PartFile→MediaType + base64 Data + Filename 为内联文档（PDF）。
// 各家 provider 各自渲成自己的 wire（无共享基座——各家自包含；无法承载某 part 类型的家各自优雅降级）。
type ContentPart struct {
	Type      string
	Text      string
	ImageURL  string
	VideoURL  string
	MediaType string
	Data      string
	Filename  string
}

// ContentPart.Type values. PartImageURL keeps the legacy "image_url" wire name (the existing
// per-provider switch convention); PartVideoURL / PartInputAudio are neutral internal names for
// their OpenAI-compatible counterparts; PartFile is the document/PDF carrier.
//
// ContentPart.Type 取值。PartImageURL 沿用历史 "image_url" 线缆名（既有各家 switch 约定）；
// PartVideoURL / PartInputAudio 是各自 OpenAI-compatible 线缆的中立内部名；PartFile 是文档/PDF 载体。
const (
	PartText       = "text"
	PartImageURL   = "image_url"
	PartVideoURL   = "video_url"
	PartInputAudio = "input_audio"
	PartFile       = "file"
)

// LLMToolCall is one tool invocation in an assistant message; Arguments is a JSON object string.
//
// LLMToolCall 描述 assistant 消息中的一次工具调用；Arguments 为 JSON object 字符串。
type LLMToolCall struct {
	ID        string
	Name      string
	Arguments string
}

// ToolDef is the tool description sent to the LLM; Parameters must be a JSON Schema object.
//
// ToolDef 是发给 LLM 的工具描述；Parameters 必须是 JSON Schema object。
type ToolDef struct {
	Name        string
	Description string
	Parameters  json.RawMessage
}

// Request specifies one LLM call.
//
// Request 是一次 LLM 调用规格。
type Request struct {
	ModelID  string
	Key      string
	BaseURL  string
	System   string
	Messages []LLMMessage
	Tools    []ToolDef

	// MaxTokens optionally overrides the model's max output cap; 0 → the provider fills it
	// from its own static spec. Each provider owns its model knowledge; infra/llm holds no
	// cross-provider catalog.
	//
	// MaxTokens 可选覆盖模型输出上限；0 → provider 用自身静态规格自填。每家 provider 自持
	// 模型知识，infra/llm 不持跨家目录。
	MaxTokens int

	// Options is the sole carrier of user-selected reasoning/config knobs, keyed by each
	// provider's native parameter name with native values (e.g. {"reasoning_effort":"high"},
	// {"thinking":"enabled"}, {"thinkingLevel":"high"}, {"effort":"max"}). Each adapter reads
	// only the keys it recognises — no neutral abstraction across providers.
	//
	// Options 是用户所选推理/配置旋钮的唯一载体，按各家原生参数名 + 原生取值（如
	// {"reasoning_effort":"high"}）。每个 adapter 只读自己认识的 key——跨家零中立抽象。
	Options map[string]string

	// DisableStream forces non-streaming wire mode (Ollama+tools workaround).
	// DisableStream 强制 non-streaming（Ollama 有 tools 时绕 bug）。
	DisableStream bool

	// InputBudgetTokens is the model's INPUT token budget (context window − max output), resolved at
	// bundle time from the model catalog. It is NEVER sent on the wire — it feeds the ReAct loop's
	// intra-turn context-budget soft guard (F58): when a step's actual input nears this budget the loop
	// stops the still-acting turn gracefully instead of letting the next call overflow. 0 = unknown
	// window → guard disabled.
	//
	// InputBudgetTokens 是模型的**输入** token 预算（context window − 最大输出），bundle 时从模型目录解析。
	// **绝不**上线缆——喂给 ReAct loop 的回合内上下文预算软守卫（F58）：某步实际 input 逼近此预算时 loop 优雅
	// 停下仍在动作的回合，而非让下次调用溢出。0 = window 未知 → 守卫禁用。
	InputBudgetTokens int
}

// Client streams LLM events via iter.Seq; ctx cancel stops cleanly.
//
// Client 通过 iter.Seq 流式输出 LLM 事件；ctx 取消可干净停止。
type Client interface {
	Stream(ctx context.Context, req Request) iter.Seq[StreamEvent]
}

// Generate consumes Stream, concatenates text deltas, returns the assembled string.
// Auto-retries transient upstream failures (429 / 5xx / connection) with exponential
// backoff. Safe only because Generate has no observable side effects until it returns
// (no partial UI emission) — Stream() callers that emit as events arrive (chat loop)
// must NOT use this; they consume raw Client.Stream().
//
// Generate 消费 Stream 拼接 text delta 返完整串，upstream 短期失败自动指数退避重试。
// 仅因 Generate 返回前无可观察副作用（不向 UI emit）才安全——边到边 emit 的 Stream()
// 直调方（chat loop）不能套此 retry，直接消费裸 Client.Stream()。
func Generate(ctx context.Context, c Client, req Request) (string, error) {
	return withRetry(ctx, func() (string, error) {
		var sb strings.Builder
		for event := range c.Stream(ctx, req) {
			switch event.Type {
			case EventText:
				sb.WriteString(event.Delta)
			case EventError:
				return "", event.Err
			}
		}
		return sb.String(), nil
	})
}

const (
	retryMaxAttempts  = 3                      // initial + 2 retries
	retryInitialDelay = 500 * time.Millisecond // first backoff
	retryDelayFactor  = 3                      // each retry waits factor× the previous
)

// withRetry runs fn up to retryMaxAttempts times, backing off between attempts when fn
// returns a retryable error. Returns the last error when retries exhaust, or ctx.Err()
// if cancellation interrupts the backoff sleep.
//
// withRetry 把 fn 跑至多 retryMaxAttempts 次，可重试错时退避；用完返最后一次错；
// backoff 期间 ctx 取消返 ctx.Err。
func withRetry(ctx context.Context, fn func() (string, error)) (string, error) {
	delay := retryInitialDelay
	var lastErr error
	for attempt := range retryMaxAttempts {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(delay):
			}
			delay *= retryDelayFactor
		}
		out, err := fn()
		if err == nil {
			return out, nil
		}
		if !isRetryable(err) {
			return "", err
		}
		lastErr = err
	}
	return "", lastErr
}

// isRetryable identifies upstream errors worth a retry: rate limit, generic provider
// errors (often 5xx / network blips), and deadline. Auth / bad-request / model-not-found
// and explicit cancellation are not retryable — same input fails the same way.
//
// isRetryable 识别值得重试的 upstream 错：限流、通用 provider 错（多半 5xx/网络抖动）、
// 超时。Auth / 参数错 / model-不存在 与显式 cancel 不重试。
func isRetryable(err error) bool {
	if err == nil {
		return false
	}
	switch {
	case errors.Is(err, ErrRateLimited):
		return true
	case errors.Is(err, ErrProviderError):
		return true
	case errors.Is(err, context.DeadlineExceeded):
		return true
	case errors.Is(err, ErrAuthFailed),
		errors.Is(err, ErrBadRequest),
		errors.Is(err, ErrModelNotFound),
		errors.Is(err, ErrQuotaExhausted),
		errors.Is(err, context.Canceled):
		return false
	}
	return false
}
