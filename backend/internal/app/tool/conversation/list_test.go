package conversation

import (
	"context"
	"encoding/json"
	"testing"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
)

// Test_listConversations_EnumeratesAndPages — F146: list_conversations is a faithful enumeration that
// surfaces nextCursor when more pages remain (so the agent can't mistake one page for the complete set)
// and excludes archived threads by default (active only) unless includeArchived is set.
func Test_listConversations_EnumeratesAndPages(t *testing.T) {
	fm := &fakeManager{
		listRows: []*conversationdomain.Conversation{
			{ID: "cv_1", Title: "first", Pinned: true},
			{ID: "cv_2", Title: "second", Archived: false},
		},
		listNext: "cursor_page2",
	}
	tool := &ListConversations{mgr: fm}

	out, err := tool.Execute(context.Background(), `{}`)
	if err != nil {
		t.Fatalf("execute: %v", err)
	}
	var got struct {
		Conversations []struct {
			ConversationID string `json:"conversationId"`
			Title          string `json:"title"`
			Pinned         bool   `json:"pinned"`
		} `json:"conversations"`
		Count      int    `json:"count"`
		NextCursor string `json:"nextCursor"`
	}
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("unmarshal: %v (%s)", err, out)
	}
	if got.Count != 2 || len(got.Conversations) != 2 || got.Conversations[0].ConversationID != "cv_1" {
		t.Fatalf("enumeration wrong: %+v", got)
	}
	if got.NextCursor != "cursor_page2" {
		t.Fatalf("nextCursor must surface so a page isn't mistaken for the whole set, got %q", got.NextCursor)
	}
	// default excludes archived (ArchiveActive = active only).
	if fm.gotFilter.Archive != conversationdomain.ArchiveActive {
		t.Fatalf("default must be ArchiveActive (active only), got %q", fm.gotFilter.Archive)
	}

	// includeArchived → ArchiveAll (active + archived together). Regression guard: the old code left
	// the filter at the active-only default believing it meant "all", so includeArchived silently
	// returned NO archived threads — the very bug ArchiveScope fixes.
	if _, err := tool.Execute(context.Background(), `{"includeArchived":true}`); err != nil {
		t.Fatalf("execute includeArchived: %v", err)
	}
	if fm.gotFilter.Archive != conversationdomain.ArchiveAll {
		t.Fatalf("includeArchived must set ArchiveAll (active+archived), got %q", fm.gotFilter.Archive)
	}
}

func Test_listConversations_LimitClamp(t *testing.T) {
	fm := &fakeManager{}
	tool := &ListConversations{mgr: fm}
	if _, err := tool.Execute(context.Background(), `{"limit":999}`); err != nil {
		t.Fatalf("execute: %v", err)
	}
	if fm.gotFilter.Limit != 50 {
		t.Fatalf("limit must clamp to 50, got %d", fm.gotFilter.Limit)
	}
	if _, err := tool.Execute(context.Background(), `{}`); err != nil {
		t.Fatalf("execute: %v", err)
	}
	if fm.gotFilter.Limit != 20 {
		t.Fatalf("default limit must be 20, got %d", fm.gotFilter.Limit)
	}
}
