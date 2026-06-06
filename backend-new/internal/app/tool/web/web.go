// Package web provides the network-facing system tools (WebFetch + WebSearch).
//
// WebFetch fetches a URL behind an SSRF guard and returns a utility-model summary.
// WebSearch routes a query to the workspace's chosen search key (BYOK: brave /
// serper / tavily / bocha — a single explicit key, provider implied by the key),
// or returns an actionable message when none is configured. There is NO MCP tier:
// a connected search MCP server exposes its own tool via tool/mcp (波次 3) — the
// LLM calls it directly; WebSearch does not proxy it.
//
// Package web 提供网络相关 system tool（WebFetch + WebSearch）。
//
// WebFetch 在 SSRF 守卫后抓 URL，返回 utility 模型摘要。WebSearch 把查询路由到 workspace
// 选定的搜索 key（BYOK：brave / serper / tavily / bocha——单把显式 key、provider 由 key 隐含），
// 未配置时返可操作引导。**无 MCP tier**：连接的搜索 MCP server 经 tool/mcp（波次 3）暴露自己的
// 工具、LLM 直接调；WebSearch 不代理它。
package web

import (
	"net/http"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	websearchdomain "github.com/sunweilin/forgify/backend/internal/domain/websearch"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// WebTools constructs the web system tools. searchKeys resolves the workspace's
// default search key (websearch.SearchKeyPicker, implemented by workspace.Service).
//
// WebTools 构造 web system tool。searchKeys 解析 workspace 默认搜索 key
// （websearch.SearchKeyPicker，由 workspace.Service 实现）。
func WebTools(
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
	searchKeys websearchdomain.SearchKeyPicker,
	log *zap.Logger,
) []toolapp.Tool {
	return []toolapp.Tool{
		newWebFetch(picker, keys, factory),
		newWebSearch(keys, searchKeys, log),
	}
}

func newWebFetch(
	picker modeldomain.ModelPicker,
	keys apikeydomain.KeyProvider,
	factory *llminfra.Factory,
) *WebFetch {
	return &WebFetch{picker: picker, keys: keys, factory: factory}
}

func newWebSearch(keys apikeydomain.KeyProvider, searchKeys websearchdomain.SearchKeyPicker, log *zap.Logger) *WebSearch {
	if log == nil {
		log = zap.NewNop()
	}
	return &WebSearch{
		httpClient: &http.Client{Timeout: searchTimeout},
		keys:       keys,
		searchKeys: searchKeys,
		log:        log,
	}
}
