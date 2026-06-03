package llm

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"iter"
	"net/http"
	"strings"
)

const (
	anthropicVersion          = "2023-06-01"
	anthropicMessagesPath     = "/v1/messages"
	anthropicDefaultMaxTokens = 8096
	anthropicDefaultBaseURL   = "https://api.anthropic.com"
)

// anthropicProvider speaks Anthropic's native /v1/messages dialect, fully self-contained:
// block-form messages, x-api-key auth, cache_control breakpoints, named-event SSE, and
// thinking-block + signature round-trip. Nothing here is shared with the OpenAI-compat
// providers — its wire is genuinely different and evolves on its own.
//
// anthropicProvider 完整自包含地讲 Anthropic 原生 /v1/messages 方言：block 形式 messages、
// x-api-key 鉴权、cache_control 断点、命名事件 SSE、thinking block + signature 回传。与
// OpenAI-compat 各家不共享任何东西——它的 wire 确实不同、自行演化。
type anthropicProvider struct{}

func newAnthropicProvider() *anthropicProvider { return &anthropicProvider{} }

func (p *anthropicProvider) Name() string           { return "anthropic" }
func (p *anthropicProvider) DefaultBaseURL() string { return anthropicDefaultBaseURL }

// BuildRequest encodes a Request into an Anthropic /v1/messages HTTP request. Auth:
// x-api-key header. The 1m context beta is opt-in via Options["context"]=="1m".
//
// BuildRequest 把 Request 编码为 Anthropic /v1/messages 请求。Auth：x-api-key。
// 1m context beta 经 Options["context"]=="1m" 开启。
func (p *anthropicProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	body, err := buildAnthropicBody(req)
	if err != nil {
		return nil, fmt.Errorf("llm.anthropic: build body: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(
		ctx, http.MethodPost, req.BaseURL+anthropicMessagesPath, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("llm.anthropic: new request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("x-api-key", req.Key)
	httpReq.Header.Set("anthropic-version", anthropicVersion)
	if req.Options["context"] == "1m" {
		httpReq.Header.Set("anthropic-beta", "context-1m-2025-08-07")
	}
	return httpReq, nil
}

func (p *anthropicProvider) ParseStream(ctx context.Context, resp *http.Response, _ Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		parseAnthropicSSE(ctx, resp.Body, yield)
	}
}

// parseAnthropicSSE consumes Anthropic's named-event SSE stream into StreamEvents. Unlike
// the OpenAI data-only stream, this tracks the current "event: <name>" line, so it cannot
// use the shared scanSSELines — named-event parsing is part of Anthropic's wire.
//
// parseAnthropicSSE 读 Anthropic 命名事件 SSE 流转成 StreamEvent。它要跟踪当前
// "event: <name>" 行，故不能用共享的 scanSSELines——命名事件解析是 Anthropic wire 的一部分。
func parseAnthropicSSE(ctx context.Context, body io.Reader, yield func(StreamEvent) bool) {
	scanner := bufio.NewScanner(body)
	scanner.Buffer(make([]byte, 0, 64*1024), maxSSELineBytes)
	var eventName string
	var inputTokens, outputTokens int

	for scanner.Scan() {
		if ctx.Err() != nil {
			return
		}
		line := scanner.Text()

		if name, ok := strings.CutPrefix(line, "event: "); ok {
			eventName = name
			continue
		}
		data, ok := strings.CutPrefix(line, "data: ")
		if !ok {
			continue
		}

		switch eventName {
		case "message_start":
			var e anthropicMsgStart
			if err := json.Unmarshal([]byte(data), &e); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.anthropic: parse message_start: %w", err)})
				return
			}
			if e.Message.Usage != nil {
				inputTokens = e.Message.Usage.InputTokens
			}

		case "content_block_start":
			var e anthropicBlockStart
			if err := json.Unmarshal([]byte(data), &e); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.anthropic: parse content_block_start: %w", err)})
				return
			}
			if e.ContentBlock.Type == "tool_use" {
				if !yield(StreamEvent{
					Type:      EventToolStart,
					ToolIndex: e.Index,
					ToolID:    e.ContentBlock.ID,
					ToolName:  e.ContentBlock.Name,
				}) {
					return
				}
			}

		case "content_block_delta":
			var e anthropicBlockDelta
			if err := json.Unmarshal([]byte(data), &e); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.anthropic: parse content_block_delta: %w", err)})
				return
			}
			if !emitAnthropicDelta(e, yield) {
				return
			}

		case "message_delta":
			var e anthropicMsgDelta
			if err := json.Unmarshal([]byte(data), &e); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.anthropic: parse message_delta: %w", err)})
				return
			}
			if e.Usage != nil {
				outputTokens = e.Usage.OutputTokens
			}
			if e.Delta.StopReason != "" {
				if !yield(StreamEvent{
					Type:         EventFinish,
					FinishReason: e.Delta.StopReason,
					InputTokens:  inputTokens,
					OutputTokens: outputTokens,
				}) {
					return
				}
			}
		}
	}

	if err := scanner.Err(); err != nil && ctx.Err() == nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.anthropic: scan: %w", err)})
	}
}

