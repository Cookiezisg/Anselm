package handlers

import (
	"net/http"

	"go.uber.org/zap"

	aispawnapp "github.com/sunweilin/forgify/backend/internal/app/aispawn"
	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// iterateEntity is the shared `:iterate` body for every forge entity (R0065): decode the user's
// change request, spawn an AI iterate conversation seeded with this entity (@-mentioned, so its
// current definition is frozen in), and return the new conversation id (202 — the turn streams over
// the messages SSE). Each entity handler calls this from its action dispatcher with its own
// mention type; there is no per-entity logic.
//
// iterateEntity 是每个 forge 实体共享的 `:iterate` 主体（R0065）：解码用户的修改诉求、开一个以本实体为种子（@-mention、
// 当前定义冻结进来）的 AI 迭代对话、返回新对话 id（202——回合经 messages SSE 流式）。各实体 handler 从其 action 分发口
// 用自己的 mention 类型调它；无 per-entity 逻辑。
func iterateEntity(w http.ResponseWriter, r *http.Request, log *zap.Logger, svc *aispawnapp.Service, mentionType mentiondomain.MentionType, id string) {
	var req struct {
		Request string `json:"request"` // what the user wants changed
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, log, err)
		return
	}
	convID, err := svc.Iterate(r.Context(), mentionType, id, req.Request)
	if err != nil {
		responsehttpapi.FromDomainError(w, log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusAccepted, map[string]string{"conversationId": convID})
}

// TriageHandler serves the universal `:triage` verb (R0065): diagnose ANY execution record, not
// just a workflow run. The unified `/executions/{id}:triage` collection dispatches by the id's
// prefix (function / handler / agent / flowrun execution) inside aispawn's renderer.
//
// TriageHandler 提供通用 `:triage` 动词（R0065）：诊断**任意**执行记录、不只工作流运行。统一的
// `/executions/{id}:triage` 集合按 id 前缀（function/handler/agent/flowrun 执行）在 aispawn 渲染器内分发。
type TriageHandler struct {
	svc *aispawnapp.Service
	log *zap.Logger
}

func NewTriageHandler(svc *aispawnapp.Service, log *zap.Logger) *TriageHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &TriageHandler{svc: svc, log: log.Named("handlers.triage")}
}

func (h *TriageHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/executions/{idAction}", h.post)
}

// post dispatches POST /executions/{execId}:triage — opens an AI diagnosis conversation for the
// execution and returns its id (202; the turn streams over the messages SSE).
//
// post 派发 POST /executions/{execId}:triage——为该执行开一个 AI 诊断对话、返回其 id（202；回合经 messages SSE 流式）。
func (h *TriageHandler) post(w http.ResponseWriter, r *http.Request) {
	execID, action, ok := idAndAction(r, "idAction")
	if !ok || action != "triage" {
		http.NotFound(w, r)
		return
	}
	var req struct {
		Note string `json:"note"` // optional: what the user wants help understanding
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	convID, err := h.svc.Triage(r.Context(), execID, req.Note)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusAccepted, map[string]string{"conversationId": convID})
}
