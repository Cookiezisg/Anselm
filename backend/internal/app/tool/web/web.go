// Package web provides the network-facing system tools the LLM uses to
// browse the open web: WebFetch (single-URL retrieval + LLM summarisation)
// and WebSearch (3-tier fallback search). Imported as `webtool` per §S13
// nested sub-package alias rule.
//
// Both tools share an SSRF guard (no private/loopback/link-local hosts)
// and a 30-second per-request timeout. WebFetch routes content through
// the user's web_summary model scenario (with transparent fallback to
// the chat scenario when web_summary is unconfigured) so users never
// have to set anything up to get a useful summary.
//
// Package web 提供 LLM 用于上网的 system tool：WebFetch（抓 URL + LLM
// 摘要）与 WebSearch（3 层 fallback 搜索）。按 §S13 嵌套子包别名规则
// 导入为 `webtool`。
//
// 两者共用 SSRF 守卫（拒私网/loopback/link-local）+ 30s 单次请求超时。
// WebFetch 走用户 web_summary 模型场景（未配置时透明 fallback 到 chat
// 场景），开箱即用无需配置。
package web

import (
	"net/http"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// WebTools constructs the web system tools wired with their dependencies.
//
// WebTools 构造装配好依赖的 web system tool。
func WebTools(
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) []toolapp.Tool {
	return []toolapp.Tool{
		newWebFetch(picker, keys, factory),
		newWebSearch(),
	}
}

// newWebFetch constructs a WebFetch with the default HTTP client.
//
// newWebFetch 用默认 HTTP 客户端构造 WebFetch。
func newWebFetch(
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) *WebFetch {
	return &WebFetch{
		picker:  picker,
		keys:    keys,
		factory: factory,
	}
}

// newWebSearch constructs a WebSearch with a 10s-timeout client and the
// resolved SearXNG instance pool (FORGIFY_SEARXNG_INSTANCES override or
// curated default).
//
// newWebSearch 构造 WebSearch：10s 超时 client + 解析后的 SearXNG 实例池
// （`FORGIFY_SEARXNG_INSTANCES` 覆盖或精选默认）。
func newWebSearch() *WebSearch {
	return &WebSearch{
		httpClient: &http.Client{Timeout: searchTimeout},
		instances:  resolveSearXNGInstances(),
	}
}
