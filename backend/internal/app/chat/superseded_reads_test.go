package chat

import (
	"strings"
	"testing"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// TestRetry_SupersededRowsRemainInEveryHistoryRead proves that retry changes only the LLM projection:
// the ordinary older pager and the deep-jump window can still address the old answer by id, while the
// newer continuation reaches the current answer and LoadThreadForLLM hides the superseded prose.
//
// TestRetry_SupersededRowsRemainInEveryHistoryRead 证明 retry 只改变 LLM 投影：普通旧页和深跳窗口仍能按 id 找回旧回答，
// newer 续翻能到达当前回答，而 LoadThreadForLLM 隐去被取代正文。
func TestRetry_SupersededRowsRemainInEveryHistoryRead(t *testing.T) {
	svc, store, bridge, _ := retryFixture(t, "FIRST ANSWER", "SECOND ANSWER", "THIRD ANSWER")
	ctx := ctxWS("ws_1")

	oldID, err := svc.Send(ctx, "cv_1", SendInput{Content: "the question"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	waitClose(t, bridge, oldID)
	currentID, err := svc.Retry(ctx, "cv_1", RetryInput{})
	if err != nil {
		t.Fatalf("Retry: %v", err)
	}
	waitClose(t, bridge, currentID)
	futureID, err := svc.Send(ctx, "cv_1", SendInput{Content: "a later question"})
	if err != nil {
		t.Fatalf("Send later turn: %v", err)
	}
	waitClose(t, bridge, futureID)

	// The first REST shape is the ordinary newest-first pager. Its next cursor must still walk onto
	// the old answer; superseded_by is not a history visibility filter.
	page, cursor, err := svc.ListMessages(ctx, "cv_1", "", 1)
	if err != nil {
		t.Fatalf("ListMessages first page: %v", err)
	}
	if len(page) != 1 || page[0].ID != futureID {
		t.Fatalf("newest page = %v, want later answer %s", messageIDs(page), futureID)
	}
	if cursor == "" {
		t.Fatal("newest page must expose an older cursor")
	}
	older, _, err := svc.ListMessages(ctx, "cv_1", cursor, 10)
	if err != nil {
		t.Fatalf("ListMessages older continuation: %v", err)
	}
	if !containsMessage(older, oldID) {
		t.Fatalf("ordinary older continuation lost superseded answer %s: %v", oldID, messageIDs(older))
	}

	// The second shape is ?around=<oldID>. The target itself is an addressable durable row, regardless
	// of its superseded pointer. Use limit=2 so the window also yields a newer continuation cursor.
	window, err := svc.MessagesAround(ctx, "cv_1", oldID, 2)
	if err != nil {
		t.Fatalf("MessagesAround old answer: %v", err)
	}
	if window.TargetID != oldID || !containsMessage(window.Messages, oldID) {
		t.Fatalf("around target = %q, rows = %v; want addressable old answer %s", window.TargetID, messageIDs(window.Messages), oldID)
	}
	if window.NewerCursor == "" {
		t.Fatal("around old answer must expose a newer cursor for the current version")
	}

	// The third shape is ?cursor=<newerCursor>&dir=newer. It continues from the same durable window and
	// must return the later row, not silently re-filter or duplicate the old target.
	newer, _, err := svc.ListMessagesNewer(ctx, "cv_1", window.NewerCursor, 10)
	if err != nil {
		t.Fatalf("ListMessages newer continuation: %v", err)
	}
	if !containsMessage(window.Messages, currentID) {
		t.Fatalf("around window = %v, want current version %s beside old target", messageIDs(window.Messages), currentID)
	}
	if !containsMessage(newer, futureID) || containsMessage(newer, oldID) {
		t.Fatalf("newer continuation = %v, want later %s and not old %s", messageIDs(newer), futureID, oldID)
	}

	// The model projection is the intentional exception: only it applies superseded_by filtering.
	llm, err := store.LoadThreadForLLM(ctx, "cv_1", 0)
	if err != nil {
		t.Fatalf("LoadThreadForLLM: %v", err)
	}
	var assembled strings.Builder
	for _, m := range llm {
		for _, block := range m.Blocks {
			assembled.WriteString(block.Content)
		}
	}
	if strings.Contains(assembled.String(), "FIRST ANSWER") {
		t.Fatalf("superseded answer leaked into LLM projection: %s", assembled.String())
	}
	if !strings.Contains(assembled.String(), "SECOND ANSWER") {
		t.Fatalf("current answer missing from LLM projection: %s", assembled.String())
	}
}

func containsMessage(rows []*messagesdomain.Message, id string) bool {
	for _, row := range rows {
		if row.ID == id {
			return true
		}
	}
	return false
}

func messageIDs(rows []*messagesdomain.Message) []string {
	ids := make([]string, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, row.ID)
	}
	return ids
}
