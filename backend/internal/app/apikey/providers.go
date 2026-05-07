// providers.go — hardcoded whitelist of supported provider integrations
// (LLM + search) and their metadata. Categorised so the frontend "API
// Keys" page can group LLM credentials separately from search credentials,
// while sharing the same encryption / per-user storage.
//
// Adding a new provider:
//  1. Add a ProviderMeta entry to the providers map below.
//  2. If it introduces a new TestMethod, implement the matching branch
//     in HTTPTester.Test.
//
// providers.go — 支持的 provider 集成（LLM + 搜索）白名单 + 元数据。带分类
// 让前端"API Keys"页能 LLM 与搜索分组展示，同时共用加密 / per-user 存储。
//
// 新增 provider 步骤：
//  1. 在下方 providers map 加一条 ProviderMeta。
//  2. 若引入新 TestMethod，需在 HTTPTester.Test 实现对应分支。

package apikey

// ProviderCategory groups providers by integration kind. The frontend uses
// this to render LLM credentials and search credentials in separate panels;
// the backend uses it for routing (e.g. WebSearch only iterates Search
// providers when looking for a BYOK key).
//
// ProviderCategory 按集成种类分组 provider。前端按其分面板渲染 LLM 凭证 /
// 搜索凭证；后端按其路由（如 WebSearch 找 BYOK key 时只遍历 Search 类）。
type ProviderCategory string

const (
	CategoryLLM    ProviderCategory = "llm"
	CategorySearch ProviderCategory = "search"
)

// TestMethod enumerates the HTTP pattern used to test connectivity.
//
// TestMethod 枚举测试连通性的 HTTP 调用模式。
type TestMethod string

const (
	TestMethodGetModels        TestMethod = "get_models"
	TestMethodAnthropicPing    TestMethod = "anthropic_ping"
	TestMethodGoogleListModels TestMethod = "google_list_models"
	TestMethodOllamaTags       TestMethod = "ollama_tags"
	TestMethodCustom           TestMethod = "custom"
	// TestMethodAlwaysOK is for the "mock" dev provider — no real
	// connectivity to test, so the connectivity check is a no-op
	// returning a synthetic ok result with a single model slot.
	//
	// TestMethodAlwaysOK 给 "mock" dev provider——无真实连通性，测试是
	// no-op 返合成 ok 结果含单 model slot。
	TestMethodAlwaysOK TestMethod = "always_ok"
	// TestMethodSearchPing dispatches by provider name to the matching
	// search-API probe (Brave / Serper / Tavily / Bocha). Each runs a
	// lightweight 1-result query; the OK/auth-fail outcome surfaces in
	// TestResult exactly like the LLM probes.
	//
	// TestMethodSearchPing 按 provider 名分派到匹配的搜索 API 探测
	// （Brave / Serper / Tavily / Bocha）。各跑 1-result 轻 query；OK/认证
	// 失败结果通过 TestResult 返回，与 LLM 探测一致。
	TestMethodSearchPing TestMethod = "search_ping"
)

// ProviderMeta describes a supported provider integration.
//
// ProviderMeta 描述一个支持的 provider 集成。
type ProviderMeta struct {
	Name            string
	DisplayName     string
	DefaultBaseURL  string
	BaseURLRequired bool
	TestMethod      TestMethod
	Category        ProviderCategory
}

