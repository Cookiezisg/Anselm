package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// qwenProvider speaks Qwen DashScope's compatible-mode /chat/completions API.
// It owns its own BuildRequest (enable_thinking bool + stream guard per 03 §6)
// and ParseStream (reads delta.reasoning_content → EventReasoning; detects
// Qwen's FLAT error envelope {code,message,request_id} that arrives as a 200
// SSE chunk — not the nested {error:{}} form used by most other providers).
//
// qwenProvider 按 Qwen DashScope compatible-mode API 标准实现。自有 BuildRequest
// （enable_thinking bool + 流式守卫，03 §6）和 ParseStream（delta.reasoning_content
// →EventReasoning；检测 Qwen 扁平错误信封 {code,message,request_id}，以 200 SSE
// chunk 返回而非嵌套 {error:{}} 形式）。

type qwenProvider struct{}

func newQwenProvider() *qwenProvider { return &qwenProvider{} }

func (p *qwenProvider) Name() string           { return "qwen" }
func (p *qwenProvider) DefaultBaseURL() string { return "https://dashscope.aliyuncs.com/compatible-mode/v1" }

// BuildRequest encodes a Request into a Qwen DashScope /chat/completions HTTP request.
//
// Thinking encoding per 03 §6:
//   - on  → enable_thinking=true (+ thinking_budget if Budget>0)
//   - off → enable_thinking=false
//   - nil/auto → omit both fields
//
// Stream guard: enable_thinking=true requires stream=true. When DisableStream=true
// and Mode=on, the thinking fields are silently omitted to avoid a Qwen 400
// ("parameter.enable_thinking must be set to false for non-streaming calls").
//
// BuildRequest 把 Request 编码为 Qwen DashScope /chat/completions HTTP 请求。
// thinking 编码（03 §6）：on→enable_thinking=true（+budget）；off→false；nil/auto→省略。
// 流式守卫：enable_thinking=true 必须 stream=true；非流式+on 时静默省略，避免 400。
func (p *qwenProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.qwen: build messages: %w", err)
	}
	body := qwenRequest{
		Model:    req.ModelID,
		Messages: msgs,
		Stream:   !req.DisableStream,
	}
	if !req.DisableStream {
		body.StreamOptions = &oaiStreamOptions{IncludeUsage: true}
	}
	if len(req.Tools) > 0 {
		body.Tools = toOpenAITools(req.Tools)
	}
	// Thinking encoding: nil/auto → no fields; on/off → enable_thinking bool.
	// Stream guard: skip enable_thinking=true when request is already non-streaming —
	// Qwen 400s with "enable_thinking must be set to false for non-streaming calls".
	//
	// thinking 编码：nil/auto→不发；on/off→enable_thinking bool。
	// 流式守卫：非流式请求时跳过 enable_thinking=true，否则 Qwen 返 400。
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		switch req.Thinking.Mode {
		case "on":
			if !req.DisableStream {
				t := true
				body.EnableThinking = &t
				if req.Thinking.Budget > 0 {
					body.ThinkingBudget = req.Thinking.Budget
				}
			}
			// DisableStream+on: omit enable_thinking entirely (stream guard).
		case "off":
			f := false
			body.EnableThinking = &f
		}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.qwen: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.qwen: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

// ParseStream reads Qwen DashScope SSE chunks and yields StreamEvents.
// Handles two distinct error shapes:
//  1. Standard nested {error:{message,...}} — same as OpenAI family.
//  2. Qwen's FLAT envelope {code,message,request_id} arriving as a 200 chunk
//     with no nested "error" field — this is a real Qwen DashScope quirk and
//     must not be silently dropped.
//
// ParseStream 读 Qwen SSE chunk 并 yield StreamEvent。处理两种错误形式：
// 1. 标准嵌套 {error:{}} — 与 OpenAI 家族相同。
// 2. Qwen 扁平信封 {code,message,request_id}：以 200 chunk 返回、无 "error" 嵌套，
//    是 Qwen DashScope 特有的 quirk，不得静默丢弃。
func (p *qwenProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		state := newToolCallState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk qwenChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.qwen: malformed SSE chunk: %w", err)})
				return false
			}
			return emitQwenChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.qwen: scan: %w", scanErr)})
		}
	}
}

