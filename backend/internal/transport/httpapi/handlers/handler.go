// handler.go — HTTP handlers for the handler domain (forge_redesign Plan 02
// Phase 6). 17 endpoints per spec/03-handler.md §8.2.
//
// LLM-driven authoring (ops streams) goes through the LLM tool path
// (create_handler / edit_handler / call_handler), not POST /handlers. The
// HTTP shape is the direct flat definition for curl / UI / scripts.

package handlers

import (
	"net/http"
	"strconv"

	"go.uber.org/zap"

	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

type HandlerHandler struct {
	svc *handlerapp.Service
	log *zap.Logger
}

func NewHandlerHandler(svc *handlerapp.Service, log *zap.Logger) *HandlerHandler {
	return &HandlerHandler{svc: svc, log: log}
}

func (h *HandlerHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/handlers", h.Create)
	mux.HandleFunc("GET /api/v1/handlers", h.List)
	mux.HandleFunc("GET /api/v1/handlers/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/handlers/{id}", h.UpdateMeta)
	mux.HandleFunc("DELETE /api/v1/handlers/{id}", h.Delete)
	mux.HandleFunc("POST /api/v1/handlers/{idAction}", h.postOnHandler)
	mux.HandleFunc("GET /api/v1/handlers/{id}/versions", h.ListVersions)
	mux.HandleFunc("GET /api/v1/handlers/{id}/versions/{version}", h.GetVersion)
	mux.HandleFunc("GET /api/v1/handlers/{id}/pending", h.GetPending)
	mux.HandleFunc("POST /api/v1/handlers/{id}/pending:accept", h.AcceptPending)
	mux.HandleFunc("POST /api/v1/handlers/{id}/pending:reject", h.RejectPending)
	mux.HandleFunc("GET /api/v1/handlers/{id}/config", h.GetConfig)
	mux.HandleFunc("POST /api/v1/handlers/{id}/config", h.UpdateConfig)
	mux.HandleFunc("DELETE /api/v1/handlers/{id}/config", h.ClearConfig)
}

// ── CRUD ─────────────────────────────────────────────────────────────────────

func (h *HandlerHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name           string                       `json:"name"`
		Description    string                       `json:"description"`
		Tags           []string                     `json:"tags"`
		Imports        string                       `json:"imports"`
		InitBody       string                       `json:"initBody"`
		ShutdownBody   string                       `json:"shutdownBody"`
		Methods        []handlerdomain.MethodSpec   `json:"methods"`
		InitArgsSchema []handlerdomain.InitArgSpec  `json:"initArgsSchema"`
		Dependencies   []string                     `json:"dependencies"`
		PythonVersion  string                       `json:"pythonVersion"`
		ChangeReason   string                       `json:"changeReason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	hd, v, err := h.svc.CreateDirect(r.Context(), handlerapp.DirectCreateInput{
		Name:           req.Name,
		Description:    req.Description,
		Tags:           req.Tags,
		Imports:        req.Imports,
		InitBody:       req.InitBody,
		ShutdownBody:   req.ShutdownBody,
		Methods:        req.Methods,
		InitArgsSchema: req.InitArgsSchema,
		Dependencies:   req.Dependencies,
		PythonVersion:  req.PythonVersion,
		ChangeReason:   req.ChangeReason,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, map[string]any{"handler": hd, "version": v})
}

func (h *HandlerHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := paginationpkg.Parse(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	items, next, err := h.svc.List(r.Context(), handlerdomain.ListFilter{Cursor: p.Cursor, Limit: p.Limit})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

func (h *HandlerHandler) Get(w http.ResponseWriter, r *http.Request) {
	hd, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, hd)
}

func (h *HandlerHandler) UpdateMeta(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        *string   `json:"name"`
		Description *string   `json:"description"`
		Tags        *[]string `json:"tags"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	hd, err := h.svc.UpdateMeta(r.Context(), handlerapp.UpdateMetaInput{
		ID:          r.PathValue("id"),
		Name:        req.Name,
		Description: req.Description,
		Tags:        req.Tags,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, hd)
}

func (h *HandlerHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// postOnHandler dispatches POST /api/v1/handlers/{id}:action.
//
// postOnHandler 派发 POST /api/v1/handlers/{id}:action。
func (h *HandlerHandler) postOnHandler(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		http.NotFound(w, r)
		return
	}
	switch action {
	case "call":
		h.Call(w, r, id)
	case "revert":
		h.Revert(w, r, id)
	default:
		http.NotFound(w, r)
	}
}

func (h *HandlerHandler) Call(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		Method string         `json:"method"`
		Args   map[string]any `json:"args"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if req.Method == "" {
		responsehttpapi.Error(w, http.StatusBadRequest, "INVALID_REQUEST", "method required", nil)
		return
	}
	// HTTP scope = "session" — explicit per-call from the API. Each HTTP
	// request spawns + calls + destroys (effectively per-call too, since
	// we don't have a session lifecycle endpoint yet).
	//
	// HTTP scope = "session";V1 没 session lifecycle 端点,实际等同于
	// per-call(spawn+call+destroy)。
	result, err := h.svc.Call(r.Context(), handlerapp.CallInput{
		HandlerID: id,
		Method:    req.Method,
		Args:      req.Args,
		Owner:     handlerapp.Owner{Kind: "chat"}, // per-call lifetime
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"result": result})
}

func (h *HandlerHandler) Revert(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		TargetVersion int `json:"targetVersion"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	v, err := h.svc.Revert(r.Context(), id, req.TargetVersion)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

// ── Versions ─────────────────────────────────────────────────────────────────

func (h *HandlerHandler) ListVersions(w http.ResponseWriter, r *http.Request) {
	p, err := paginationpkg.Parse(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	rows, next, err := h.svc.ListVersions(r.Context(), r.PathValue("id"), handlerdomain.VersionListFilter{
		Cursor: p.Cursor,
		Limit:  p.Limit,
		Status: r.URL.Query().Get("status"),
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, rows, next, next != "")
}

func (h *HandlerHandler) GetVersion(w http.ResponseWriter, r *http.Request) {
	versionStr := r.PathValue("version")
	versionN, err := strconv.Atoi(versionStr)
	if err != nil {
		v, gerr := h.svc.GetVersion(r.Context(), versionStr)
		if gerr != nil {
			responsehttpapi.FromDomainError(w, h.log, gerr)
			return
		}
		responsehttpapi.Success(w, http.StatusOK, v)
		return
	}
	v, err := h.svc.GetVersionByNumber(r.Context(), r.PathValue("id"), versionN)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

// ── Pending ──────────────────────────────────────────────────────────────────

func (h *HandlerHandler) GetPending(w http.ResponseWriter, r *http.Request) {
	v, err := h.svc.GetPending(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

func (h *HandlerHandler) AcceptPending(w http.ResponseWriter, r *http.Request) {
	v, err := h.svc.AcceptPending(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

func (h *HandlerHandler) RejectPending(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.RejectPending(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// ── Config (D-handler) ───────────────────────────────────────────────────────

func (h *HandlerHandler) GetConfig(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	// Resolve active version to find schema → mask appropriately.
	// 拿 active 版本的 schema 做 mask。
	hd, err := h.svc.Get(r.Context(), id)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	var schema []handlerdomain.InitArgSpec
	if hd.ActiveVersionID != "" {
		v, _ := h.svc.GetVersion(r.Context(), hd.ActiveVersionID)
		if v != nil {
			schema = v.InitArgsSchema
		}
	}
	masked, err := h.svc.MaskedConfig(r.Context(), id, schema)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	out := map[string]any{
		"configState": hd.ConfigState,
		"config":      masked,
	}
	responsehttpapi.Success(w, http.StatusOK, out)
}

func (h *HandlerHandler) UpdateConfig(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Config map[string]any `json:"config"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	id := r.PathValue("id")
	if err := h.svc.UpdateConfig(r.Context(), id, req.Config); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	hd, _ := h.svc.Get(r.Context(), id)
	responsehttpapi.Success(w, http.StatusOK, map[string]any{
		"updated":     true,
		"configState": hd.ConfigState,
	})
}

func (h *HandlerHandler) ClearConfig(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.ClearConfig(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