func emitAnthropicDelta(e anthropicBlockDelta, yield func(StreamEvent) bool) bool {
	switch e.Delta.Type {
	case "text_delta":
		if e.Delta.Text != "" {
			return yield(StreamEvent{Type: EventText, Delta: e.Delta.Text})
		}
	case "thinking_delta":
		if e.Delta.Thinking != "" {
			return yield(StreamEvent{Type: EventReasoning, Delta: e.Delta.Thinking})
		}
	case "signature_delta":
		// A zero-Delta EventReasoning carrying only the signature, so the consumer can
		// store it next to the reasoning content for verbatim round-trip next turn.
		// 一个 Delta 为空、只带 Signature 的 EventReasoning，让消费者把签名和 reasoning
		// 一起存，下一轮原样回传。
		if e.Delta.Signature != "" {
			return yield(StreamEvent{Type: EventReasoning, Signature: e.Delta.Signature})
		}
	case "input_json_delta":
		if e.Delta.PartialJSON != "" {
			return yield(StreamEvent{Type: EventToolDelta, ToolIndex: e.Index, ArgsDelta: e.Delta.PartialJSON})
		}
	}
	return true
}

// ── request body ──────────────────────────────────────────────────────────────

func buildAnthropicBody(req Request) ([]byte, error) {
	// Anthropic permanently 400s on any orphan tool_use_id — sanitize first.
	// Anthropic 一个孤儿 tool_use_id 就 400 锁死，先 sanitize。
	req.Messages = SanitizeMessages(req.Messages)
	msgs, err := toAnthropicMsgs(req.Messages)
	if err != nil {
		return nil, err
	}

	// max_tokens is required; the caller supplies the model's cap via Request.MaxTokens
	// (0 → default), so the provider never down-caps silently nor reads a catalog.
	// max_tokens 必填；caller 经 Request.MaxTokens 提供 model 上限（0 → 默认），provider
	// 既不静默截低也不读 catalog。
	maxTok := req.MaxTokens
	if maxTok == 0 {
		maxTok = anthropicDefaultMaxTokens
	}

	body := anthropicRequest{
		Model:     req.ModelID,
		MaxTokens: maxTok,
		Messages:  msgs,
		Stream:    true,
	}

	// thinking: on → budget_tokens (≥1024, < max_tokens; bump max_tokens if needed);
	// off → disabled; nil/auto → omit. (anthropicRequest has no temperature/top_p, so
	// there is nothing to guard off when thinking is on.)
	//
	// thinking：on → budget_tokens（≥1024 且 < max_tokens，必要时上调 max_tokens）；
	// off → disabled；nil/auto → 省略。（anthropicRequest 无 temperature/top_p，无需 guard。）
	if req.Thinking != nil && req.Thinking.Mode == "on" {
		budget := req.Thinking.Budget
		if budget == 0 {
			budget = min(max(maxTok/2, 1024), 8192)
		}
		if budget < 1024 {
			budget = 1024
		}
		if budget >= maxTok {
			maxTok = budget + 1024
			body.MaxTokens = maxTok
		}
		body.Thinking = &anthropicThinking{Type: "enabled", BudgetTokens: budget}
	} else if req.Thinking != nil && req.Thinking.Mode == "off" {
		body.Thinking = &anthropicThinking{Type: "disabled"}
	}

	if req.System != "" {
		// Send system as a block array (not a plain string) so cache_control attaches.
		// 用 block 数组形式发 system（而非纯字符串），以便附加 cache_control。
		raw, err := json.Marshal([]anthropicSystemBlock{{
			Type:         "text",
			Text:         req.System,
			CacheControl: &cacheControl{Type: "ephemeral"},
		}})
		if err != nil {
			return nil, fmt.Errorf("llm.anthropic: marshal system block: %w", err)
		}
		body.System = raw
	}
	if len(req.Tools) > 0 {
		body.Tools = toAnthropicTools(req.Tools)
	}
	return json.Marshal(body)
}