var providers = map[string]ProviderMeta{
	// ── LLM providers ────────────────────────────────────────────────
	"openai":     {Name: "openai", DisplayName: "OpenAI", DefaultBaseURL: "https://api.openai.com/v1", TestMethod: TestMethodGetModels, Category: CategoryLLM},
	"anthropic":  {Name: "anthropic", DisplayName: "Anthropic", DefaultBaseURL: "https://api.anthropic.com", TestMethod: TestMethodAnthropicPing, Category: CategoryLLM},
	"google":     {Name: "google", DisplayName: "Google Gemini", DefaultBaseURL: "https://generativelanguage.googleapis.com", TestMethod: TestMethodGoogleListModels, Category: CategoryLLM},
	"deepseek":   {Name: "deepseek", DisplayName: "DeepSeek", DefaultBaseURL: "https://api.deepseek.com", TestMethod: TestMethodGetModels, Category: CategoryLLM},
	"openrouter": {Name: "openrouter", DisplayName: "OpenRouter", DefaultBaseURL: "https://openrouter.ai/api/v1", TestMethod: TestMethodGetModels, Category: CategoryLLM},
	"qwen":       {Name: "qwen", DisplayName: "通义千问 (Alibaba Qwen)", DefaultBaseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", TestMethod: TestMethodGetModels, Category: CategoryLLM},
	"zhipu":      {Name: "zhipu", DisplayName: "智谱 GLM", DefaultBaseURL: "https://open.bigmodel.cn/api/paas/v4", TestMethod: TestMethodGetModels, Category: CategoryLLM},
	"moonshot":   {Name: "moonshot", DisplayName: "Moonshot Kimi", DefaultBaseURL: "https://api.moonshot.cn/v1", TestMethod: TestMethodGetModels, Category: CategoryLLM},
	"doubao":     {Name: "doubao", DisplayName: "字节豆包 (Doubao)", DefaultBaseURL: "https://ark.cn-beijing.volces.com/api/v3", TestMethod: TestMethodGetModels, Category: CategoryLLM},
	"ollama":     {Name: "ollama", DisplayName: "Ollama (local)", BaseURLRequired: true, TestMethod: TestMethodOllamaTags, Category: CategoryLLM},
	"custom":     {Name: "custom", DisplayName: "Custom (OpenAI/Anthropic compatible)", BaseURLRequired: true, TestMethod: TestMethodCustom, Category: CategoryLLM},
	// Dev-only provider: testend's Mock LLM tab pushes scripts via
	// /dev/mock-llm/scripts; chat resolves provider="mock" → factory
	// returns the singleton MockClient that pops the next script on
	// each Stream call.
	//
	// Dev-only provider：testend Mock LLM tab 经 /dev/mock-llm/scripts
	// 推脚本；chat 解析 provider="mock" → factory 返 MockClient 单例，
	// 每次 Stream 弹下一脚本。
	"mock": {Name: "mock", DisplayName: "Mock (dev — testend-driven scripts)", TestMethod: TestMethodAlwaysOK, Category: CategoryLLM},

	// ── Search providers (BYOK for WebSearch tool) ───────────────────
	// Iteration order in WebSearch.Execute matches priority of these
	// entries: Brave (international quality leader, free 2k/mo) → Serper
	// (Google results, free 2.5k) → Tavily (AI-agent-tuned, free 1k/mo)
	// → Bocha (mainland China, no-VPN). User typically configures one;
	// having multiple = automatic failover.
	//
	// 搜索 provider（WebSearch 工具的 BYOK）。WebSearch.Execute 按本表
	// 顺序优先：Brave（国际质量领先，免费 2k/月）→ Serper（Google 结果，
	// 免费 2.5k）→ Tavily（agent 调优，免费 1k）→ Bocha（国内免 VPN）。
	// 一般配一个，配多个 = 自动故障切换。
	"brave":  {Name: "brave", DisplayName: "Brave Search", DefaultBaseURL: "https://api.search.brave.com/res/v1", TestMethod: TestMethodSearchPing, Category: CategorySearch},
	"serper": {Name: "serper", DisplayName: "Serper.dev (Google search)", DefaultBaseURL: "https://google.serper.dev", TestMethod: TestMethodSearchPing, Category: CategorySearch},
	"tavily": {Name: "tavily", DisplayName: "Tavily (AI-tuned search)", DefaultBaseURL: "https://api.tavily.com", TestMethod: TestMethodSearchPing, Category: CategorySearch},
	"bocha":  {Name: "bocha", DisplayName: "博查 Bocha (CN search)", DefaultBaseURL: "https://api.bochaai.com/v1", TestMethod: TestMethodSearchPing, Category: CategorySearch},
}

// GetProviderMeta returns metadata for the given provider name.
// Returns false if the name is not in the whitelist.
//
// GetProviderMeta 返回指定 provider 的元数据。bool 为 false 表示不在白名单内。
func GetProviderMeta(name string) (ProviderMeta, bool) {
	m, ok := providers[name]
	return m, ok
}

// IsValidProvider reports whether the name is a supported provider.
//
// IsValidProvider 报告名字是否为支持的 provider。
func IsValidProvider(name string) bool {
	_, ok := providers[name]
	return ok
}

// ListProviders returns all supported provider names (unordered).
// Production code does not call this — it exists for the contract test
// that asserts the registry stays in sync with documentation.
//
// ListProviders 返回所有支持的 provider 名字（无序）。生产代码不调用——
// 仅契约测试用以断言注册表与文档一致。
func ListProviders() []string {
	names := make([]string, 0, len(providers))
	for name := range providers {
		names = append(names, name)
	}
	return names
}
