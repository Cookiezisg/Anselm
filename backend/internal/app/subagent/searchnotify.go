package subagent

import (
	"context"

	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

// notifySearchMessage marks a finalized sub-message dirty for the parent
// conversation's index — subagent text output is conversation content too.
//
// notifySearchMessage 把定稿的 sub-message 标脏给父对话索引——subagent 的文本输出
// 也是对话内容。
func (s *Service) notifySearchMessage(ctx context.Context, convID, msgID string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeConversation, convID, msgID)
}
