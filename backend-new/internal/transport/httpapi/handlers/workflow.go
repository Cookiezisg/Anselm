package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"go.uber.org/zap"

	aispawnapp "github.com/sunweilin/forgify/backend/internal/app/aispawn"
	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// WorkflowHandler hosts the workflow graph HTTP endpoints. The version model is linear with
// a free-moving active pointer — no pending/accept endpoints. There is NO :trigger and no
// execution-history endpoint: those consume the durable scheduler (later wave). The :iterate
// verb (R0065) opens an AI conversation to edit this workflow via aispawn.
//
// WorkflowHandler 持 workflow 图 HTTP 端点。版本模型线性 + 可自由移动的 active 指针——无
// pending/accept 端点。无 :trigger、无 execution-history 端点：那些消费 durable 调度器（后续
// 波次）。:iterate 动词（R0065）经 aispawn 开一个 AI 对话来编辑本 workflow。
type WorkflowHandler struct {
	svc     *workflowapp.Service
	aispawn *aispawnapp.Service
	log     *zap.Logger
}

// NewWorkflowHandler constructs the handler.
//
// NewWorkflowHandler 构造 handler。
func NewWorkflowHandler(svc *workflowapp.Service, aispawn *aispawnapp.Service, log *zap.Logger) *WorkflowHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &WorkflowHandler{svc: svc, aispawn: aispawn, log: log.Named("handlers.workflow")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *WorkflowHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/workflows", h.Create)
	mux.HandleFunc("GET /api/v1/workflows", h.List)
	mux.HandleFunc("GET /api/v1/workflows/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/workflows/{id}", h.UpdateMeta)
	mux.HandleFunc("DELETE /api/v1/workflows/{id}", h.Delete)
	mux.HandleFunc("POST /api/v1/workflows/{idAction}", h.postOnWorkflow)
	mux.HandleFunc("GET /api/v1/workflows/{id}/versions", h.ListVersions)
	mux.HandleFunc("GET /api/v1/workflows/{id}/versions/{version}", h.GetVersion)
}

type createWorkflowRequest struct {
	Name         string          `json:"name"`
	Description  string          `json:"description"`
	Tags         []string        `json:"tags"`
	Ops          json.RawMessage `json:"ops"`
	ChangeReason string          `json:"changeReason"`
}

func (h *WorkflowHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createWorkflowRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	ops, err := workflowdomain.ParseOps(req.Ops)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	wf, v, err := h.svc.Create(r.Context(), workflowapp.CreateInput{
		Name: req.Name, Description: req.Description, Tags: req.Tags, Ops: ops, ChangeReason: req.ChangeReason,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, map[string]any{"workflow": wf, "version": v})
}

func (h *WorkflowHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	items, next, err := h.svc.List(r.Context(), workflowdomain.ListFilter{Cursor: p.Cursor, Limit: p.Limit})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

func (h *WorkflowHandler) Get(w http.ResponseWriter, r *http.Request) {
	wf, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, wf)
}

func (h *WorkflowHandler) UpdateMeta(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        *string   `json:"name"`
		Description *string   `json:"description"`
		Tags        *[]string `json:"tags"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	wf, err := h.svc.UpdateMeta(r.Context(), workflowapp.UpdateMetaInput{
		ID: r.PathValue("id"), Name: req.Name, Description: req.Description, Tags: req.Tags,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, wf)
}

func (h *WorkflowHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// postOnWorkflow dispatches POST /workflows/{id}:<action>
// (:edit / :revert / :activate / :deactivate / :capability-check). No :trigger.
//
// postOnWorkflow 派发 POST /workflows/{id}:<action>
// （:edit / :revert / :activate / :deactivate / :capability-check）。无 :trigger。
func (h *WorkflowHandler) postOnWorkflow(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		http.NotFound(w, r)
		return
	}
	switch action {
	case "edit":
		h.edit(w, r, id)
	case "revert":
		h.revert(w, r, id)
	case "activate":
		h.setLifecycle(w, r, id, workflowdomain.LifecycleActive)
	case "deactivate":
		h.setLifecycle(w, r, id, workflowdomain.LifecycleInactive)
	case "capability-check":
		h.capabilityCheck(w, r, id)
	case "iterate":
		iterateEntity(w, r, h.log, h.aispawn, mentiondomain.MentionWorkflow, id)
	default:
		http.NotFound(w, r)
	}
}

func (h *WorkflowHandler) edit(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	ops, err := workflowdomain.ParseOps(req.Ops)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	v, err := h.svc.Edit(r.Context(), workflowapp.EditInput{ID: id, Ops: ops, ChangeReason: req.ChangeReason})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

func (h *WorkflowHandler) revert(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		Version int `json:"version"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	v, err := h.svc.Revert(r.Context(), id, req.Version)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

// setLifecycle backs :activate / :deactivate (a user action). Draining is a system-driven
// state the scheduler sets, so it has no dedicated user verb.
//
// setLifecycle 支撑 :activate / :deactivate（用户动作）。draining 是调度器设的系统状态，故无专门
// 用户动词。
func (h *WorkflowHandler) setLifecycle(w http.ResponseWriter, r *http.Request, id, state string) {
	wf, err := h.svc.SetLifecycle(r.Context(), id, state, workflowdomain.ActorUser)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, wf)
}

func (h *WorkflowHandler) capabilityCheck(w http.ResponseWriter, r *http.Request, id string) {
	rep, err := h.svc.CapabilityCheckByID(r.Context(), id)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, rep)
}

func (h *WorkflowHandler) ListVersions(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	rows, next, err := h.svc.ListVersions(r.Context(), r.PathValue("id"), workflowdomain.VersionListFilter{Cursor: p.Cursor, Limit: p.Limit})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, rows, next, next != "")
}

// GetVersion accepts either an integer version number or a version id in {version}.
//
// GetVersion 的 {version} 接整数版本号或 version id。
func (h *WorkflowHandler) GetVersion(w http.ResponseWriter, r *http.Request) {
	versionStr := r.PathValue("version")
	if n, err := strconv.Atoi(versionStr); err == nil {
		v, gerr := h.svc.GetVersionByNumber(r.Context(), r.PathValue("id"), n)
		if gerr != nil {
			responsehttpapi.FromDomainError(w, h.log, gerr)
			return
		}
		responsehttpapi.Success(w, http.StatusOK, v)
		return
	}
	v, err := h.svc.GetVersion(r.Context(), versionStr)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}
