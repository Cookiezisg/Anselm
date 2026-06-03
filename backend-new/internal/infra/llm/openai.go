package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"iter"
	"net/http"
	"slices"
)

// openaiProvider speaks OpenAI's /chat/completions wire directly and self-contained:
// its own body shape, message encoding, SSE chunk parsing, and wire types. Other
// OpenAI-compat providers each carry their OWN copy — duplication is deliberate so a
// per-provider quirk (a new thinking field, a different error envelope) never forces a
// branch into shared code. Reasoning models accept reasoning_effort.
//
// openaiProvider 直接、自包含地讲 OpenAI /chat/completions wire：自己的 body 形状、
// 消息编码、SSE chunk 解析、wire 类型。其他 OpenAI-compat provider 各持自己的一份——
// 重复是故意的：某家的特性（新 thinking 字段、不同错误信封）永不逼共享代码加分支。
type openaiProvider struct{}

func newOpenAIProvider() *openaiProvider { return &openaiProvider{} }

func (p *openaiProvider) Name() string           { return "openai" }
func (p *openaiProvider) DefaultBaseURL() string { return "https://api.openai.com/v1" }

// BuildRequest encodes a Request into an OpenAI /chat/completions HTTP request. Auth:
// Bearer token. Reasoning models (o-series) accept reasoning_effort; standard models
// ignore it (on→clamped effort, default medium; off→"none"; auto→omitted).
//
// BuildRequest 把 Request 编码为 OpenAI /chat/completions HTTP 请求。Auth：Bearer。
// 推理模型（o 系列）接受 reasoning_effort（on→clamp effort，默认 medium；off→"none"；auto→省略）。
func (p *openaiProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.openai: build messages: %w", err)
	}
	body := oaiRequest{
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
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		allowed := []string{"none", "minimal", "low", "medium", "high", "xhigh"}
		switch req.Thinking.Mode {
		case "on":
			body.ReasoningEffort = clampEffort(req.Thinking.Effort, allowed, "medium")
		case "off":
			body.ReasoningEffort = "none"
		}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.openai: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.openai: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

// ParseStream reads OpenAI SSE chunks (or one non-streaming body) into StreamEvents,
// using the shared scanSSELines for raw SSE line mechanics.
//
// ParseStream 读 OpenAI SSE chunk（或单条非流式 body）为 StreamEvent，用共享的
// scanSSELines 处理原始 SSE 行语义。
func (p *openaiProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
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
			var chunk oaiChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.openai: malformed SSE chunk: %w", err)})
				return false
			}
			return emitOpenAIChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.openai: scan: %w", scanErr)})
		}
	}
}

// ── message encoding ──────────────────────────────────────────────────────────

func toOpenAIMsgs(msgs []LLMMessage, system string) ([]oaiMessage, error) {
	var out []oaiMessage
	if system != "" {
		out = append(out, oaiMessage{Role: "system", Content: jsonString(system)})
	}
	for _, m := range msgs {
		om, err := toOpenAIMsg(m)
		if err != nil {
			return nil, err
		}
		out = append(out, om)
	}
	return out, nil
}

func toOpenAIMsg(m LLMMessage) (oaiMessage, error) {
	switch m.Role {
	case RoleUser:
		return buildOpenAIUserMsg(m)
	case RoleAssistant:
		return buildOpenAIAssistantMsg(m), nil
	case RoleTool:
		return oaiMessage{Role: "tool", Content: jsonString(m.Content), ToolCallID: m.ToolCallID}, nil
	default:
		return oaiMessage{}, fmt.Errorf("llm.openai: unknown role %q: %w", m.Role, ErrBadRequest)
	}
}

func buildOpenAIUserMsg(m LLMMessage) (oaiMessage, error) {
	if len(m.Parts) == 0 {
		return oaiMessage{Role: "user", Content: jsonString(m.Content)}, nil
	}
	parts := make([]oaiContentPart, 0, len(m.Parts))
	for _, part := range m.Parts {
		switch part.Type {
		case "text":
			parts = append(parts, oaiContentPart{Type: "text", Text: part.Text})
		case "image_url":
			parts = append(parts, oaiContentPart{Type: "image_url", ImageURL: &oaiImageURL{URL: part.ImageURL}})
		default:
			return oaiMessage{}, fmt.Errorf("llm.openai: unknown part type %q: %w", part.Type, ErrBadRequest)
		}
	}
	raw, err := json.Marshal(parts)
	if err != nil {
		return oaiMessage{}, fmt.Errorf("llm.openai: marshal parts: %w", err)
	}
	return oaiMessage{Role: "user", Content: raw}, nil
}

