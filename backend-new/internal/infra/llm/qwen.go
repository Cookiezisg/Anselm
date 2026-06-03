package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// qwenProvider speaks Qwen DashScope's compatible-mode /chat/completions API, fully
// self-contained: its own wire types, message encoding, and SSE chunk parsing — no
// sharing with the openai/deepseek providers even though the wire is OpenAI-shaped.
// Qwen specifics: enable_thinking bool (pointer to distinguish false vs absent) +
// thinking_budget, a stream guard (enable_thinking=true is illegal on non-streaming
// calls), and a FLAT error envelope {code,message,request_id} that arrives as a 200
// SSE chunk with no nested "error" object — unlike every other provider here.
//
// qwenProvider 完整自包含地讲 Qwen DashScope compatible-mode /chat/completions：自己的
// wire 类型、消息编码、SSE 解析——即使 wire 是 OpenAI 形状也不与 openai/deepseek 共享。
// Qwen 特有：enable_thinking bool（指针区分 false 与 absent）+ thinking_budget、流式守卫
// （非流式调用禁用 enable_thinking=true）、以及扁平错误信封 {code,message,request_id}：以
// 200 SSE chunk 返回、无嵌套 "error"，区别于这里所有其他 provider。
type qwenProvider struct{}

func newQwenProvider() *qwenProvider { return &qwenProvider{} }

func (p *qwenProvider) Name() string { return "qwen" }
func (p *qwenProvider) DefaultBaseURL() string {
	return "https://dashscope.aliyuncs.com/compatible-mode/v1"
}

