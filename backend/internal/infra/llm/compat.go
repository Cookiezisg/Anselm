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

// compatProvider is THE OpenAI-compatible dialect. Eight providers used to carry a near-identical
// copy of it (~3800 lines); this is the one implementation they now share, with the genuine
// per-family differences named in a [compatSpec] instead of duplicated around them.
//
// **Why the duplication had to end.** The old comment on each copy said it out loud — "duplication
// is deliberate so a per-provider quirk never forces a branch into shared code" — and that argument
// is real, but it was paid for in a currency nobody was counting: a wire fix has to be applied N
// times, and the day one is missed is invisible. Both halves of that bill came due in one week:
//
//   - The tool-argument wire fix (some endpoints stream argument INCREMENTS, others re-send the
//     whole string each chunk) was applied to seven copies. `openai.go` never got it — so an
//     OpenAI-compatible endpoint that sends cumulative arguments produced garbage tool calls there
//     and correct ones everywhere else, for no reason a reader could ever find.
//   - Merging makes that class of bug structurally impossible: there is one parser, so a fix lands
//     once and reaches every family, including the ~160 catalog providers that H12 routes here.
//
// **What did NOT get flattened.** The differences that are real stay real and stay visible: the
// request-body knobs each family speaks (§encode), how it renders content parts (§parts — Ollama
// does not use content parts at all), and whether a turn needs preparing before it goes out
// (§prepare — DeepSeek's reasoning_content round-trip rule). A spec field is a fact about a
// provider; a branch inside shared code would have been a fact about our code.
//
// compatProvider 是**那一条** OpenAI 兼容方言。此前八家各持一份近乎相同的拷贝(约 3800 行);这里是
// 它们现在共用的**唯一**实现,而真正的家族差异写进 [compatSpec]、不再散在拷贝之间。
//
// **重复为什么必须终结。** 旧注释把理由说得很明白——「重复是故意的:某家的特性永不逼共享代码加分支」
// ——这条论证是真的,但它的代价用的是**没人在数的货币**:一处线缆修复要修 N 遍,而漏掉一遍的那天
// **是看不见的**。这张账单的两半在同一周同时到期:
//
//   - 工具参数的线缆修复(有的端点流式发**增量**、有的每块**重发整串**)修了七份拷贝,`openai.go`
//     **从没拿到**——于是一个发累积值的 OpenAI 兼容端点在那里产出乱码工具调用、在别处一切正常,
//     而读代码的人**永远找不到**这个差别的理由。
//   - 合并让这一类 bug **结构上不可能**:只有一个解析器,故一处修复落地一次、抵达每一家,包括 H12
//     会路由到这里的约 160 家目录供应商。
//
// **没有被抹平的东西。** 真实的差异仍然真实、仍然可见:每家会说的请求体旋钮(§encode)、它怎么渲染
// content part(§parts——Ollama **根本不用** content part)、以及一个回合出门前要不要先处理
// (§prepare——DeepSeek 的 reasoning_content round-trip 规则)。**spec 里的一个字段是关于供应商的
// 事实;共享代码里的一个分支则是关于我们代码的事实。**
type compatProvider struct{ spec compatSpec }

