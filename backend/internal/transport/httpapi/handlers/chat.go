package handlers

import (
	"net/http"

	"go.uber.org/zap"

	chatapp "github.com/sunweilin/anselm/backend/internal/app/chat"
	mentiondomain "github.com/sunweilin/anselm/backend/internal/domain/mention"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// ChatHandler serves the chat engine's 8 routes: send a message (202, streams over the messages
// SSE), list a conversation's history (paged), the conversation-level actions (:cancel / :seen →
// 204, :fork → 201 + the new thread, :retry → 202 + the new assistant turn's id), and the
// debug/usage/anchor/interaction reads. The assistant turn itself is delivered over the messages
// stream, not this REST surface.
//
// ChatHandler 提供 chat 引擎 8 条路由：发消息（202，经 messages SSE 流式）、列对话历史（分页）、对话级
// 动作（:cancel / :seen → 204，:fork → 201 + 新线程，:retry → 202 + 新 assistant 回合 id）、调试/用量/
// 锚点/交互读。assistant 回合本身经 messages 流交付、不在此 REST 面。
type ChatHandler struct {
	svc *chatapp.Service
	log *zap.Logger
}

// NewChatHandler constructs the handler.
//
// NewChatHandler 构造 handler。
func NewChatHandler(svc *chatapp.Service, log *zap.Logger) *ChatHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &ChatHandler{svc: svc, log: log.Named("handlers.chat")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *ChatHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/conversations/{id}/messages", h.Send)
	mux.HandleFunc("GET /api/v1/conversations/{id}/messages", h.List)
	mux.HandleFunc("POST /api/v1/conversations/{idAction}", h.postAction) // :cancel / :seen / :fork / :retry(N5 动作后缀)
	mux.HandleFunc("GET /api/v1/conversations/{id}/system-prompt-preview", h.SystemPromptPreview)
	mux.HandleFunc("GET /api/v1/conversations/{id}/usage", h.Usage)
	mux.HandleFunc("GET /api/v1/conversations/{id}/interactions", h.ListInteractions)
	mux.HandleFunc("POST /api/v1/conversations/{id}/interactions/{toolCallId}", h.ResolveInteraction)
	mux.HandleFunc("GET /api/v1/conversations/{id}/anchors", h.Anchors)
}

// sendMessageRequest is the user turn: text + referenced attachments + @-mentions.
//
// sendMessageRequest 是用户回合：文本 + 引用附件 + @ mention。
type sendMessageRequest struct {
	Content       string                       `json:"content"`
	AttachmentIDs []string                     `json:"attachmentIds"`
	Mentions      []mentiondomain.MentionInput `json:"mentions"`
}

// Send accepts a user turn and starts the generation: 202 Accepted + the assistant message id;
// the turn streams over the messages SSE. EMPTY_CONTENT (400) / STREAM_IN_PROGRESS (409) bubble
// from the service.
//
// Send 接受用户回合并启动生成：202 Accepted + assistant message id；回合经 messages SSE 流式。
// EMPTY_CONTENT (400) / STREAM_IN_PROGRESS (409) 从 service 冒泡。
func (h *ChatHandler) Send(w http.ResponseWriter, r *http.Request) {
	var req sendMessageRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	msgID, err := h.svc.Send(r.Context(), r.PathValue("id"), chatapp.SendInput{
		Content:       req.Content,
		AttachmentIDs: req.AttachmentIDs,
		Mentions:      req.Mentions,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusAccepted, map[string]string{"id": msgID}) // 异步动作返新资源 id 统一 {id}
}

// List returns one keyset page of the conversation's history (newest-first), each message with
// its blocks. N4 pagination via ?cursor & ?limit. Two extra query forms share the route:
// ?around=<messageId> opens a deep-jump window centered on the target (bidirectional coordinates
// in a window envelope; around is mutually exclusive with cursor and dir — only one read form
// may be requested at a time), and ?dir=newer walks a cursor FORWARD in time (the window's
// newerCursor continuation; requires a cursor). Every form keeps the same newest-first data
// ordering — one rule, no direction-dependent reversals on the wire.
//
// List 返回对话历史的一页 keyset（最新在前），每条带 blocks。N4 分页经 ?cursor & ?limit。同路由
// 另有两种查询形态：?around=<messageId> 开以目标为中心的深跳窗（窗 envelope 带双向坐标；around 与
// cursor、dir **互斥**——一次只可请求一种读形态），?dir=newer 让 cursor 沿时间**向前**走（窗口
// newerCursor 的续翻；必须带 cursor）。所有形态保持同一 newest-first 排序——单一规则，线缆无随
// 方向反转。
func (h *ChatHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	q := r.URL.Query()
	around, dir := q.Get("around"), q.Get("dir")
	if around != "" {
		if p.Cursor != "" || dir != "" {
			// The shared INVALID_REQUEST sentinel (wire codes are globally unique; the message detail
			// rides details). 共享 sentinel(线缆码全局唯一;具体原因走 details)。
			responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrInvalidRequest.WithDetails(
				map[string]any{"reason": "around is mutually exclusive with cursor and dir"}))
			return
		}
		win, err := h.svc.MessagesAround(r.Context(), r.PathValue("id"), around, p.Limit)
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		responsehttpapi.Window(w, win.Messages, win.TargetID, win.OlderCursor, win.NewerCursor, win.HasOlder, win.HasNewer)
		return
	}
	switch dir {
	case "", "older":
		items, next, err := h.svc.ListMessages(r.Context(), r.PathValue("id"), p.Cursor, p.Limit)
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		responsehttpapi.Paged(w, items, next, next != "")
	case "newer":
		items, next, err := h.svc.ListMessagesNewer(r.Context(), r.PathValue("id"), p.Cursor, p.Limit)
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		responsehttpapi.Paged(w, items, next, next != "")
	default:
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrInvalidRequest.WithDetails(
			map[string]any{"reason": "dir must be omitted, 'older' or 'newer'"}))
	}
}

