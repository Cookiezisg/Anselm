package handlers

import (
	"net/http"
	"strings"
	"time"

	"go.uber.org/zap"

	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// SearchHandler serves the unified search surface: omni/vertical search (one
// endpoint — empty types = omni) and the reindex action. The window-cursor
// pagination follows N4; reindex follows N5 (:action) and returns 204 — it is
// fire-and-forget with no pollable product, so no 202+id.
//
// SearchHandler 提供统一搜索面：综搜/垂搜（同一端点——types 空 = 综搜）与重建动作。
// 窗口 cursor 分页遵循 N4；reindex 遵循 N5（:action）、返 204——fire-and-forget、
// 无可轮询产物，故非 202+id。
type SearchHandler struct {
	svc *searchapp.Service
	log *zap.Logger
}

// NewSearchHandler constructs the handler.
//
// NewSearchHandler 构造 handler。
func NewSearchHandler(svc *searchapp.Service, log *zap.Logger) *SearchHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &SearchHandler{svc: svc, log: log.Named("handlers.search")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *SearchHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/search", h.Search)
	mux.HandleFunc("POST /api/v1/search:reindex", h.Reindex)
	mux.HandleFunc("GET /api/v1/search/settings", h.GetSettings)
	mux.HandleFunc("PATCH /api/v1/search/settings", h.PatchSettings)
}

// GetSettings handles GET /api/v1/search/settings — the machine-level embedder
// choice + live engine status (the model/engine are install-once per machine,
// shared by every workspace, hence not a workspaces column).
//
// GetSettings 处理 GET /api/v1/search/settings——机器级 embedder 选择 + 引擎实时
// 状态（模型/引擎装机一次、全 workspace 共用，故不是 workspaces 列）。
func (h *SearchHandler) GetSettings(w http.ResponseWriter, r *http.Request) {
	view, err := h.svc.Settings(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, view)
}

type patchSearchSettingsRequest struct {
	Embedder      *string `json:"embedder"`
	OllamaBaseURL *string `json:"ollamaBaseUrl"`
	OllamaModel   *string `json:"ollamaModel"`
}

// PatchSettings handles PATCH /api/v1/search/settings — switch embedder
// (builtin|ollama|off) and/or patch the Ollama connection (baseUrl/model; "" resets to
// default). A model change invalidates old-model vectors by the model column; they
// re-embed in the background.
//
// PatchSettings 处理 PATCH /api/v1/search/settings——切 embedder（builtin|ollama|off）
// 与/或修补 Ollama 连接（baseUrl/model；"" 重置默认）。改 model 即按 model 列失效旧向量、后台重嵌。
func (h *SearchHandler) PatchSettings(w http.ResponseWriter, r *http.Request) {
	var req patchSearchSettingsRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	view, err := h.svc.UpdateSettings(r.Context(), searchapp.UpdateSettingsInput{
		Embedder: req.Embedder, OllamaBaseURL: req.OllamaBaseURL, OllamaModel: req.OllamaModel,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, view)
}

// Search handles GET /api/v1/search?q=&types=&tags=&updatedAfter=&updatedBefore=&includeArchived=&cursor=&limit=.
//
// Search 处理 GET /api/v1/search 全参数面。
func (h *SearchHandler) Search(w http.ResponseWriter, r *http.Request) {
	qp := r.URL.Query()
	// search 专属界（默认 20 / 上限 50），走统一 ParsePageBounded 取错误语义 + 钳制（N4），
	// 不再手搓 limit 解析。
	pg, err := responsehttpapi.ParsePageBounded(r, 20, 50)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	includeArchived, err := parseSearchIncludeArchived(qp.Get("includeArchived"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	updatedAfter, updatedBefore, err := parseSearchWindow(qp.Get("updatedAfter"), qp.Get("updatedBefore"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	q := &searchdomain.Query{
		Q:               qp.Get("q"),
		Cursor:          pg.Cursor,
		Limit:           pg.Limit,
		IncludeArchived: includeArchived,
		UpdatedAfter:    updatedAfter,
		UpdatedBefore:   updatedBefore,
	}
	for _, t := range splitCSV(qp.Get("types")) {
		q.Types = append(q.Types, searchdomain.EntityType(t))
	}
	q.Tags = splitCSV(qp.Get("tags"))
	page, err := h.svc.Search(r.Context(), q)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// 分页坐标恒在 envelope 顶层(Paged);total 作 list 元数据进 data 子对象。
	responsehttpapi.Paged(w, map[string]any{"hits": page.Hits, "total": page.Total}, page.NextCursor, page.NextCursor != "")
}

// parseSearchIncludeArchived keeps the query contract closed: an unknown value must not
// silently widen the result set back to the default (include archived). Empty means absent
// for compatibility with clients that serialize optional query fields as an empty string.
//
// parseSearchIncludeArchived 收紧 query 文法：未知值不能静默把结果集放宽回默认（含归档）。空值
// 按缺席处理，兼容把可选 query 字段序列化为空字符串的客户端。
func parseSearchIncludeArchived(raw string) (bool, error) {
	raw = strings.TrimSpace(raw)
	switch strings.ToLower(raw) {
	case "":
		return true, nil
	case "true":
		return true, nil
	case "false":
		return false, nil
	default:
		return false, searchdomain.ErrInvalidIncludeArchived.WithDetails(map[string]any{
			"param": "includeArchived",
			"got":   raw,
			"want":  "true or false",
		})
	}
}

// parseSearchWindow parses inclusive UTC-normalized RFC3339 bounds and rejects an inverted
// range before the search service can turn the caller's typo into a convincing empty result.
//
// parseSearchWindow 解析包含端点、归一 UTC 的 RFC3339 窗口，并在进入 search service 前拒绝反向
// 区间，避免把调用方的笔误伪装成可信的空结果。
func parseSearchWindow(afterRaw, beforeRaw string) (after, before *time.Time, err error) {
	parse := func(raw, param string) (*time.Time, error) {
		if strings.TrimSpace(raw) == "" {
			return nil, nil
		}
		ts, err := parseListTime(raw, param, searchdomain.ErrInvalidWindow)
		if err != nil {
			return nil, err
		}
		return &ts, nil
	}
	if after, err = parse(afterRaw, "updatedAfter"); err != nil {
		return nil, nil, err
	}
	if before, err = parse(beforeRaw, "updatedBefore"); err != nil {
		return nil, nil, err
	}
	if after != nil && before != nil && after.After(*before) {
		return nil, nil, searchdomain.ErrInvalidWindow.WithDetails(map[string]any{
			"param":         "updatedAfter/updatedBefore",
			"updatedAfter":  after.Format(time.RFC3339Nano),
			"updatedBefore": before.Format(time.RFC3339Nano),
			"reason":        "updatedAfter must not be later than updatedBefore",
		})
	}
	return after, before, nil
}

// Reindex handles POST /api/v1/search:reindex — force-reconcile the ctx
// workspace asynchronously, returning 204 (fire-and-forget, nothing to poll).
//
// Reindex 处理 POST /api/v1/search:reindex——异步就地 force-reconcile ctx workspace，返 204
// （fire-and-forget、无可轮询产物）。
func (h *SearchHandler) Reindex(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Reindex(r.Context()); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w) // fire-and-forget、无可轮询产物
}

func splitCSV(s string) []string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}
