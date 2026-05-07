package eventlog

import (
	"context"
	"errors"
	"strings"
	"testing"

	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	eventloginfra "github.com/sunweilin/forgify/backend/internal/infra/eventlog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// helper: build ctx with conv + msg + emitter wired up.
func setupCtx(t *testing.T) (context.Context, *eventloginfra.Bridge, Emitter) {
	t.Helper()
	br := eventloginfra.NewBridge(nil)
	em := New(br, nil)
	ctx := context.Background()
	ctx = reqctxpkg.WithConversationID(ctx, "cv_test")
	ctx = reqctxpkg.WithMessageID(ctx, "msg_test")
	ctx = With(ctx, em)
	return ctx, br, em
}

func TestEmitter_StartMessageReturnsMintedID(t *testing.T) {
	ctx, _, em := setupCtx(t)
	id := em.StartMessage(ctx, "assistant", "", nil)
	if !strings.HasPrefix(id, "msg_") {
		t.Errorf("want msg_ prefix, got %q", id)
	}
	if len(id) < 12 {
		t.Errorf("id too short: %q", id)
	}
}

func TestEmitter_StartBlockReadsParentFromCtx(t *testing.T) {
	ctx, br, em := setupCtx(t)

	// Subscribe to capture published events.
	subCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, cancelSub, _ := br.Subscribe(subCtx, "cv_test", 0)
	defer cancelSub()

	parentBlockID := "blk_parent"
	scoped := WithParent(ctx, parentBlockID)
	blockID := em.StartBlock(scoped, eventlogdomain.BlockTypeText, nil)
	if blockID == "" {
		t.Fatal("expected minted blockID, got empty")
	}

	env := <-ch
	bs, ok := env.Event.(eventlogdomain.BlockStart)
	if !ok {
		t.Fatalf("expected BlockStart, got %T", env.Event)
	}
	if bs.ParentID != parentBlockID {
		t.Errorf("ParentID: got %q, want %q", bs.ParentID, parentBlockID)
	}
	if bs.MessageID != "msg_test" {
		t.Errorf("MessageID: got %q, want msg_test", bs.MessageID)
	}
}

func TestEmitter_StartBlockFallsBackToMessageID(t *testing.T) {
	ctx, br, em := setupCtx(t) // no WithParent — falls back to messageID

	subCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, cancelSub, _ := br.Subscribe(subCtx, "cv_test", 0)
	defer cancelSub()

	blockID := em.StartBlock(ctx, eventlogdomain.BlockTypeText, nil)
	if blockID == "" {
		t.Fatal("expected minted blockID")
	}

	env := <-ch
	bs := env.Event.(eventlogdomain.BlockStart)
	if bs.ParentID != "msg_test" {
		t.Errorf("ParentID fallback: got %q, want msg_test", bs.ParentID)
	}
}

func TestEmitter_DeltaAndStopBlock(t *testing.T) {
	ctx, br, em := setupCtx(t)

	subCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, cancelSub, _ := br.Subscribe(subCtx, "cv_test", 0)
	defer cancelSub()

	blockID := em.StartBlock(ctx, eventlogdomain.BlockTypeText, nil)
	em.DeltaBlock(ctx, blockID, "hello")
	em.DeltaBlock(ctx, blockID, " world")
	em.StopBlock(ctx, blockID, eventlogdomain.StatusCompleted, nil)

	want := []string{"block_start", "block_delta", "block_delta", "block_stop"}
	for i, w := range want {
		env := <-ch
		if env.Event.EventType() != w {
			t.Errorf("event %d: got %s, want %s", i, env.Event.EventType(), w)
		}
	}
}

func TestEmitter_StopBlockWithError(t *testing.T) {
	ctx, br, em := setupCtx(t)
	subCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, cancelSub, _ := br.Subscribe(subCtx, "cv_test", 0)
	defer cancelSub()

	blockID := em.StartBlock(ctx, eventlogdomain.BlockTypeText, nil)
	<-ch // start
	em.StopBlock(ctx, blockID, eventlogdomain.StatusError, errors.New("boom"))
	env := <-ch
	bs := env.Event.(eventlogdomain.BlockStop)
	if bs.Error != "boom" {
		t.Errorf("Error: got %q, want %q", bs.Error, "boom")
	}
	if bs.Status != eventlogdomain.StatusError {
		t.Errorf("Status: got %q, want error", bs.Status)
	}
}

func TestEmitter_MissingConversationIDSkipsEmit(t *testing.T) {
	br := eventloginfra.NewBridge(nil)
	em := New(br, nil)
	ctx := context.Background() // no convID
	id := em.StartMessage(ctx, "assistant", "", nil)
	// We still mint the id locally (there's no way to fail gracefully
	// for callers expecting an ID), but the Bridge sees nothing.
	// 仍铸本地 id（要求返 ID 的调用方无法优雅失败），但 Bridge 看不到。
	if id != "" {
		t.Errorf("StartMessage with no convID should return empty id, got %q", id)
	}
}

func TestFrom_ReturnsNoopWhenAbsent(t *testing.T) {
	em := From(context.Background())
	// no panic, no emit — no-op
	em.StartMessage(context.Background(), "user", "", nil)
	em.DeltaBlock(context.Background(), "blk_x", "ignored")
	em.StopBlock(context.Background(), "blk_x", eventlogdomain.StatusCompleted, nil)
}

func TestMustFrom_PanicsWhenAbsent(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic")
		}
	}()
	MustFrom(context.Background())
}

func TestStartBlockUnder_ExplicitParent(t *testing.T) {
	ctx, br, em := setupCtx(t)
	subCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, cancelSub, _ := br.Subscribe(subCtx, "cv_test", 0)
	defer cancelSub()

	bid := em.StartBlockUnder(ctx, "blk_explicit", "msg_explicit", eventlogdomain.BlockTypeProgress, map[string]any{"stage": "x"})
	if bid == "" {
		t.Fatal("expected minted blockID")
	}
	env := <-ch
	bs := env.Event.(eventlogdomain.BlockStart)
	if bs.ParentID != "blk_explicit" {
		t.Errorf("ParentID: got %q, want blk_explicit", bs.ParentID)
	}
	if bs.MessageID != "msg_explicit" {
		t.Errorf("MessageID: got %q, want msg_explicit", bs.MessageID)
	}
	if bs.BlockType != eventlogdomain.BlockTypeProgress {
		t.Errorf("BlockType: got %q, want progress", bs.BlockType)
	}
}