func buildOpenAIAssistantMsg(m LLMMessage) oaiMessage {
	// Reasoning-only turn → copy reasoning into content, else a strict provider 400s
	// next turn on an assistant message with neither content nor tool_calls.
	// 仅 reasoning 的回合 → 把 reasoning 复制进 content，否则严格 provider 下一轮会 400。
	if m.Content == "" && len(m.ToolCalls) == 0 && m.ReasoningContent != "" {
		m.Content = m.ReasoningContent
	}
	// Always emit content (even "") — strict providers reject a null content field.
	// content 即使空也 emit ""——严格 provider 拒 null。
	om := oaiMessage{
		Role:             "assistant",
		ReasoningContent: m.ReasoningContent,
		Content:          jsonString(m.Content),
	}
	for _, tc := range m.ToolCalls {
		om.ToolCalls = append(om.ToolCalls, oaiToolCall{
			ID:       tc.ID,
			Type:     "function",
			Function: oaiFuncCall{Name: tc.Name, Arguments: tc.Arguments},
		})
	}
	return om
}

func toOpenAITools(defs []ToolDef) []oaiTool {
	out := make([]oaiTool, len(defs))
	for i, d := range defs {
		out[i] = oaiTool{Type: "function", Function: oaiFuncDef(d)}
	}
	return out
}

func jsonString(s string) json.RawMessage {
	b, _ := json.Marshal(s)
	return b
}

// clampEffort returns effort if it appears in allowed, else fallback (also for empty).
//
// clampEffort 若 effort 在 allowed 列表则返回它，否则（含空）返 fallback。
func clampEffort(effort string, allowed []string, fallback string) string {
	if effort == "" {
		return fallback
	}
	if slices.Contains(allowed, effort) {
		return effort
	}
	return fallback
}

// ── SSE chunk parsing ─────────────────────────────────────────────────────────

// toolCallState tracks per-chunk tool-call streaming state; synthesizes an index by ID
// for chunks that omit it.
//
// toolCallState 跨 chunk 跟踪 tool-call 流式状态；对不填 index 的 chunk 按 ID 合成 index。
type toolCallState struct {
	toolNameSent     map[int]bool
	idToSyntheticIdx map[string]int
	nextSyntheticIdx int
}

func newToolCallState() *toolCallState {
	return &toolCallState{
		toolNameSent:     map[int]bool{},
		idToSyntheticIdx: map[string]int{},
	}
}

func (s *toolCallState) resolveIndex(tc oaiToolCallDelta) int {
	if tc.Index > 0 {
		return tc.Index
	}
	if tc.ID == "" {
		return 0
	}
	if idx, ok := s.idToSyntheticIdx[tc.ID]; ok {
		return idx
	}
	idx := s.nextSyntheticIdx
	s.idToSyntheticIdx[tc.ID] = idx
	s.nextSyntheticIdx++
	return idx
}

