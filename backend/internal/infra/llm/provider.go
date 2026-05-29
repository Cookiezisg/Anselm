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

// buildProviderRegistry derives one registry entry per known adapter, reusing
// the adapter's name + DefaultBaseURL so identity stays single-sourced. The 9
// OpenAI-compat providers share one openAICompatProvider wire body, differing
// only by identity; anthropic / mock get their own Provider.
//
// buildProviderRegistry 从每个已知 adapter 派生一条注册项，复用 adapter 的
// name + DefaultBaseURL 让身份单一来源。9 个 OpenAI-compat provider 共用一份
// openAICompatProvider wire 逻辑，仅身份不同；anthropic / mock 各有自己的 Provider。
func buildProviderRegistry() map[string]Provider {
	reg := map[string]Provider{}
	for _, a := range adapters {
		switch a.Name() {
		case "anthropic":
			reg[a.Name()] = newAnthropicProvider()
		case "mock":
			// mock has no wire Provider; factory short-circuits to MockClient.
			// mock 无 wire Provider；factory 直接短路到 MockClient。
			continue
		default:
			reg[a.Name()] = newOpenAICompatProvider(a.Name(), a.DefaultBaseURL())
		}
	}
	return reg
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
