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
	mux.HandleFunc("GET /api/v1/agents/{id}/executions", h.ListExecutions)
	mux.HandleFunc("GET /api/v1/agent-executions/{execId}", h.GetExecution)
}

// postOnAgent dispatches POST /api/v1/agents/{id}:<action> (:edit / :invoke / :revert) — mirrors
// postOnFunction (:run / :revert / :edit), with the agent verb being :invoke instead of :run.
//
// postOnAgent 派发 :edit / :invoke / :revert（对标 postOnFunction，agent 用 :invoke 替 :run）。
func (h *AgentHandler) postOnAgent(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		http.NotFound(w, r)
		return
	}
	switch action {
	case "edit":
		h.Edit(w, r, id)
	case "invoke":
		h.Invoke(w, r, id)
	case "revert":
		h.Revert(w, r, id)
	default:
		http.NotFound(w, r)
	}
}

// Invoke runs the agent (real ReAct run; records an execution). Mirrors function :run.
func (h *AgentHandler) Invoke(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		Version string         `json:"version"`
		Input   map[string]any `json:"input"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	res, err := h.svc.InvokeAgent(r.Context(), agentapp.InvokeInput{
		AgentID:     id,
		VersionID:   req.Version,
		Input:       req.Input,
		TriggeredBy: agentdomain.TriggeredByHTTP,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, res)
}

// Revert flips the agent's active version to a prior accepted version. Mirrors function :revert.
func (h *AgentHandler) Revert(w http.ResponseWriter, r *http.Request, id string) {
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

// ListExecutions returns the agent's execution log (mirrors function GET /functions/{id}/executions).
func (h *AgentHandler) ListExecutions(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	limit, cursor := parseLimitCursorAgent(r, 50)
	res, err := h.svc.SearchExecutions(r.Context(), agentdomain.ExecutionFilter{
		AgentID: id,
		Status:  r.URL.Query().Get("status"),
		Limit:   limit,
		Cursor:  cursor,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{
		"data": res.Executions, "nextCursor": res.NextCursor, "hasMore": res.HasMore, "aggregates": res.Aggregates,
	})
}

// GetExecution returns one execution row + hints (mirrors function GET /function-executions/{execId}).
func (h *AgentHandler) GetExecution(w http.ResponseWriter, r *http.Request) {
	execID := r.PathValue("execId")
	detail, err := h.svc.GetExecutionDetail(r.Context(), execID)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, detail)
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
