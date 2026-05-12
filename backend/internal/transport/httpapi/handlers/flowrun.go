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

// Register mounts every flowrun route on mux. Workflow-scoped routes
// (POST /workflows/{id}:trigger and GET /workflows/{id}/triggers) live
// in the WorkflowHandler since they share the {idAction} mux pattern.
//
// Register 挂 flowrun 路由。workflow-scoped :trigger + /triggers 由
// WorkflowHandler 持(共享 {idAction} mux 模式,避 mux 冲突)。
func (h *FlowRunHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/flowruns", h.List)
	mux.HandleFunc("GET /api/v1/flowruns/{id}", h.Get)
	mux.HandleFunc("GET /api/v1/flowruns/{id}/nodes", h.ListNodes)
	mux.HandleFunc("DELETE /api/v1/flowruns/{id}", h.Cancel)
	mux.HandleFunc("POST /api/v1/flowruns/{id}/approvals/{nodeId}", h.Approve)
}

// FireManual delegates a workflow trigger to the wrapped trigger Service.
// Exposed so WorkflowHandler can route `:trigger` action through this
// FlowRunHandler instance (avoids duplicating the trigger Service
// reference in two HTTP handler structs).
//
// FireManual 给 WorkflowHandler 派 :trigger action 调;避免在两个 handler
// 各持一份 triggerService 引用。
func (h *FlowRunHandler) FireManual(w http.ResponseWriter, r *http.Request, workflowID string) {
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
	runID, err := h.trigger.FireManual(r.Context(), workflowID, req.Input)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, map[string]any{"runId": runID})
}

// TriggerStates returns per-trigger States for a workflow. Exposed for
// WorkflowHandler to route GET /workflows/{id}/triggers — see FireManual.
//
// TriggerStates 给 WorkflowHandler 派 GET /workflows/{id}/triggers 调。
func (h *FlowRunHandler) TriggerStates(workflowID string) []any {
	if h.trigger == nil {
		return []any{}
	}
	states := h.trigger.State(workflowID)
	out := make([]any, len(states))
	for i, s := range states {
		out[i] = s
	}
	return out
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
