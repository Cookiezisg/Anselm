package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// moonshotProvider speaks Moonshot Kimi's /v1 /chat/completions API, fully self-contained:
// its own wire types, message encoding, and SSE chunk parsing — no sharing with the openai
// provider even though the wire is OpenAI-shaped. Moonshot specifics: thinking:{type} toggle
// for k2.5/k2.6 (kimi-k2-thinking is intrinsic and needs no param), and the official
// api.moonshot.cn streams reasoning_content (underscore form, never a bare "reasoning" alias).
//
// moonshotProvider 完整自包含地讲 Moonshot Kimi /v1 /chat/completions：自己的 wire 类型、消息
// 编码、SSE 解析——即使 wire 是 OpenAI 形状也不与 openai 共享。Moonshot 特有：k2.5/k2.6 的
// thinking:{type} 开关（kimi-k2-thinking 内禀，无需参数），官方 api.moonshot.cn 流
// reasoning_content（下划线形，绝不用裸 "reasoning" 别名）。
type moonshotProvider struct{}

func newMoonshotProvider() *moonshotProvider { return &moonshotProvider{} }

func (p *moonshotProvider) Name() string           { return "moonshot" }
func (p *moonshotProvider) DefaultBaseURL() string { return "https://api.moonshot.cn/v1" }

// BuildRequest encodes a Request into a Moonshot Kimi /chat/completions HTTP request.
//
// thinking: on → thinking:{type:enabled}; off → thinking:{type:disabled}; nil/auto → omit.
// kimi-k2-thinking callers pass nil (model is intrinsic); k2.5/k2.6 callers pass on/off to
// toggle the param. No max_tokens is sent so callers that omit a cap get the model default.
//
// BuildRequest 把 Request 编码为 Moonshot Kimi /chat/completions 请求。
// thinking：on→enabled；off→disabled；nil/auto→省略。kimi-k2-thinking 传 nil（模型内禀），
// k2.5/k2.6 传 on/off。不发 max_tokens，未指定上限时走模型默认。
func (p *moonshotProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := tomoonshotMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.moonshot: build messages: %w", err)
	}
	body := moonshotRequest{
		Model:    req.ModelID,
		Messages: msgs,
		Stream:   !req.DisableStream,
	}
	if !req.DisableStream {
		body.StreamOptions = &moonshotStreamOptions{IncludeUsage: true}
	}
	if len(req.Tools) > 0 {
		body.Tools = tomoonshotTools(req.Tools)
	}
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		switch req.Thinking.Mode {
		case "on":
			body.Thinking = &moonshotThinking{Type: "enabled"}
		case "off":
			body.Thinking = &moonshotThinking{Type: "disabled"}
		}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.moonshot: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.moonshot: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

func (p *moonshotProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		state := newmoonshotToolState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk moonshotChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.moonshot: malformed SSE chunk: %w", err)})
				return false
			}
			return emitmoonshotChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.moonshot: scan: %w", scanErr)})
		}
	}
}

