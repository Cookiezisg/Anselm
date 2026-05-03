// answers.go — HTTP handler for delivering user answers to questions
// the AskUserQuestion tool is currently waiting on. The route lives
// under the conversation namespace because answers are conceptually a
// conversation-scoped resource (one tool_call_id per conversation
// turn), but the actual rendezvous keying is by tool_call_id.
//
// Decision D11: no separate event family for asking — the question
// itself rides chat.message SSE; this handler only closes the loop
// from user answer back to the blocked tool.
//
// answers.go — 把用户答案投递给正在等的 AskUserQuestion 工具的 HTTP
// handler。路由放在 conversation 命名空间下（答案概念上 conv-scoped），
// 但实际会合按 tool_call_id 索引。
//
// 决策 D11：问题不新建事件家族——问题本身坐 chat.message SSE；本 handler
// 只负责把用户答案闭合回阻塞的工具。
package handlers

import (
	"net/http"

	"go.uber.org/zap"

	askapp "github.com/sunweilin/forgify/backend/internal/app/ask"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// AnswerHandler serves POST /api/v1/conversations/{id}/answers.
//
// AnswerHandler 提供 POST /api/v1/conversations/{id}/answers。
type AnswerHandler struct {
	svc *askapp.Service
	log *zap.Logger
}

// NewAnswerHandler wires the handler dependencies.
//
// NewAnswerHandler 装配 handler 依赖。
func NewAnswerHandler(svc *askapp.Service, log *zap.Logger) *AnswerHandler {
	return &AnswerHandler{svc: svc, log: log}
}

// Register attaches the answer route.
//
// Register 挂载路由。
func (h *AnswerHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/conversations/{id}/answers", h.Submit)
}

// answerRequest is the POST body shape. ConversationID is taken from
// the URL path; the body only carries the tool_call_id the answer is
// for and the answer text itself.
//
// answerRequest 是 POST 体形态。ConversationID 从 URL 取；body 只带要
// 答的 tool_call_id 与答案文本。
type answerRequest struct {
	ToolCallID string `json:"toolCallId"`
	Answer     string `json:"answer"`
}

// Submit: POST /api/v1/conversations/{id}/answers → 204.
// Body: {"toolCallId": "...", "answer": "..."}.
//
// Errors:
//   - 400 INVALID_REQUEST — body missing toolCallId or answer
//   - 404 ASK_NO_PENDING_QUESTION — toolCallId not waiting (or already answered)
//
// Submit：POST /api/v1/conversations/{id}/answers → 204。
//
// 错误：400 缺字段；404 toolCallId 无 pending（或已答）。
func (h *AnswerHandler) Submit(w http.ResponseWriter, r *http.Request) {
	var req answerRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if req.ToolCallID == "" {
		responsehttpapi.Error(w, http.StatusBadRequest, "INVALID_REQUEST",
			"toolCallId is required", nil)
		return
	}
	if err := h.svc.Resolve(req.ToolCallID, req.Answer); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
