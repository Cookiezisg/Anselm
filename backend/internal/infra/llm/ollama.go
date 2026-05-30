package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"iter"
	"net/http"
)

// ollamaProvider speaks Ollama's /v1/chat/completions OpenAI-compat API.
// It owns its own BuildRequest (reasoning_effort:high/medium/low/none per 03 §11;
// forces non-streaming when tools present to avoid tool_call drop quirk) and
// ParseStream (reads delta.reasoning → EventReasoning — Ollama /v1 uses "reasoning"
// NOT "reasoning_content"; falls back to non-streaming parse when tools are present).
// Written to Ollama's documented /v1 standard; shares only transport-level primitives.
//
// ollamaProvider 按 Ollama /v1/chat/completions OpenAI-compat API 标准实现。
// 自有 BuildRequest（reasoning_effort:high/medium/low/none，03 §11；有 tools 时强制非流避免
// tool_call 丢失）和 ParseStream（delta.reasoning→EventReasoning——Ollama /v1 用 "reasoning"
// 非 "reasoning_content"；tools 场景走非流式路径）；仅共享 transport 层原语。

type ollamaProvider struct{}

func newOllamaProvider() *ollamaProvider { return &ollamaProvider{} }

func (p *ollamaProvider) Name() string           { return "ollama" }
func (p *ollamaProvider) DefaultBaseURL() string { return "" } // caller must supply base_url

// BuildRequest encodes a Request into an Ollama /v1/chat/completions HTTP request.
//
// Stream disable: forces non-streaming (DisableStream=true) when tools are
// present — Ollama drops tool_calls in streaming mode (older daemon quirk).
//
// Thinking encoding per 03 §11:
//   - on  → reasoning_effort = Effort (clamp to {high,medium,low,none}; default "medium")
//   - off → reasoning_effort = "none"
//   - nil/auto → omit
//
// BuildRequest 把 Request 编码为 Ollama /v1/chat/completions HTTP 请求。
// 流式强制：有 tools 时设 DisableStream=true（Ollama streaming 模式丢 tool_calls）。
// thinking 编码（03 §11）：on→reasoning_effort（clamp；默认 medium）；off→"none"；nil/auto→省略。
func (p *ollamaProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	// Force non-streaming when tools present — Ollama drops tool_calls when streaming.
	// 有 tools 时强制非流式——Ollama streaming 时会吞 tool_calls。
	if len(req.Tools) > 0 {
		req.DisableStream = true
	}

	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.ollama: build messages: %w", err)
	}
	body := ollamaRequest{
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
	// Thinking encoding per Ollama /v1 API (03 §11).
	// on  → reasoning_effort = clamped effort (default "medium")
	// off → reasoning_effort = "none"
	// nil/auto → omit
	//
	// 按 Ollama /v1 API 编码 thinking（03 §11）：on→clamp effort（默认 medium）；off→"none"；nil/auto→省略。
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		allowed := []string{"high", "medium", "low", "none"}
		switch req.Thinking.Mode {
		case "on":
			body.ReasoningEffort = clampEffort(req.Thinking.Effort, allowed, "medium")
		case "off":
			body.ReasoningEffort = "none"
		}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.ollama: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.ollama: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

// ParseStream reads Ollama /v1 SSE chunks and yields StreamEvents.
// When tools are present the request is non-streaming; this parser routes
// to the non-streaming path in that case. For the streaming path, Ollama /v1
// uses delta.reasoning (NOT reasoning_content) for thinking content.
//
// ParseStream 读 Ollama /v1 SSE chunk 并 yield StreamEvent。
// 有 tools 时请求非流式，此处路由到非流式路径。流式路径中 Ollama /v1 用
// delta.reasoning（非 reasoning_content）传输思考内容。
func (p *ollamaProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		if req.DisableStream {
			ollamaParseNonStreaming(resp.Body, yield)
			return
		}
		state := newToolCallState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk ollamaChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.ollama: malformed SSE chunk: %w", err)})
				return false
			}
			return emitOllamaChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.ollama: scan: %w", scanErr)})
		}
	}
}