// toAnthropicMsgs converts LLMMessages; consecutive RoleTool entries merge into one user message.
//
// toAnthropicMsgs 把 LLMMessage 列表转为 Anthropic 格式；连续 RoleTool 合并成一条 user 消息。
func toAnthropicMsgs(msgs []LLMMessage) ([]anthropicMessage, error) {
	var out []anthropicMessage
	for i := 0; i < len(msgs); {
		m := msgs[i]
		if m.Role == RoleTool {
			var blocks []anthropicContent
			for i < len(msgs) && msgs[i].Role == RoleTool {
				blocks = append(blocks, anthropicContent{
					Type:      "tool_result",
					ToolUseID: msgs[i].ToolCallID,
					Content:   msgs[i].Content,
				})
				i++
			}
			out = append(out, anthropicMessage{Role: "user", Content: blocks})
			continue
		}
		am, err := toAnthropicMsg(m)
		if err != nil {
			return nil, err
		}
		out = append(out, am)
		i++
	}
	return out, nil
}

func toAnthropicMsg(m LLMMessage) (anthropicMessage, error) {
	switch m.Role {
	case RoleUser:
		return buildAnthropicUserMsg(m), nil
	case RoleAssistant:
		return buildAnthropicAssistantMsg(m), nil
	default:
		return anthropicMessage{}, fmt.Errorf("llm.anthropic: unexpected role %q: %w", m.Role, ErrBadRequest)
	}
}

func buildAnthropicUserMsg(m LLMMessage) anthropicMessage {
	if len(m.Parts) == 0 {
		return anthropicMessage{Role: "user", Content: []anthropicContent{{Type: "text", Text: m.Content}}}
	}
	blocks := make([]anthropicContent, 0, len(m.Parts))
	for _, part := range m.Parts {
		switch part.Type {
		case "text":
			blocks = append(blocks, anthropicContent{Type: "text", Text: part.Text})
		case "image_url":
			blocks = append(blocks, anthropicContent{
				Type: "image",
				Source: &anthropicImageSource{
					Type:      "base64",
					MediaType: extractMediaType(part.ImageURL),
					Data:      extractBase64Data(part.ImageURL),
				},
			})
		}
	}
	return anthropicMessage{Role: "user", Content: blocks}
}

func buildAnthropicAssistantMsg(m LLMMessage) anthropicMessage {
	var blocks []anthropicContent
	if m.ReasoningContent != "" {
		blocks = append(blocks, anthropicContent{
			Type:      "thinking",
			Thinking:  m.ReasoningContent,
			Signature: m.ReasoningSignature,
		})
	}
	for _, tc := range m.ToolCalls {
		// Malformed persisted args → fall back to "{}" silently (history corruption
		// must not 400 the live turn).
		// 历史里 arguments JSON 烂了 → 静默回退 "{}"（历史损坏不该让当前回合 400）。
		input := json.RawMessage("{}")
		if tc.Arguments != "" && json.Valid([]byte(tc.Arguments)) {
			input = json.RawMessage(tc.Arguments)
		}
		blocks = append(blocks, anthropicContent{Type: "tool_use", ID: tc.ID, Name: tc.Name, Input: input})
	}
	if m.Content != "" {
		blocks = append(blocks, anthropicContent{Type: "text", Text: m.Content})
	}
	return anthropicMessage{Role: "assistant", Content: blocks}
}

func toAnthropicTools(defs []ToolDef) []anthropicTool {
	out := make([]anthropicTool, len(defs))
	for i, d := range defs {
		out[i] = anthropicTool{Name: d.Name, Description: d.Description, InputSchema: d.Parameters}
	}
	// Cache breakpoint on the last tool caches the whole tools block (stable prefix).
	// 在最后一个工具上打断点，缓存整个 tools 块（稳定前缀）。
	out[len(out)-1].CacheControl = &cacheControl{Type: "ephemeral"}
	return out
}

