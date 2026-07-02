// The conversation-ledger tap on the USER side of a turn: Send is where @-mentions and
// attachments enter the thread, so it books them as `mentioned` / `attached` touches (actor
// user, anchored to the user message). The AI side records at the loop's tool choke point —
// together the two taps cover everything a conversation touches.
//
// 对话台账在回合**用户侧**的水龙头:@ 提及与附件在 Send 进入线程,故在此记 `mentioned`/`attached`
// 触碰(actor=user、锚定 user 消息)。AI 侧在 loop 工具咽喉记——两个水龙头合起来覆盖对话碰过的一切。
package chat

import (
	"context"

	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
)

// recordSendTouches books the user turn's mention/attachment touches. Best-effort by
// construction (Record never fails the caller); nil ledger = feature off. Mention snapshots
// carry name already resolved (freeze-on-send), so no second hydration; a stub snapshot's
// "(unavailable)" name is honest — the touch happened even if the target was broken.
//
// recordSendTouches 记用户回合的提及/附件触碰。天生 best-effort(Record 绝不让调用方失败);
// 台账 nil = 功能关闭。mention 快照已带解析好的名(freeze-on-send),无需二次 hydrate;stub 快照
// 的 "(unavailable)" 名是诚实的——目标坏了、触碰仍发生过。
func (s *Service) recordSendTouches(ctx context.Context, conversationID, messageID string, mentionSnaps []map[string]any, attachmentIDs []string) {
	if s.deps.Touchpoints == nil {
		return
	}
	for _, snap := range mentionSnaps {
		kind, _ := snap["type"].(string)
		id, _ := snap["id"].(string)
		name, _ := snap["name"].(string)
		s.deps.Touchpoints.Record(ctx, touchpointdomain.Touch{
			ConversationID: conversationID,
			ItemKind:       kind,
			ItemID:         id,
			ItemName:       name,
			Verb:           touchpointdomain.VerbMentioned,
			Actor:          touchpointdomain.ActorUser,
			MessageID:      messageID,
		})
	}
	for _, id := range attachmentIDs {
		s.deps.Touchpoints.Record(ctx, touchpointdomain.Touch{
			ConversationID: conversationID,
			ItemKind:       touchpointdomain.ItemKindAttachment,
			ItemID:         id,
			Verb:           touchpointdomain.VerbAttached,
			Actor:          touchpointdomain.ActorUser,
			MessageID:      messageID,
		})
	}
}
