package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"net/http"
)

// openrouterProvider speaks OpenRouter's /chat/completions API directly.
// It owns its own BuildRequest (top-level reasoning:{effort|max_tokens} per
// 03 §10; effort preferred over max_tokens when both are set) and ParseStream
// (reads delta.reasoning AND delta.reasoning_content alias → EventReasoning;
// scanSSELines already skips ':' keep-alive comment lines). Written to
// OpenRouter's documented standard; shares only transport-level primitives.
//
// openrouterProvider 直接按 OpenRouter /chat/completions API 标准实现。
// 自有 BuildRequest（顶层 reasoning:{effort|max_tokens}，03 §10；effort 优先）
// 和 ParseStream（delta.reasoning 及 reasoning_content 别名→EventReasoning；
// scanSSELines 已跳过 ':' 心跳行）；仅共享 transport 层原语。

type openrouterProvider struct{}

func newOpenRouterProvider() *openrouterProvider { return &openrouterProvider{} }

func (p *openrouterProvider) Name() string           { return "openrouter" }
func (p *openrouterProvider) DefaultBaseURL() string { return "https://openrouter.ai/api/v1" }

// BuildRequest encodes a Request into an OpenRouter /chat/completions HTTP request.
//
// Thinking encoding per 03 §10:
//   - on + Effort set → reasoning:{effort:Effort}
//   - on + no Effort + Budget>0 → reasoning:{max_tokens:Budget}
//   - on + neither  → reasoning:{effort:"medium"} (default)
//   - off           → omit reasoning (no documented clean disable form)
//   - nil/auto      → omit reasoning
//
// BuildRequest 把 Request 编码为 OpenRouter /chat/completions HTTP 请求。
// thinking 编码（03 §10）：on+Effort→reasoning:{effort}；on+Budget→reasoning:{max_tokens}；
// on 无参→{effort:medium}；off/nil/auto→省略 reasoning。
func (p *openrouterProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toOpenAIMsgs(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.openrouter: build messages: %w", err)
	}
	body := orRequest{
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
	// Thinking encoding: nil/auto/off → no reasoning field.
	// on + Effort preferred over Budget (mutually exclusive per 03 §10).
	//
	// thinking 编码：nil/auto/off→不发 reasoning；on 时 Effort 优先于 Budget（互斥）。
	if req.Thinking != nil && req.Thinking.Mode == "on" {
		r := &orReasoningField{}
		if req.Thinking.Effort != "" {
			r.Effort = req.Thinking.Effort
		} else if req.Thinking.Budget > 0 {
			r.MaxTokens = req.Thinking.Budget
		} else {
			r.Effort = "medium"
		}
		body.Reasoning = r
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.openrouter: marshal body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.openrouter: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	return httpReq, nil
}

// ParseStream reads OpenRouter SSE chunks and yields StreamEvents.
// OpenRouter sends ':' keep-alive comment lines (": OPENROUTER PROCESSING") —
// these are already skipped by scanSSELines's "data: " prefix filter.
// Reasoning arrives in delta.reasoning OR delta.reasoning_content (alias);
// delta.reasoning_details may also appear but is ignored (not crashed on).
//
// ParseStream 读 OpenRouter SSE chunk 并 yield StreamEvent。
// ':' 心跳注释行（如 ": OPENROUTER PROCESSING"）已由 scanSSELines 的 "data: " 过滤跳过。
// reasoning 在 delta.reasoning 或 delta.reasoning_content（别名）；
// delta.reasoning_details 可能出现，忽略不崩溃。
func (p *openrouterProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		state := newToolCallState()
		scanErr := scanSSELines(resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk orChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.openrouter: malformed SSE chunk: %w", err)})
				return false
			}
			return emitOpenRouterChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.openrouter: scan: %w", scanErr)})
		}
	}
}

// emitOpenRouterChunk converts one OpenRouter SSE chunk to StreamEvents.
// Handles mid-stream errors, reasoning delta (via both field names), content
// delta, tool calls, and finish with usage.
//
// emitOpenRouterChunk 把一个 OpenRouter SSE chunk 转为 StreamEvent 序列。
// 处理流中错误、reasoning delta（双字段名）、content delta、tool_calls、finish+usage。
func emitOpenRouterChunk(chunk orChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
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

	// OpenRouter uses delta.reasoning as the primary field name; delta.reasoning_content
	// is an alias provided for CN-family compatibility. Prefer reasoning over alias.
	//
	// OpenRouter 主字段名为 delta.reasoning；delta.reasoning_content 是别名（CN 兼容）。
	reasoningDelta := delta.Reasoning
	if reasoningDelta == "" {
		reasoningDelta = delta.ReasoningContent
	}
	if reasoningDelta != "" {
		if !yield(StreamEvent{Type: EventReasoning, Delta: reasoningDelta}) {
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

// ── OpenRouter-specific wire types ───────────────────────────────────────────
//
// OpenRouter is an OpenAI-compat aggregator with one key addition: a top-level
// "reasoning" object for routing thinking across upstream providers (Anthropic,
// OpenAI, Gemini, DeepSeek). Response deltas use "reasoning" as the primary
// field name, with "reasoning_content" as an alias.
//
// OpenRouter 是 OpenAI-compat 聚合器，主要增量：顶层 "reasoning" 对象（跨上游转
// thinking 控制）。响应 delta 主字段名 "reasoning"，"reasoning_content" 为别名。

type orRequest struct {
	Model         string            `json:"model"`
	Messages      []oaiMessage      `json:"messages"`
	Tools         []oaiTool         `json:"tools,omitempty"`
	Stream        bool              `json:"stream"`
	StreamOptions *oaiStreamOptions `json:"stream_options,omitempty"`
	// Reasoning object (03 §10): effort and max_tokens are mutually exclusive.
	// reasoning 对象（03 §10）：effort 与 max_tokens 互斥。
	Reasoning *orReasoningField `json:"reasoning,omitempty"`
}

type orReasoningField struct {
	Effort    string `json:"effort,omitempty"`
	MaxTokens int    `json:"max_tokens,omitempty"`
}

type orChunk struct {
	Choices []orChoice     `json:"choices"`
	Usage   *oaiUsage      `json:"usage"`
	Error   *oaiChunkError `json:"error,omitempty"`
}

type orChoice struct {
	Delta        orDelta `json:"delta"`
	FinishReason string  `json:"finish_reason"`
}

type orDelta struct {
	Content string `json:"content"`
	// OpenRouter primary reasoning field; "reasoning_content" is the alias
	// provided for CN-family (DeepSeek/Qwen) compatibility.
	//
	// OpenRouter 主 reasoning 字段；"reasoning_content" 是 CN 家族别名。
	Reasoning        string               `json:"reasoning"`
	ReasoningContent string               `json:"reasoning_content"`
	ToolCalls        []orToolCallDelta    `json:"tool_calls"`
}

// orToolCallDelta mirrors oaiToolCallDelta for OpenRouter — same shape but typed
// separately so openrouter.go reads end-to-end as its own provider story.
//
// orToolCallDelta 镜像 oaiToolCallDelta；类型独立，保持 openrouter.go 可独立阅读。
type orToolCallDelta struct {
	Index    int          `json:"index"`
	ID       string       `json:"id"`
	Function oaiFuncDelta `json:"function"`
}
