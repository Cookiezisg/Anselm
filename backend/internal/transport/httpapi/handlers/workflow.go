// workflow.go — HTTP handlers for the workflow domain (forge_redesign Plan 04
// W7). 11 endpoints per spec/04-workflow.md §8:
//
//   POST   /api/v1/workflows                          create (direct ops)
//   GET    /api/v1/workflows                          list (paginated)
//   GET    /api/v1/workflows/{id}                     detail (with pending)
//   PATCH  /api/v1/workflows/{id}                     update metadata
//   DELETE /api/v1/workflows/{id}                     soft-delete
//   POST   /api/v1/workflows/{idAction}               :revert (no :trigger — Plan 05)
//   GET    /api/v1/workflows/{id}/versions            list versions
//   GET    /api/v1/workflows/{id}/versions/{v}        version detail
//   GET    /api/v1/workflows/{id}/pending             fetch pending
//   POST   /api/v1/workflows/{id}/pending:accept      accept pending
//   POST   /api/v1/workflows/{id}/pending:reject      reject pending
//
// :trigger + flowrun endpoints live in Plan 05 (scheduler / trigger / flowrun
// domains). LLM-driven authoring (ops streams) goes through the LLM tool path
// (create_workflow / edit_workflow), NOT POST /workflows. The HTTP shape is
// the direct ops definition for curl / UI / scripts.
//
// workflow.go —— workflow domain 的 HTTP handler(forge_redesign Plan 04 W7)。
// 11 端点 per 04-workflow.md §8。:trigger + flowrun 在 Plan 05;LLM 走 ops 流
// (create_workflow / edit_workflow 工具)。

package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"go.uber.org/zap"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// WorkflowHandler hosts the workflow HTTP routes.
//
// WorkflowHandler 持 workflow HTTP 路由。
type WorkflowHandler struct {
	svc     *workflowapp.Service
	flowrun *FlowRunHandler // optional — drives :trigger action + /triggers state
	log     *zap.Logger
}

// NewWorkflowHandler wires handler dependencies.
//
// NewWorkflowHandler 装配 handler 依赖。
func NewWorkflowHandler(svc *workflowapp.Service, log *zap.Logger) *WorkflowHandler {
	return &WorkflowHandler{svc: svc, log: log}
}

// AttachFlowRunHandler enables the workflow-scoped Plan 05 routes
// (:trigger action + /triggers state). Called by the router after the
// FlowRunHandler is constructed.
//
// AttachFlowRunHandler 接 Plan 05 workflow-scoped 路由(:trigger 与
// /triggers state)。router 在 FlowRunHandler 构造后调。
func (h *WorkflowHandler) AttachFlowRunHandler(f *FlowRunHandler) {
	h.flowrun = f
}

// Register mounts every workflow route on mux.
//
// Register 把所有 workflow 路由挂到 mux。
func (h *WorkflowHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/workflows", h.Create)
	mux.HandleFunc("GET /api/v1/workflows", h.List)
	mux.HandleFunc("GET /api/v1/workflows/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/workflows/{id}", h.UpdateMeta)
	mux.HandleFunc("DELETE /api/v1/workflows/{id}", h.Delete)
	mux.HandleFunc("POST /api/v1/workflows/{idAction}", h.postOnWorkflow)
	mux.HandleFunc("GET /api/v1/workflows/{id}/triggers", h.GetTriggers)
	mux.HandleFunc("GET /api/v1/workflows/{id}/versions", h.ListVersions)
	mux.HandleFunc("GET /api/v1/workflows/{id}/versions/{version}", h.GetVersion)
	mux.HandleFunc("GET /api/v1/workflows/{id}/pending", h.GetPending)
	mux.HandleFunc("POST /api/v1/workflows/{id}/pending:accept", h.AcceptPending)
	mux.HandleFunc("POST /api/v1/workflows/{id}/pending:reject", h.RejectPending)
}

// ── CRUD ──────────────────────────────────────────────────────────────────────

