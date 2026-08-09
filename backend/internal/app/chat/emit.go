package chat

import (
	"context"

	"go.uber.org/zap"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
)

// nodeTypeMessage is the messages-stream node type for a whole conversation turn — the parent
// under which loop's block nodes (text / reasoning / tool_call / tool_result) nest. message_start
// is its Open, message_stop its Close (carrying the turn's terminal metadata + token accounting).
// loop emits the block vocabulary; chat emits this one message-level type.
//
// nodeTypeMessage 是一整个对话回合的 messages 流节点类型——loop 的 block 节点（text / reasoning /
// tool_call / tool_result）嵌在其下的父节点。message_start 是它的 Open、message_stop 是 Close
// （带回合终态元数据 + token 记账）。loop 发 block 词表；chat 发这一个 message 级类型。
const nodeTypeMessage = "message"

// messageOpenContent rides message_start: the role, so the front end can render the right bubble
// before any block streams in, plus RetryOf when this turn is a new VERSION of an earlier one
// (WRK-077 CH-c). The pointer travels on the existing message node's content — no new frame type, no
// new stream (E1/E2) — because a client that did NOT initiate the retry has no other way to learn that
// the arriving turn replaces one already on screen rather than following it.
//
// messageOpenContent 随 message_start：带 role，使前端在任何 block 流入前就能渲对的气泡；当本回合是更早
// 某回合的**新版本**时另带 RetryOf（WRK-077 CH-c）。指针搭在**既有** message 节点的 content 上——不加新帧
// 型、不加新流（E1/E2）——因为一个**不是**发起方的客户端没有别的办法知道：正在到来的这个回合是**取代**屏幕
// 上已有的那一条、而不是接在它后面。
type messageOpenContent struct {
	Role    string `json:"role"`
	RetryOf string `json:"retryOf,omitempty"`
}

// messageUserContent is the user turn's close snapshot — the echoed text (+ attachment ids) the
// front end renders the user bubble from, without re-fetching.
//
// messageUserContent 是 user 回合的 close 快照——前端据此渲用户气泡的回显文本（+ 附件 id），无需回取。
type messageUserContent struct {
	Role          string   `json:"role"`
	Content       string   `json:"content"`
	AttachmentIDs []string `json:"attachmentIds,omitempty"`
	RetryOf       string   `json:"retryOf,omitempty"` // 编辑重发：本句取代的那条 user 回合（见 messageOpenContent）
}

// messageStopContent is the assistant turn's close snapshot: terminal status + stop reason +
// token accounting (turn metadata — deliberately NOT in any block snapshot). The front end ends
// the streaming bubble and shows the token cost from this.
//
// It repeats RetryOf from [messageOpenContent] because a Close is the DURABLE frame and its snapshot is
// the replay truth (E2): a client that missed the open — replay after a 410, a window that connected
// mid-turn, any reconnect — rebuilds the node from this alone, and clients replace content wholesale
// from it. Without the pointer here, such a client is told the turn FOLLOWS the one above it when it
// REPLACES it: it renders both versions as consecutive rounds, one question answered twice, no version
// pager (WRK-083 L6). The store side has the same shape and the same repeat — runner.go re-seeds Attrs
// because WriteFinalize writes them wholesale.
//
// messageStopContent 是 assistant 回合的 close 快照：终态 + stop reason + token 记账（回合元数据
// ——刻意不进任何 block 快照）。前端据此结束流式气泡并显示 token 成本。
//
// 它**重复** [messageOpenContent] 的 RetryOf，因为 Close 是 durable 帧、其快照即 replay 真相（E2）：错过 open 的
// 客户端——410 后 replay、中途连上的窗口、任何重连——只凭这一份重建节点，且客户端从它**整体覆写** content。这里
// 缺了指针，这类客户端就被告知本回合**接在**上面那条后面，而真相是**取代**它：两个版本被渲成连续两轮、同一个问题
// 答两遍、没有版本翻页（WRK-083 L6）。库那侧形状相同、重复也相同——runner.go 因 WriteFinalize 整体写 Attrs 而
// 重新种一次。
type messageStopContent struct {
	Role         string `json:"role"`
	Status       string `json:"status"`
	StopReason   string `json:"stopReason,omitempty"`
	InputTokens  int    `json:"inputTokens"`
	OutputTokens int    `json:"outputTokens"`
	ErrorCode    string `json:"errorCode,omitempty"`
	ErrorMessage string `json:"errorMessage,omitempty"`
	RetryOf      string `json:"retryOf,omitempty"`
}