// compatSpec is everything that differs between OpenAI-compatible families. Anything not here is,
// by construction, identical across all of them.
//
// compatSpec 是 OpenAI 兼容家族之间**全部**的差异。不在这里的东西,**按构造**在所有家之间相同。
type compatSpec struct {
	// name is the provider key used by the factory and stored on api_keys rows.
	name string
	// baseURL answers DefaultBaseURL. A func, not a string, because two families compute it at call
	// time (the managed gateway reads an env override; Qwen derives a regional host).
	// baseURL 回答 DefaultBaseURL。用 func 而非 string,因为有两家在调用时才算得出来(受管网关读
	// env 覆盖;Qwen 派生区域主机)。
	baseURL func() string

	// prepare adjusts the message list before encoding. Only DeepSeek needs it, and its rule is a
	// real upstream constraint rather than a preference — see deepseek.go.
	// prepare 在编码前调整消息列表。只有 DeepSeek 需要,而它那条规则是**真实的上游约束**、不是偏好。
	prepare func([]LLMMessage) []LLMMessage

	// parts renders one user message's parts. nil = the plain text/image_url pair every family
	// supports. A family that renders more (OpenAI's file, Qwen's video/audio) or renders them
	// somewhere else entirely (Ollama's message-level `images`) supplies its own.
	// parts 渲染一条 user 消息的 parts。nil = 每家都支持的 text/image_url 那一对。渲得更多的
	// (OpenAI 的 file、Qwen 的 video/audio)或**渲在别处**的(Ollama 的消息级 `images`)自带一个。
	parts func(m LLMMessage) (compatMessage, error)

	// encode writes this family's native knobs and token cap onto the request body. Each family
	// touches only its own fields; the body type is a superset and everything else stays off the
	// wire through omitempty. A guard test asserts exactly that (compat_test.go).
	// encode 把本家的原生旋钮与 token 上限写进请求体。每家只碰**自己的**字段;body 类型是超集,其余
	// 的靠 omitempty 不上线缆。守卫测试断言的正是这一点。
	encode func(req Request, body *compatRequest)

	// forceNonStreamWithTools turns streaming OFF for a request that carries tools. Ollama needs it:
	// its streamed tool calls are unusable, so the choice is between a working non-streamed call and
	// a streamed one that produces nothing callable.
	// forceNonStreamWithTools 让**带工具**的请求关掉流式。Ollama 需要它:它流式的 tool call 不可用,
	// 故这是「能用的非流式」与「流着却产不出可调用东西」之间的选择。
	forceNonStreamWithTools bool

	// toolChoice, when set, is sent alongside a non-empty tools array (Zhipu needs "auto" or it
	// will not call a tool at all).
	// toolChoice 非空时随非空 tools 一起发(智谱不给它就根本不调工具)。
	toolChoice string

	// wire declares which part kinds this dialect renders. It must agree with [parts] — a mask that
	// promises more than the encoder writes is a silent drop, and a guard test compares them.
	// wire 声明本方言渲哪些 part。它必须与 [parts] **一致**——承诺多于编码器实际写出的掩码是一次
	// 静默丢弃,守卫测试逐家比对二者。
	wire partMask

	// chatURL builds the endpoint this family posts to. nil = `{base}/chat/completions`, which is what
	// every OpenAI-compatible provider but one uses. Azure is the exception and the reason this is a
	// func: its deployment name lives in the PATH and its API version in a query parameter — a shape
	// no `api` string in any catalog can express.
	// chatURL 构造本家 POST 的端点。nil = `{base}/chat/completions`,除一家外每个 OpenAI 兼容 provider
	// 都是它。Azure 是那个例外,也是这里用 func 的理由:它的 deployment 名在**路径**里、API 版本在
	// **query** 里——一个**任何目录的 `api` 字符串都表达不了**的形状。
	chatURL func(req Request) string

	// auth writes the credential header. nil = `Authorization: Bearer`. Azure uses `api-key`, and
	// sending it as a bearer token gets a 401 that reads exactly like a wrong key.
	// auth 写凭证头。nil = `Authorization: Bearer`。Azure 用 `api-key`,而把它当 bearer 发会换来一个
	// **读起来和「key 填错了」一模一样**的 401。
	auth func(h http.Header, key string)

	// describe parses this provider's /models probe body. Every family has its own because the
	// catalog key and the knob table are its own.
	// describe 解析本家 /models 探测体。每家自带,因为目录 key 与旋钮表都是自己的。
	describe func(raw string) ([]ModelInfo, error)
}

func (p *compatProvider) Name() string           { return p.spec.name }
func (p *compatProvider) DefaultBaseURL() string { return p.spec.baseURL() }

func (p *compatProvider) DescribeModels(raw string) ([]ModelInfo, error) {
	return p.spec.describe(raw)
}

