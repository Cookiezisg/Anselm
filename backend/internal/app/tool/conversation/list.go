package conversation

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	conversationapp "github.com/sunweilin/anselm/backend/internal/app/conversation"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

var _ toolapp.Tool = (*ListConversations)(nil)

// ListConversations is list_conversations: a faithful, cursor-paged ENUMERATION of the user's
// conversations. It complements search_conversations (which is CONTENT recall — it only returns
// threads whose messages match a query and silently misses ones with no matching text). Without an
// enumeration path the agent answered "list all my conversations" by guessing search words and
// presenting partial results as complete (F146). Returns lightweight rows (id/title/archived/pinned/
// lastMessageAt), never transcripts.
//
// ListConversations 即 list_conversations：用户对话的忠实、游标分页**枚举**。补 search_conversations
// （那是**内容**回忆——只返消息匹配查询的线程、无匹配文本的静默漏掉）。无枚举路径时 agent 靠猜搜索词答
// 「列出我所有对话」、把部分结果当全集呈现（F146）。返轻量行（id/title/archived/pinned/lastMessageAt）、绝不返全文。
type ListConversations struct{ mgr Manager }

func (t *ListConversations) Name() string { return "list_conversations" }

func (t *ListConversations) Description() string {
	return "Enumerate the user's conversations, most-recently-active first — the FAITHFUL way to answer \"list / show all my conversations\". Prefer this over search_conversations for enumeration: search only finds threads whose CONTENT matches a query and silently misses ones with no matching text, so it must NEVER be presented as a complete list. Cursor-paged: if the result includes nextCursor, there are more — pass it back to get the next page (a single page is NOT necessarily all of them). Archived threads are excluded unless includeArchived:true. Returns per conversation: conversationId, title, archived, pinned, lastMessageAt (no transcripts)."
}

func (t *ListConversations) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"cursor": {"type": "string", "description": "Pass the nextCursor from a previous call to fetch the next page; omit for the first page."},
			"limit": {"type": "integer", "description": "Max conversations per page (1-50, default 20)."},
			"includeArchived": {"type": "boolean", "description": "Include archived conversations too (default false = active only)."}
		}
	}`)
}

func (t *ListConversations) ValidateInput(args json.RawMessage) error {
	var a struct {
		Cursor          string `json:"cursor"`
		Limit           int    `json:"limit"`
		IncludeArchived bool   `json:"includeArchived"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("list_conversations: bad args: %w", err)
	}
	return nil
}

func (t *ListConversations) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Cursor          string `json:"cursor"`
		Limit           int    `json:"limit"`
		IncludeArchived bool   `json:"includeArchived"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("list_conversations: bad args: %w", err)
	}
	limit := args.Limit
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	filter := conversationapp.ListFilter{Cursor: args.Cursor, Limit: limit}
	if args.IncludeArchived {
		filter.Archive = conversationapp.ArchiveAll // active + archived in one enumeration
	} // else: zero value ArchiveActive = active only (the default)
	rows, next, err := t.mgr.List(ctx, filter)
	if err != nil {
		return "", fmt.Errorf("list_conversations: %w", err)
	}
	type item struct {
		ConversationID string `json:"conversationId"`
		Title          string `json:"title"`
		Archived       bool   `json:"archived"`
		Pinned         bool   `json:"pinned"`
		LastMessageAt  string `json:"lastMessageAt"`
	}
	items := make([]item, 0, len(rows))
	for _, c := range rows {
		items = append(items, item{
			ConversationID: c.ID, Title: c.Title, Archived: c.Archived, Pinned: c.Pinned,
			LastMessageAt: c.LastMessageAt.UTC().Format(time.RFC3339),
		})
	}
	out := map[string]any{"conversations": items, "count": len(items)}
	if next != "" {
		out["nextCursor"] = next // more pages remain — this is NOT the complete set
	}
	return toolapp.ToJSON(out), nil
}