func emitmoonshotChunk(chunk moonshotChunk, state *moonshotToolState, yield func(StreamEvent) bool) bool {
	if chunk.Error != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: in-stream: %s", ErrProviderError, chunk.Error.Message)})
		return false
	}
	if len(chunk.Choices) == 0 {
		if chunk.Usage != nil {
			return yield(StreamEvent{Type: EventFinish, InputTokens: chunk.Usage.PromptTokens, OutputTokens: chunk.Usage.CompletionTokens})
		}
		return true
	}

	choice := chunk.Choices[0]
	delta := choice.Delta

	// Official api.moonshot.cn streams reasoning_content before content — preserve that order.
	// 官方 api.moonshot.cn 先流 reasoning_content 再流 content——严格保序。
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
		if !state.nameSent[idx] && tc.Function.Name != "" {
			state.nameSent[idx] = true
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

// ── message encoding ──────────────────────────────────────────────────────────

func tomoonshotMsgs(msgs []LLMMessage, system string) ([]moonshotMessage, error) {
	var out []moonshotMessage
	if system != "" {
		out = append(out, moonshotMessage{Role: "system", Content: system})
	}
	for _, m := range msgs {
		mm, err := tomoonshotMsg(m)
		if err != nil {
			return nil, err
		}
		out = append(out, mm)
	}
	return out, nil
}

func tomoonshotMsg(m LLMMessage) (moonshotMessage, error) {
	switch m.Role {
	case RoleUser:
		return moonshotMessage{Role: "user", Content: m.Content}, nil
	case RoleAssistant:
		return buildmoonshotAssistantMsg(m), nil
	case RoleTool:
		return moonshotMessage{Role: "tool", Content: m.Content, ToolCallID: m.ToolCallID}, nil
	default:
		return moonshotMessage{}, fmt.Errorf("llm.moonshot: unknown role %q: %w", m.Role, ErrBadRequest)
	}
}

func buildmoonshotAssistantMsg(m LLMMessage) moonshotMessage {
	mm := moonshotMessage{Role: "assistant", Content: m.Content}
	for _, tc := range m.ToolCalls {
		args := json.RawMessage(tc.Arguments)
		// Stub malformed historical tool args with "{}" so a strict provider does not 400 on
		// a non-JSON arguments field; the call itself is still replayed by id+name.
		// 用 "{}" 兜底非法历史 tool args，避免严格 provider 因 arguments 非 JSON 而 400；
		// 调用本身仍由 id+name 重放。
		if len(args) == 0 || !json.Valid(args) {
			args = json.RawMessage("{}")
		}
		mm.ToolCalls = append(mm.ToolCalls, moonshotToolCall{
			ID:       tc.ID,
			Type:     "function",
			Function: moonshotFuncCall{Name: tc.Name, Arguments: args},
		})
	}
	return mm
}

func tomoonshotTools(defs []ToolDef) []moonshotTool {
	out := make([]moonshotTool, len(defs))
	for i, d := range defs {
		out[i] = moonshotTool{Type: "function", Function: moonshotFuncDef{Name: d.Name, Description: d.Description, Parameters: d.Parameters}}
	}
	return out
}

// ── tool-call streaming state ──────────────────────────────────────────────────
//
// Moonshot streams tool_calls in fragments. index pins each call's slot; when an early
// fragment omits a positive index but carries an id, the id anchors a synthesized slot so
// later argument fragments accrete to the right call.
//
// Moonshot 分片流 tool_calls。index 钉住每个调用的槽位；早期分片若无正 index 但带 id，
// 则以 id 锚定合成槽位，使后续参数分片归并到正确调用。

type moonshotToolState struct {
	nameSent     map[int]bool
	idToIdx      map[string]int
	nextSynthIdx int
}

func newmoonshotToolState() *moonshotToolState {
	return &moonshotToolState{nameSent: map[int]bool{}, idToIdx: map[string]int{}}
}

func (s *moonshotToolState) resolveIndex(tc moonshotToolCallDelta) int {
	if tc.Index > 0 {
		return tc.Index
	}
	if tc.ID == "" {
		return 0
	}
	if idx, ok := s.idToIdx[tc.ID]; ok {
		return idx
	}
	idx := s.nextSynthIdx
	s.idToIdx[tc.ID] = idx
	s.nextSynthIdx++
	return idx
}

// ── Moonshot wire types ─────────────────────────────────────────────────────────

type moonshotRequest struct {
	Model         string                 `json:"model"`
	Messages      []moonshotMessage      `json:"messages"`
	Tools         []moonshotTool         `json:"tools,omitempty"`
	Stream        bool                   `json:"stream"`
	StreamOptions *moonshotStreamOptions `json:"stream_options,omitempty"`
	Thinking      *moonshotThinking      `json:"thinking,omitempty"`
}

type moonshotStreamOptions struct {
	IncludeUsage bool `json:"include_usage"`
}

type moonshotThinking struct {
	Type string `json:"type"`
}

type moonshotMessage struct {
	Role       string             `json:"role"`
	Content    string             `json:"content"`
	ToolCalls  []moonshotToolCall `json:"tool_calls,omitempty"`
	ToolCallID string             `json:"tool_call_id,omitempty"`
}

type moonshotToolCall struct {
	ID       string           `json:"id"`
	Type     string           `json:"type"`
	Function moonshotFuncCall `json:"function"`
}

type moonshotFuncCall struct {
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments"`
}

type moonshotTool struct {
	Type     string          `json:"type"`
	Function moonshotFuncDef `json:"function"`
}

type moonshotFuncDef struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Parameters  json.RawMessage `json:"parameters"`
}

type moonshotChunk struct {
	Choices []moonshotChoice    `json:"choices"`
	Usage   *moonshotUsage      `json:"usage"`
	Error   *moonshotChunkError `json:"error,omitempty"`
}

type moonshotChunkError struct {
	Message string `json:"message"`
}

type moonshotChoice struct {
	Delta        moonshotDelta `json:"delta"`
	FinishReason string        `json:"finish_reason"`
}

type moonshotDelta struct {
	Content string `json:"content"`
	// reasoning_content is the official api.moonshot.cn field (underscore form). No "reasoning"
	// alias — Together/NIM aliases are not part of the official Moonshot API.
	//
	// reasoning_content 是官方 api.moonshot.cn 字段（下划线形）。不加 "reasoning" 别名——
	// Together/NIM 别名不属于官方 Moonshot API。
	ReasoningContent string                  `json:"reasoning_content"`
	ToolCalls        []moonshotToolCallDelta `json:"tool_calls"`
}

type moonshotToolCallDelta struct {
	Index    int               `json:"index"`
	ID       string            `json:"id"`
	Function moonshotFuncDelta `json:"function"`
}

type moonshotFuncDelta struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type moonshotUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
}
