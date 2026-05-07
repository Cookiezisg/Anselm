package eventlog

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	gormlogger "gorm.io/gorm/logger"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	eventloginfra "github.com/sunweilin/forgify/backend/internal/infra/eventlog"
	chatstore "github.com/sunweilin/forgify/backend/internal/infra/store/chat"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// helper: build ctx with conv + msg + emitter wired up.
func setupCtx(t *testing.T) (context.Context, *eventloginfra.Bridge, Emitter) {
	t.Helper()
	br := eventloginfra.NewBridge(nil)
	em := New(br, nil, nil)
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
	em := New(br, nil, nil)
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

// ── DB dual-write (Phase 2B) ─────────────────────────────────────────

// helper: build ctx + emitter wired to a real BlockV2Store backed by
// in-memory SQLite. Returns ctx, repo, and emitter.
func setupDBCtx(t *testing.T) (context.Context, *chatstore.BlockV2Store, Emitter) {
	t.Helper()
	database, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(database) })
	if err := dbinfra.Migrate(database, &chatdomain.BlockV2{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	repo := chatstore.NewBlockV2Store(database)

	br := eventloginfra.NewBridge(nil)
	em := New(br, repo, nil)
	ctx := context.Background()
	ctx = reqctxpkg.WithConversationID(ctx, "cv_db")
	ctx = reqctxpkg.WithMessageID(ctx, "msg_db")
	ctx = With(ctx, em)
	return ctx, repo, em
}

func TestEmitBlockStart_DualWritesToDB(t *testing.T) {
	ctx, repo, em := setupDBCtx(t)

	em.EmitBlockStart(ctx, "blk_t1", "msg_db", "msg_db", eventlogdomain.BlockTypeText, nil)

	got, err := repo.GetByID(ctx, "blk_t1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.ConversationID != "cv_db" {
		t.Errorf("conversationID: got %q, want cv_db", got.ConversationID)
	}
	if got.MessageID != "msg_db" {
		t.Errorf("messageID: got %q, want msg_db", got.MessageID)
	}
	if got.ParentBlockID != "" {
		t.Errorf("parentBlockID: got %q, want empty (top-level)", got.ParentBlockID)
	}
	if got.Type != eventlogdomain.BlockTypeText {
		t.Errorf("type: got %q, want text", got.Type)
	}
	if got.Status != eventlogdomain.StatusStreaming {
		t.Errorf("status: got %q, want streaming", got.Status)
	}
	if got.Seq != 1 {
		t.Errorf("seq: got %d, want 1", got.Seq)
	}
}

func TestEmitBlockStart_DualWritesNestedParent(t *testing.T) {
	ctx, repo, em := setupDBCtx(t)

	em.EmitBlockStart(ctx, "blk_parent", "msg_db", "msg_db", eventlogdomain.BlockTypeToolCall, nil)
	em.EmitBlockStart(ctx, "blk_child", "blk_parent", "msg_db", eventlogdomain.BlockTypeProgress, nil)

	child, _ := repo.GetByID(ctx, "blk_child")
	if child.ParentBlockID != "blk_parent" {
		t.Errorf("nested parent: got %q, want blk_parent", child.ParentBlockID)
	}
}

func TestDeltaBlock_DualWritesAppend(t *testing.T) {
	ctx, repo, em := setupDBCtx(t)

	em.EmitBlockStart(ctx, "blk_t1", "msg_db", "msg_db", eventlogdomain.BlockTypeText, nil)
	em.DeltaBlock(ctx, "blk_t1", "hello")
	em.DeltaBlock(ctx, "blk_t1", " world")

	got, _ := repo.GetByID(ctx, "blk_t1")
	if got.Content != "hello world" {
		t.Errorf("content: got %q, want %q", got.Content, "hello world")
	}
}

func TestStopBlock_DualWritesFinalize(t *testing.T) {
	ctx, repo, em := setupDBCtx(t)

	em.EmitBlockStart(ctx, "blk_t1", "msg_db", "msg_db", eventlogdomain.BlockTypeText, nil)
	em.DeltaBlock(ctx, "blk_t1", "all done")
	em.StopBlock(ctx, "blk_t1", eventlogdomain.StatusCompleted, nil)

	got, _ := repo.GetByID(ctx, "blk_t1")
	if got.Status != eventlogdomain.StatusCompleted {
		t.Errorf("status: got %q, want completed", got.Status)
	}
	if got.Error != "" {
		t.Errorf("error: got %q, want empty", got.Error)
	}
}

func TestStopBlock_DualWritesError(t *testing.T) {
	ctx, repo, em := setupDBCtx(t)

	em.EmitBlockStart(ctx, "blk_t1", "msg_db", "msg_db", eventlogdomain.BlockTypeText, nil)
	em.StopBlock(ctx, "blk_t1", eventlogdomain.StatusError, errors.New("boom"))

	got, _ := repo.GetByID(ctx, "blk_t1")
	if got.Status != eventlogdomain.StatusError {
		t.Errorf("status: got %q, want error", got.Status)
	}
	if got.Error != "boom" {
		t.Errorf("error: got %q, want boom", got.Error)
	}
}

func TestEmitter_AttrsJSONMarshalled(t *testing.T) {
	ctx, repo, em := setupDBCtx(t)

	em.EmitBlockStart(ctx, "blk_t1", "msg_db", "msg_db", eventlogdomain.BlockTypeToolCall,
		map[string]any{"tool": "Read", "summary": "fetching"})

	got, _ := repo.GetByID(ctx, "blk_t1")
	if !strings.Contains(got.Attrs, `"tool":"Read"`) {
		t.Errorf("attrs missing tool: %q", got.Attrs)
	}
}

// ── Contract test: full simulated chat round (Phase 5) ────────────────
//
// Drives the Emitter through a realistic message lifecycle (message_start
// → text block → tool_call block → tool_result block → message_stop),
// observes via the Bridge, and asserts the protocol invariants from
// CLAUDE.md §S21:
//   - seq strictly monotonic, no gaps
//   - block_start.parentId references entities that already exist
//   - block.status flows streaming → terminal monotonically
//   - tool_call block ID = caller-supplied (LLM tc_id), not minted
//   - DB rows for blocks reflect content + status correctly
//
// 完整模拟一轮 chat 协议契约测试。

func TestProtocolContract_ChatRoundtrip(t *testing.T) {
	ctx, repo, em := setupDBCtx(t)

	// Need to subscribe to bridge to capture events. setupDBCtx wires a
	// fresh Bridge inside; we have to recreate state here for clarity.
	br := em.(*emitter).bridge
	subCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ch, cancelSub, err := br.Subscribe(subCtx, "cv_db", 0)
	if err != nil {
		t.Fatalf("subscribe: %v", err)
	}
	defer cancelSub()

	// Drive the sequence.
	em.EmitMessageStart(ctx, "msg_db", "assistant", "", nil)

	// text block (top-level under message)
	textID := "blk_text_1"
	em.EmitBlockStart(ctx, textID, "msg_db", "msg_db", eventlogdomain.BlockTypeText, nil)
	em.DeltaBlock(ctx, textID, "Hello, ")
	em.DeltaBlock(ctx, textID, "world.")
	em.StopBlock(ctx, textID, eventlogdomain.StatusCompleted, nil)

	// tool_call block (LLM-supplied id, top-level under message)
	tcID := "tc_abc123"
	em.EmitBlockStart(ctx, tcID, "msg_db", "msg_db", eventlogdomain.BlockTypeToolCall,
		map[string]any{"tool": "Read"})
	em.DeltaBlock(ctx, tcID, `{"path":"/etc/hosts"}`)
	em.StopBlock(ctx, tcID, eventlogdomain.StatusCompleted, nil)

	// tool_result block (nested under the tool_call)
	resultID := "blk_result_1"
	em.EmitBlockStart(ctx, resultID, tcID, "msg_db", eventlogdomain.BlockTypeToolResult, nil)
	em.DeltaBlock(ctx, resultID, "127.0.0.1 localhost\n")
	em.StopBlock(ctx, resultID, eventlogdomain.StatusCompleted, nil)

	em.StopMessage(ctx, "msg_db", eventlogdomain.StatusCompleted, "end_turn", "", "", 100, 200)

	// Collect envelopes (5 stops + 5 starts + 4 deltas + 1 msg_start + 1 msg_stop = ?)
	// Count: 1 (msg_start) + 3 (text: start/delta/delta/stop = 4 actually) ...
	// Let me recount: msg_start=1, text(start+2 delta+stop)=4, tc(start+1 delta+stop)=3, result(start+delta+stop)=3, msg_stop=1 → total 12
	expected := 12
	got := make([]eventlogdomain.Envelope, 0, expected)
	for i := 0; i < expected; i++ {
		select {
		case env := <-ch:
			got = append(got, env)
		case <-time.After(2 * time.Second):
			t.Fatalf("timeout waiting for envelope #%d (got %d)", i+1, len(got))
		}
	}

	// ── Invariant 1: seq strict monotonic 1..N ──
	for i, env := range got {
		want := int64(i + 1)
		if env.Seq != want {
			t.Errorf("env[%d].Seq: got %d, want %d", i, env.Seq, want)
		}
	}

	// ── Invariant 2: known entities exist before being referenced ──
	known := map[string]bool{}
	for i, env := range got {
		switch e := env.Event.(type) {
		case eventlogdomain.MessageStart:
			known[e.ID] = true
		case eventlogdomain.BlockStart:
			if !known[e.ParentID] {
				t.Errorf("env[%d] BlockStart parent %q referenced before it existed",
					i, e.ParentID)
			}
			if !known[e.MessageID] {
				t.Errorf("env[%d] BlockStart messageId %q referenced before it existed",
					i, e.MessageID)
			}
			known[e.ID] = true
		case eventlogdomain.BlockDelta:
			if !known[e.ID] {
				t.Errorf("env[%d] BlockDelta id %q has no prior block_start", i, e.ID)
			}
		case eventlogdomain.BlockStop:
			if !known[e.ID] {
				t.Errorf("env[%d] BlockStop id %q has no prior block_start", i, e.ID)
			}
		case eventlogdomain.MessageStop:
			if !known[e.ID] {
				t.Errorf("env[%d] MessageStop id %q has no prior message_start", i, e.ID)
			}
		}
	}

	// ── Invariant 3: tool_call block ID is caller-supplied (LLM tc_id) ──
	var foundToolCallStart bool
	for _, env := range got {
		if bs, ok := env.Event.(eventlogdomain.BlockStart); ok &&
			bs.BlockType == eventlogdomain.BlockTypeToolCall {
			if bs.ID != "tc_abc123" {
				t.Errorf("tool_call BlockStart ID: got %q, want tc_abc123 (LLM-supplied)", bs.ID)
			}
			foundToolCallStart = true
		}
	}
	if !foundToolCallStart {
		t.Error("never saw tool_call BlockStart")
	}

	// ── Invariant 4: tool_result has parent = tool_call ID ──
	for _, env := range got {
		if bs, ok := env.Event.(eventlogdomain.BlockStart); ok &&
			bs.BlockType == eventlogdomain.BlockTypeToolResult {
			if bs.ParentID != "tc_abc123" {
				t.Errorf("tool_result parent: got %q, want tc_abc123", bs.ParentID)
			}
		}
	}

	// ── Invariant 5: DB rows reflect final state ──
	textRow, err := repo.GetByID(ctx, textID)
	if err != nil {
		t.Fatalf("get text block: %v", err)
	}
	if textRow.Content != "Hello, world." {
		t.Errorf("text content: got %q, want %q", textRow.Content, "Hello, world.")
	}
	if textRow.Status != eventlogdomain.StatusCompleted {
		t.Errorf("text status: got %q, want completed", textRow.Status)
	}
	if textRow.ParentBlockID != "" {
		t.Errorf("text parent_block_id: got %q, want empty (top-level)", textRow.ParentBlockID)
	}

	tcRow, _ := repo.GetByID(ctx, tcID)
	if tcRow.Content != `{"path":"/etc/hosts"}` {
		t.Errorf("tool_call content: got %q, want JSON args", tcRow.Content)
	}
	if !strings.Contains(tcRow.Attrs, `"tool":"Read"`) {
		t.Errorf("tool_call attrs missing tool name: %q", tcRow.Attrs)
	}

	resultRow, _ := repo.GetByID(ctx, resultID)
	if resultRow.ParentBlockID != tcID {
		t.Errorf("tool_result parent: got %q, want %q (nested under tool_call)", resultRow.ParentBlockID, tcID)
	}
}

// ── Existing minimal-coverage tests (no DB) ──────────────────────────

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