// emitUserMessage echoes a complete user turn as one message node (Open then Close) so every
// connected client sees it immediately. No-op when no bridge is wired (REST history still has it).
//
// emitUserMessage 把一个完整 user 回合作为一个 message 节点回显（Open 后 Close），使每个连接的
// 客户端立即看到。无 bridge 时 no-op（REST 历史仍有）。
func (s *Service) emitUserMessage(ctx context.Context, conversationID string, m *messagesdomain.Message, text string) {
	s.publishFrame(ctx, conversationID, m.ID, streamdomain.Open{
		Node: streamdomain.Node{Type: nodeTypeMessage, Content: streamdomain.JSONContent(
			messageOpenContent{Role: messagesdomain.RoleUser, RetryOf: retryOfOf(m)},
		)},
	})
	s.publishFrame(ctx, conversationID, m.ID, streamdomain.Close{
		Status: messagesdomain.StatusCompleted,
		Result: &streamdomain.Node{
			Type: nodeTypeMessage,
			Content: streamdomain.JSONContent(messageUserContent{
				Role: messagesdomain.RoleUser, Content: text,
				AttachmentIDs: attachmentIDsOf(m), RetryOf: retryOfOf(m),
			}),
		},
	})
}

// emitMessageStart opens the assistant turn's message node; loop then nests its block nodes
// under the message id (their Open.ParentID = that id). It takes the whole row rather than the id so
// the version pointer has exactly one home — Attrs — read the same way here and by the REST projection.
//
// emitMessageStart 开 assistant 回合的 message 节点；loop 随后把 block 节点嵌在该 id 下（其
// Open.ParentID = 该 id）。它收整行而非 id，使版本指针只有一个家——Attrs——此处与 REST 投影同款读法。
func (s *Service) emitMessageStart(ctx context.Context, conversationID string, m *messagesdomain.Message) {
	s.publishFrame(ctx, conversationID, m.ID, streamdomain.Open{
		Node: streamdomain.Node{Type: nodeTypeMessage, Content: streamdomain.JSONContent(
			messageOpenContent{Role: messagesdomain.RoleAssistant, RetryOf: retryOfOf(m)})},
	})
}

// retryOfOf reads the version pointer Retry snapshotted into Message.Attrs. Attrs survives a JSON
// round-trip through the store, so the value is a plain string either way; a missing key (every
// ordinary turn) is "".
//
// retryOfOf 读 Retry 快照进 Message.Attrs 的版本指针。Attrs 经 store 走一趟 JSON 往返，两种情形下值都是
// 纯字符串；键缺失（所有普通回合）即 ""。
func retryOfOf(m *messagesdomain.Message) string {
	s, _ := m.Attrs[messagesdomain.AttrRetryOf].(string)
	return s
}

// emitMessageStop closes the assistant turn's message node with its terminal metadata — the
// final frame of a generation. The Close.Result snapshot is the reconnect truth for the turn's
// status + token cost.
//
// emitMessageStop 用终态元数据关 assistant 回合的 message 节点——一次生成的最后一帧。Close.Result
// 快照是回合状态 + token 成本的重连真相。
func (s *Service) emitMessageStop(ctx context.Context, conversationID string, m *messagesdomain.Message) {
	s.publishFrame(ctx, conversationID, m.ID, streamdomain.Close{
		Status: m.Status,
		Error:  m.ErrorMessage,
		Result: &streamdomain.Node{
			Type: nodeTypeMessage,
			Content: streamdomain.JSONContent(messageStopContent{
				Role:         messagesdomain.RoleAssistant,
				Status:       m.Status,
				StopReason:   m.StopReason,
				InputTokens:  m.InputTokens,
				OutputTokens: m.OutputTokens,
				ErrorCode:    m.ErrorCode,
				ErrorMessage: m.ErrorMessage,
				RetryOf:      retryOfOf(m),
			}),
		},
	})
}

// publishFrame pushes one frame for a node anchored at conversation:<id>. best-effort: no bridge
// → skip; a failed push is recovered by SSE replay + REST history, so it never fails the turn.
//
// publishFrame 推一帧到锚在 conversation:<id> 的节点。best-effort：无 bridge → 跳过；推送失败由
// SSE replay + REST 历史兜回，故绝不让回合失败。
func (s *Service) publishFrame(ctx context.Context, conversationID, nodeID string, frame streamdomain.Frame) {
	if s.deps.Bridge == nil {
		return
	}
	if _, err := s.deps.Bridge.Publish(ctx, streamdomain.Event{
		Scope: streamdomain.Scope{Kind: streamdomain.KindConversation, ID: conversationID},
		ID:    nodeID,
		Frame: frame,
	}); err != nil {
		s.log.Warn("chatapp: messages stream push failed", zap.String("nodeId", nodeID), zap.Error(err))
	}
}
