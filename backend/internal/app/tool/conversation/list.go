package conversation

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
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
	return "Enumerate the user's conversations, most-recently-active first — the FAITHFUL way to answer \"list / show all my conversations\". Prefer this over search_conversations for enumeration: search only finds threads whose CONTENT matches a query and silently misses ones with no matching text, so it must NEVER be presented as a complete list. Cursor-paged: if the result includes nextCursor, there are more — pass it back to get the next page (a single page is NOT necessarily all of them). Archived threads are excluded unless includeArchived:true. Returns per conversation: conversationId, title, archived, pinned, lastMessageAt (no transcripts). `lastMessageAt` is the authoritative RFC3339 string: when reporting it, copy the exact value verbatim and never replace it with a generic phrase such as \"the recorded time\". For hosted-model compatibility, an exact decimal string for limit is accepted; floats, arbitrary strings, arrays, and other shapes remain invalid."
}

func (t *ListConversations) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"cursor": {"type": "string", "description": "Pass the nextCursor from a previous call to fetch the next page; omit for the first page."},
			"limit": {"type": "integer", "description": "Max conversations per page (1-50, default 20). An exact decimal string such as 1 is also accepted for hosted-model compatibility; floats, arbitrary strings, and arrays remain invalid."},
			"includeArchived": {"type": "boolean", "description": "Include archived conversations too (default false = active only). Exact \"true\"/\"false\" strings are also accepted from hosted model callers; other shapes remain invalid."}
		}
	}`)
}

func (t *ListConversations) ValidateInput(args json.RawMessage) error {
	var a listConversationsArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("list_conversations: bad args: %w", err)
	}
	return nil
}

func (t *ListConversations) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args listConversationsArgs
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

type listConversationsArgs struct {
	Cursor          string
	Limit           int
	IncludeArchived bool
}

// UnmarshalJSON accepts native integers and the exact decimal-string variant emitted by some
// hosted models. Floats, arbitrary strings, arrays, and other shapes remain invalid.
// UnmarshalJSON 接受原生整数及部分托管模型发出的精确十进制字符串；浮点、任意字符串、数组等仍拒绝。
func (a *listConversationsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		Cursor          string          `json:"cursor"`
		Limit           json.RawMessage `json:"limit"`
		IncludeArchived json.RawMessage `json:"includeArchived"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	limit, err := decodeListConversationsInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	includeArchived, err := decodeListConversationsBool(raw.IncludeArchived)
	if err != nil {
		return fmt.Errorf("includeArchived: %w", err)
	}
	*a = listConversationsArgs{Cursor: raw.Cursor, Limit: limit, IncludeArchived: includeArchived}
	return nil
}

func decodeListConversationsInt(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be integer or an exact decimal integer string, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be integer or an exact decimal integer string, got %q", text)
	}
	return value, nil
}

func decodeListConversationsBool(raw json.RawMessage) (bool, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return false, nil
	}
	var value bool
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return false, fmt.Errorf("must be boolean or the exact string \"true\"/\"false\", got %s", string(raw))
	}
	switch strings.TrimSpace(text) {
	case "true":
		return true, nil
	case "false":
		return false, nil
	default:
		return false, fmt.Errorf("must be boolean or the exact string \"true\"/\"false\", got %q", text)
	}
}
