package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// moonshotProvider speaks Moonshot Kimi's /v1 /chat/completions API.
// It owns its own BuildRequest (thinking:{type:enabled/disabled} for k2.5/k2.6
// per 03 §8; kimi-k2-thinking model has intrinsic thinking, no params needed)
// and ParseStream (reads delta.reasoning_content → EventReasoning; official
// api.moonshot.cn uses the underscore form, not the bare "reasoning" alias).
//
// moonshotProvider 按 Moonshot Kimi /v1 API 标准实现。自有 BuildRequest
// （k2.5/k2.6 的 thinking:{type:enabled/disabled}，03 §8；kimi-k2-thinking 模型
// 内禀 thinking，无需参数）和 ParseStream（delta.reasoning_content→EventReasoning；
// 官方 api.moonshot.cn 用下划线形，非裸 "reasoning" 别名）。

type moonshotProvider struct{}

func newMoonshotProvider() *moonshotProvider { return &moonshotProvider{} }

func (p *moonshotProvider) Name() string           { return "moonshot" }
func (p *moonshotProvider) DefaultBaseURL() string { return "https://api.moonshot.cn/v1" }

// BuildRequest encodes a Request into a Moonshot Kimi /chat/completions HTTP request.
//
// Thinking encoding per 03 §8:
//   - kimi-k2-thinking model: intrinsic thinking — no params needed; ThinkingSpec
//     is respected only for explicit on/off on k2.5/k2.6-style models.
//   - on  → thinking:{type:"enabled"}
//   - off → thinking:{type:"disabled"}
//   - nil/auto → omit thinking field
//
// max_tokens note: Moonshot deprecated max_tokens in favour of
// max_completion_tokens, but since Forgify does not currently send a cap, we
// do not add one. This preserves byte-identical default behaviour.
//
// BuildRequest 把 Request 编码为 Moonshot Kimi /chat/completions HTTP 请求。
// thinking 编码（03 §8）：on→{type:"enabled"}；off→{type:"disabled"}；nil/auto→省略。
// kimi-k2-thinking 内禀 thinking，无需参数。
// max_tokens：Moonshot 已弃用，改用 max_completion_tokens；当前不发上限，保持默认行为。
func (p *moonshotProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.moonshot: build messages: %w", err)
	}
	body := moonshotRequest{
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
	// Thinking encoding: nil/auto → no field; on → enabled; off → disabled.
	// kimi-k2-thinking callers typically pass nil ThinkingSpec (model is intrinsic);
	// k2.5/k2.6 callers pass Mode=on or Mode=off to toggle the thinking param.
	//
	// thinking 编码：nil/auto→不发；on→enabled；off→disabled。
	// kimi-k2-thinking 调用方通常传 nil（模型内禀）；k2.5/k2.6 传 on/off。
	if req.Thinking != nil && req.Thinking.Mode != "auto" {
		switch req.Thinking.Mode {
		case "on":
			body.Thinking = &moonshotThinkingField{Type: "enabled"}
		case "off":
			body.Thinking = &moonshotThinkingField{Type: "disabled"}
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

// ParseStream reads Moonshot Kimi SSE chunks and yields StreamEvents.
// Official api.moonshot.cn uses delta.reasoning_content (underscore form).
// Do NOT fall back to delta.reasoning — the underscore form is the documented
// field name and Together/NIM aliases must not leak into this provider.
//
// ParseStream 读 Moonshot SSE chunk 并 yield StreamEvent。
// 官方 api.moonshot.cn 用 delta.reasoning_content（下划线形）。
// 不得 fallback 到 delta.reasoning——下划线形是文档字段名，Together/NIM 别名不属于本 provider。
func (p *moonshotProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		state := newToolCallState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk moonshotChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.moonshot: malformed SSE chunk: %w", err)})
				return false
			}
			return emitMoonshotChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.moonshot: scan: %w", scanErr)})
		}
	}
}

// emitMoonshotChunk converts one Moonshot SSE chunk to StreamEvents.
// reasoning_content → EventReasoning (before content), content → EventText,
// tool_calls → EventToolStart + EventToolDelta, finish_reason → EventFinish.
//
// emitMoonshotChunk 把一个 Moonshot SSE chunk 转为 StreamEvent 序列。
// reasoning_content→EventReasoning（先于 content）；content→EventText；
// tool_calls→EventToolStart+EventToolDelta；finish_reason→EventFinish。
func emitMoonshotChunk(chunk moonshotChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
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

	// Official api.moonshot.cn streams reasoning_content (underscore) before content.
	// 官方 api.moonshot.cn 先流 reasoning_content（下划线形）再流 content。
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

// ── Moonshot-specific wire types ──────────────────────────────────────────────
//
// moonshotThinkingField is the thinking object for Moonshot k2.5/k2.6. It has
// the same JSON shape as Zhipu ({type:...}) but is typed separately so
// moonshot.go reads end-to-end as its own provider story.
//
// moonshotThinkingField 是 Moonshot k2.5/k2.6 的 thinking 对象；JSON 形态与
// 智谱相同（{type:...}），但类型独立，保持 moonshot.go 可独立阅读。

type moonshotThinkingField struct {
	Type string `json:"type"`
}

type moonshotRequest struct {
	Model         string                 `json:"model"`
	Messages      []oaiMessage           `json:"messages"`
	Tools         []oaiTool              `json:"tools,omitempty"`
	Stream        bool                   `json:"stream"`
	StreamOptions *oaiStreamOptions      `json:"stream_options,omitempty"`
	Thinking      *moonshotThinkingField `json:"thinking,omitempty"`
}

type moonshotChunk struct {
	Choices []moonshotChoice `json:"choices"`
	Usage   *oaiUsage        `json:"usage"`
	Error   *oaiChunkError   `json:"error,omitempty"`
}

type moonshotChoice struct {
	Delta        moonshotDelta `json:"delta"`
	FinishReason string        `json:"finish_reason"`
}

type moonshotDelta struct {
	Content          string                `json:"content"`
	// reasoning_content is the official api.moonshot.cn field (underscore form).
	// Do not add a "reasoning" alias — Together/NIM aliases are not part of the
	// official Moonshot API documented at platform.kimi.ai.
	//
	// reasoning_content 是官方 api.moonshot.cn 字段（下划线形）。
	// 不加 "reasoning" 别名——Together/NIM 别名不属于官方 Moonshot API。
	ReasoningContent string                `json:"reasoning_content"`
	ToolCalls        []moonshotToolCallDelta `json:"tool_calls"`
}

// moonshotToolCallDelta mirrors oaiToolCallDelta for Moonshot — same shape but
// typed separately so moonshot.go reads end-to-end as its own provider story.
//
// moonshotToolCallDelta 镜像 oaiToolCallDelta；类型独立，保持 moonshot.go 可独立阅读。
type moonshotToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}