// emitQwenChunk converts one Qwen SSE chunk to StreamEvents.
// Detects Qwen's flat error envelope (code non-empty) before falling through
// to the standard OpenAI-compat delta processing.
//
// emitQwenChunk 把一个 Qwen SSE chunk 转为 StreamEvent。
// 先检测 Qwen 扁平错误信封（code 非空），再走标准 OpenAI-compat delta 处理。
func emitQwenChunk(chunk qwenChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
	// Standard nested error (e.g. auth failure at the HTTP layer that slipped through).
	// 标准嵌套错误（如 auth 失败在 HTTP 层穿透的情况）。
	if chunk.Error != nil {
		yield(StreamEvent{
			Type: EventError,
			Err:  fmt.Errorf("%w: in-stream: %s", ErrProviderError, chunk.Error.Message),
		})
		return false
	}
	// Qwen flat error envelope: {code,message,request_id} with no nested "error".
	// Detected when Error is nil but Code is non-empty. Must not be silently dropped.
	//
	// Qwen 扁平错误信封：code/message 在顶层，无 "error" 嵌套。
	// Error==nil 但 Code 非空时检出；不得静默丢弃。
	if chunk.Code != "" {
		yield(StreamEvent{
			Type: EventError,
			Err:  fmt.Errorf("%w: qwen: %s: %s", ErrProviderError, chunk.Code, chunk.Message),
		})
		return false
	}
	if len(chunk.Choices) == 0 {
		if chunk.Usage != nil {
			return yield(StreamEvent{
				Type:         EventFinish,
				InputTokens:  chunk.Usage.PromptTokens,
				OutputTokens: chunk.Usage.CompletionTokens,
			})
		}
		return true
	}

	choice := chunk.Choices[0]
	delta := choice.Delta

	// Qwen streams reasoning_content before content — same order contract as DeepSeek.
	// Qwen 先发 reasoning_content 再发 content——与 DeepSeek 相同的顺序约定。
	if delta.ReasoningContent != "" {
		if !yield(StreamEvent{Type: EventReasoning, Delta: delta.ReasoningContent}) {
			return false
		}
	}
	if delta.Content != "" {
		if !yield(StreamEvent{Type: EventText, Delta: delta.Content}) {
			return false
		}
	}

	for _, tc := range delta.ToolCalls {
		idx := state.resolveIndex(oaiToolCallDelta(tc))
		if !state.toolNameSent[idx] && tc.Function.Name != "" {
			state.toolNameSent[idx] = true
			if !yield(StreamEvent{
				Type: EventToolStart, ToolIndex: idx,
				ToolID: tc.ID, ToolName: tc.Function.Name,
			}) {
				return false
			}
		}
		if tc.Function.Arguments != "" {
			if !yield(StreamEvent{
				Type: EventToolDelta, ToolIndex: idx,
				ArgsDelta: tc.Function.Arguments,
			}) {
				return false
			}
		}
	}

	if choice.FinishReason != "" {
		ev := StreamEvent{Type: EventFinish, FinishReason: choice.FinishReason}
		if chunk.Usage != nil {
			ev.InputTokens = chunk.Usage.PromptTokens
			ev.OutputTokens = chunk.Usage.CompletionTokens
		}
		return yield(ev)
	}
	return true
}

// ── Qwen-specific wire types ──────────────────────────────────────────────────
//
// These are Qwen DashScope-specific. The most notable addition is the flat
// error envelope fields (Code, Message, RequestID) at the top level of the
// chunk — separate from the standard nested "error" field used by other providers.
//
// 这些类型是 Qwen DashScope 专属。最显著的是顶层扁平错误字段（Code/Message/
// RequestID），与其他 provider 使用的标准嵌套 "error" 字段相互独立。

type qwenRequest struct {
	Model         string            `json:"model"`
	Messages      []oaiMessage      `json:"messages"`
	Tools         []oaiTool         `json:"tools,omitempty"`
	Stream        bool              `json:"stream"`
	StreamOptions *oaiStreamOptions `json:"stream_options,omitempty"`
	// Qwen thinking fields (03 §6): pointer to distinguish false vs absent.
	// Qwen thinking 字段（03 §6）：指针以区分 false 与 absent。
	EnableThinking *bool `json:"enable_thinking,omitempty"`
	ThinkingBudget int   `json:"thinking_budget,omitempty"`
}

type qwenChunk struct {
	Choices []qwenChoice    `json:"choices"`
	Usage   *oaiUsage       `json:"usage"`
	Error   *oaiChunkError  `json:"error,omitempty"`
	// Flat error envelope: {"code":"...","message":"...","request_id":"..."}.
	// Present when DashScope rejects a parameter at stream-open time.
	//
	// 扁平错误信封：参数无效时 DashScope 以此形式返回，无嵌套 "error" 字段。
	Code      string `json:"code,omitempty"`
	Message   string `json:"message,omitempty"`
	RequestID string `json:"request_id,omitempty"`
}

type qwenChoice struct {
	Delta        qwenDelta `json:"delta"`
	FinishReason string    `json:"finish_reason"`
}

type qwenDelta struct {
	Content          string             `json:"content"`
	ReasoningContent string             `json:"reasoning_content"`
	ToolCalls        []qwenToolCallDelta `json:"tool_calls"`
}

// qwenToolCallDelta mirrors oaiToolCallDelta for Qwen — same shape but typed
// separately so qwen.go reads end-to-end as its own provider story.
//
// qwenToolCallDelta 镜像 oaiToolCallDelta；类型独立，保持 qwen.go 可独立阅读。
type qwenToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}
