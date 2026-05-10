// providers.go — read-only HTTP endpoint exposing the apikey provider
// registry to the frontend. Lets testend (and the future Wails UI) render
// the "add API Key" dropdown + group LLM vs Search providers without
// duplicating the whitelist client-side.
//
// providers.go ——只读 HTTP 端点把 apikey provider 注册表暴露给前端。让
// testend（与未来 Wails UI）渲染"添加 API Key"下拉框 + LLM/Search 分组，
// 不再客户端重复硬编码白名单。
package handlers

import (
	"net/http"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// ProvidersHandler serves GET /api/v1/providers.
//
// ProvidersHandler 提供 GET /api/v1/providers。
type ProvidersHandler struct{}

// NewProvidersHandler is a no-arg constructor — provider data comes from
// the package-level registry, no Service dependency needed.
//
// NewProvidersHandler 无参构造——provider 数据来自包级 registry，无需 Service 依赖。
func NewProvidersHandler() *ProvidersHandler {
	return &ProvidersHandler{}
}

// Register attaches the providers route.
//
// Register 挂载 providers 路由。
func (h *ProvidersHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/providers", h.List)
}

// providerInfo is the wire shape for one provider entry. Mirrors
// app/apikey.ProviderMeta but hides internal TestMethod / DisplayName
// formatting concerns aren't needed by clients.
//
// providerInfo 是一条 provider 的线形。镜像 app/apikey.ProviderMeta，藏
// 内部 TestMethod；客户端不需要 DisplayName 格式化关切。
type providerInfo struct {
	Name            string `json:"name"`
	DisplayName     string `json:"displayName"`
	Category        string `json:"category"` // "llm" / "search"
	DefaultBaseURL  string `json:"defaultBaseUrl,omitempty"`
	BaseURLRequired bool   `json:"baseUrlRequired"`
}

// List: GET /api/v1/providers[?category=llm|search] → list of providers,
// stable alphabetical order by name. Optional ?category= filter narrows
// to one category; unknown category values return an empty list (the
// frontend already validated the choice locally — this is a thin wire).
//
// List：GET /api/v1/providers[?category=llm|search] → provider 列表，按 name
// 稳定字母序。可选 ?category= 过滤；未知 category 返空列表（前端已本地校验
// ——这是薄 wire）。
func (h *ProvidersHandler) List(w http.ResponseWriter, r *http.Request) {
	wantCategory := r.URL.Query().Get("category")

	names := apikeyapp.ListProviders()
	out := make([]providerInfo, 0, len(names))
	for _, name := range names {
		meta, ok := apikeyapp.GetProviderMeta(name)
		if !ok {
			// Defensive against registry invariant violation: ListProviders
			// and GetProviderMeta read the same package-level registry, so
			// a name surfaced by List having no meta is impossible unless
			// the registry is half-initialized. Silent skip is correct —
			// no logger is injected (handler is intentionally empty struct
			// per §S6 thin-handler), and the user-visible symptom is "one
			// dropdown entry missing" which testend will catch.
			//
			// Defensive 防 registry invariant 违反：ListProviders 与
			// GetProviderMeta 同源包级 registry，List 出的 name 没 meta
			// 仅可能是 registry 半初始化。静默跳过——handler 故意空 struct
			// 不注入 logger（§S6 薄 handler），用户可见症状是"下拉漏一项"
			// testend 会发现。
			continue
		}
		if wantCategory != "" && string(meta.Category) != wantCategory {
			continue
		}
		out = append(out, providerInfo{
			Name:            meta.Name,
			DisplayName:     meta.DisplayName,
			Category:        string(meta.Category),
			DefaultBaseURL:  meta.DefaultBaseURL,
			BaseURLRequired: meta.BaseURLRequired,
		})
	}
	// Sort by name for deterministic UI ordering.
	// 按 name 稳定排序让 UI 渲染确定。
	sortProviderInfos(out)
	responsehttpapi.Success(w, http.StatusOK, out)
}

// sortProviderInfos in-place by Name ascending.
//
// sortProviderInfos 按 Name 升序原地排。
func sortProviderInfos(s []providerInfo) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1].Name > s[j].Name; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}
