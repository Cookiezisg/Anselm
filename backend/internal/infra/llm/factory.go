// factory.go — Provider dispatch: maps (provider, config) to the correct
// Client implementation and resolves the default BaseURL when not supplied.
//
// factory.go — Provider 分派：把（provider, config）映射到正确的 Client 实现，
// 并在未提供 BaseURL 时解析 provider 默认值。
package llm

import "fmt"

// Config carries everything needed to pick and configure a Client.
//
// Config 携带选择和配置 Client 所需的全部信息。
type Config struct {
	Provider  string // "openai" | "anthropic" | "ollama" | "deepseek" | "custom" | …
	APIFormat string // custom provider only: "openai-compatible" | "anthropic-compatible"
	ModelID   string
	Key       string
	BaseURL   string // overrides the provider default when non-empty
}

// Factory creates Clients. It owns one shared HTTP client per wire protocol
// so connections are reused across requests, plus a singleton MockClient
// used when provider="mock" (dev /dev/mock-llm/* surface — script queue
// shared across all Stream calls so testend can push a script then drive
// chat to consume it).
//
// Factory 创建 Client。每种协议共用一个 HTTP client，跨请求复用连接。
// 加一个 MockClient 单例供 provider="mock" 时用（dev /dev/mock-llm/*
// 端面 — script 队列跨 Stream 调用共享，testend 推脚本后驱动 chat 消费）。
type Factory struct {
	openai    *openAIClient
	anthropic *anthropicClient
	mock      *MockClient
	tracer    *TraceRecorder // nil = no tracing; set via SetTracer in --dev
}

// NewFactory constructs a Factory ready for use.
//
// NewFactory 构造一个可直接使用的 Factory。
func NewFactory() *Factory {
	return &Factory{
		openai:    newOpenAIClient(),
		anthropic: newAnthropicClient(),
		mock:      NewMockClient(),
	}
}

// Mock returns the singleton MockClient. Used by /dev/mock-llm/* HTTP
// handlers to push scripts + inspect last-request, and by tests that
// want direct in-process driving without going through the dev HTTP
// surface.
//
// Mock 返 MockClient 单例。供 /dev/mock-llm/* HTTP handler push 脚本 +
// 查 last-request 用，也供想跳 dev HTTP 直接 in-process 驱动的测试用。
func (f *Factory) Mock() *MockClient { return f.mock }

// SetTracer enables LLM call tracing. When set, every Build()-returned
// Client is wrapped to record Stream() calls into the recorder. main.go
// --dev path calls this once during boot. Production unchanged (tracer
// stays nil → Build returns the raw provider client unwrapped).
//
// SetTracer 启 LLM 调用跟踪。设了之后每个 Build() 返的 Client 被包装把
// Stream() 调用记到 recorder。main.go --dev 路径 boot 时调一次。生产
// 不动（tracer 保持 nil → Build 返不带包装的原 provider client）。
func (f *Factory) SetTracer(r *TraceRecorder) { f.tracer = r }

// Tracer returns the active recorder (or nil if not set). Used by the
// /dev/llm-trace handler to read recorded traces.
//
// Tracer 返当前 recorder（未设返 nil）。/dev/llm-trace handler 用此读
// 已记录的 trace。
func (f *Factory) Tracer() *TraceRecorder { return f.tracer }

// Build returns the Client and resolved BaseURL for the given Config.
// When a tracer is set (via SetTracer in --dev) the returned Client
// is wrapped in a recordingClient that captures every Stream call.
//
// Build 返回给定 Config 对应的 Client 和解析后的 BaseURL。tracer
// 已设（SetTracer in --dev）时返的 Client 被 recordingClient 包，
// 捕获每次 Stream 调用。
func (f *Factory) Build(cfg Config) (Client, string, error) {
	baseURL, err := resolveBaseURL(cfg)
	if err != nil {
		return nil, "", err
	}
	// Step 1: pick the underlying wire client based on protocol family.
	// Anthropic-native vs OpenAI-compat is the only real fork.
	// Step 1：按协议族挑底层 wire client。Anthropic-native vs OpenAI-compat
	// 是仅有的真正分叉。
	var client Client
	switch cfg.Provider {
	case "anthropic":
		client = f.anthropic
	case "mock":
		client = f.mock
	case "custom":
		if cfg.APIFormat == "anthropic-compatible" {
			client = f.anthropic
		} else {
			client = f.openai
		}
	default:
		client = f.openai
	}
	// Step 2: wrap in adapter so per-provider hooks (BeforeRequest /
	// AfterStreamEvent) fire for every Stream call. Most adapters are
	// no-ops today; they're here so future provider-specific quirks
	// (e.g. Moonshot temperature clamping) plug in without touching
	// factory.go again.
	// Step 2：包 adapter 让 per-provider 钩子（BeforeRequest /
	// AfterStreamEvent）在每次 Stream 时触发。当前多数 no-op；放在这里
	// 让未来 provider quirk（如 Moonshot 温度 clamp）插入时不用再改 factory。
	client = &adapterWrappedClient{inner: client, adapter: lookupAdapter(cfg.Provider)}
	// Step 3: outer recording wrapper (--dev tracing only).
	// Step 3：外层 recording 包装（仅 --dev tracing）。
	if f.tracer != nil {
		client = &recordingClient{inner: client, recorder: f.tracer}
	}
	return client, baseURL, nil
}

// resolveBaseURL returns cfg.BaseURL when set, or the adapter's default.
// Adapters owning provider metadata replaces the per-provider switch that
// used to live here (see adapter.go).
//
// resolveBaseURL 有 cfg.BaseURL 时直接返回，否则按 Adapter 取默认值。
// Adapter 持有 provider 元数据，替代原来散在这里的 switch（见 adapter.go）。
func resolveBaseURL(cfg Config) (string, error) {
	if cfg.BaseURL != "" {
		return cfg.BaseURL, nil
	}
	a := lookupAdapter(cfg.Provider)
	url := a.DefaultBaseURL()
	if url == "" {
		// Adapter signals "no default" (custom / ollama in some configs).
		// Adapter 报"无默认"（custom / 某些 ollama 配置）。
		return "", fmt.Errorf("llm: %s provider requires base_url", cfg.Provider)
	}
	return url, nil
}
