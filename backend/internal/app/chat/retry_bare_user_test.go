package chat

import (
	"strings"
	"testing"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// TestRetry_BareUserTailProducesTheMissingAnswer exercises the real service after a crash-shaped
// thread stopped before the assistant row was created. Retry must behave as "answer this question",
// not as a special error or a second user turn, and the new assistant must not claim a retryOf.
//
// TestRetry_BareUserTailProducesTheMissingAnswer 用真实 service 验证进程在 assistant 行落地前崩溃后的线程：retry 必须
// 自然表现为「回答这个问题」，不能报特殊错误或再写一条 user，新的 assistant 也不能伪造 retryOf。
func TestRetry_BareUserTailProducesTheMissingAnswer(t *testing.T) {
	svc, store, bridge, _ := retryFixture(t, "RECOVERED ANSWER")
	ctx := ctxWS("ws_1")

	const userID = "msg_crash_user0000001"
	if err := store.CreateMessage(ctx, &messagesdomain.Message{
		ID:             userID,
		ConversationID: "cv_crash_user",
		Role:           messagesdomain.RoleUser,
		Status:         messagesdomain.StatusCompleted,
	}, []messagesdomain.Block{{Type: messagesdomain.BlockTypeText, Content: "question before crash"}}); err != nil {
		t.Fatalf("seed user-only crash tail: %v", err)
	}

	// Boot reconciliation is part of the scenario: there is nothing non-terminal to sweep because
	// the process died before the assistant message was minted. The retry must still be useful.
	// 这是场景的一部分：进程在 assistant 行铸出前死亡，boot sweep 没有非终态行可收扫，但 retry 仍必须可用。
	svc.SweepOrphans(ctx)
	assistantID, err := svc.Retry(ctx, "cv_crash_user", RetryInput{})
	if err != nil {
		t.Fatalf("Retry user-only tail: %v", err)
	}
	waitClose(t, bridge, assistantID)

	thread, err := store.LoadThread(ctx, "cv_crash_user")
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	if len(thread) != 2 {
		t.Fatalf("retry must keep one user plus one recovered assistant, got %d rows", len(thread))
	}
	if retryOfOf(retryRow(t, store, assistantID)) != "" {
		t.Fatalf("missing-answer retry must not claim retryOf, got row %+v", retryRow(t, store, assistantID).Attrs)
	}
	if got, _ := blockText(retryRow(t, store, assistantID)); got != "RECOVERED ANSWER" {
		t.Fatalf("recovered assistant text = %q, want scripted answer", got)
	}
	assembled := llmText(t, store, "cv_crash_user")
	if !strings.Contains(assembled, "question before crash") || !strings.Contains(assembled, "RECOVERED ANSWER") {
		t.Fatalf("LLM history lost the recovered turn: %s", assembled)
	}
}