// extractMediaType pulls the MIME from a base64 data URL; falls back to image/jpeg.
//
// extractMediaType 从 data URL 提取 MIME；非 data URL 回退 image/jpeg。
func extractMediaType(dataURL string) string {
	if !strings.HasPrefix(dataURL, "data:") {
		return "image/jpeg"
	}
	rest := strings.TrimPrefix(dataURL, "data:")
	if idx := strings.Index(rest, ";"); idx > 0 {
		return rest[:idx]
	}
	return "image/jpeg"
}

func extractBase64Data(dataURL string) string {
	if _, data, ok := strings.Cut(dataURL, ","); ok {
		return data
	}
	return dataURL
}

// ── wire types ────────────────────────────────────────────────────────────────

type anthropicRequest struct {
	Model     string             `json:"model"`
	MaxTokens int                `json:"max_tokens"`
	System    json.RawMessage    `json:"system,omitempty"`
	Messages  []anthropicMessage `json:"messages"`
	Tools     []anthropicTool    `json:"tools,omitempty"`
	Stream    bool               `json:"stream"`
	Thinking  *anthropicThinking `json:"thinking,omitempty"`
}

// anthropicThinking is the wire form of the thinking param; type "enabled" requires
// budget_tokens ≥ 1024 and < max_tokens.
//
// anthropicThinking 是 thinking 参数 wire 形式；type "enabled" 要求 budget_tokens ≥ 1024 且 < max_tokens。
type anthropicThinking struct {
	Type         string `json:"type"`
	BudgetTokens int    `json:"budget_tokens,omitempty"`
}

type anthropicMessage struct {
	Role    string             `json:"role"`
	Content []anthropicContent `json:"content"`
}

type anthropicContent struct {
	Type string `json:"type"`
	Text string `json:"text,omitempty"`
	// Thinking + Signature: signature is the opaque Anthropic token authorising re-use of
	// a thinking block; echo it verbatim when present.
	// Thinking + Signature：signature 是授权重用 thinking block 的不透明令牌，存在时原样回传。
	Thinking  string                `json:"thinking,omitempty"`
	Signature string                `json:"signature,omitempty"`
	ID        string                `json:"id,omitempty"`
	Name      string                `json:"name,omitempty"`
	Input     json.RawMessage       `json:"input,omitempty"`
	ToolUseID string                `json:"tool_use_id,omitempty"`
	Content   string                `json:"content,omitempty"`
	Source    *anthropicImageSource `json:"source,omitempty"`
}

type anthropicImageSource struct {
	Type      string `json:"type"`
	MediaType string `json:"media_type"`
	Data      string `json:"data"`
}

type cacheControl struct {
	Type string `json:"type"`
}

type anthropicTool struct {
	Name         string          `json:"name"`
	Description  string          `json:"description"`
	InputSchema  json.RawMessage `json:"input_schema"`
	CacheControl *cacheControl   `json:"cache_control,omitempty"`
}

type anthropicSystemBlock struct {
	Type         string        `json:"type"`
	Text         string        `json:"text"`
	CacheControl *cacheControl `json:"cache_control,omitempty"`
}

type anthropicMsgStart struct {
	Message struct {
		Usage *struct {
			InputTokens int `json:"input_tokens"`
		} `json:"usage"`
	} `json:"message"`
}

type anthropicBlockStart struct {
	Index        int `json:"index"`
	ContentBlock struct {
		Type string `json:"type"`
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"content_block"`
}

type anthropicBlockDelta struct {
	Index int `json:"index"`
	Delta struct {
		Type        string `json:"type"`
		Text        string `json:"text"`
		Thinking    string `json:"thinking"`
		Signature   string `json:"signature"`
		PartialJSON string `json:"partial_json"`
	} `json:"delta"`
}

type anthropicMsgDelta struct {
	Delta struct {
		StopReason string `json:"stop_reason"`
	} `json:"delta"`
	Usage *struct {
		OutputTokens int `json:"output_tokens"`
	} `json:"usage"`
}
