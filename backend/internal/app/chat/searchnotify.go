package chat

import (
	"context"

	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

// notifySearchMessage marks one completed message dirty for the conversation
// index — the anchor routes the indexer to the single-message incremental path
// instead of re-projecting the whole conversation.
//
// notifySearchMessage 把一条完成的 message 标脏给对话索引——anchor 让索引器走单
// message 增量路径，而非整会话重投影。
func (s *Service) notifySearchMessage(ctx context.Context, convID, msgID string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeConversation, convID, msgID)
}
