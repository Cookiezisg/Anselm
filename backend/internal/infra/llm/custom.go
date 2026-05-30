package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// customProvider speaks a generic OpenAI-compatible /chat/completions API.
// It is the wire dialect for user-configured custom endpoints that speak
// the OpenAI wire format. No thinking encoding is applied (custom endpoints
// are generic; callers should not assume thinking support).
// The anthropic-compatible custom case is routed to anthropicProvider by
// lookupProvider before this provider is ever reached.
//
// customProvider 按通用 OpenAI-compat /chat/completions API 标准实现。
// 用于用户配置的自定义端点（OpenAI wire 格式）。不进行 thinking 编码（自定义端点
// 是通用的，不应假设 thinking 支持）。anthropic-compatible 的 custom 情况由
// lookupProvider 在到达此 provider 前路由到 anthropicProvider。

type customProvider struct{}

func newCustomProvider() *customProvider { return &customProvider{} }

func (p *customProvider) Name() string           { return "custom" }
func (p *customProvider) DefaultBaseURL() string { return "" } // caller must supply base_url

// BuildRequest encodes a Request into a generic OpenAI-compat /chat/completions
// HTTP request. No thinking fields are emitted — custom endpoints are assumed
// to be generic; thinking encoding would risk 400 errors on endpoints that
// don't support it.
//
// BuildRequest 把 Request 编码为通用 OpenAI-compat /chat/completions HTTP 请求。
// 不发 thinking 字段——自定义端点假设为通用接口；thinking 编码会在不支持它的端点触发 400。
func (p *customProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.custom: build messages: %w", err)
	}
	body := customRequest{
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
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.custom: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.custom: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

// ParseStream reads OpenAI-compat SSE chunks from a custom endpoint and yields
// StreamEvents. Handles standard content deltas, tool calls, and reasoning_content
// if the upstream happens to send it (pass-through; not relied upon). Uses
// transport-level scanSSELines for line mechanics.
//
// ParseStream 读自定义端点的 OpenAI-compat SSE chunk 并 yield StreamEvent。
// 处理标准 content delta、tool_calls，以及 reasoning_content（若上游发送则透传；不依赖）。
// 用共享的 scanSSELines 处理原始 SSE 行语义。
func (p *customProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		if req.DisableStream {
			parseOpenAINonStreaming(resp.Body, yield)
			return
		}
		state := newToolCallState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk customChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.custom: malformed SSE chunk: %w", err)})
				return false
			}
			return emitCustomChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.custom: scan: %w", scanErr)})
		}
	}
}

// emitCustomChunk converts one custom endpoint SSE chunk to StreamEvents.
// Standard OpenAI-compat shape: content delta, tool calls, finish with usage.
// reasoning_content is handled if present (pass-through for compatible endpoints).
//
// emitCustomChunk 把一个自定义端点 SSE chunk 转为 StreamEvent 序列。
// 标准 OpenAI-compat 形式：content delta、tool_calls、finish+usage。
// reasoning_content 若存在则透传（兼容端点的直通支持）。
func emitCustomChunk(chunk customChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
	if chunk.Error != nil {
		yield(StreamEvent{
			Type: EventError,
			Err:  fmt.Errorf("%w: in-stream: %s", ErrProviderError, chunk.Error.Message),
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

	// Pass through reasoning_content if the upstream sends it (e.g. a custom
	// DeepSeek-compatible endpoint). Not required; best-effort.
	//
	// 若上游发送 reasoning_content 则透传（如自定义 DeepSeek-compat 端点）。非必须；尽力而为。
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

// ── Custom-specific wire types ────────────────────────────────────────────────
//
// Plain OpenAI-compat shape. No thinking fields — custom endpoints are generic.
// reasoning_content in response delta is handled as pass-through only.
//
// 纯 OpenAI-compat 形。无 thinking 字段——自定义端点是通用的。
// 响应 delta 中的 reasoning_content 仅作透传处理。

type customRequest struct {
	Model         string            `json:"model"`
	Messages      []oaiMessage      `json:"messages"`
	Tools         []oaiTool         `json:"tools,omitempty"`
	Stream        bool              `json:"stream"`
	StreamOptions *oaiStreamOptions `json:"stream_options,omitempty"`
}

type customChunk struct {
	Choices []customChoice `json:"choices"`
	Usage   *oaiUsage      `json:"usage"`
	Error   *oaiChunkError `json:"error,omitempty"`
}

type customChoice struct {
	Delta        customDelta `json:"delta"`
	FinishReason string      `json:"finish_reason"`
}

type customDelta struct {
	Content          string               `json:"content"`
	ReasoningContent string               `json:"reasoning_content"`
	ToolCalls        []customToolCallDelta `json:"tool_calls"`
}

// customToolCallDelta mirrors oaiToolCallDelta for custom endpoints — same shape
// but typed separately so custom.go reads end-to-end as its own provider story.
//
// customToolCallDelta 镜像 oaiToolCallDelta；类型独立，保持 custom.go 可独立阅读。
type customToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}