// BuildRequest encodes a Request into `POST {base}/chat/completions` with Bearer auth — the shape
// every family in this dialect agrees on. What varies is written by spec.encode.
//
// BuildRequest 把 Request 编码成 `POST {base}/chat/completions` + Bearer——本方言每一家都同意的形状。
// 变化的部分由 spec.encode 写。
func (p *compatProvider) BuildRequest(ctx context.Context, req Request) (*http.Request, error) {
	req.Messages = SanitizeMessages(req.Messages)
	if p.spec.prepare != nil {
		req.Messages = p.spec.prepare(req.Messages)
	}
	msgs, err := p.toMessages(req.Messages, req.System)
	if err != nil {
		return nil, fmt.Errorf("llm.%s: build messages: %w", p.spec.name, err)
	}
	stream := p.streaming(req)
	body := compatRequest{
		Model:    req.ModelID,
		Messages: msgs,
		Stream:   stream,
	}
	if stream {
		body.StreamOptions = &compatStreamOptions{IncludeUsage: true}
	}
	if len(req.Tools) > 0 {
		body.Tools = toCompatTools(req.Tools)
		body.ToolChoice = p.spec.toolChoice
	}
	if p.spec.encode != nil {
		p.spec.encode(req, &body)
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("llm.%s: marshal body: %w", p.spec.name, err)
	}
	url := req.BaseURL + "/chat/completions"
	if p.spec.chatURL != nil {
		url = p.spec.chatURL(req)
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("llm.%s: new request: %w", p.spec.name, err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if p.spec.auth != nil {
		p.spec.auth(httpReq.Header, req.Key)
	} else {
		httpReq.Header.Set("Authorization", "Bearer "+req.Key)
	}
	return httpReq, nil
}

// streaming answers whether THIS request goes out streamed — the single predicate both halves
// consult, because a request built non-streamed and parsed as SSE reads the body with the wrong
// grammar and yields nothing. The old per-family copies computed it in BuildRequest and re-derived
// it from `DisableStream` alone in ParseStream; Ollama's own comment claimed the two agreed while
// the code did not. One function, asked twice.
//
// streaming 回答**这一条**请求是不是流式出门——两半共查的**同一个**谓词,因为「按非流式构建、却按 SSE
// 解析」会用错误的文法读 body、什么也产不出。旧的逐家拷贝在 BuildRequest 里算它、在 ParseStream 里
// **只**据 `DisableStream` 重新推;Ollama 自己的注释声称两者一致,而代码并非如此。**一个函数,问两次。**
func (p *compatProvider) streaming(req Request) bool {
	if req.DisableStream {
		return false
	}
	return !(p.spec.forceNonStreamWithTools && len(req.Tools) > 0)
}

// ParseStream reads SSE chunks (or one non-streaming body) into StreamEvents.
//
// ParseStream 读 SSE chunk(或单条非流式 body)为 StreamEvent。
func (p *compatProvider) ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		if !p.streaming(req) {
			parseCompatNonStreaming(p.spec.name, resp.Body, yield)
			return
		}
		state := newToolCallState()
		scanErr := scanSSELines(ctx, resp.Body, func(payload []byte) bool {
			if ctx.Err() != nil {
				return false
			}
			var chunk compatChunk
			if err := json.Unmarshal(payload, &chunk); err != nil {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.%s: malformed SSE chunk: %w", p.spec.name, err)})
				return false
			}
			return emitCompatChunk(chunk, state, yield)
		})
		if scanErr != nil && ctx.Err() == nil {
			yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.%s: scan: %w", p.spec.name, scanErr)})
		}
	}
}

// ── message encoding ──────────────────────────────────────────────────────────

func (p *compatProvider) toMessages(msgs []LLMMessage, system string) ([]compatMessage, error) {
	var out []compatMessage
	if system != "" {
		out = append(out, compatMessage{Role: "system", Content: jsonString(system)})
	}
	for _, m := range msgs {
		cm, err := p.toMessage(m)
		if err != nil {
			return nil, err
		}
		out = append(out, cm)
	}
	return out, nil
}

func (p *compatProvider) toMessage(m LLMMessage) (compatMessage, error) {
	switch m.Role {
	case RoleUser:
		if len(m.Parts) == 0 {
			return compatMessage{Role: "user", Content: jsonString(m.Content)}, nil
		}
		if p.spec.parts != nil {
			return p.spec.parts(m)
		}
		return compatTextImageParts(m)
	case RoleAssistant:
		return buildCompatAssistantMsg(m), nil
	case RoleTool:
		return compatMessage{Role: "tool", Content: jsonString(m.Content), ToolCallID: m.ToolCallID}, nil
	default:
		return compatMessage{}, fmt.Errorf("llm.compat: unknown role %q: %w", m.Role, ErrBadRequest)
	}
}

