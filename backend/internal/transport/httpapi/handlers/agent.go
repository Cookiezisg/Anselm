package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"go.uber.org/zap"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	"github.com/sunweilin/forgify/backend/internal/app/askai"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// AgentHandler hosts Agent CRUD + version management HTTP routes.
//
// AgentHandler 持 Agent CRUD + 版本管理 HTTP 路由。
type AgentHandler struct {
	svc     *agentapp.Service
	spawner *askai.Spawner // optional; nil disables :iterate
	log     *zap.Logger
}

func NewAgentHandler(svc *agentapp.Service, log *zap.Logger) *AgentHandler {
	return &AgentHandler{svc: svc, log: log}
}

// SetSpawner installs the askai Spawner post-construction; nil disables :iterate.
//
// SetSpawner 装配后注入 askai Spawner；nil 关闭 :iterate。
func (h *AgentHandler) SetSpawner(s *askai.Spawner) { h.spawner = s }

func (h *AgentHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/agents", h.Create)
	mux.HandleFunc("GET /api/v1/agents", h.List)
	mux.HandleFunc("GET /api/v1/agents/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/agents/{id}", h.UpdateMeta)
	mux.HandleFunc("DELETE /api/v1/agents/{id}", h.Delete)
	mux.HandleFunc("POST /api/v1/agents/{idAction}", h.postOnAgent)
	mux.HandleFunc("GET /api/v1/agents/{id}/versions", h.ListVersions)
	mux.HandleFunc("GET /api/v1/agents/{id}/versions/{version}", h.GetVersion)
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
	case "iterate":
		h.Iterate(w, r, id)
	default:
		http.NotFound(w, r)
	}
}

// Iterate spawns an AI-driven editing conversation for this agent (mirrors function :iterate).
// Returns conversationId for the frontend to subscribe to eventlog + forge stream.
//
// Iterate 起一个 AI 编辑对话（对标 function :iterate），返 conversationId 供前端订阅。
func (h *AgentHandler) Iterate(w http.ResponseWriter, r *http.Request, id string) {
	if h.spawner == nil {
		responsehttpapi.Error(w, http.StatusServiceUnavailable, "ASKAI_NOT_AVAILABLE", "askai spawner not wired", nil)
		return
	}
	var req struct {
		Prompt string `json:"prompt"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	sysPrompt, err := askai.BuildAgentContext(r.Context(), id, h.svc)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	result, err := h.spawner.Spawn(r.Context(), askai.SpawnInput{
		SystemPrompt: sysPrompt,
		UserPrompt:   req.Prompt,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, result)
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
	responsehttpapi.Success(w, http.StatusOK, res)
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
		ModelOverride *modeldomain.ModelRef     `json:"modelOverride"`
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
	responsehttpapi.Paged(w, agents, next, next != "")
}

func (h *AgentHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := h.svc.Delete(r.Context(), id); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusNoContent, nil)
}

// UpdateMeta patches agent name/description/tags without a version bump (mirrors function PATCH).
func (h *AgentHandler) UpdateMeta(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        *string   `json:"name"`
		Description *string   `json:"description"`
		Tags        *[]string `json:"tags"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	a, err := h.svc.UpdateMeta(r.Context(), agentapp.UpdateMetaInput{
		ID: r.PathValue("id"), Name: req.Name, Description: req.Description, Tags: req.Tags,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, a)
}

// GetVersion returns one version by integer number or by versionId (mirrors function GET /versions/{version}).
func (h *AgentHandler) GetVersion(w http.ResponseWriter, r *http.Request) {
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

func (h *AgentHandler) Edit(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		Prompt        *string                   `json:"prompt"`
		Skill         *string                   `json:"skill"`
		Knowledge     []string                  `json:"knowledge"`
		Tools         []agentdomain.ToolRef     `json:"tools"`
		OutputSchema  *agentdomain.OutputSchema  `json:"outputSchema"`
		ModelOverride *modeldomain.ModelRef     `json:"modelOverride"`
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
	responsehttpapi.Paged(w, versions, "", false)
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