// emitOllamaChunk converts one Ollama /v1 SSE chunk to StreamEvents.
// Ollama /v1 uses delta.reasoning (no underscore) for thinking content;
// delta.reasoning_content is NOT sent by Ollama.
//
// emitOllamaChunk 把一个 Ollama /v1 SSE chunk 转为 StreamEvent 序列。
// Ollama /v1 用 delta.reasoning（无下划线）传思考内容；不发 reasoning_content。
func emitOllamaChunk(chunk ollamaChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
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

	// Ollama /v1 uses "reasoning" (no underscore) — distinct from CN-family "reasoning_content".
	// Some models (Gemma-class) put full text in reasoning with empty content; surface it.
	//
	// Ollama /v1 用 "reasoning"（无下划线），区别于 CN 家族的 "reasoning_content"。
	// 部分 model（Gemma 类）将全文落 reasoning 而 content 空——照样呈现。
	if delta.Reasoning != "" {
		if !yield(StreamEvent{Type: EventReasoning, Delta: delta.Reasoning}) {
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

// ollamaParseNonStreaming reads a single non-streaming Ollama JSON response and
// synthesizes StreamEvents. Used when tools are present (forced DisableStream).
// Handles both "reasoning" (Ollama /v1) and "reasoning_content" (CN-family alias)
// in the non-streaming message shape.
//
// ollamaParseNonStreaming 读单条非流式 Ollama JSON 响应并合成 StreamEvent。
// 有 tools 时使用（强制 DisableStream）。处理 "reasoning"（Ollama /v1）和
// "reasoning_content"（CN 家族别名）两种字段名。
func ollamaParseNonStreaming(body io.Reader, yield func(StreamEvent) bool) {
	raw, err := io.ReadAll(io.LimitReader(body, 8<<20))
	if err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.ollama: read non-streaming body: %w", err)})
		return
	}
	var resp ollamaNonStreamResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.ollama: parse non-streaming response: %w", err)})
		return
	}
	if resp.Error != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm: provider returned error: %s", resp.Error.Message)})
		return
	}
	if len(resp.Choices) == 0 {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.ollama: non-streaming response has no choices: %w", ErrProviderError)})
		return
	}
	msg := resp.Choices[0].Message
	// Prefer reasoning_content (CN-family round-trip); fall back to reasoning (Ollama /v1).
	// 优先 reasoning_content（CN 家族 round-trip）；fallback 到 reasoning（Ollama /v1）。
	reasoningText := msg.ReasoningContent
	if reasoningText == "" {
		reasoningText = msg.Reasoning
	}
	if reasoningText != "" {
		if !yield(StreamEvent{Type: EventReasoning, Delta: reasoningText}) {
			return
		}
	}
	if msg.Content != "" {
		if !yield(StreamEvent{Type: EventText, Delta: msg.Content}) {
			return
		}
	}
	for i, tc := range msg.ToolCalls {
		if !yield(StreamEvent{
			Type: EventToolStart, ToolIndex: i,
			ToolID: tc.ID, ToolName: tc.Function.Name,
		}) {
			return
		}
		if tc.Function.Arguments != "" {
			if !yield(StreamEvent{
				Type: EventToolDelta, ToolIndex: i,
				ArgsDelta: tc.Function.Arguments,
			}) {
				return
			}
		}
	}
	ev := StreamEvent{Type: EventFinish, FinishReason: resp.Choices[0].FinishReason}
	if resp.Usage != nil {
		ev.InputTokens = resp.Usage.PromptTokens
		ev.OutputTokens = resp.Usage.CompletionTokens
	}
	yield(ev)
}

// ── Ollama-specific wire types ────────────────────────────────────────────────
//
// Ollama /v1 follows OpenAI-compat with two key differences:
//  1. delta.reasoning (no underscore) for thinking content in SSE
//  2. non-streaming message.reasoning (no underscore) for thinking content
//
// Ollama /v1 与 OpenAI-compat 两处关键差异：
//  1. SSE delta.reasoning（无下划线）传思考内容
//  2. 非流式 message.reasoning（无下划线）传思考内容

type ollamaRequest struct {
	Model           string            `json:"model"`
	Messages        []oaiMessage      `json:"messages"`
	Tools           []oaiTool         `json:"tools,omitempty"`
	Stream          bool              `json:"stream"`
	StreamOptions   *oaiStreamOptions `json:"stream_options,omitempty"`
	// Ollama /v1 thinking: reasoning_effort:high/medium/low/none (03 §11).
	// Ollama /v1 thinking：reasoning_effort:high/medium/low/none（03 §11）。
	ReasoningEffort string `json:"reasoning_effort,omitempty"`
}

type ollamaChunk struct {
	Choices []ollamaChoice `json:"choices"`
	Usage   *oaiUsage      `json:"usage"`
	Error   *oaiChunkError `json:"error,omitempty"`
}

type ollamaChoice struct {
	Delta        ollamaDelta `json:"delta"`
	FinishReason string      `json:"finish_reason"`
}

type ollamaDelta struct {
	Content string `json:"content"`
	// Ollama /v1 uses "reasoning" (no underscore) — NOT "reasoning_content".
	// Ollama /v1 用 "reasoning"（无下划线），非 "reasoning_content"。
	Reasoning string              `json:"reasoning"`
	ToolCalls []ollamaToolCallDelta `json:"tool_calls"`
}

// ollamaToolCallDelta mirrors oaiToolCallDelta for Ollama — same shape but typed
// separately so ollama.go reads end-to-end as its own provider story.
//
// ollamaToolCallDelta 镜像 oaiToolCallDelta；类型独立，保持 ollama.go 可独立阅读。
type ollamaToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}

type ollamaNonStreamResponse struct {
	Choices []ollamaNonStreamChoice `json:"choices"`
	Usage   *oaiUsage               `json:"usage"`
	Error   *oaiChunkError          `json:"error,omitempty"`
}

type ollamaNonStreamChoice struct {
	Message      ollamaNonStreamMessage `json:"message"`
	FinishReason string                 `json:"finish_reason"`
}

type ollamaNonStreamMessage struct {
	Role string `json:"role"`
	// reasoning is Ollama /v1's field name; reasoning_content is the CN-family alias.
	// reasoning 是 Ollama /v1 字段名；reasoning_content 是 CN 家族别名（fallback）。
	Content          string                `json:"content"`
	Reasoning        string                `json:"reasoning"`
	ReasoningContent string                `json:"reasoning_content"`
	ToolCalls        []ollamaToolCallDelta `json:"tool_calls"`
}
