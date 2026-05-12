// flowrun.go — HTTP handlers for the execution plane (Plan 05).
// 8 endpoints:
//
//   POST   /api/v1/workflows/{id}:trigger              手动触发(转 scheduler)
//   GET    /api/v1/flowruns                            列表
//   GET    /api/v1/flowruns/{id}                       详情
//   GET    /api/v1/flowruns/{id}/nodes                 node 执行记录
//   DELETE /api/v1/flowruns/{id}                       取消
//   POST   /api/v1/flowruns/{id}/approvals/{nodeId}    approval 签收
//   GET    /api/v1/workflows/{id}/triggers             trigger 状态(§6.12)
//
// Webhook entry POST /api/v1/webhooks/{wfId}/{path} is registered by the
// trigger Service's webhook listener directly on the ServeMux, not via
// this handler (webhook.go in infra/trigger/webhook/).
//
// flowrun.go —— 执行 plane HTTP handler(Plan 05)。8 端点。webhook 端点
// 由 trigger webhook listener 直接挂 ServeMux,不走此 handler。

package handlers

import (
	"net/http"

	"go.uber.org/zap"

	schedulerapp "github.com/sunweilin/forgify/backend/internal/app/scheduler"
	triggerapp "github.com/sunweilin/forgify/backend/internal/app/trigger"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// FlowRunHandler hosts the execution-plane HTTP routes.
//
// FlowRunHandler 持执行 plane HTTP 路由。
type FlowRunHandler struct {
	repo      flowrundomain.Repository
	scheduler *schedulerapp.Service
	trigger   *triggerapp.Service
	log       *zap.Logger
}

// NewFlowRunHandler wires dependencies.
//
// NewFlowRunHandler 装配依赖。
func NewFlowRunHandler(repo flowrundomain.Repository, scheduler *schedulerapp.Service, trigger *triggerapp.Service, log *zap.Logger) *FlowRunHandler {
	return &FlowRunHandler{repo: repo, scheduler: scheduler, trigger: trigger, log: log}
}

// Register mounts every flowrun route on mux.
//
// Register 把所有 flowrun 路由挂 mux。
func (h *FlowRunHandler) Register(mux *http.ServeMux) {
	// Workflow-scoped — must come after the workflow handler's specific
	// routes (httpapi/router orders that, this just registers).
	mux.HandleFunc("POST /api/v1/workflows/{idTrigger}", h.postOnWorkflowTrigger)
	mux.HandleFunc("GET /api/v1/workflows/{id}/triggers", h.GetTriggers)

	// Flowruns
	mux.HandleFunc("GET /api/v1/flowruns", h.List)
	mux.HandleFunc("GET /api/v1/flowruns/{id}", h.Get)
	mux.HandleFunc("GET /api/v1/flowruns/{id}/nodes", h.ListNodes)
	mux.HandleFunc("DELETE /api/v1/flowruns/{id}", h.Cancel)
	mux.HandleFunc("POST /api/v1/flowruns/{id}/approvals/{nodeId}", h.Approve)
}

// postOnWorkflowTrigger dispatches POST /workflows/{idTrigger}. Only
// supports `:trigger` action — anything else 404s (so it composes with
// the workflow handler's `:revert` etc. routes which take precedence
// via more-specific match).
//
// postOnWorkflowTrigger 派发 POST /workflows/{idTrigger}。只支持 :trigger。
func (h *FlowRunHandler) postOnWorkflowTrigger(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idTrigger")
	if !ok || action != "trigger" {
		http.NotFound(w, r)
		return
	}
	var req struct {
		Input map[string]any `json:"input"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if h.trigger == nil {
		responsehttpapi.Error(w, http.StatusServiceUnavailable, "SCHEDULER_NOT_AVAILABLE",
			"trigger service not wired", nil)
		return
	}
	runID, err := h.trigger.FireManual(r.Context(), id, req.Input)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, map[string]any{"runId": runID})
}

// GetTriggers returns the per-trigger State for a workflow (§6.12).
//
// GetTriggers 返某 workflow 所有 trigger 状态(§6.12)。
func (h *FlowRunHandler) GetTriggers(w http.ResponseWriter, r *http.Request) {
	if h.trigger == nil {
		responsehttpapi.Success(w, http.StatusOK, []any{})
		return
	}
	states := h.trigger.State(r.PathValue("id"))
	responsehttpapi.Success(w, http.StatusOK, states)
}

// List paginates FlowRuns.
//
// List 列分页。
func (h *FlowRunHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := paginationpkg.Parse(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	q := r.URL.Query()
	filter := flowrundomain.ListFilter{
		WorkflowID:  q.Get("workflowId"),
		Status:      q.Get("status"),
		TriggerKind: q.Get("triggerKind"),
		Cursor:      p.Cursor,
		Limit:       p.Limit,
	}
	rows, next, err := h.repo.List(r.Context(), filter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, rows, next, next != "")
}

// Get returns one FlowRun by id.
//
// Get 按 id 返单 FlowRun。
func (h *FlowRunHandler) Get(w http.ResponseWriter, r *http.Request) {
	run, err := h.repo.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, run)
}

// ListNodes returns per-node execution rows.
//
// ListNodes 返某 FlowRun 的节点执行行。
func (h *FlowRunHandler) ListNodes(w http.ResponseWriter, r *http.Request) {
	p, err := paginationpkg.Parse(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	q := r.URL.Query()
	filter := flowrundomain.NodeFilter{
		FlowrunID: r.PathValue("id"),
		NodeType:  q.Get("nodeType"),
		Status:    q.Get("status"),
		Cursor:    p.Cursor,
		Limit:     p.Limit,
	}
	rows, next, err := h.repo.ListNodes(r.Context(), filter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, rows, next, next != "")
}

// Cancel cancels a running or paused FlowRun.
//
// Cancel 取消运行中 / paused FlowRun。
func (h *FlowRunHandler) Cancel(w http.ResponseWriter, r *http.Request) {
	if h.scheduler == nil {
		responsehttpapi.Error(w, http.StatusServiceUnavailable, "SCHEDULER_NOT_AVAILABLE",
			"scheduler not wired", nil)
		return
	}
	if err := h.scheduler.Cancel(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// Approve resolves an approval-paused FlowRun.
//
// Approve 解 approval-paused FlowRun。
func (h *FlowRunHandler) Approve(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Decision string `json:"decision"`
		Reason   string `json:"reason"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if h.scheduler == nil {
		responsehttpapi.Error(w, http.StatusServiceUnavailable, "SCHEDULER_NOT_AVAILABLE",
			"scheduler not wired", nil)
		return
	}
	if err := h.scheduler.ResumeApproval(r.Context(), r.PathValue("id"), r.PathValue("nodeId"), req.Decision); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusAccepted, map[string]any{"resumed": true})
}
