package llm

import (
	"context"
	"iter"
	"net/http"
)

// Provider is one LLM wire dialect: it owns how a Request becomes an HTTP
// request (body shape, auth headers, base-url + path) and how the response
// becomes the typed StreamEvent stream. Identity (Name / DefaultBaseURL)
// drives registry lookup and base-url resolution. Thinking-encoding will
// land inside BuildRequest in P3.
//
// Provider 是一种 LLM wire 方言：负责 Request→HTTP 请求（body 形状、auth
// 头、base-url+path）与响应→StreamEvent 流。Name / DefaultBaseURL 供注册表
// 查找与 base-url 解析。P3 的 thinking 编码落在 BuildRequest 内。
type Provider interface {
	Name() string
	DefaultBaseURL() string
	BuildRequest(ctx context.Context, req Request) (*http.Request, error)
	ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent]
}

// providerClient adapts a Provider to the Client contract by running the shared
// transport iron-law (build → do → status-map → parse). It is the single copy
// of the request/response plumbing every Provider funnels through, so callers
// keep seeing the unchanged Client.Stream interface.
//
// providerClient 把 Provider 适配成 Client：跑共享传输铁律（build → do →
// status-map → parse）。它是所有 Provider 共用的唯一请求/响应管道，故调用方
// 看到的 Client.Stream 契约不变。
type providerClient struct {
	provider Provider
	http     *http.Client
}

func (c *providerClient) Stream(ctx context.Context, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		// Apply per-provider Request mutations (e.g. deepseek reasoning strip,
		// ollama stream-disable) before wire encoding — same point as the old Adapter.
		//
		// 在 wire 编码前应用 per-provider Request 变换（如 deepseek 剥 reasoning、
		// ollama 关流）——与旧 Adapter 的执行位置相同。
		if p, ok := c.provider.(*openAICompatProvider); ok && p.beforeRequest != nil {
			p.beforeRequest(&req)
		}
		httpReq, err := c.provider.BuildRequest(ctx, req)
		if err != nil {
			yield(StreamEvent{Type: EventError, Err: err})
			return
		}
		resp, ok := doRequest(c.http, httpReq, "llm."+c.provider.Name(), yield)
		if !ok {
			return
		}
		defer resp.Body.Close()

		for ev := range c.provider.ParseStream(ctx, resp, req) {
			if !yield(ev) {
				return
			}
		}
	}
}

// providerRegistry maps a Config.Provider name to its Provider. Unknown names
// (and bare "custom" without anthropic-compatible) fall through to the
// OpenAI-compat default in lookupProvider — they all speak /chat/completions.
//
// providerRegistry 把 Config.Provider name 映射到 Provider。未知 name（及未声明
// anthropic-compatible 的裸 "custom"）在 lookupProvider 回落到 OpenAI-compat 默认
// —— 它们都讲 /chat/completions。
var providerRegistry = buildProviderRegistry()

