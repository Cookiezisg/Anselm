package chat

import (
	"errors"
	"testing"
	"time"
)

// TestRetry_RejectsInMemoryGeneratingTurn proves the second half of the retry gate: a durable tail
// may look terminal later, but while the conversation queue is actively generating, retry must reject
// immediately and must not append a speculative user or assistant row.
//
// TestRetry_RejectsInMemoryGeneratingTurn 证明 retry 闸的另一半：即使耐久尾巴稍后可能终态，只要 conversation queue 当前正在生成，
// retry 就必须立即拒绝，不能先写一条猜测性的 user 或 assistant。
func TestRetry_RejectsInMemoryGeneratingTurn(t *testing.T) {
	gate := make(chan struct{})
	entered := make(chan struct{}, 1)
	bridge := newRecordBridge()
	svc, store := newSvc(t, &fakeClient{script: textTurn(), gate: gate, entered: entered}, bridge)
	ctx := ctxWS("ws_1")
	released := false
	release := func() {
		if !released {
			close(gate)
			released = true
		}
	}
	t.Cleanup(release)

	assistantID, err := svc.Send(ctx, "cv_retry_inflight", SendInput{Content: "first question"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	select {
	case <-entered:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for the provider to enter the in-flight turn")
	}
	if _, err := svc.Retry(ctx, "cv_retry_inflight", RetryInput{}); !errors.Is(err, ErrStreamInProgress) {
		t.Fatalf("Retry while generating = %v, want STREAM_IN_PROGRESS", err)
	}
	thread, err := store.LoadThread(ctx, "cv_retry_inflight")
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	if len(thread) != 2 || thread[1].ID != assistantID {
		t.Fatalf("rejected retry must not append rows, got %+v", thread)
	}
	if users := retryRoleIDs(t, store, "cv_retry_inflight", "user"); len(users) != 1 {
		t.Fatalf("rejected retry must not append a user row, got %v", users)
	}

	release()
	waitClose(t, bridge, assistantID)
}
