package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"go.uber.org/zap"

	searchapp "github.com/sunweilin/forgify/backend/internal/app/search"
	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// SearchHandler serves the unified search surface: omni/vertical search (one
// endpoint — empty types = omni) and the reindex action. The window-cursor
// pagination follows N4; reindex follows N2/N5 (202 + :action).
//
// SearchHandler 提供统一搜索面：综搜/垂搜（同一端点——types 空 = 综搜）与重建动作。
// 窗口 cursor 分页遵循 N4；reindex 遵循 N2/N5（202 + :action）。
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
}

// Search handles GET /api/v1/search?q=&types=&tags=&updatedAfter=&updatedBefore=&includeArchived=&cursor=&limit=.
//
// Search 处理 GET /api/v1/search 全参数面。
func (h *SearchHandler) Search(w http.ResponseWriter, r *http.Request) {
	qp := r.URL.Query()
	q := &searchdomain.Query{
		Q:               qp.Get("q"),
		Cursor:          qp.Get("cursor"),
		IncludeArchived: qp.Get("includeArchived") != "false", // default true: archived+searchable is the point of archiving. 默认 true：归档+可搜正是归档的意义。
	}
	for _, t := range splitCSV(qp.Get("types")) {
		q.Types = append(q.Types, searchdomain.EntityType(t))
	}
	q.Tags = splitCSV(qp.Get("tags"))
	if v := qp.Get("updatedAfter"); v != "" {
		if ts, err := time.Parse(time.RFC3339, v); err == nil {
			q.UpdatedAfter = &ts
		}
	}
	if v := qp.Get("updatedBefore"); v != "" {
		if ts, err := time.Parse(time.RFC3339, v); err == nil {
			q.UpdatedBefore = &ts
		}
	}
	if v := qp.Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			q.Limit = n
		}
	}
	page, err := h.svc.Search(r.Context(), q)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, page)
}

// Reindex handles POST /api/v1/search:reindex — purge + rebuild the ctx
// workspace asynchronously (202).
//
// Reindex 处理 POST /api/v1/search:reindex——异步清空重建 ctx workspace（202）。
func (h *SearchHandler) Reindex(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Reindex(r.Context()); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusAccepted, map[string]string{"status": "accepted"})
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
