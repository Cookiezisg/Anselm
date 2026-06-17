package handlers

import (
	"encoding/json"
	"net/http"

	"go.uber.org/zap"

	conversationapp "github.com/sunweilin/anselm/backend/internal/app/conversation"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// ConversationHandler serves the 5 /api/v1/conversations/* CRUD endpoints. The tokensUsed
// enrichment + the system-prompt-preview endpoint are chat data (message_blocks token sum /
// prompt assembly) and live on ChatHandler, not here.
//
// ConversationHandler 提供 /api/v1/conversations/* 的 5 个 CRUD 端点。tokensUsed 富化 +
// system-prompt-preview 端点属 chat 数据（message_blocks token 求和 / prompt 拼装），归 ChatHandler。
type ConversationHandler struct {
	svc *conversationapp.Service
	log *zap.Logger
}

// NewConversationHandler constructs the handler.
//
// NewConversationHandler 构造 handler。
func NewConversationHandler(svc *conversationapp.Service, log *zap.Logger) *ConversationHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &ConversationHandler{svc: svc, log: log.Named("handlers.conversation")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *ConversationHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/conversations", h.Create)
	mux.HandleFunc("GET /api/v1/conversations", h.List)
	mux.HandleFunc("GET /api/v1/conversations/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/conversations/{id}", h.Update)
	mux.HandleFunc("DELETE /api/v1/conversations/{id}", h.Delete)
}

type createConversationRequest struct {
	Title string `json:"title"`
}

// updateConversationRequest uses pointer fields so absent vs explicit values stay distinct.
// hasModelOverride records whether the modelOverride key was present at all (so the handler can
// tell "leave unchanged" from "explicitly set to null").
//
// updateConversationRequest 用指针字段区分「未传」与「显式传值」。hasModelOverride 记录
// modelOverride key 是否出现（区分「不动」与「显式 null 清除」）。
type updateConversationRequest struct {
	Title             *string                            `json:"title,omitempty"`
	SystemPrompt      *string                            `json:"systemPrompt,omitempty"`
	AttachedDocuments *[]documentdomain.AttachedDocument `json:"attachedDocuments,omitempty"`
	Archived          *bool                              `json:"archived,omitempty"`
	Pinned            *bool                              `json:"pinned,omitempty"`
	ModelOverride     *modeldomain.ModelRef              `json:"modelOverride,omitempty"`
	hasModelOverride  bool
}

// UnmarshalJSON detects whether `modelOverride` was present as a key (vs absent), to distinguish
// "leave unchanged" from "explicitly clear to null" — the tristate the per-thread override needs.
//
// UnmarshalJSON 探测 `modelOverride` 是否在 JSON 中出现（区分「不动」与「显式 null 清除」）——
// 即线程级 override 需要的三态。
func (r *updateConversationRequest) UnmarshalJSON(data []byte) error {
	type raw updateConversationRequest
	if err := json.Unmarshal(data, (*raw)(r)); err != nil {
		return err
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(data, &m); err == nil {
		_, r.hasModelOverride = m["modelOverride"]
	}
	return nil
}

func (h *ConversationHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createConversationRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	c, err := h.svc.Create(r.Context(), req.Title)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, c)
}

func (h *ConversationHandler) List(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// archived: absent = exclude archived (default); "true"/"1" = archived only; else = active only.
	// archived：缺省 = 排除已归档；"true"/"1" = 仅归档；其余 = 仅活跃。
	var archived *bool
	if v := q.Get("archived"); v != "" {
		b := v == "true" || v == "1"
		archived = &b
	}
	// sort: "created" = pinned-first then creation order; anything else (incl absent) = "activity"
	// (pinned-first then most-recently-active, the default). Switching sort resets pagination.
	// sort："created" = 置顶优先再创建序；其余（含缺省）= "activity"（置顶优先再最近活跃，默认）。切换排序须重置分页。
	items, next, err := h.svc.List(r.Context(), conversationdomain.ListFilter{
		Cursor:   p.Cursor,
		Limit:    p.Limit,
		Search:   q.Get("search"),
		Archived: archived,
		Sort:     conversationdomain.ListSort(q.Get("sort")),
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

func (h *ConversationHandler) Get(w http.ResponseWriter, r *http.Request) {
	c, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

// Update is a partial-update PATCH; modelOverride is tristate (absent / null=clear / object=set).
//
// Update 是部分更新 PATCH；modelOverride 三态（缺 / null=清除 / object=设置）。
func (h *ConversationHandler) Update(w http.ResponseWriter, r *http.Request) {
	var req updateConversationRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	in := conversationapp.UpdateInput{
		Title:             req.Title,
		SystemPrompt:      req.SystemPrompt,
		AttachedDocuments: req.AttachedDocuments,
		Archived:          req.Archived,
		Pinned:            req.Pinned,
	}
	if req.hasModelOverride {
		in.ModelOverride = &req.ModelOverride // **ModelRef tristate; req.ModelOverride nil = clear
	}
	c, err := h.svc.Update(r.Context(), r.PathValue("id"), in)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

func (h *ConversationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