// compatTextImageParts is the floor every OpenAI-compatible family stands on: text and image_url.
// Anything else is SKIPPED rather than refused — the attachment layer already degraded whatever it
// could (a PDF becomes text), and a hard error here would fail a whole turn over one part that the
// model was never going to be shown anyway.
//
// compatTextImageParts 是每家 OpenAI 兼容都站着的地板:text 与 image_url。其余一律**跳过**而非拒绝
// ——附件层已经把能降级的都降级了(PDF 变文本),而在这里硬报错会为**一个模型本来也看不到的 part**
// 弄挂整个回合。
func compatTextImageParts(m LLMMessage) (compatMessage, error) {
	parts := make([]compatContentPart, 0, len(m.Parts))
	for _, part := range m.Parts {
		switch part.Type {
		case "text":
			parts = append(parts, compatContentPart{Type: "text", Text: part.Text})
		case "image_url":
			parts = append(parts, compatContentPart{Type: "image_url", ImageURL: &compatImageURL{URL: part.ImageURL}})
		}
	}
	return compatPartsMessage(parts)
}

func compatPartsMessage(parts []compatContentPart) (compatMessage, error) {
	raw, err := json.Marshal(parts)
	if err != nil {
		return compatMessage{}, fmt.Errorf("llm.compat: marshal parts: %w", err)
	}
	return compatMessage{Role: "user", Content: raw}, nil
}

func buildCompatAssistantMsg(m LLMMessage) compatMessage {
	// Reasoning-only turn → copy reasoning into content, else a strict provider 400s next turn on an
	// assistant message with neither content nor tool_calls.
	// 仅 reasoning 的回合 → 把 reasoning 复制进 content,否则严格 provider 下一轮会 400。
	if m.Content == "" && len(m.ToolCalls) == 0 && m.ReasoningContent != "" {
		m.Content = m.ReasoningContent
	}
	// Always emit content (even "") — strict providers reject a null content field.
	// content 即使空也 emit ""——严格 provider 拒 null。
	cm := compatMessage{
		Role:             "assistant",
		ReasoningContent: m.ReasoningContent,
		Content:          jsonString(m.Content),
	}
	for _, tc := range m.ToolCalls {
		// Malformed historical arguments become `{}` rather than travelling as-is. Ollama 400s on
		// non-JSON arguments and the others are no happier about it; replacing a broken string with
		// an empty object loses nothing (the call already failed to parse) and keeps a whole turn
		// from dying over one bad row in history. This guard used to live in one family only —
		// which meant the same broken history was survivable on Ollama and fatal everywhere else.
		// 历史里 malformed 的 arguments 换成 `{}`、不原样上路。Ollama 对非 JSON arguments 会 400,
		// 其余各家也好不到哪去;把一个已经坏掉的串换成空对象**什么也没丢**(它本来就解析不了),却能
		// 让整个回合不至于为历史里的一行烂数据而死。这道闸此前只住在**一家**里——于是同一段坏历史
		// 在 Ollama 上活得下来、在别处必死。
		args := json.RawMessage(tc.Arguments)
		if !json.Valid(args) {
			args = json.RawMessage("{}")
		}
		cm.ToolCalls = append(cm.ToolCalls, compatToolCall{
			ID:       tc.ID,
			Type:     "function",
			Function: compatFuncCall{Name: tc.Name, Arguments: string(args)},
		})
	}
	return cm
}

func toCompatTools(defs []ToolDef) []compatTool {
	out := make([]compatTool, len(defs))
	for i, d := range defs {
		out[i] = compatTool{Type: "function", Function: compatFuncDef(d)}
	}
	return out
}

func jsonString(s string) json.RawMessage {
	b, _ := json.Marshal(s)
	return b
}

// ── SSE chunk parsing ─────────────────────────────────────────────────────────

// toolCallState tracks per-chunk tool-call streaming state: a synthetic index for chunks that omit
// one, whether the name has been announced, and the argument-wire normalizer.
//
// toolCallState 跨 chunk 跟踪 tool-call 流式状态:对不填 index 的 chunk 合成 index、名字是否已宣告、
// 以及参数线缆的归一器。
type toolCallState struct {
	toolNameSent     map[int]bool
	idToSyntheticIdx map[string]int
	nextSyntheticIdx int
	args             *toolArgs
}

