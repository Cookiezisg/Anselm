// Package handlers — voice: the cloned-voice management face (WRK-082 H9). Two operations, both
// the user's: see what is enrolled, and free a slot. Enrollment is NOT here — it is a tool call,
// because it needs a source attachment and an LLM's judgement about which clip to use.
//
// handlers — voice:克隆音色的管理面(H9)。两个操作,都是用户的:看有什么、腾一个位。**登记不在这里**
// ——它是一次工具调用,因为它需要一个源附件、以及 LLM 对「用哪一段」的判断。
package handlers

import (
	"net/http"

	"go.uber.org/zap"

	generatetool "github.com/sunweilin/anselm/backend/internal/app/tool/generate"
	voiceapp "github.com/sunweilin/anselm/backend/internal/app/voice"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// VoiceHandler serves the voice list and delete.
//
// VoiceHandler 提供音色列表与删除。
type VoiceHandler struct {
	svc *voiceapp.Service
	log *zap.Logger
}

// NewVoiceHandler constructs the handler.
//
// NewVoiceHandler 构造 handler。
func NewVoiceHandler(svc *voiceapp.Service, log *zap.Logger) *VoiceHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &VoiceHandler{svc: svc, log: log.Named("handlers.voice")}
}

// Register mounts the routes.
//
// Register 挂载路由。
func (h *VoiceHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/voices", h.List)
	mux.HandleFunc("DELETE /api/v1/voices/{id}", h.Delete)
}

// List returns every enrolled voice plus the inventory arithmetic. `capacity` and `remaining` ride
// the response because the cap is the whole reason a user comes here: a list that shows two rows
// without saying "that is all of them" leaves the next enrollment's failure unexplained.
//
// **N4 exemption ①** — a bounded, enumerable resource (the cap IS the bound), so the full set comes
// back with no cursor.
//
// List 返回全部已登记音色 + 库存算术。`capacity` 与 `remaining` 随响应走,因为**上限正是用户来这里的
// 理由**:一个列出两行却不说「就这些了」的列表,会让下一次登记的失败无从解释。
//
// **N4 豁免①**——有界可枚举资源(上限**就是**那个界),故返全集、无游标。
func (h *VoiceHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.svc.List(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// A non-nil empty slice so an empty inventory serialises as [] rather than null — a client that
	// has to special-case null before it can count is a client we made write that branch.
	// 用**非 nil 的空切片**,使空库存序列化成 [] 而非 null——让客户端先判 null 才数得了数,那个分支是
	// 我们逼它写的。
	rows := make([]any, 0, len(items))
	for _, v := range items {
		rows = append(rows, v)
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{
		"items":     rows,
		"capacity":  generatetool.VoiceInventory,
		"remaining": max(0, generatetool.VoiceInventory-len(rows)),
	})
}

// Delete removes the upstream registration and then the row. An upstream failure surfaces as an
// error with the row intact — see the service for why that is not papered over.
//
// Delete 先删上游登记、再删行。上游失败会以错误暴露且行完好——为什么不糊过去,见 service。
func (h *VoiceHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
