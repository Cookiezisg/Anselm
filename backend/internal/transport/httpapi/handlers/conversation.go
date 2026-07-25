package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"

	"go.uber.org/zap"

	conversationapp "github.com/sunweilin/anselm/backend/internal/app/conversation"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// ConversationHandler serves the 5 /api/v1/conversations/* CRUD endpoints plus the residency
// projection (`GET /{id}/workdir`). The tokensUsed enrichment + the system-prompt-preview endpoint are
// chat data (message_blocks token sum / prompt assembly) and live on ChatHandler, not here.
//
// ConversationHandler 提供 /api/v1/conversations/* 的 5 个 CRUD 端点 + 驻地投影（`GET /{id}/workdir`）。
// tokensUsed 富化 + system-prompt-preview 端点属 chat 数据（message_blocks token 求和 / prompt 拼装），
// 归 ChatHandler。
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
	mux.HandleFunc("GET /api/v1/conversations/{id}/workdir", h.WorkDir)
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
	// WorkDir needs no `has` companion: unlike modelOverride, its cleared value is the empty STRING, so
	// `{"workDir":""}` decodes to a non-nil pointer to "" and says "unmount" all by itself. An absent key
	// is the nil pointer = leave unchanged, as with every other field here.
	//
	// WorkDir 不需要 `has` 伴生字段:不同于 modelOverride,它清除后的值是**空字符串**,故 `{"workDir":""}`
	// 解出一个指向 "" 的非 nil 指针、它自己就说出了「退出驻地」。缺键即 nil 指针 = 不动,与此处其余字段一致。
	WorkDir *string `json:"workDir,omitempty"`
}

// UnmarshalJSON detects whether `modelOverride` was present as a key (vs absent), to distinguish
// "leave unchanged" from "explicitly clear to null" — the tristate the per-thread override needs.
// It stays STRICT (DisallowUnknownFields) like decodeJSON: this custom unmarshal shadows the
// transport's strict decoder, so without this a typo'd field (e.g. "titel") would silently no-op
// instead of a 400 — the same silent-drop inconsistency every other PATCH rejects.
//
// UnmarshalJSON 探测 `modelOverride` 是否在 JSON 中出现（区分「不动」与「显式 null 清除」）——
// 即线程级 override 需要的三态。它像 decodeJSON 一样保持**严格**（DisallowUnknownFields）:此自定义
// unmarshal 遮蔽了 transport 的严格解码器,不加则拼错的字段(如 "titel")会静默 no-op 而非 400——正是其余
// PATCH 都拒的静默丢弃不一致。
func (r *updateConversationRequest) UnmarshalJSON(data []byte) error {
	type raw updateConversationRequest
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode((*raw)(r)); err != nil {
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
	// archived: absent/else = active only (default); "true"/"1"/"archived" = archived only; "all" =
	// both (the rail's "show archived" — archived rows carry archived=true for the gray dot).
	// archived：缺省/其余 = 仅活跃（默认）；"true"/"1"/"archived" = 仅归档；"all" = 两者（rail「显示已归档」，归档行带 archived=true 供灰点）。
	var archive conversationdomain.ArchiveScope
	switch q.Get("archived") {
	case "all":
		archive = conversationdomain.ArchiveAll
	case "true", "1", "archived":
		archive = conversationdomain.ArchiveArchived
	default:
		archive = conversationdomain.ArchiveActive
	}
	// sort: "created" = pinned-first then creation order; "name" = pinned-first then title A–Z
	// (case-insensitive); anything else (incl absent) = "activity" (pinned-first then most-recently-
	// active, the default). Each sort keys its own keyset column, so switching sort MUST reset pagination.
	// sort："created" = 置顶优先再创建序；"name" = 置顶优先再 title A–Z（大小写不敏感）；其余（含缺省）= "activity"
	// （置顶优先再最近活跃，默认）。每种排序键各自的 keyset 列，故切换排序**必须重置分页**。
	items, next, err := h.svc.List(r.Context(), conversationdomain.ListFilter{
		Cursor:  p.Cursor,
		Limit:   p.Limit,
		Search:  q.Get("search"),
		Archive: archive,
		Sort:    conversationdomain.ListSort(q.Get("sort")),
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
		WorkDir:           req.WorkDir,
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

// WorkDir returns the residency's live projection for one conversation: the mounted path plus what is
// true about it right now (exists / git repo / branch / dirty). Recomputed per request and cached
// nowhere — the filesystem and git are the truth, so a directory the user just deleted, or a branch they
// just switched in their own terminal, reads as it now IS.
//
// N4: a derived BOUNDED PROJECTION, so no cursor and no `nextCursor`. It is not a stored collection at
// all — it is ONE object computed on demand, in the same class as `GET /storage-stat` rather than the
// trigger-schedule kind that takes real window parameters. It accepts NO parameters, so there is nothing
// to clamp and nothing to 422 over, and it never reports truncation.
//
// An UNMOUNTED conversation returns 200 with the zero projection (empty path, exists=false), not 404:
// "this thread has no residency" is a successful answer to the question, and the button that calls this
// has to render the unmounted state too. Only an unknown conversation is a 404.
//
// WorkDir 返回某对话驻地的活投影：已挂路径 + 此刻关于它为真的东西（存在 / 是否 git 仓库 / 分支 / 脏）。
// 逐请求现算、零缓存——文件系统与 git 才是真相，故用户刚删掉的目录、或刚在自己终端里切的分支，读作它
// **现在的样子**。
//
// N4：派生的**有界投影**，故无游标、无 `nextCursor`。它根本不是已存集合——它是**一个**按需现算的对象，与
// `GET /storage-stat` 同类，而**不是** trigger-schedule 那种收真窗口参数的一类。它**不收任何参数**，故无从
// 钳制、无从 422，也从不上报截断。
//
// **未挂**对话返 200 + 零投影（空路径、exists=false）、**不是** 404：「这条线程没有驻地」是对该问题的一个
// **成功**回答，而调用它的那个按钮也得渲染未挂态。只有对话本身不存在才是 404。
func (h *ConversationHandler) WorkDir(w http.ResponseWriter, r *http.Request) {
	info, err := h.svc.WorkDirInfo(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, info)
}

func (h *ConversationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
