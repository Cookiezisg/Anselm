package handlers

import (
	"net/http"
	"strconv"
	"time"

	"go.uber.org/zap"

	aispawnapp "github.com/sunweilin/anselm/backend/internal/app/aispawn"
	triggerapp "github.com/sunweilin/anselm/backend/internal/app/trigger"
	mentiondomain "github.com/sunweilin/anselm/backend/internal/domain/mention"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// TriggerHandler hosts the trigger HTTP endpoints. A trigger is a standalone signal source
// (cron / webhook / fsnotify / sensor) with no version model. Edit is a plain PATCH (config
// takes effect immediately); :fire manually fires it. The activation log (GET .../activations)
// answers "why didn't it fire?". Reference-counted listen lifecycle is driven by workflow
// activate/deactivate, not exposed here.
//
// TriggerHandler 持 trigger HTTP 端点。trigger 是独立信号源（cron/webhook/fsnotify/sensor），无版本。
// Edit 是普通 PATCH（config 立即生效）；:fire 手动触发。activation 日志回答「为什么没触发」。
// 引用计数监听生命周期由 workflow 激活/停用驱动，不在此暴露。
type TriggerHandler struct {
	svc     *triggerapp.Service
	aispawn *aispawnapp.Service
	log     *zap.Logger
}

func NewTriggerHandler(svc *triggerapp.Service, aispawn *aispawnapp.Service, log *zap.Logger) *TriggerHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &TriggerHandler{svc: svc, aispawn: aispawn, log: log.Named("handlers.trigger")}
}

func (h *TriggerHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/triggers", h.Create)
	mux.HandleFunc("GET /api/v1/triggers", h.List)
	mux.HandleFunc("GET /api/v1/triggers/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/triggers/{id}", h.Edit)
	mux.HandleFunc("DELETE /api/v1/triggers/{id}", h.Delete)
	mux.HandleFunc("POST /api/v1/triggers/{idAction}", h.postOnTrigger)
	mux.HandleFunc("GET /api/v1/triggers/{id}/activations", h.ListActivations)
	mux.HandleFunc("GET /api/v1/triggers/{id}/firings", h.ListFirings)
	mux.HandleFunc("GET /api/v1/trigger-activations/{id}", h.GetActivation) // Log 单读路径变量统一 {id}(MD-id4)
	mux.HandleFunc("GET /api/v1/trigger-schedule", h.Schedule)
}

// Schedule serves the forward-looking cron timeline (scheduler 工单⑧): every tick due within
// ?within= (Go duration, default 168h, max 30d), capped at ?limit= (default 200, max 1000),
// ascending. Bounded by the cap → N4 cursor-free; `truncated` reports an overflow honestly instead
// of a silent short page. Only listening, non-paused cron triggers contribute — the other kinds
// have no knowable next fire.
//
// Schedule 供给前瞻 cron 时间线（scheduler 工单⑧）：?within=（Go duration，默认 168h、上限 30d）内每个
// 到期刻度，?limit= 封顶（默认 200、上限 1000），升序。有 cap 即有界 → N4 免游标；`truncated` 诚实报告
// 溢出、而非静默给个短页。只有正在监听、未暂停的 cron trigger 有贡献——其余 kind 的下次 fire 不可知。
func (h *TriggerHandler) Schedule(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	var in triggerapp.ScheduleQuery
	if v := q.Get("within"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d <= 0 {
			responsehttpapi.FromDomainError(w, h.log, triggerdomain.ErrInvalidScheduleQuery.WithDetails(
				map[string]any{"param": "within", "got": v}))
			return
		}
		in.Within = d
	}
	if v := q.Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			responsehttpapi.FromDomainError(w, h.log, triggerdomain.ErrInvalidScheduleQuery.WithDetails(
				map[string]any{"param": "limit", "got": v}))
			return
		}
		in.Limit = n
	}
	res, err := h.svc.Schedule(r.Context(), in)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, res)
}

