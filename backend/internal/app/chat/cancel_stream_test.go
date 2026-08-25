package chat

import (
	"context"
	"iter"
	"testing"
	"time"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

type cancelAwareClient struct {
	started chan struct{}
}

func (c *cancelAwareClient) Stream(ctx context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	return func(yield func(llminfra.StreamEvent) bool) {
		select {
		case c.started <- struct{}{}:
		default:
		}
		<-ctx.Done()
		yield(llminfra.StreamEvent{Type: llminfra.EventError, Err: ctx.Err()})
	}
}

// TestCancelStreamingTurnFinalizesOnDetachedContext proves a user cancellation during provider
// streaming still persists a cancelled terminal and emits message_stop instead of leaving an
// orphaned streaming row after the client has gone away.
// TestCancelStreamingTurnFinalizesOnDetachedContext 验证 provider 流式期间用户取消后，仍在 detached
// context 上落 cancelled 终态并发 message_stop，不因客户端离开而留下 streaming 孤儿。
func TestCancelStreamingTurnFinalizesOnDetachedContext(t *testing.T) {
	bridge := newRecordBridge()
	client := &cancelAwareClient{started: make(chan struct{}, 1)}
	svc, store := newSvc(t, client, bridge)
	ctx := ctxWS("ws_cancel")

	asstID, err := svc.Send(ctx, "cv_cancel", SendInput{Content: "stop this reply"})
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	select {
	case <-client.started:
	case <-time.After(2 * time.Second):
		t.Fatal("provider stream did not start")
	}

	if err := svc.Cancel(ctx, "cv_cancel"); err != nil {
		t.Fatalf("Cancel: %v", err)
	}
	waitClose(t, bridge, asstID)

	got, err := store.GetMessage(ctx, asstID)
	if err != nil {
		t.Fatalf("GetMessage: %v", err)
	}
	if got.Status != messagesdomain.StatusCancelled || got.StopReason != messagesdomain.StopReasonCancelled {
		t.Fatalf("cancelled stream did not finalize honestly: status=%q stop=%q", got.Status, got.StopReason)
	}
	if got.Status == messagesdomain.StatusStreaming || svc.IsGenerating("cv_cancel") {
		t.Fatal("cancelled stream left a live/orphaned generation")
	}
}
