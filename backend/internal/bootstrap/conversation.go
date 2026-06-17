package bootstrap

import (
	"context"

	contextmgrapp "github.com/sunweilin/anselm/backend/internal/app/contextmgr"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
)

// ConversationStore is the slice of conversation.Service the compaction summary adapter needs.
// *conversationapp.Service satisfies it.
//
// ConversationStore 是压缩摘要适配器需要的 conversation.Service 切片。*conversationapp.Service 满足它。
type ConversationStore interface {
	Get(ctx context.Context, id string) (*conversationdomain.Conversation, error)
	SetSummary(ctx context.Context, id, summary string, coversUpToSeq int64) error
}

// conversationSummary adapts conversation.Service to contextmgr's ConversationSummary port,
// projecting the Conversation entity down to the (summary, watermark) pair contextmgr cares about
// (so contextmgr never imports the conversation domain type).
//
// conversationSummary 把 conversation.Service 适配成 contextmgr 的 ConversationSummary 端口，把
// Conversation 实体投影成 contextmgr 关心的 (summary, 水位) 二元组（使 contextmgr 不引 conversation
// domain 类型）。
type conversationSummary struct{ svc ConversationStore }

// NewConversationSummary wraps a conversation store as contextmgr's ConversationSummary port.
//
// NewConversationSummary 把 conversation store 包成 contextmgr 的 ConversationSummary 端口。
func NewConversationSummary(svc ConversationStore) contextmgrapp.ConversationSummary {
	return conversationSummary{svc: svc}
}

var _ contextmgrapp.ConversationSummary = conversationSummary{}

func (a conversationSummary) GetSummary(ctx context.Context, conversationID string) (string, int64, error) {
	c, err := a.svc.Get(ctx, conversationID)
	if err != nil {
		return "", 0, err
	}
	return c.Summary, c.SummaryCoversUpToSeq, nil
}

func (a conversationSummary) SetSummary(ctx context.Context, conversationID, summary string, coversUpToSeq int64) error {
	return a.svc.SetSummary(ctx, conversationID, summary, coversUpToSeq)
}
