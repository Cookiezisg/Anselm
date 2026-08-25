package chat

import (
	"context"
	"testing"
	"time"

	"go.uber.org/zap"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
)

type blockingCompactor struct {
	entered chan struct{}
	release chan struct{}
}

func (c *blockingCompactor) MaybeCompact(context.Context, string) error {
	close(c.entered)
	<-c.release
	return nil
}

// TestSendDuringCompactionUsesSingleBuffer proves the deliberate tail window: after the visible
// assistant turn is finalized, a slow compaction call releases running and accepts exactly one
// follow-up Send into the queue, but that task cannot start until compaction finishes.
//
// TestSendDuringCompactionUsesSingleBuffer 证明刻意保留的收尾窗口：assistant 已可见收尾后，慢速 compaction
// 释放 running 并允许恰一条后续 Send 进队，但该 task 必须等 compaction 完成才启动。
func TestSendDuringCompactionUsesSingleBuffer(t *testing.T) {
	entered := make(chan struct{}, 2)
	compactor := &blockingCompactor{entered: make(chan struct{}), release: make(chan struct{})}
	bridge := newRecordBridge()
	svc := NewService(newStore(t), Deps{
		Conversations: fakeConvs{conv: &conversationdomain.Conversation{Title: "t"}},
		Resolver:      fakeResolver{client: &fakeClient{script: textTurn(), entered: entered}},
		Bridge:        bridge,
		Compactor:     compactor,
	}, zap.NewNop())
	ctx := ctxWS("ws_1")

	first, err := svc.Send(ctx, "cv_1", SendInput{Content: "first"})
	if err != nil {
		t.Fatalf("first Send: %v", err)
	}
	select {
	case <-entered:
	case <-time.After(2 * time.Second):
		t.Fatal("first turn did not enter provider stream")
	}
	select {
	case <-compactor.entered:
	case <-time.After(2 * time.Second):
		t.Fatal("first turn did not enter compaction")
	}
	waitClose(t, bridge, first)

	second, err := svc.Send(ctx, "cv_1", SendInput{Content: "second"})
	if err != nil {
		t.Fatalf("Send during compaction should occupy the single slot: %v", err)
	}
	select {
	case <-entered:
		t.Fatal("buffered follow-up started before compaction released")
	case <-time.After(100 * time.Millisecond):
	}

	close(compactor.release)
	select {
	case <-entered:
	case <-time.After(2 * time.Second):
		t.Fatal("buffered follow-up did not start after compaction released")
	}
	waitClose(t, bridge, second)
}
