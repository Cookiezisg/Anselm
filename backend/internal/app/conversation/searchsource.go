package conversation

import (
	"context"
	"errors"
	"strings"
	"time"

	conversationdomain "github.com/sunweilin/foryx/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/foryx/backend/internal/domain/messages"
	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
)

// MessageReader is the slice of the messages repository the projection needs —
// a DIP port so this package never depends on the messages store.
//
// MessageReader 是投影所需的 messages 仓储切面——DIP 端口，本包不依赖 messages store。
type MessageReader interface {
	ListMessages(ctx context.Context, conversationID, cursor string, limit int) ([]*messagesdomain.Message, string, error)
	GetMessage(ctx context.Context, id string) (*messagesdomain.Message, error)
}

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeConversation, id, "")
}

// SearchSource projects a conversation: chunk 0 is the title card, then one
// row per message holding ONLY its text blocks (tool_result / reasoning /
// tool_call / compaction / progress are noise). chunk_no =
// first block seq + 1 — stable per message, so the incremental DocAt path
// upserts without renumbering; 0 stays reserved for the card.
//
// SearchSource 投影对话：chunk 0 是标题卡，之后每条 message 一行、只含其 text 块
// （tool_result/reasoning/tool_call/compaction/progress 为噪声）。
// chunk_no = 首块 seq + 1——对 message 稳定，增量 DocAt 直接 upsert 不重排号；
// 0 留给标题卡。
func (s *Service) SearchSource(messages MessageReader) *SearchSource {
	return &SearchSource{svc: s, messages: messages}
}

type SearchSource struct {
	svc      *Service
	messages MessageReader
}

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeConversation }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	out := map[string]time.Time{}
	cursor := ""
	for {
		items, next, err := ss.svc.repo.List(ctx, conversationdomain.ListFilter{Cursor: cursor, Limit: 200})
		if err != nil {
			return nil, err
		}
		for _, c := range items {
			out[c.ID] = c.UpdatedAt
		}
		if next == "" {
			return out, nil
		}
		cursor = next
	}
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	c, err := ss.svc.repo.Get(ctx, id)
	if errors.Is(err, conversationdomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	docs := []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: c.Title, Archived: c.Archived, UpdatedAt: c.UpdatedAt,
	}}
	cursor := ""
	for {
		msgs, next, err := ss.messages.ListMessages(ctx, id, cursor, 200)
		if err != nil {
			return nil, err
		}
		for _, m := range msgs {
			if doc := messageDoc(c, m); doc != nil {
				docs = append(docs, *doc)
			}
		}
		if next == "" {
			return docs, nil
		}
		cursor = next
	}
}

// DocAt is the incremental path: one completed message → one row. A message
// without text content returns (nil, true) — nothing to index, and no reason
// to re-project the whole conversation.
//
// DocAt 是增量路径：一条完成的 message → 一行。无 text 内容的 message 返回
// (nil, true)——无可索，也没理由整会话重投影。
func (ss *SearchSource) DocAt(ctx context.Context, id, anchor string) (*searchdomain.SourceDoc, bool, error) {
	c, err := ss.svc.repo.Get(ctx, id)
	if errors.Is(err, conversationdomain.ErrNotFound) {
		return nil, false, nil // conversation gone → full path deletes. 会话已无 → 整体路径删。
	}
	if err != nil {
		return nil, false, err
	}
	m, err := ss.messages.GetMessage(ctx, anchor)
	if errors.Is(err, messagesdomain.ErrMessageNotFound) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	return messageDoc(c, m), true, nil
}

// messageDoc renders one message's text blocks into a projection row (nil if
// it has none).
//
// messageDoc 把一条 message 的 text 块渲染成一行投影（没有则 nil）。
func messageDoc(c *conversationdomain.Conversation, m *messagesdomain.Message) *searchdomain.SourceDoc {
	var parts []string
	minSeq := int64(-1)
	for _, b := range m.Blocks {
		if minSeq < 0 || b.Seq < minSeq {
			minSeq = b.Seq
		}
		if b.Type == messagesdomain.BlockTypeText && strings.TrimSpace(b.Content) != "" {
			parts = append(parts, b.Content)
		}
	}
	if len(parts) == 0 || minSeq < 0 {
		return nil
	}
	return &searchdomain.SourceDoc{
		ChunkNo:   int(minSeq) + 1,
		Anchor:    m.ID,
		Title:     c.Title,
		Body:      searchdomain.CapRunes(strings.Join(parts, "\n")),
		Archived:  c.Archived,
		UpdatedAt: m.UpdatedAt,
	}
}
