package handlers

import (
	"encoding/json"
	"net/http"

	"go.uber.org/zap"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// AgentHandler hosts Agent CRUD + version management HTTP routes.
//
// AgentHandler 持 Agent CRUD + 版本管理 HTTP 路由。
type AgentHandler struct {
	svc *agentapp.Service
	log *zap.Logger
}

func NewAgentHandler(svc *agentapp.Service, log *zap.Logger) *AgentHandler {
	return &AgentHandler{svc: svc, log: log}
}

func (h *AgentHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/agents", h.Create)
	mux.HandleFunc("GET /api/v1/agents", h.List)
	mux.HandleFunc("GET /api/v1/agents/{id}", h.Get)
	mux.HandleFunc("DELETE /api/v1/agents/{id}", h.Delete)
	mux.HandleFunc("POST /api/v1/agents/{idAction}", h.postOnAgent)
	mux.HandleFunc("GET /api/v1/agents/{id}/versions", h.ListVersions)
	mux.HandleFunc("GET /api/v1/agents/{id}/pending", h.GetPending)
	mux.HandleFunc("POST /api/v1/agents/{id}/pending:accept", h.AcceptPending)
	mux.HandleFunc("POST /api/v1/agents/{id}/pending:reject", h.RejectPending)
}

func (h *AgentHandler) postOnAgent(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		http.NotFound(w, r)
		return
	}
	switch action {
	case "edit":
		h.Edit(w, r, id)
	default:
		http.NotFound(w, r)
	}
}

func (h *AgentHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name          string                    `json:"name"`
		Description   string                    `json:"description"`
		Tags          []string                  `json:"tags"`
		Prompt        string                    `json:"prompt"`
		Skill         string                    `json:"skill"`
		Knowledge     []string                  `json:"knowledge"`
		Tools         []agentdomain.ToolRef     `json:"tools"`
		OutputSchema  *agentdomain.OutputSchema  `json:"outputSchema"`
		ModelOverride string                    `json:"modelOverride"`
		ChangeReason  string                    `json:"changeReason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	a, v, err := h.svc.Create(r.Context(), agentapp.CreateInput{
		Name: req.Name, Description: req.Description, Tags: req.Tags,
		Prompt: req.Prompt, Skill: req.Skill, Knowledge: req.Knowledge,
		Tools: req.Tools, OutputSchema: req.OutputSchema,
		ModelOverride: req.ModelOverride, ChangeReason: req.ChangeReason,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	a.ActiveVersion = v
	responsehttpapi.Created(w, a)
}

func (h *AgentHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	a, err := h.svc.Get(r.Context(), id)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, a)
}

func (h *AgentHandler) List(w http.ResponseWriter, r *http.Request) {
	limit, cursor := parseLimitCursorAgent(r, 50)
	agents, next, err := h.svc.List(r.Context(), limit, cursor)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{
		"data": agents, "nextCursor": next, "hasMore": next != "",
	})
}

func (h *AgentHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := h.svc.Delete(r.Context(), id); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusNoContent, nil)
}

func (h *AgentHandler) Edit(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		Prompt        *string                   `json:"prompt"`
		Skill         *string                   `json:"skill"`
		Knowledge     []string                  `json:"knowledge"`
		Tools         []agentdomain.ToolRef     `json:"tools"`
		OutputSchema  *agentdomain.OutputSchema  `json:"outputSchema"`
		ModelOverride *string                   `json:"modelOverride"`
		ChangeReason  string                    `json:"changeReason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	v, err := h.svc.Edit(r.Context(), agentapp.EditInput{
		ID: id, Prompt: req.Prompt, Skill: req.Skill,
		Knowledge: req.Knowledge, Tools: req.Tools,
		OutputSchema: req.OutputSchema, ModelOverride: req.ModelOverride,
		ChangeReason: req.ChangeReason,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

func (h *AgentHandler) ListVersions(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	versions, err := h.svc.ListVersions(r.Context(), id)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"data": versions, "nextCursor": "", "hasMore": false})
}

func (h *AgentHandler) GetPending(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	pv, err := h.svc.GetPending(r.Context(), id)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, pv)
}

func (h *AgentHandler) AcceptPending(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	v, err := h.svc.Accept(r.Context(), id)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"versionId": v.ID, "accepted": true})
}

func (h *AgentHandler) RejectPending(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := h.svc.RejectPending(r.Context(), id); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"rejected": true})
}

// parseLimitCursorAgent parses limit/cursor query params for agent list handlers.
func parseLimitCursorAgent(r *http.Request, defaultLimit int) (int, string) {
	limit := defaultLimit
	if v := r.URL.Query().Get("limit"); v != "" {
		var n int
		if err := json.Unmarshal([]byte(v), &n); err == nil && n > 0 {
			limit = n
		}
	}
	return limit, r.URL.Query().Get("cursor")
}
