package chat

import (
	"context"

	humanloopapp "github.com/sunweilin/anselm/backend/internal/app/humanloop"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// nodeTypeInteraction is the messages-stream node type for a pending human interaction: an
// ephemeral signal carrying the humanloop.Request so the front end renders the prompt (a danger
// approve/deny, or an ask_user question) inline under the conversation.
//
// nodeTypeInteraction 是一条待决人机交互的 messages 流节点类型：一条 ephemeral signal 承载
// humanloop.Request，使前端在对话内联渲提示（danger 批准/拒绝，或 ask_user 提问）。
const nodeTypeInteraction = "interaction"

// ErrNoPendingInteraction is returned when a resolve targets a tool_call that isn't awaiting a
// human decision (unknown id, or already resolved — a double POST is a safe no-op).
//
// ErrNoPendingInteraction 在 resolve 指向一个并未在等人决定的 tool_call 时返回（未知 id，或已决议——重复 POST
// 安全 no-op）。
var ErrNoPendingInteraction = errorspkg.New(errorspkg.KindNotFound, "NO_PENDING_INTERACTION", "no pending interaction with that tool call id in this conversation")

// ErrInvalidInteractionAction rejects a resolve carrying an action outside the closed decision set
// (F168 family: out-of-enum → 422 with the valid set, never a silent misinterpretation). The loop's
// gate is fail-safe — anything not approve/approve_always/accept is a denial — so a typo'd "aprove"
// would SILENTLY deny a dangerous tool the user meant to approve; we reject it loudly instead. The
// kind (danger vs ask) is still the loop's to interpret; this only guards against garbage.
//
// ErrInvalidInteractionAction 拒绝携带封闭决策集之外 action 的 resolve（F168 族：枚举外 → 422 带合法集,
// 绝不静默误读）。loop 的门是 fail-safe——非 approve/approve_always/accept 一律拒——故拼错的 "aprove" 会
// **静默拒掉**用户本想批准的危险工具;我们改为大声拒。kind(danger vs ask)仍由 loop 解读,这里只拦垃圾。
var ErrInvalidInteractionAction = errorspkg.New(errorspkg.KindUnprocessable, "INTERACTION_INVALID_ACTION",
	"action must be one of: approve, approve_always, deny, accept, decline").
	WithDetails(map[string]any{"validActions": []string{
		humanloopapp.DecisionApprove, humanloopapp.DecisionApproveAlways, humanloopapp.DecisionDeny,
		humanloopapp.DecisionAccept, humanloopapp.DecisionDecline,
	}})

// validInteractionActions is the closed decision set (mirrors humanloop's Decision* constants).
// validInteractionActions 是封闭决策集（镜像 humanloop 的 Decision* 常量）。
var validInteractionActions = map[string]bool{
	humanloopapp.DecisionApprove: true, humanloopapp.DecisionApproveAlways: true,
	humanloopapp.DecisionDeny: true, humanloopapp.DecisionAccept: true, humanloopapp.DecisionDecline: true,
}

// interactionSurface is the humanloop.Surface chat injects into its broker: it pushes an EPHEMERAL
// interaction signal on the messages stream (conversation scope, keyed by the tool_call id) so a
// connected front end shows the prompt the instant a tool blocks. Ephemeral by design — a
// reconnecting client re-syncs via GET .../interactions (the broker's pending map is the truth);
// resolution is signalled by the tool_result block streaming in under the same tool_call.
//
// interactionSurface 是 chat 注入 broker 的 humanloop.Surface：它在 messages 流推一条 **ephemeral** interaction
// signal（对话 scope，按 tool_call id 键），使连接的前端在工具一阻塞就显示提示。刻意 ephemeral——重连客户端经
// GET .../interactions 重新同步（broker 的 pending 表是真相）；决议由同一 tool_call 下流入的 tool_result 块标示。
func (s *Service) interactionSurface(ctx context.Context, req humanloopapp.Request) {
	s.publishFrame(ctx, req.ConversationID, req.ToolCallID, streamdomain.Signal{
		Node:      streamdomain.Node{Type: nodeTypeInteraction, Content: streamdomain.JSONContent(req)},
		Ephemeral: true,
	})
}

// ResolveInteraction delivers a human decision to a tool/ask blocked in this conversation. It hands
// the decision to the broker — the gated tool / ask_user, blocked inside the running turn's goroutine,
// wakes and interprets it (approve runs the tool; deny / decline feed back; approve_always also
// session-whitelists) — then mirrors the pending signal with a resolved one so the front end clears
// the prompt + the conversation's awaiting-input rail dot without reverse-inferring from the
// tool_result. Returns ErrNoPendingInteraction if nothing is waiting.
//
// ResolveInteraction 把人的决定送给本对话中阻塞的工具/ask。它把决定交给 broker——被门工具 / ask_user 阻塞在运行
// 回合的 goroutine 里，醒来并解读它（approve 跑工具；deny / decline 反馈；approve_always 还会话白名单）——再镜像
// pending 信号发一条 resolved，使前端清提示 + 会话 awaiting rail 点而不靠 tool_result 反推。无等待项则返 ErrNoPendingInteraction。
func (s *Service) ResolveInteraction(ctx context.Context, conversationID, toolCallID, action, answer string) error {
	if !validInteractionActions[action] {
		return ErrInvalidInteractionAction
	}
	if s.broker == nil || !s.broker.Resolve(toolCallID, humanloopapp.Response{Action: action, Answer: answer}) {
		return ErrNoPendingInteraction
	}
	// Symmetric ephemeral "interaction cleared" signal (same scope + node.type, resolved:true).
	// 对称 ephemeral「交互已清」信号（同 scope + node.type、resolved:true）。
	s.publishFrame(ctx, conversationID, toolCallID, streamdomain.Signal{
		Node: streamdomain.Node{
			Type:    nodeTypeInteraction,
			Content: streamdomain.JSONContent(humanloopapp.Request{ToolCallID: toolCallID, ConversationID: conversationID, Resolved: true}),
		},
		Ephemeral: true,
	})
	return nil
}

// PendingInteractions lists the interactions a conversation is currently awaiting — the front
// end's reconnect/refresh re-sync (the broker's in-memory map is the source of truth, since the
// surface signal is ephemeral). Empty slice when none.
//
// PendingInteractions 列出一个对话当前在等的交互——前端重连/刷新的重新同步（broker 内存表是真相源，因 surface
// signal 是 ephemeral）。无则空切片。
func (s *Service) PendingInteractions(_ context.Context, conversationID string) []humanloopapp.Request {
	if s.broker == nil {
		return nil
	}
	return s.broker.Pending(conversationID)
}

// HasAwaitingInteraction reports whether a conversation has ≥1 pending human interaction — the
// conversation list's per-row AwaitingInput derive (chatapp satisfies conversationapp's
// AwaitingInputQuerier). A cheap broker short-circuit; nil broker → false.
//
// HasAwaitingInteraction 报告某对话是否有 ≥1 个待决人机交互——会话列表逐行 AwaitingInput 派生（chatapp 满足
// conversationapp 的 AwaitingInputQuerier）。廉价 broker 短路；nil broker → false。
func (s *Service) HasAwaitingInteraction(conversationID string) bool {
	return s.broker != nil && s.broker.HasPending(conversationID)
}