func (h *TriggerHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        string            `json:"name"`
		Description string            `json:"description"`
		Kind        string            `json:"kind"`
		Config      map[string]any    `json:"config"`
		Outputs     []schemapkg.Field `json:"outputs"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	t, err := h.svc.Create(r.Context(), triggerapp.CreateInput{
		Name: req.Name, Description: req.Description, Kind: req.Kind, Config: req.Config, Outputs: req.Outputs,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, t) // 裸实体(trigger 无版本)
}

func (h *TriggerHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	items, next, err := h.svc.List(r.Context(), triggerdomain.ListFilter{Cursor: p.Cursor, Limit: p.Limit})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

func (h *TriggerHandler) Get(w http.ResponseWriter, r *http.Request) {
	t, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, t)
}

func (h *TriggerHandler) Edit(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        *string           `json:"name"`
		Description *string           `json:"description"`
		Config      map[string]any    `json:"config"`
		Outputs     []schemapkg.Field `json:"outputs"`
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	t, err := h.svc.Edit(r.Context(), r.PathValue("id"), triggerapp.EditInput{
		Name: req.Name, Description: req.Description, Config: req.Config, Outputs: req.Outputs,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, t)
}

func (h *TriggerHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// postOnTrigger dispatches POST /triggers/{id}:<action> (:fire / :pause / :resume / :iterate).
// :pause / :resume are the runtime scheduling switch (scheduler 工单⑦): synchronous state flips,
// idempotent (repeating is a harmless no-op), 200 with the bare post-action trigger (same shape as
// PATCH) — paused=true reads with nextFireAt absent and listening=false.
//
// postOnTrigger 派发 POST /triggers/{id}:<action>（:fire / :pause / :resume / :iterate）。
// :pause / :resume 是运行时调度开关（scheduler 工单⑦）：同步状态翻转、幂等（重复无害 no-op），
// 200 返动作后裸 trigger（与 PATCH 同形）——paused=true 时 nextFireAt 缺席、listening=false。
func (h *TriggerHandler) postOnTrigger(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
		return
	}
	switch action {
	case "fire":
		actID, err := h.svc.FireManual(r.Context(), id)
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		// 新产物 = activation;triggerId 已在 URL 路径、fired 被 202 蕴含 → 单产物 {id}
		responsehttpapi.Success(w, http.StatusAccepted, map[string]any{"id": actID})
	case "pause":
		t, err := h.svc.Pause(r.Context(), id)
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		responsehttpapi.Success(w, http.StatusOK, t)
	case "resume":
		t, err := h.svc.Resume(r.Context(), id)
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		responsehttpapi.Success(w, http.StatusOK, t)
	case "iterate":
		iterateEntity(w, r, h.log, h.aispawn, mentiondomain.MentionTrigger, id)
	default:
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
	}
}

func (h *TriggerHandler) ListActivations(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	acts, next, err := h.svc.SearchActivations(r.Context(), triggerdomain.ActivationFilter{
		TriggerID: r.PathValue("id"),
		FiredOnly: r.URL.Query().Get("firedOnly") == "true",
		Cursor:    p.Cursor,
		Limit:     p.Limit,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, acts, next, next != "")
}

// ListFirings pages the trigger's firing inbox (?status=pending|started|skipped|superseded|shed) —
// the disposition surface behind "it fired, why didn't it run".
//
// ListFirings 分页 trigger 的 firing 收件箱（?status=…）——「触发了为什么没跑」的处置面。
func (h *TriggerHandler) ListFirings(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	rows, next, err := h.svc.SearchFirings(r.Context(), triggerdomain.FiringFilter{
		TriggerID: r.PathValue("id"),
		Status:    r.URL.Query().Get("status"),
		Cursor:    p.Cursor,
		Limit:     p.Limit,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, rows, next, next != "")
}

func (h *TriggerHandler) GetActivation(w http.ResponseWriter, r *http.Request) {
	act, err := h.svc.GetActivation(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, act)
}