// Anchors returns one keyset page of the conversation's navigation anchors (场次条), newest-first
// — user turns (first-line excerpt), folded machine-action clusters, dangerous tool calls,
// compaction marks, abnormal terminal turns; pending human gates ride the first page's top
// (live broker state, outside the keyset). N4 pagination via ?cursor & ?limit.
//
// Anchors 返回对话导航锚点（场次条）的一页 keyset（最新在前）——user 回合（首行节选）、折叠的机器
// 动作簇、危险工具调用、压缩标记、异常终态回合；待决人闸骑首页顶（broker 活状态、keyset 之外）。
// N4 分页经 ?cursor & ?limit。
func (h *ChatHandler) Anchors(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	items, next, err := h.svc.ListAnchors(r.Context(), r.PathValue("id"), p.Cursor, p.Limit)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

// forkConversationRequest is the fork's cut point. Optional: an omitted / empty atMessageId forks
// at the latest message (the rail's "fork this conversation", which has no message id at hand).
//
// forkConversationRequest 是分叉的切点。可选：缺省 / 空 atMessageId 表示从最新消息处分叉（左岛 rail
// 的「分叉对话」，它手上没有 message id）。
type forkConversationRequest struct {
	AtMessageID string `json:"atMessageId"`
}

// retryConversationRequest is the two-branch retry payload. Both fields are optional: an absent /
// empty content is REGENERATE (answer the same question again), a non-empty one is EDIT-RESEND (replace
// the question too). modelOverride is a plain pointer, NOT the PATCH tristate — retry has no "clear"
// case to express, because absent already means "use whatever this thread is set to".
//
// retryConversationRequest 是重试的两分支载荷。两个字段都可选：content 缺省/空 = **重生成**（把同一个问题再答
// 一次），非空 = **编辑重发**（连问题一起换）。modelOverride 是**朴素指针、非** PATCH 那个三态——重试没有「清除」
// 这一格要表达，因为「缺席」本就意味着「用这条线程现有的设置」。
type retryConversationRequest struct {
	Content       string                `json:"content"`
	ModelOverride *modeldomain.ModelRef `json:"modelOverride,omitempty"`
}

// postAction dispatches the conversation-level :action POSTs that share the {idAction} pattern
// (Go 1.22 ServeMux allows ONE handler per pattern, so :cancel / :seen / :fork / :retry are switched
// here rather than registered as separate routes). :cancel and :seen return 204 and fall through to the
// shared tail; :fork returns 201 + the new Conversation and :retry returns 202 + the new assistant
// message id, so both return early. An unknown action is 404.
//
// postAction 派发共享 {idAction} 模式的对话级 :action（Go 1.22 ServeMux 每模式仅一处理器，故 :cancel /
// :seen / :fork / :retry 在此 switch、而非各注册一条路由）。:cancel 与 :seen 返 204、走共享尾；:fork 返 201 +
// 新 Conversation、:retry 返 202 + 新 assistant message id，故两者都提前 return。未知动作 404。
func (h *ChatHandler) postAction(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok {
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
		return
	}
	switch action {
	case "fork":
		// Fork branches the thread into a NEW conversation carrying the prefix through atMessageId
		// (inclusive); the source is untouched. 201 + the new Conversation — a fork is a resource the
		// client navigates to, so it ships the whole row rather than a bare id (no async turn to await,
		// unlike the 202 {id} spawners).
		// Fork 把线程分叉成一条**新**对话、承载直到 atMessageId（含）的前缀；源分毫不动。201 + 新
		// Conversation——分叉是客户端要导航过去的资源，故直接给整行、而非裸 id（与 202 {id} 那些 spawner
		// 不同，这里没有异步回合要等）。
		var req forkConversationRequest
		if err := decodeJSONOptional(r, &req); err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		fork, err := h.svc.Fork(r.Context(), id, req.AtMessageID)
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		responsehttpapi.Created(w, fork)
		return
	case "retry":
		// Retry replaces the conversation's last round with a NEW VERSION and streams it over the
		// messages SSE, so it answers exactly as Send does: 202 + the new assistant message id. The old
		// version is not deleted — it gets a superseded_by pointer and keeps coming back from all three
		// read forms, which is what the UI's version pager reads. 409 STREAM_IN_PROGRESS when the last
		// round has not settled; 404 MESSAGE_NOT_FOUND when there is no round to retry.
		// Retry 把对话的末回合换成一个**新版本**并经 messages SSE 推流，故它的应答与 Send 完全一样：202 + 新
		// assistant message id。旧版**不删**——它被写上 superseded_by 指针、并照常从三种读形态返回，那正是 UI
		// 版本翻页所读。末回合未落定 → 409 STREAM_IN_PROGRESS；无回合可重试 → 404 MESSAGE_NOT_FOUND。
		var req retryConversationRequest
		if err := decodeJSONOptional(r, &req); err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		msgID, err := h.svc.Retry(r.Context(), id, chatapp.RetryInput{
			Content:       req.Content,
			ModelOverride: req.ModelOverride,
		})
		if err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
		responsehttpapi.Success(w, http.StatusAccepted, map[string]string{"id": msgID}) // 异步动作返新资源 id 统一 {id}
		return
	case "cancel":
		// Cancel stops the conversation's running turn (204). Graceful no-op when nothing runs.
		// Cancel 停止对话运行中的回合（204）。无运行回合时优雅 no-op。
		if err := h.svc.Cancel(r.Context(), id); err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
	case "seen":
		// Seen clears the unread flag (the user opened the thread). Idempotent (204) — a no-op on an
		// unknown id, since the client only :seens a thread it is currently viewing.
		// Seen 清未读标志（用户打开了线程）。幂等（204）——未知 id 上 no-op，因客户端只对正在看的线程 :seen。
		if err := h.svc.MarkSeen(r.Context(), id); err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
	default:
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
		return
	}
	responsehttpapi.NoContent(w)
}

// SystemPromptPreview returns the system prompt a turn in this conversation would receive — a
// transparency / debugging aid.
//
// SystemPromptPreview 返回本对话一个回合会收到的 system prompt——透明度 / 调试辅助。
func (h *ChatHandler) SystemPromptPreview(w http.ResponseWriter, r *http.Request) {
	prompt, err := h.svc.SystemPromptPreview(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]string{"systemPrompt": prompt})
}