// buildProviderRegistry constructs the canonical Provider registry. Providers
// with non-trivial request mutations (beforeRequest) or thinking encoders
// (thinkingEncoder) carry their hooks inline. anthropic gets its own
// native-dialect Provider; mock is absent (Build short-circuits to MockClient).
//
// buildProviderRegistry 构建权威 Provider 注册表。有非平凡 Request 变换
// (beforeRequest) 或 thinking 编码器 (thinkingEncoder) 的 provider 内联钩子；
// anthropic 使用自有原生方言 Provider；mock 缺席（Build 直接短路到 MockClient）。
func buildProviderRegistry() map[string]Provider {
	compat := func(name, baseURL string) *openAICompatProvider {
		return newOpenAICompatProvider(name, baseURL)
	}
	reg := map[string]Provider{
		"custom":    compat("custom", ""),
		"anthropic": newAnthropicProvider(),
	}

	// openai: reasoning_effort for reasoning models.
	// openai：推理模型用 reasoning_effort。
	oa := compat("openai", "https://api.openai.com/v1")
	oa.thinkingEncoder = encodeThinkingOpenAI([]string{"none", "minimal", "low", "medium", "high", "xhigh"})
	reg["openai"] = oa

	// google compat: reasoning_effort (same shape as OpenAI compat surface).
	// google compat：reasoning_effort（与 OpenAI compat 面相同）。
	gc := compat("google", "https://generativelanguage.googleapis.com/v1beta/openai")
	gc.thinkingEncoder = encodeThinkingGeminiCompat([]string{"minimal", "low", "medium", "high"})
	reg["google"] = gc

	// deepseek: strip reasoning_content from plain turns + thinking:{type} + reasoning_effort.
	// deepseek：剥普通 turn reasoning_content + thinking:{type} + reasoning_effort。
	ds := compat("deepseek", "https://api.deepseek.com")
	ds.beforeRequest = deepseekBeforeRequest
	ds.thinkingEncoder = encodeThinkingDeepSeek
	reg["deepseek"] = ds

	// qwen: enable_thinking bool + optional thinking_budget (stream guard in buildOpenAIBody).
	// qwen：enable_thinking bool + 可选 thinking_budget（流式守卫在 buildOpenAIBody）。
	qw := compat("qwen", "https://dashscope.aliyuncs.com/compatible-mode/v1")
	qw.thinkingEncoder = encodeThinkingQwen
	reg["qwen"] = qw

	// zhipu: thinking:{type:"enabled"|"disabled"}.
	// zhipu：thinking:{type} 切换。
	zh := compat("zhipu", "https://open.bigmodel.cn/api/paas/v4")
	zh.thinkingEncoder = encodeThinkingZhipu
	reg["zhipu"] = zh

	// moonshot: thinking:{type:"enabled"|"disabled"} for k2.5/k2.6.
	// moonshot：k2.5/k2.6 用 thinking:{type} 切换。
	ms := compat("moonshot", "https://api.moonshot.cn/v1")
	ms.thinkingEncoder = encodeThinkingMoonshot
	reg["moonshot"] = ms

	// doubao: thinking:{type:"enabled"|"disabled"} + optional budget_tokens.
	// doubao：thinking:{type} + 可选 budget_tokens。
	db := compat("doubao", "https://ark.cn-beijing.volces.com/api/v3")
	db.thinkingEncoder = encodeThinkingDoubao
	reg["doubao"] = db

	// openrouter: reasoning:{effort|max_tokens}.
	// openrouter：reasoning:{effort|max_tokens}。
	or_ := compat("openrouter", "https://openrouter.ai/api/v1")
	or_.thinkingEncoder = encodeThinkingOpenRouter
	reg["openrouter"] = or_

	// ollama: force non-streaming when tools present + reasoning_effort.
	// ollama：有 tools 时强制非流 + reasoning_effort。
	ol := compat("ollama", "")
	ol.beforeRequest = ollamaBeforeRequest
	ol.thinkingEncoder = encodeThinkingOllama
	reg["ollama"] = ol

	return reg
}

// deepseekBeforeRequest enforces DeepSeek's turn-type-dependent reasoning_content round-trip rule.
//
// deepseekBeforeRequest 守 DeepSeek 按 turn 类型的 reasoning_content round-trip 规则。
func deepseekBeforeRequest(req *Request) {
	for i := range req.Messages {
		m := &req.Messages[i]
		if m.Role != RoleAssistant {
			continue
		}
		// Plain assistant turn: strip; tool-call turn: preserve (V3.2+ requires it).
		// 纯文字 turn 剥；含 tool_calls turn 保留（V3.2+ 必须）。
		if len(m.ToolCalls) == 0 {
			m.ReasoningContent = ""
		}
	}
}

// ollamaBeforeRequest forces non-streaming when tools are present (Ollama drops tool_calls when streaming).
//
// ollamaBeforeRequest 有 tools 时强制非流式（Ollama streaming 时会吞 tool_calls）。
func ollamaBeforeRequest(req *Request) {
	if len(req.Tools) > 0 {
		req.DisableStream = true
	}
}

// lookupProvider resolves the Provider for a Config; "custom" + anthropic-compatible
// routes to anthropic, every other unknown name falls back to OpenAI-compat (matching
// the historical default wire client).
//
// lookupProvider 按 Config 解析 Provider；"custom"+anthropic-compatible 路由到
// anthropic，其余未知 name 回落 OpenAI-compat（与历史默认 wire client 一致）。
func lookupProvider(cfg Config) Provider {
	if cfg.Provider == "custom" && cfg.APIFormat == "anthropic-compatible" {
		return providerRegistry["anthropic"]
	}
	if p, ok := providerRegistry[cfg.Provider]; ok {
		return p
	}
	return providerRegistry["openai"]
}
