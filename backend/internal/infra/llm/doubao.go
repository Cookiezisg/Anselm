package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// doubaoProvider speaks Doubao (Volcengine Ark)'s /chat/completions API directly.
// It owns its own BuildRequest (top-level thinking:{type:enabled|disabled|auto} +
// optional budget_tokens per 03 §9) and ParseStream (reads delta.reasoning_content
// → EventReasoning before delta.content → EventText). Written to Doubao's
// documented standard; shares only transport-level primitives.
//
// doubaoProvider 直接按豆包（Volcengine Ark）/chat/completions API 标准实现。
// 自有 BuildRequest（顶层 thinking:{type}+可选 budget_tokens，03 §9）和 ParseStream
// （delta.reasoning_content→EventReasoning 先于 content→EventText）；仅共享 transport 层原语。

type doubaoProvider struct{}

func newDoubaoProvider() *doubaoProvider { return &doubaoProvider{} }

func (p *doubaoProvider) Name() string           { return "doubao" }
func (p *doubaoProvider) DefaultBaseURL() string { return "https://ark.cn-beijing.volces.com/api/v3" }

// BuildRequest encodes a Request into a Doubao /chat/completions HTTP request.
//
// Thinking encoding per 03 §9:
//   - on  → thinking:{type:"enabled"} (+ budget_tokens if Budget>0)
//   - off → thinking:{type:"disabled"}
//   - nil/auto → omit (no thinking fields)
//
// BuildRequest 把 Request 编码为豆包 /chat/completions HTTP 请求。
// thinking 编码（03 §9）：on→{type:enabled}(+budget)；off→{type:disabled}；nil/auto→省略。
func (p *doubaoProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.doubao: build messages: %w", err)
	}
	body := doubaoRequest{
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
	// Thinking encoding per Doubao Seed API (03 §9).
	// nil / "auto" → no fields emitted (default).
	//
	// 按豆包 Seed API 编码 thinking（03 §9）；nil/"auto"→不发字段。
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		switch req.Thinking.Mode {
		case "on":
			tf := &doubaoThinkingField{Type: "enabled"}
			if req.Thinking.Budget > 0 {
				tf.BudgetTokens = req.Thinking.Budget
			}
			body.Thinking = tf
		case "off":
			body.Thinking = &doubaoThinkingField{Type: "disabled"}
		}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.doubao: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.doubao: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

// ParseStream reads Doubao SSE chunks and yields StreamEvents.
// Doubao sends delta.reasoning_content before delta.content; this parser
// preserves that order explicitly. Uses transport-level scanSSELines for line
// mechanics.
//
// ParseStream 读豆包 SSE chunk 并 yield StreamEvent。
// 豆包先发 delta.reasoning_content 后发 delta.content；此处显式保序。
// 用共享的 scanSSELines 处理原始 SSE 行语义。
func (p *doubaoProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		if req.DisableStream {
			doubaoParseNonStreaming(resp.Body, yield)
			return
		}
		state := newToolCallState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk doubaoChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.doubao: malformed SSE chunk: %w", err)})
				return false
			}
			return emitDoubaoChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.doubao: scan: %w", scanErr)})
		}
	}
}

// emitDoubaoChunk converts one Doubao SSE chunk to StreamEvents.
// reasoning_content → EventReasoning (before content), content → EventText,
// tool_calls → EventToolStart + EventToolDelta, finish_reason → EventFinish.
//
// emitDoubaoChunk 把一个豆包 SSE chunk 转为 StreamEvent 序列。
// reasoning_content→EventReasoning（先于 content）；content→EventText；
// tool_calls→EventToolStart+EventToolDelta；finish_reason→EventFinish。
func emitDoubaoChunk(chunk doubaoChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
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

	// Doubao sends reasoning_content first, then content — preserve that order.
	// 豆包先发 reasoning_content 再发 content——严格保序。
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

// doubaoParseNonStreaming reads a single non-streaming Doubao JSON response
// and synthesizes StreamEvents.
//
// doubaoParseNonStreaming 读单条非流式豆包 JSON 响应并合成 StreamEvent。
func doubaoParseNonStreaming(body interface{ Read([]byte) (int, error) }, yield func(StreamEvent) bool) {
	raw, err := readAll(body)
	if err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.doubao: read non-streaming body: %w", err)})
		return
	}
	var resp doubaoNonStreamResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.doubao: parse non-streaming response: %w", err)})
		return
	}
	if resp.Error != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm: provider returned error: %s", resp.Error.Message)})
		return
	}
	if len(resp.Choices) == 0 {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.doubao: non-streaming response has no choices: %w", ErrProviderError)})
		return
	}
	msg := resp.Choices[0].Message
	if msg.ReasoningContent != "" {
		if !yield(StreamEvent{Type: EventReasoning, Delta: msg.ReasoningContent}) {
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

// ── Doubao-specific wire types ────────────────────────────────────────────────
//
// These mirror the OpenAI chunk types but are Doubao-specific. The key
// difference from other CN-family providers is the top-level thinking object
// (type:enabled/disabled/auto + optional budget_tokens) in requests, and
// reasoning_content in delta responses.
//
// 这些类型镜像 OpenAI chunk 类型但专属豆包。与其他 CN 家族的主要区别：请求中的
// 顶层 thinking 对象（type:enabled/disabled/auto + 可选 budget_tokens），
// 以及 delta 响应中的 reasoning_content。

type doubaoRequest struct {
	Model         string            `json:"model"`
	Messages      []oaiMessage      `json:"messages"`
	Tools         []oaiTool         `json:"tools,omitempty"`
	Stream        bool              `json:"stream"`
	StreamOptions *oaiStreamOptions `json:"stream_options,omitempty"`
	// Doubao thinking object (03 §9): top-level, type:enabled/disabled/auto.
	// 豆包 thinking 对象（03 §9）：顶层，type:enabled/disabled/auto。
	Thinking *doubaoThinkingField `json:"thinking,omitempty"`
}

type doubaoThinkingField struct {
	Type         string `json:"type"`
	BudgetTokens int    `json:"budget_tokens,omitempty"`
}

type doubaoChunk struct {
	Choices []doubaoChoice `json:"choices"`
	Usage   *oaiUsage      `json:"usage"`
	Error   *oaiChunkError `json:"error,omitempty"`
}

type doubaoChoice struct {
	Delta        doubaoChunkDelta `json:"delta"`
	FinishReason string           `json:"finish_reason"`
}

type doubaoChunkDelta struct {
	Content          string                 `json:"content"`
	ReasoningContent string                 `json:"reasoning_content"`
	ToolCalls        []doubaoToolCallDelta  `json:"tool_calls"`
}

// doubaoToolCallDelta mirrors oaiToolCallDelta for Doubao — same shape but typed
// separately so doubao.go reads end-to-end as its own provider story.
//
// doubaoToolCallDelta 镜像 oaiToolCallDelta；类型独立，保持 doubao.go 可独立阅读。
type doubaoToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}

type doubaoNonStreamResponse struct {
	Choices []doubaoNonStreamChoice `json:"choices"`
	Usage   *oaiUsage               `json:"usage"`
	Error   *oaiChunkError          `json:"error,omitempty"`
}

type doubaoNonStreamChoice struct {
	Message      doubaoNonStreamMessage `json:"message"`
	FinishReason string                 `json:"finish_reason"`
}

type doubaoNonStreamMessage struct {
	Role             string               `json:"role"`
	Content          string               `json:"content"`
	ReasoningContent string               `json:"reasoning_content"`
	ToolCalls        []doubaoToolCallDelta `json:"tool_calls"`
}