// ListInteractions returns the human interactions this conversation is currently awaiting — the
// front end's reconnect/refresh re-sync (the live surface signal is ephemeral). The service checks
// conversation ownership first, so a foreign or nonexistent id is an honest 404.
//
// ListInteractions 返回本对话当前在等的人机交互——前端重连/刷新的重新同步（live surface signal 是 ephemeral）。
// service 先校验对话归属，跨 workspace 或不存在的 id 诚实返回 404。
func (h *ChatHandler) ListInteractions(w http.ResponseWriter, r *http.Request) {
	interactions, err := h.svc.ListInteractions(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, interactions)
}

// ResolveInteraction delivers a human decision (approve / approve_always / deny / accept / decline) to
// a tool blocked awaiting input in this conversation. The conversation is first ownership-checked against the
// current workspace; a foreign or nonexistent conversation is 404 CONVERSATION_NOT_FOUND, while a mismatched or
// unknown tool-call id in a known conversation is 404 NO_PENDING_INTERACTION. 204 (pure state change, no new product; the gated
// tool resuming + streaming over the messages SSE is an async side effect, not the HTTP response).
// An out-of-enum action → 422 INTERACTION_INVALID_ACTION; nothing waiting on that tool_call → 404
// NO_PENDING_INTERACTION.
//
// ResolveInteraction 把人的决定（approve / approve_always / deny / accept / decline）送给本对话中阻塞等输入的
// 工具。先校验对话属于当前 workspace；跨 workspace/不存在会话为 404 CONVERSATION_NOT_FOUND，已知会话中
// tool-call id 不匹配或未知才是 404 NO_PENDING_INTERACTION。204（纯状态变更、无新产物；
// 被门工具续跑 + 经 messages SSE 流式是异步副作用、非 HTTP 响应）。枚举外 action
// → 422 INTERACTION_INVALID_ACTION；该 tool_call 无等待项则 404 NO_PENDING_INTERACTION。
func (h *ChatHandler) ResolveInteraction(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Action string `json:"action"` // approve | approve_always | deny | accept | decline
		Answer string `json:"answer"` // ask accept: the user's answer
	}
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if err := h.svc.ResolveInteraction(r.Context(), r.PathValue("id"), r.PathValue("toolCallId"), req.Action, req.Answer); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w) // 纯状态变更、无新产物
}

// Usage returns a conversation's total token cost for API consumers.
//
// Usage 返回一个对话的 token 总成本，供 API 调用方读取。
func (h *ChatHandler) Usage(w http.ResponseWriter, r *http.Request) {
	in, out, err := h.svc.Usage(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]int{
		"inputTokens":  in,
		"outputTokens": out,
		"totalTokens":  in + out,
	})
}