func newToolCallState() *toolCallState {
	return &toolCallState{
		toolNameSent:     map[int]bool{},
		idToSyntheticIdx: map[string]int{},
		args:             newToolArgs(),
	}
}

func (s *toolCallState) resolveIndex(tc compatToolCallDelta) int {
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

func emitCompatChunk(chunk compatChunk, state *toolCallState, yield func(StreamEvent) bool) bool {
	// A chunk-level error object inside a 200 stream (rare; e.g. content filter) — surface it.
	// 200 流里出现 chunk 级 error 对象(罕见,如内容过滤)——透出。
	if chunk.Error != nil {
		yield(StreamEvent{Type: EventError, Err: compatResponseError(chunk.Error)})
		return false
	}
	if chunk.Code != "" {
		yield(StreamEvent{Type: EventError, Err: streamProviderError(chunk.Code, chunk.Message)})
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

	if r := delta.reasoning(); r != "" {
		if !yield(StreamEvent{Type: EventReasoning, Delta: r}) {
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
		// The argument wire has TWO conventions and the same vendor serves both from two hostnames:
		// increments, or the whole string re-sent every chunk. `toolArgs.delta` normalizes to
		// increments, so the consumer never has to know which one it is talking to.
		// 参数线缆有**两种**约定,而同一家供应商从两个主机名上**各发一种**:增量,或每块重发整串。
		// `toolArgs.delta` 归一成增量,故消费方永远不必知道自己在跟哪一种说话。
		if d := state.args.delta(idx, tc.Function.Arguments); d != "" {
			if !yield(StreamEvent{Type: EventToolDelta, ToolIndex: idx, ArgsDelta: d}) {
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

// parseCompatNonStreaming reads a single non-streaming JSON body into StreamEvents.
//
// parseCompatNonStreaming 读单条非流式 JSON 响应并合成 StreamEvent 序列。
func parseCompatNonStreaming(name string, body io.Reader, yield func(StreamEvent) bool) {
	raw, err := io.ReadAll(io.LimitReader(body, 8<<20))
	if err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.%s: read non-streaming body: %w", name, err)})
		return
	}
	var resp compatNonStreamResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.%s: parse non-streaming response: %w", name, err)})
		return
	}
	if resp.Error != nil {
		yield(StreamEvent{Type: EventError, Err: compatResponseError(resp.Error)})
		return
	}
	if len(resp.Choices) == 0 {
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("llm.%s: non-streaming response has no choices: %w", name, ErrProviderError)})
		return
	}
	msg := resp.Choices[0].Message
	if r := msg.reasoning(); r != "" {
		if !yield(StreamEvent{Type: EventReasoning, Delta: r}) {
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

// compatRequest is the SUPERSET body. Every knob field is omitempty and only the family's own
// spec.encode writes it, so a Zhipu request carries no `verbosity` and an OpenAI request carries no
// `enable_thinking` — asserted per family in compat_test.go, because "nobody sets it" is a property
// of the code and the wire deserves a test that reads the actual bytes.
//
// compatRequest 是**超集** body。每个旋钮字段都 omitempty、且只由本家的 spec.encode 写,故一个智谱
// 请求不带 `verbosity`、一个 OpenAI 请求不带 `enable_thinking`——逐家在 compat_test.go 里断言,因为
// 「没人会设它」是**代码的**属性,而线缆值得一个**读真实字节**的测试。
type compatRequest struct {
	Model         string               `json:"model"`
	Messages      []compatMessage      `json:"messages"`
	Tools         []compatTool         `json:"tools,omitempty"`
	ToolChoice    string               `json:"tool_choice,omitempty"`
	Stream        bool                 `json:"stream"`
	StreamOptions *compatStreamOptions `json:"stream_options,omitempty"`

	// Token caps: two spellings, and which one a family accepts is not negotiable.
	// token 上限:两种拼法,而某家收哪一种**没得商量**。
	MaxTokens           int `json:"max_tokens,omitempty"`
	MaxCompletionTokens int `json:"max_completion_tokens,omitempty"`

	// Native reasoning knobs — five shapes across the families, each omitted unless its own family
	// writes it. 原生推理旋钮——各家五种形状,非本家不写即不出现。
	ReasoningEffort string           `json:"reasoning_effort,omitempty"`
	Verbosity       string           `json:"verbosity,omitempty"`
	Thinking        *compatThinking  `json:"thinking,omitempty"`
	Reasoning       *compatReasoning `json:"reasoning,omitempty"`
	EnableThinking  *bool            `json:"enable_thinking,omitempty"`
	ThinkingBudget  int              `json:"thinking_budget,omitempty"`
	Think           any              `json:"think,omitempty"`
	Options         map[string]any   `json:"options,omitempty"`
	Extra           map[string]any   `json:"-"`
}

// setOption writes into the Ollama-style `options` bag, creating it on first use.
// setOption 写进 Ollama 那种 `options` 袋子,首次使用时创建。
func (r *compatRequest) setOption(k string, v any) {
	if r.Options == nil {
		r.Options = map[string]any{}
	}
	r.Options[k] = v
}

type compatStreamOptions struct {
	IncludeUsage bool `json:"include_usage"`
}

type compatThinking struct {
	Type string `json:"type"`
}

// compatReasoning carries OpenRouter's reasoning:{effort} control.
type compatReasoning struct {
	Effort string `json:"effort,omitempty"`
}

// compatMessage holds Content as RawMessage to accept either a string or a content-part array.
// Images carries Ollama's message-level base64 array (that family does not use content parts).
//
// compatMessage 的 Content 用 RawMessage,可装字符串或 content-part 数组。Images 承载 Ollama 的
// 消息级 base64 数组(那一家不用 content part)。
type compatMessage struct {
	Role             string           `json:"role"`
	Content          json.RawMessage  `json:"content,omitempty"`
	ReasoningContent string           `json:"reasoning_content,omitempty"`
	Images           []string         `json:"images,omitempty"`
	ToolCalls        []compatToolCall `json:"tool_calls,omitempty"`
	ToolCallID       string           `json:"tool_call_id,omitempty"`
}

type compatContentPart struct {
	Type       string            `json:"type"`
	Text       string            `json:"text,omitempty"`
	ImageURL   *compatImageURL   `json:"image_url,omitempty"`
	VideoURL   *compatVideoURL   `json:"video_url,omitempty"`
	InputAudio *compatInputAudio `json:"input_audio,omitempty"`
	File       *compatFile       `json:"file,omitempty"`
}

type compatImageURL struct {
	URL string `json:"url"`
}

type compatVideoURL struct {
	URL string `json:"url"`
}

type compatInputAudio struct {
	Data   string `json:"data"`
	Format string `json:"format,omitempty"`
}

// compatFile carries a document (PDF) inline per OpenAI chat-completions file input:
// {type:"file", file:{filename, file_data:"data:application/pdf;base64,…"}}.
//
// compatFile 按 OpenAI chat-completions 文件输入内联文档(PDF)。
type compatFile struct {
	Filename string `json:"filename"`
	FileData string `json:"file_data"`
}

type compatToolCall struct {
	ID       string         `json:"id"`
	Type     string         `json:"type"`
	Function compatFuncCall `json:"function"`
}

type compatFuncCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type compatTool struct {
	Type     string        `json:"type"`
	Function compatFuncDef `json:"function"`
}

type compatFuncDef struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Parameters  json.RawMessage `json:"parameters"`
}

type compatChunk struct {
	Choices []compatChoice    `json:"choices"`
	Usage   *compatUsage      `json:"usage"`
	Error   *compatChunkError `json:"error,omitempty"`
	// A FLAT error envelope — {"code":…,"message":…,"request_id":…} at the top level with no nested
	// "error" — is what DashScope returns as a **200 chunk** when it rejects a parameter. It is read
	// for every family, not just the one that was known to send it: no family puts a top-level
	// `code` on an ordinary delta, so reading it costs nothing, while NOT reading it turns a real
	// rejection into a stream that simply ends with no output and no reason.
	// **扁平**错误信封——顶层 {"code":…,"message":…,"request_id":…}、没有嵌套 "error"——是 DashScope
	// 拒绝参数时以 **200 chunk** 返回的东西。它对**每一家**都读、不只对已知会发它的那一家:没有哪一家
	// 会在普通 delta 上放顶层 `code`,故读它零代价;而**不读**它会把一次真实的拒绝变成一条没有输出、
	// 也没有理由就结束了的流。
	Code    string `json:"code"`
	Message string `json:"message"`
}

type compatChunkError struct {
	Message string `json:"message"`
	Code    any    `json:"code,omitempty"`
	Type    string `json:"type,omitempty"`
	Details struct {
		Reason string `json:"reason"`
	} `json:"details,omitempty"`
}

// compatResponseError maps an in-stream / in-body error object to the provider-agnostic taxonomy.
//
// It is shared rather than per-family because the two things it recognises are not family traits:
// `BUDGET_EXHAUSTED` is the managed gateway's own code (and the managed provider speaks this
// dialect), and the structured rejection envelope carries the CONTEXT-LENGTH recovery signal that
// the retry path depends on. A family that dropped either would fail in a way the user reads as
// 「it just stopped」.
//
// compatResponseError 把流内/体内 error 映射到 provider 无关的分类。
//
// 它共享而非逐家,因为它认得的两样东西**都不是**家族特征:`BUDGET_EXHAUSTED` 是受管网关自己的码
// (而受管 provider 说的正是本方言),结构化拒绝信封则带着重试路径赖以工作的**上下文长度**恢复信号。
// 哪一家漏掉任一样,失败在用户眼里都读作「它就那么停了」。
func compatResponseError(e *compatChunkError) error {
	if code, _ := e.Code.(string); code == "BUDGET_EXHAUSTED" {
		return fmt.Errorf("%w: monthly gateway budget exhausted", ErrQuotaExhausted)
	}
	envelope, _ := json.Marshal(map[string]any{"error": e})
	if reason := requestRejectionReason(envelope); reason != "" {
		return &RequestRejectedError{Reason: reason}
	}
	return fmt.Errorf("%w: in-stream provider error", ErrProviderError)
}

type compatChoice struct {
	Delta        compatDelta `json:"delta"`
	FinishReason string      `json:"finish_reason"`
}

// compatDelta accepts BOTH spellings of the thinking field: most families send
// `reasoning_content`, Ollama and OpenRouter send `reasoning`. Reading both is not permissiveness —
// they are alternatives, never rivals, and a parser that knew only one silently dropped the whole
// chain of thought for the other family.
//
// compatDelta 同时收思考字段的**两种拼法**:多数家发 `reasoning_content`,Ollama 与 OpenRouter 发
// `reasoning`。两个都读不是宽容——它们是**互斥的备选**、从不同时出现,而只认得一种的解析器会为另一家
// **静默丢掉整条思维链**。
type compatDelta struct {
	Content          string                `json:"content"`
	ReasoningContent string                `json:"reasoning_content"`
	Reasoning        string                `json:"reasoning"`
	ToolCalls        []compatToolCallDelta `json:"tool_calls"`
}

func (d compatDelta) reasoning() string {
	if d.ReasoningContent != "" {
		return d.ReasoningContent
	}
	return d.Reasoning
}

type compatToolCallDelta struct {
	Index    int             `json:"index"`
	ID       string          `json:"id"`
	Function compatFuncDelta `json:"function"`
}

type compatFuncDelta struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type compatNonStreamResponse struct {
	Choices []compatNonStreamChoice `json:"choices"`
	Usage   *compatUsage            `json:"usage"`
	Error   *compatChunkError       `json:"error,omitempty"`
}

type compatNonStreamChoice struct {
	Message      compatNonStreamMessage `json:"message"`
	FinishReason string                 `json:"finish_reason"`
}

type compatNonStreamMessage struct {
	Role             string                `json:"role"`
	Content          string                `json:"content"`
	ReasoningContent string                `json:"reasoning_content"`
	Reasoning        string                `json:"reasoning"`
	ToolCalls        []compatToolCallDelta `json:"tool_calls"`
}

func (m compatNonStreamMessage) reasoning() string {
	if m.ReasoningContent != "" {
		return m.ReasoningContent
	}
	return m.Reasoning
}

type compatUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
}