// BuildRequest encodes a Request into a Qwen DashScope /chat/completions HTTP request.
//
// thinking: on → enable_thinking=true (+ thinking_budget when Budget>0); off →
// enable_thinking=false; nil/auto → omit both. Stream guard: enable_thinking=true is
// rejected on non-streaming calls, so when DisableStream is set the on-branch silently
// omits the thinking fields rather than provoke a 400.
//
// BuildRequest 把 Request 编码为 Qwen DashScope 请求。thinking：on→enable_thinking=true
// （Budget>0 时加 thinking_budget）；off→false；nil/auto→省略。流式守卫：非流式调用拒绝
// enable_thinking=true，故 DisableStream 时 on 分支静默省略 thinking 字段以免 400。
func (p *qwenProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toQwenMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.qwen: build messages: %w", err)
	}
	body := qwenRequest{
		Model:    req.ModelID,
		Messages: msgs,
		Stream:   !req.DisableStream,
	}
	if !req.DisableStream {
		body.StreamOptions = &qwenStreamOptions{IncludeUsage: true}
	}
	if len(req.Tools) > 0 {
		body.Tools = toQwenTools(req.Tools)
	}
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		switch req.Thinking.Mode {
		case "on":
			// Stream guard: enable_thinking=true demands stream=true, so skip it on a
			// non-streaming call to avoid Qwen's 400 on the conflicting parameter.
			// 流式守卫：enable_thinking=true 要求 stream=true，非流式时跳过以避 400。
			if !req.DisableStream {
				t := true
				body.EnableThinking = &t
				if req.Thinking.Budget > 0 {
					body.ThinkingBudget = req.Thinking.Budget
				}
			}
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

func (p *qwenProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		state := newQwenToolState()
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

// emitQwenChunk converts one Qwen SSE chunk to StreamEvents. It checks both error
// shapes before the delta path: the standard nested {error:{}} and Qwen's flat
// {code,message,request_id} envelope (Error nil but Code non-empty), which DashScope
// returns as a 200 chunk when it rejects a parameter and must not be silently dropped.
//
// emitQwenChunk 把一个 Qwen SSE chunk 转为 StreamEvent。在 delta 前先查两种错误形式：
// 标准嵌套 {error:{}} 与 Qwen 扁平信封 {code,message,request_id}（Error 为 nil 但 Code
// 非空）——参数无效时 DashScope 以 200 chunk 返回，不得静默丢弃。
func emitQwenChunk(chunk qwenChunk, state *qwenToolState, yield func(StreamEvent) bool) bool {
	if chunk.Error != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: in-stream: %s", ErrProviderError, chunk.Error.Message)})
		return false
	}
	if chunk.Code != "" {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: qwen: %s: %s", ErrProviderError, chunk.Code, chunk.Message)})
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

	// Qwen streams reasoning_content before content — preserve that order.
	// Qwen 先发 reasoning_content 再发 content——严格保序。
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

func toQwenMsgs(msgs []LLMMessage, system string) ([]qwenMessage, error) {
	var out []qwenMessage
	if system != "" {
		out = append(out, qwenMessage{Role: "system", Content: qwenJSONString(system)})
	}
	for _, m := range msgs {
		qm, err := toQwenMsg(m)
		if err != nil {
			return nil, err
		}
		out = append(out, qm)
	}
	return out, nil
}

func toQwenMsg(m LLMMessage) (qwenMessage, error) {
	switch m.Role {
	case RoleUser:
		return qwenMessage{Role: "user", Content: qwenJSONString(m.Content)}, nil
	case RoleAssistant:
		return buildQwenAssistantMsg(m), nil
	case RoleTool:
		return qwenMessage{Role: "tool", Content: qwenJSONString(m.Content), ToolCallID: m.ToolCallID}, nil
	default:
		return qwenMessage{}, fmt.Errorf("llm.qwen: unknown role %q: %w", m.Role, ErrBadRequest)
	}
}

func buildQwenAssistantMsg(m LLMMessage) qwenMessage {
	qm := qwenMessage{
		Role:    "assistant",
		Content: qwenJSONString(m.Content),
	}
	for _, tc := range m.ToolCalls {
		// Reject malformed history tool args so a strict provider doesn't 400 on the
		// continuation; fall back to an empty JSON object silently.
		// 拒绝历史中残缺的 tool args，避免严格 provider 在续答时 400；静默回退空对象。
		args := json.RawMessage(tc.Arguments)
		if !json.Valid(args) {
			args = json.RawMessage("{}")
		}
		qm.ToolCalls = append(qm.ToolCalls, qwenToolCall{
			ID:       tc.ID,
			Type:     "function",
			Function: qwenFuncCall{Name: tc.Name, Arguments: string(args)},
		})
	}
	return qm
}

func toQwenTools(defs []ToolDef) []qwenTool {
	out := make([]qwenTool, len(defs))
	for i, d := range defs {
		out[i] = qwenTool{Type: "function", Function: qwenFuncDef{Name: d.Name, Description: d.Description, Parameters: d.Parameters}}
	}
	return out
}

func qwenJSONString(s string) json.RawMessage {
	b, _ := json.Marshal(s)
	return b
}

// ── tool-call streaming state ──────────────────────────────────────────────────

// qwenToolState synthesizes a stable index for tool-call deltas that arrive with a
// zero index (Qwen, like the OpenAI family, may stream parallel calls keyed by id
// rather than a reliable positional index).
//
// qwenToolState 为 index=0 的 tool-call delta 合成稳定下标（Qwen 与 OpenAI 家族一样，
// 并行调用可能以 id 而非可靠的位置 index 标识）。
type qwenToolState struct {
	nameSent     map[int]bool
	idToIdx      map[string]int
	nextSynthIdx int
}

func newQwenToolState() *qwenToolState {
	return &qwenToolState{nameSent: map[int]bool{}, idToIdx: map[string]int{}}
}

func (s *qwenToolState) resolveIndex(tc qwenToolCallDelta) int {
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

// ── Qwen wire types ─────────────────────────────────────────────────────────────

type qwenRequest struct {
	Model         string             `json:"model"`
	Messages      []qwenMessage      `json:"messages"`
	Tools         []qwenTool         `json:"tools,omitempty"`
	Stream        bool               `json:"stream"`
	StreamOptions *qwenStreamOptions `json:"stream_options,omitempty"`
	// EnableThinking is a pointer so false (thinking explicitly off) is distinguishable
	// from absent (auto). ThinkingBudget rides along only on the on-branch with Budget>0.
	// EnableThinking 用指针，使 false（显式关）区别于 absent（auto）。ThinkingBudget 仅
	// 在 on 且 Budget>0 时随发。
	EnableThinking *bool `json:"enable_thinking,omitempty"`
	ThinkingBudget int   `json:"thinking_budget,omitempty"`
}

type qwenStreamOptions struct {
	IncludeUsage bool `json:"include_usage"`
}

type qwenMessage struct {
	Role       string          `json:"role"`
	Content    json.RawMessage `json:"content,omitempty"`
	ToolCalls  []qwenToolCall  `json:"tool_calls,omitempty"`
	ToolCallID string          `json:"tool_call_id,omitempty"`
}

type qwenToolCall struct {
	ID       string       `json:"id"`
	Type     string       `json:"type"`
	Function qwenFuncCall `json:"function"`
}

type qwenFuncCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type qwenTool struct {
	Type     string      `json:"type"`
	Function qwenFuncDef `json:"function"`
}

type qwenFuncDef struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Parameters  json.RawMessage `json:"parameters"`
}

type qwenChunk struct {
	Choices []qwenChoice    `json:"choices"`
	Usage   *qwenUsage      `json:"usage"`
	Error   *qwenChunkError `json:"error,omitempty"`
	// Flat error envelope: {"code":"...","message":"...","request_id":"..."} at the top
	// level with no nested "error". DashScope returns this as a 200 chunk when it rejects
	// a parameter at stream-open time; detected via Code non-empty.
	// 扁平错误信封：顶层 {code,message,request_id}、无嵌套 "error"。参数无效时 DashScope
	// 以 200 chunk 返回；以 Code 非空检出。
	Code      string `json:"code,omitempty"`
	Message   string `json:"message,omitempty"`
	RequestID string `json:"request_id,omitempty"`
}

type qwenChunkError struct {
	Message string `json:"message"`
}

type qwenChoice struct {
	Delta        qwenDelta `json:"delta"`
	FinishReason string    `json:"finish_reason"`
}

type qwenDelta struct {
	Content          string              `json:"content"`
	ReasoningContent string              `json:"reasoning_content"`
	ToolCalls        []qwenToolCallDelta `json:"tool_calls"`
}

type qwenToolCallDelta struct {
	Index    int           `json:"index"`
	ID       string        `json:"id"`
	Function qwenFuncDelta `json:"function"`
}

type qwenFuncDelta struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type qwenUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
}