// Create applies ops to an empty graph and persists workflow + auto-accepted
// v1. ops payload is required (set_meta + at least one trigger node + edges).
// ops is parsed via workflowapp.ParseOps (each op kept as json.RawMessage so
// per-op handlers decode their own schema — handler-level DisallowUnknownFields
// only inspects the top-level request envelope, not the ops payload).
//
// Create 应用 ops 到空图 + 持久化 workflow + 自动 accept v1。ops 走 ParseOps
// (每条 op 保 raw,per-op handler 自己解码,handler 层 DisallowUnknownFields
// 只看顶层 envelope)。
func (h *WorkflowHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	ops, err := workflowapp.ParseOps(req.Ops)
	if err != nil {
		responsehttpapi.Error(w, http.StatusBadRequest, "WORKFLOW_OP_INVALID", err.Error(), nil)
		return
	}
	wf, v, err := h.svc.Create(r.Context(), workflowapp.CreateInput{
		Ops:          ops,
		ChangeReason: req.ChangeReason,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, map[string]any{"workflow": wf, "version": v})
}

func (h *WorkflowHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := paginationpkg.Parse(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	enabledOnly := r.URL.Query().Get("enabled") == "true"
	items, next, err := h.svc.List(r.Context(), workflowdomain.ListFilter{
		Cursor:      p.Cursor,
		Limit:       p.Limit,
		EnabledOnly: enabledOnly,
	})
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
		Name            *string   `json:"name"`
		Description     *string   `json:"description"`
		Tags            *[]string `json:"tags"`
		Enabled         *bool     `json:"enabled"`
		Concurrency     *string   `json:"concurrency"`
		NeedsAttention  *bool     `json:"needsAttention"`
		AttentionReason *string   `json:"attentionReason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	wf, err := h.svc.UpdateMeta(r.Context(), workflowapp.UpdateMetaInput{
		ID:              r.PathValue("id"),
		Name:            req.Name,
		Description:     req.Description,
		Tags:            req.Tags,
		Enabled:         req.Enabled,
		Concurrency:     req.Concurrency,
		NeedsAttention:  req.NeedsAttention,
		AttentionReason: req.AttentionReason,
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

// postOnWorkflow dispatches POST /api/v1/workflows/{id}:<action>. Supports
// :revert (Plan 04) + :trigger (Plan 05; delegates to attached
// FlowRunHandler so triggerService dep stays out of WorkflowHandler).
//
// postOnWorkflow 派发 POST /api/v1/workflows/{id}:<action>。:revert 走 Plan
// 04;:trigger 走 Plan 05(委派 FlowRunHandler;triggerService 依赖留 flowrun)。
func (h *WorkflowHandler) postOnWorkflow(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		http.NotFound(w, r)
		return
	}
	switch action {
	case "revert":
		h.Revert(w, r, id)
	case "trigger":
		if h.flowrun == nil {
			responsehttpapi.Error(w, http.StatusServiceUnavailable, "SCHEDULER_NOT_AVAILABLE",
				"Plan 05 execution plane not wired", nil)
			return
		}
		h.flowrun.FireManual(w, r, id)
	default:
		http.NotFound(w, r)
	}
}

// GetTriggers returns per-trigger State for a workflow (§6.12). Delegates
// to attached FlowRunHandler; falls back to empty list if not wired.
//
// GetTriggers 返某 workflow 所有 trigger 状态(§6.12);委派 FlowRunHandler。
func (h *WorkflowHandler) GetTriggers(w http.ResponseWriter, r *http.Request) {
	if h.flowrun == nil {
		responsehttpapi.Success(w, http.StatusOK, []any{})
		return
	}
	responsehttpapi.Success(w, http.StatusOK, h.flowrun.TriggerStates(r.PathValue("id")))
}

func (h *WorkflowHandler) Revert(w http.ResponseWriter, r *http.Request, id string) {
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

// ── Versions ──────────────────────────────────────────────────────────────────

func (h *WorkflowHandler) ListVersions(w http.ResponseWriter, r *http.Request) {
	p, err := paginationpkg.Parse(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	rows, next, err := h.svc.ListVersions(r.Context(), r.PathValue("id"), workflowdomain.VersionListFilter{
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

// GetVersion accepts either an integer version number or a wfv_xxx version
// ID, mirroring function / handler behaviour.
//
// GetVersion 兼容数字版本号或 wfv_xxx 版本 ID(同 function / handler)。
func (h *WorkflowHandler) GetVersion(w http.ResponseWriter, r *http.Request) {
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

// ── Pending ───────────────────────────────────────────────────────────────────

func (h *WorkflowHandler) GetPending(w http.ResponseWriter, r *http.Request) {
	v, err := h.svc.GetPending(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

func (h *WorkflowHandler) AcceptPending(w http.ResponseWriter, r *http.Request) {
	v, err := h.svc.AcceptPending(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, v)
}

func (h *WorkflowHandler) RejectPending(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.RejectPending(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