func emitOpenAIChunk(chunk oaiChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
	// A chunk-level error object inside a 200 stream (rare; e.g. content filter) — surface it.
	// 200 流里出现 chunk 级 error 对象（罕见，如内容过滤）——透出。
	if chunk.Error != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: in-stream: %s", ErrProviderError, chunk.Error.Message)})
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
		idx := state.resolveIndex(tc)
		if !state.toolNameSent[idx] && tc.Function.Name != "" {
			state.toolNameSent[idx] = true
			if !yield(StreamEvent{Type: EventToolStart, ToolIndex: idx, ToolID: tc.ID, ToolName: tc.Function.Name}) {
				return false
			}
		}
		if tc.Function.Arguments != "" {
			if !yield(StreamEvent{Type: EventToolDelta, ToolIndex: idx, ArgsDelta: tc.Function.Arguments}) {
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

// parseOpenAINonStreaming reads a single non-streaming JSON body into StreamEvents.
//
// parseOpenAINonStreaming 读单条非流式 JSON 响应并合成 StreamEvent 序列。
func parseOpenAINonStreaming(body io.Reader, yield func(StreamEvent) bool) {
	raw, err := io.ReadAll(io.LimitReader(body, 8<<20))
	if err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.openai: read non-streaming body: %w", err)})
		return
	}
	var resp oaiNonStreamResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.openai: parse non-streaming response: %w", err)})
		return
	}
	if resp.Error != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: %s", ErrProviderError, resp.Error.Message)})
		return
	}
	if len(resp.Choices) == 0 {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.openai: non-streaming response has no choices: %w", ErrProviderError)})
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
		if !yield(StreamEvent{Type: EventToolStart, ToolIndex: i, ToolID: tc.ID, ToolName: tc.Function.Name}) {
			return
		}
		if tc.Function.Arguments != "" {
			if !yield(StreamEvent{Type: EventToolDelta, ToolIndex: i, ArgsDelta: tc.Function.Arguments}) {
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

// ── wire types ────────────────────────────────────────────────────────────────

type oaiRequest struct {
	Model         string            `json:"model"`
	Messages      []oaiMessage      `json:"messages"`
	Tools         []oaiTool         `json:"tools,omitempty"`
	Stream        bool              `json:"stream"`
	StreamOptions *oaiStreamOptions `json:"stream_options,omitempty"`
	// reasoning_effort for o-series reasoning models.
	ReasoningEffort string `json:"reasoning_effort,omitempty"`
}

type oaiStreamOptions struct {
	IncludeUsage bool `json:"include_usage"`
}

// oaiMessage holds Content as RawMessage to accept either a string or a content-part array.
//
// oaiMessage Content 用 RawMessage，可装字符串或 content-part 数组。
type oaiMessage struct {
	Role             string          `json:"role"`
	Content          json.RawMessage `json:"content,omitempty"`
	ReasoningContent string          `json:"reasoning_content,omitempty"`
	ToolCalls        []oaiToolCall   `json:"tool_calls,omitempty"`
	ToolCallID       string          `json:"tool_call_id,omitempty"`
}

type oaiContentPart struct {
	Type     string       `json:"type"`
	Text     string       `json:"text,omitempty"`
	ImageURL *oaiImageURL `json:"image_url,omitempty"`
}

type oaiImageURL struct {
	URL string `json:"url"`
}

type oaiToolCall struct {
	ID       string      `json:"id"`
	Type     string      `json:"type"`
	Function oaiFuncCall `json:"function"`
}

type oaiFuncCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type oaiTool struct {
	Type     string     `json:"type"`
	Function oaiFuncDef `json:"function"`
}

type oaiFuncDef struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Parameters  json.RawMessage `json:"parameters"`
}

type oaiChunk struct {
	Choices []oaiChoice    `json:"choices"`
	Usage   *oaiUsage      `json:"usage"`
	Error   *oaiChunkError `json:"error,omitempty"`
}

type oaiChunkError struct {
	Message string `json:"message"`
	Code    any    `json:"code,omitempty"`
	Type    string `json:"type,omitempty"`
}

type oaiChoice struct {
	Delta        oaiDelta `json:"delta"`
	FinishReason string   `json:"finish_reason"`
}

type oaiDelta struct {
	Content          string             `json:"content"`
	ReasoningContent string             `json:"reasoning_content"`
	ToolCalls        []oaiToolCallDelta `json:"tool_calls"`
}

type oaiToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}

type oaiFuncDelta struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type oaiNonStreamResponse struct {
	Choices []oaiNonStreamChoice `json:"choices"`
	Usage   *oaiUsage            `json:"usage"`
	Error   *oaiChunkError       `json:"error,omitempty"`
}

type oaiNonStreamChoice struct {
	Message      oaiNonStreamMessage `json:"message"`
	FinishReason string              `json:"finish_reason"`
}

type oaiNonStreamMessage struct {
	Role             string             `json:"role"`
	Content          string             `json:"content"`
	ReasoningContent string             `json:"reasoning_content"`
	ToolCalls        []oaiToolCallDelta `json:"tool_calls"`
}

type oaiUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
}
