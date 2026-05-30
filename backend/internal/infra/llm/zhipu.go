package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// zhipuProvider speaks Zhipu GLM's BigModel /api/paas/v4 /chat/completions API.
// It owns its own BuildRequest (thinking:{type:enabled/disabled} per 03 §7;
// tool_choice restricted to "auto") and ParseStream (reads
// delta.reasoning_content → EventReasoning; handles extended finish_reason
// values: sensitive, network_error).
//
// zhipuProvider 按智谱 GLM BigModel /api/paas/v4 API 标准实现。自有 BuildRequest
// （thinking:{type:enabled/disabled}，03 §7；tool_choice 只支持 "auto"）和 ParseStream
// （delta.reasoning_content→EventReasoning；处理扩展 finish_reason：sensitive/network_error）。

type zhipuProvider struct{}

func newZhipuProvider() *zhipuProvider { return &zhipuProvider{} }

func (p *zhipuProvider) Name() string           { return "zhipu" }
func (p *zhipuProvider) DefaultBaseURL() string { return "https://open.bigmodel.cn/api/paas/v4" }

// BuildRequest encodes a Request into a Zhipu GLM /chat/completions HTTP request.
//
// Thinking encoding per 03 §7:
//   - on  → thinking:{type:"enabled"}
//   - off → thinking:{type:"disabled"}
//   - nil/auto → omit thinking field entirely
//
// tool_choice quirk: Zhipu only supports "auto" — any other value may cause a
// 400. When tools are present we always send tool_choice:"auto"; we do not send
// it for tool-less requests.
//
// BuildRequest 把 Request 编码为智谱 GLM /chat/completions HTTP 请求。
// thinking 编码（03 §7）：on→{type:"enabled"}；off→{type:"disabled"}；nil/auto→省略。
// tool_choice quirk：Zhipu 只支持 "auto"；有 tools 时固定发 "auto"。
func (p *zhipuProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.zhipu: build messages: %w", err)
	}
	body := zhipuRequest{
		Model:    req.ModelID,
		Messages: msgs,
		Stream:   !req.DisableStream,
	}
	if !req.DisableStream {
		body.StreamOptions = &oaiStreamOptions{IncludeUsage: true}
	}
	if len(req.Tools) > 0 {
		body.Tools = toOpenAITools(req.Tools)
		// Zhipu only supports tool_choice:"auto"; sending other values may 400.
		// Zhipu 的 tool_choice 只支持 "auto"，其他值可能返 400。
		body.ToolChoice = "auto"
	}
	// Thinking encoding: nil/auto → no field; on → enabled; off → disabled.
	// Zhipu supports both streaming and non-streaming with thinking (no Qwen-style guard).
	//
	// thinking 编码：nil/auto→不发；on→enabled；off→disabled。
	// Zhipu 流式/非流式均支持 thinking（无 Qwen 那种流式守卫）。
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		switch req.Thinking.Mode {
		case "on":
			body.Thinking = &zhipuThinkingField{Type: "enabled"}
		case "off":
			body.Thinking = &zhipuThinkingField{Type: "disabled"}
		}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.zhipu: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.zhipu: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	// Zhipu uses the raw API key directly (no JWT needed; JWT is legacy).
	// Zhipu 直接用原始 key（JWT 是 legacy，不需实现）。
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

// ParseStream reads Zhipu GLM SSE chunks and yields StreamEvents.
// reasoning_content → EventReasoning before content → EventText.
// Extended finish_reason values (sensitive, network_error) are passed through
// as-is inside EventFinish — the caller handles display policy.
//
// ParseStream 读智谱 GLM SSE chunk 并 yield StreamEvent。
// reasoning_content→EventReasoning 先于 content→EventText。
// 扩展 finish_reason（sensitive/network_error）直接透传到 EventFinish。
func (p *zhipuProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		state := newToolCallState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk zhipuChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.zhipu: malformed SSE chunk: %w", err)})
				return false
			}
			return emitZhipuChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.zhipu: scan: %w", scanErr)})
		}
	}
}

// emitZhipuChunk converts one Zhipu GLM SSE chunk to StreamEvents.
// reasoning_content → EventReasoning (before content), content → EventText,
// tool_calls → EventToolStart + EventToolDelta, finish_reason → EventFinish.
// finish_reason may be "sensitive" or "network_error" (Zhipu-specific) in
// addition to the standard OpenAI values.
//
// emitZhipuChunk 把一个智谱 GLM SSE chunk 转为 StreamEvent 序列。
// reasoning_content→EventReasoning（先于 content）；content→EventText；
// tool_calls→EventToolStart+EventToolDelta；finish_reason→EventFinish。
// finish_reason 可能是 Zhipu 专属的 "sensitive" 或 "network_error"。
func emitZhipuChunk(chunk zhipuChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
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

	// Emit reasoning before content (Zhipu GLM-4.5+ streams reasoning_content first).
	// 先 emit reasoning 再 emit content（GLM-4.5+ 先流 reasoning_content）。
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

	// finish_reason may include Zhipu-specific values "sensitive" and "network_error"
	// in addition to "stop"/"tool_calls"/"length". Pass through as-is.
	//
	// finish_reason 除标准 stop/tool_calls/length 外还可能是 Zhipu 专属的
	// "sensitive" 或 "network_error"，直接透传。
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

// ── Zhipu-specific wire types ─────────────────────────────────────────────────
//
// zhipuThinkingField is the thinking object for Zhipu GLM. It has the same
// JSON shape as DeepSeek/Moonshot ({type:...}) but is typed separately so
// zhipu.go reads end-to-end as its own provider story.
//
// zhipuThinkingField 是智谱 GLM 的 thinking 对象；JSON 形态与 DeepSeek/Moonshot
// 相同（{type:...}），但类型独立，保持 zhipu.go 可独立阅读。

type zhipuThinkingField struct {
	Type string `json:"type"`
}

type zhipuRequest struct {
	Model         string              `json:"model"`
	Messages      []oaiMessage        `json:"messages"`
	Tools         []oaiTool           `json:"tools,omitempty"`
	ToolChoice    string              `json:"tool_choice,omitempty"`
	Stream        bool                `json:"stream"`
	StreamOptions *oaiStreamOptions   `json:"stream_options,omitempty"`
	Thinking      *zhipuThinkingField `json:"thinking,omitempty"`
}

type zhipuChunk struct {
	Choices []zhipuChoice  `json:"choices"`
	Usage   *oaiUsage      `json:"usage"`
	Error   *oaiChunkError `json:"error,omitempty"`
}

type zhipuChoice struct {
	Delta        zhipuDelta `json:"delta"`
	FinishReason string     `json:"finish_reason"`
}

type zhipuDelta struct {
	Content          string              `json:"content"`
	ReasoningContent string              `json:"reasoning_content"`
	ToolCalls        []zhipuToolCallDelta `json:"tool_calls"`
}

// zhipuToolCallDelta mirrors oaiToolCallDelta for Zhipu — same shape but typed
// separately so zhipu.go reads end-to-end as its own provider story.
//
// zhipuToolCallDelta 镜像 oaiToolCallDelta；类型独立，保持 zhipu.go 可独立阅读。
type zhipuToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}
