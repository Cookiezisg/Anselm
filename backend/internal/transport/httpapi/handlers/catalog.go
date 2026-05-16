package handlers

import (
	"net/http"
	"strconv"

	"go.uber.org/zap"

	catalogapp "github.com/sunweilin/forgify/backend/internal/app/catalog"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// CatalogHandler hosts the 2 capability-catalog endpoints.
//
// CatalogHandler 持 2 个 catalog 端点。
type CatalogHandler struct {
	svc *catalogapp.Service
	log *zap.Logger
}

func NewCatalogHandler(svc *catalogapp.Service, log *zap.Logger) *CatalogHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &CatalogHandler{svc: svc, log: log.Named("handlers.catalog")}
}

func (h *CatalogHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/catalog", h.Get)
	mux.HandleFunc("POST /api/v1/catalog:refresh", h.Refresh)
	mux.HandleFunc("GET /api/v1/catalog/history", h.History)
	mux.HandleFunc("GET /api/v1/catalog/diff", h.Diff)
}

// Get returns the current cached Catalog; null when cache not yet built.
//
// Get 返当前缓存 Catalog;未构造时返 null。
func (h *CatalogHandler) Get(w http.ResponseWriter, _ *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.svc.Get())
}

// Refresh forces an immediate Service.Refresh and returns the new Catalog.
//
// Refresh 强制立即刷新并返新 Catalog。
func (h *CatalogHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Refresh(r.Context()); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, h.svc.Get())
}

// History returns the persisted catalog versions (§4.7); empty list when
// history repo not wired or no versions saved yet.
//
// History 返持久化的 catalog 版本(§4.7);未装 repo 或无版本时返空数组。
func (h *CatalogHandler) History(w http.ResponseWriter, r *http.Request) {
	repo := h.svc.HistoryRepo()
	if repo == nil {
		responsehttpapi.Success(w, http.StatusOK, []any{})
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	rows, err := repo.ListRecent(r.Context(), limit)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, rows)
}

// Diff compares Coverage maps between two versions; returns added/removed items per source.
//
// Diff 比较两个版本的 Coverage; 按 source 返新增/删除。
func (h *CatalogHandler) Diff(w http.ResponseWriter, r *http.Request) {
	repo := h.svc.HistoryRepo()
	if repo == nil {
		responsehttpapi.Error(w, http.StatusServiceUnavailable, "CATALOG_HISTORY_UNAVAILABLE",
			"catalog history persistence not enabled", nil)
		return
	}
	fromV, _ := strconv.Atoi(r.URL.Query().Get("from"))
	toV, _ := strconv.Atoi(r.URL.Query().Get("to"))
	if fromV <= 0 || toV <= 0 {
		responsehttpapi.Error(w, http.StatusBadRequest, "INVALID_REQUEST",
			"from / to query params required (integer versions)", nil)
		return
	}
	fromH, err := repo.GetByVersion(r.Context(), fromV)
	if err != nil {
		responsehttpapi.Error(w, http.StatusNotFound, "CATALOG_VERSION_NOT_FOUND",
			"version "+strconv.Itoa(fromV)+" not in history", nil)
		return
	}
	toH, err := repo.GetByVersion(r.Context(), toV)
	if err != nil {
		responsehttpapi.Error(w, http.StatusNotFound, "CATALOG_VERSION_NOT_FOUND",
			"version "+strconv.Itoa(toV)+" not in history", nil)
		return
	}

	added := map[string][]string{}
	removed := map[string][]string{}
	allSources := map[string]bool{}
	for s := range fromH.Coverage {
		allSources[s] = true
	}
	for s := range toH.Coverage {
		allSources[s] = true
	}
	for source := range allSources {
		fromSet := stringSet(fromH.Coverage[source])
		toSet := stringSet(toH.Coverage[source])
		for id := range toSet {
			if !fromSet[id] {
				added[source] = append(added[source], id)
			}
		}
		for id := range fromSet {
			if !toSet[id] {
				removed[source] = append(removed[source], id)
			}
		}
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{
		"from":     fromV,
		"to":       toV,
		"fromFp":   fromH.Fingerprint,
		"toFp":     toH.Fingerprint,
		"added":    added,
		"removed":  removed,
	})
}

func stringSet(items []string) map[string]bool {
	out := make(map[string]bool, len(items))
	for _, s := range items {
		out[s] = true
	}
	return out
}
