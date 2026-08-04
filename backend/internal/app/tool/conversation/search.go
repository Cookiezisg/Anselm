// Package conversation gives the LLM a recall window into past conversations — the one
// omni-search-indexed content kind reachable to the LLM only through this tool. It
// returns snippets + ids only, never full transcripts: recall is a pointer, not a
// context dump.
//
// Package conversation 给 LLM 一扇回忆历史对话的窗——综搜已索引、且 LLM 仅经本工具够得着
// 的内容类。只返 snippet + id、绝不返全文：回忆是指针、不是上下文倾倒。
package conversation

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// ConversationTools constructs the conversation tool group (lazy): search_conversations (recall past
// content by query) + list_conversations (faithful cursor-paged enumeration) + manage_conversation
// (archive/pin/rename THIS thread + state that compaction is automatic). search vs list matters:
// search is CONTENT recall (misses threads with no matching text), list is the complete enumeration.
//
// ConversationTools 构造 conversation 工具组（懒加载）：search_conversations（按查询回忆历史内容）
// + list_conversations（忠实游标分页枚举）+ manage_conversation（归档/置顶/改名本对话 + 声明 compaction 自动）。
func ConversationTools(engine *searchapp.Service, mgr Manager) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchConversations{engine: engine},
		&ListConversations{mgr: mgr},
		&ManageConversation{mgr: mgr},
	}
}

const (
	defaultLimit = 8
	maxLimit     = 20
)

type SearchConversations struct{ engine *searchapp.Service }

func (t *SearchConversations) Name() string { return "search_conversations" }

func (t *SearchConversations) Description() string {
	return "Search past conversation history by CONTENT (hybrid lexical + semantic). Use it when the user refers to something discussed earlier (\"the plan we talked about\"). The current conversation is excluded because this is past-history recall. It is content recall, NOT an enumeration: it only returns threads whose messages match the query, so a conversation absent from the results may simply have no matching text — NEVER present these hits as a complete list of conversations (use list_conversations for \"list/show all my conversations\"). Returns every hit with conversationId, title, matchKind (message or conversation_title), snippet, messageId (empty only for a title-only match), and matchedChunks. Snippets are bounded, never full transcripts. Report the returned total and each hit faithfully; do not collapse or invent hits. For hosted-model compatibility, an exact decimal string for limit is accepted; floats, arbitrary strings, arrays, and other shapes remain invalid."
}

func (t *SearchConversations) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["query"],
		"properties": {
			"query": {"type": "string", "description": "What to look for in past conversations."},
			"limit": {"type": "integer", "minimum": 1, "maximum": 20, "description": "Max hits (1-20, default 8). An exact decimal string such as 10 is also accepted for hosted-model compatibility; floats, arbitrary strings, and arrays remain invalid."}
		}
	}`)
}

func (t *SearchConversations) ValidateInput(args json.RawMessage) error {
	var a searchConversationsArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_conversations: bad args: %w", err)
	}
	if strings.TrimSpace(a.Query) == "" {
		return searchdomain.ErrQueryRequired
	}
	return nil
}

type searchConversationsArgs struct {
	Query string
	Limit int
}

// UnmarshalJSON accepts native integers and the exact decimal-string variant emitted by some
// hosted models. Floats, arbitrary strings, arrays, and other shapes remain invalid.
// UnmarshalJSON 接受原生整数及部分托管模型发出的精确十进制字符串；浮点、任意字符串、数组等仍拒绝。
func (a *searchConversationsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		Query string          `json:"query"`
		Limit json.RawMessage `json:"limit"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	limit, err := decodeSearchConversationsInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = searchConversationsArgs{Query: raw.Query, Limit: limit}
	return nil
}

func decodeSearchConversationsInt(raw json.RawMessage) (int, error) {
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

func (t *SearchConversations) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchConversationsArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_conversations: bad args: %w", err)
	}
	limit := args.Limit
	if limit <= 0 {
		limit = defaultLimit
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	page, err := t.engine.Search(ctx, &searchdomain.Query{
		Q:                args.Query,
		Types:            []searchdomain.EntityType{searchdomain.TypeConversation},
		ExcludeEntityIDs: currentConversationExclusion(ctx),
		IncludeArchived:  true,
		Limit:            limit,
	})
	if err != nil {
		return "", fmt.Errorf("search_conversations: %w", err)
	}
	type hit struct {
		ConversationID string `json:"conversationId"`
		Title          string `json:"title"`
		MatchKind      string `json:"matchKind"`
		Snippet        string `json:"snippet"`
		MessageID      string `json:"messageId"` // empty only for a conversation-title hit. 仅会话标题命中时为空。
		MatchedChunks  int    `json:"matchedChunks,omitempty"`
	}
	hits := make([]hit, 0, len(page.Hits))
	for _, h := range page.Hits {
		snippet := h.Snippet
		matchKind := "message"
		if h.Anchor == "" {
			matchKind = "conversation_title"
			if snippet == "" {
				snippet = h.Name
			}
		}
		hits = append(hits, hit{
			ConversationID: h.EntityID,
			Title:          h.Name,
			MatchKind:      matchKind,
			Snippet:        snippet,
			MessageID:      h.Anchor,
			MatchedChunks:  h.MatchedChunks,
		})
	}
	return toolapp.ToJSON(map[string]any{"hits": hits, "total": page.Total}), nil
}

func currentConversationExclusion(ctx context.Context) []string {
	conversationID, ok := reqctxpkg.GetConversationID(ctx)
	if !ok {
		return nil
	}
	return []string{conversationID}
}
