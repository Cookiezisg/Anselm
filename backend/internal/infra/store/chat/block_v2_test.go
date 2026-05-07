// block_v2_test.go — integration tests for BlockV2Store using in-memory
// SQLite. Covers Save / AppendDelta / FinalizeStop / Get / List
// (by conv + by message), CHECK constraint enforcement, and the
// (conversation_id, seq) UNIQUE invariant.
//
// block_v2_test.go ——BlockV2Store 集成测试（内存 SQLite）。
// 覆盖 Save / AppendDelta / FinalizeStop / Get / List（按 conv / message）、
// CHECK 约束、(conversation_id, seq) UNIQUE 不变量。
package chat

import (
	"context"
	"errors"
	"testing"

	gormlogger "gorm.io/gorm/logger"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
)

func newBlockV2Store(t *testing.T) *BlockV2Store {
	t.Helper()
	database, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(database) })
	if err := dbinfra.Migrate(database, &chatdomain.BlockV2{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return NewBlockV2Store(database)
}

func mkBlockV2(id, convID, msgID string, seq int64) *chatdomain.BlockV2 {
	return &chatdomain.BlockV2{
		ID:             id,
		ConversationID: convID,
		MessageID:      msgID,
		Seq:            seq,
		Type:           eventlogdomain.BlockTypeText,
		Status:         eventlogdomain.StatusStreaming,
	}
}

func TestBlockV2_SaveAndGet(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	b := mkBlockV2("blk_1", "cv_1", "msg_1", 1)
	b.Content = "hello"
	if err := s.Save(ctx, b); err != nil {
		t.Fatalf("save: %v", err)
	}
	got, err := s.GetByID(ctx, "blk_1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Content != "hello" {
		t.Errorf("content: got %q, want hello", got.Content)
	}
	if got.Status != eventlogdomain.StatusStreaming {
		t.Errorf("status: got %q, want streaming", got.Status)
	}
}

func TestBlockV2_GetMissingReturnsErrBlockNotFound(t *testing.T) {
	s := newBlockV2Store(t)
	_, err := s.GetByID(context.Background(), "blk_doesnotexist")
	if !errors.Is(err, chatdomain.ErrBlockNotFound) {
		t.Errorf("want ErrBlockNotFound, got %v", err)
	}
}

func TestBlockV2_AppendDelta(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	b := mkBlockV2("blk_1", "cv_1", "msg_1", 1)
	b.Content = "hello"
	s.Save(ctx, b)

	if err := s.AppendDelta(ctx, "blk_1", " world"); err != nil {
		t.Fatalf("append: %v", err)
	}
	if err := s.AppendDelta(ctx, "blk_1", "!"); err != nil {
		t.Fatalf("append #2: %v", err)
	}
	got, _ := s.GetByID(ctx, "blk_1")
	if got.Content != "hello world!" {
		t.Errorf("content: got %q, want %q", got.Content, "hello world!")
	}
}

func TestBlockV2_AppendDeltaMissingReturnsErr(t *testing.T) {
	s := newBlockV2Store(t)
	err := s.AppendDelta(context.Background(), "blk_doesnotexist", "delta")
	if !errors.Is(err, chatdomain.ErrBlockNotFound) {
		t.Errorf("want ErrBlockNotFound, got %v", err)
	}
}

func TestBlockV2_FinalizeStop(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	b := mkBlockV2("blk_1", "cv_1", "msg_1", 1)
	s.Save(ctx, b)

	if err := s.FinalizeStop(ctx, "blk_1", eventlogdomain.StatusError, "boom"); err != nil {
		t.Fatalf("finalize: %v", err)
	}
	got, _ := s.GetByID(ctx, "blk_1")
	if got.Status != eventlogdomain.StatusError {
		t.Errorf("status: got %q, want error", got.Status)
	}
	if got.Error != "boom" {
		t.Errorf("error: got %q, want boom", got.Error)
	}
}

func TestBlockV2_FinalizeStopMissingReturnsErr(t *testing.T) {
	s := newBlockV2Store(t)
	err := s.FinalizeStop(context.Background(), "blk_x", eventlogdomain.StatusCompleted, "")
	if !errors.Is(err, chatdomain.ErrBlockNotFound) {
		t.Errorf("want ErrBlockNotFound, got %v", err)
	}
}

func TestBlockV2_ListByConversationOrderedBySeq(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	// Insert in reverse seq order
	for i := 5; i >= 1; i-- {
		s.Save(ctx, mkBlockV2(
			"blk_"+string(rune('0'+i)),
			"cv_1", "msg_1", int64(i),
		))
	}
	rows, err := s.ListByConversation(ctx, "cv_1")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(rows) != 5 {
		t.Fatalf("want 5 rows, got %d", len(rows))
	}
	for i, r := range rows {
		if r.Seq != int64(i+1) {
			t.Errorf("row %d: seq %d, want %d", i, r.Seq, i+1)
		}
	}
}

func TestBlockV2_ListByMessageOrderedBySeq(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	// Two messages in same conv, blocks interleaved by seq.
	s.Save(ctx, mkBlockV2("blk_1", "cv_1", "msg_a", 1))
	s.Save(ctx, mkBlockV2("blk_2", "cv_1", "msg_b", 2))
	s.Save(ctx, mkBlockV2("blk_3", "cv_1", "msg_a", 3))

	rows, err := s.ListByMessage(ctx, "msg_a")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("want 2 rows, got %d", len(rows))
	}
	if rows[0].ID != "blk_1" || rows[1].ID != "blk_3" {
		t.Errorf("got order %s,%s want blk_1,blk_3", rows[0].ID, rows[1].ID)
	}
}

func TestBlockV2_UniqueConvSeqEnforced(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	if err := s.Save(ctx, mkBlockV2("blk_1", "cv_1", "msg_1", 1)); err != nil {
		t.Fatalf("save 1: %v", err)
	}
	// Same conv + seq with different ID — should violate UNIQUE.
	err := s.Save(ctx, mkBlockV2("blk_2", "cv_1", "msg_1", 1))
	if err == nil {
		t.Error("want UNIQUE violation, got nil")
	}
}

func TestBlockV2_TypeCheckEnforced(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	bad := mkBlockV2("blk_1", "cv_1", "msg_1", 1)
	bad.Type = "bogus"
	err := s.Save(ctx, bad)
	if err == nil {
		t.Error("want CHECK violation on type, got nil")
	}
}

func TestBlockV2_StatusCheckEnforced(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	bad := mkBlockV2("blk_1", "cv_1", "msg_1", 1)
	bad.Status = "bogus"
	err := s.Save(ctx, bad)
	if err == nil {
		t.Error("want CHECK violation on status, got nil")
	}
}

func TestBlockV2_SaveOverwriteUpdatesContent(t *testing.T) {
	s := newBlockV2Store(t)
	ctx := context.Background()
	b := mkBlockV2("blk_1", "cv_1", "msg_1", 1)
	b.Content = "first"
	s.Save(ctx, b)

	b2 := mkBlockV2("blk_1", "cv_1", "msg_1", 1)
	b2.Content = "overwritten"
	b2.Status = eventlogdomain.StatusCompleted
	if err := s.Save(ctx, b2); err != nil {
		t.Fatalf("save overwrite: %v", err)
	}
	got, _ := s.GetByID(ctx, "blk_1")
	if got.Content != "overwritten" {
		t.Errorf("content: got %q, want overwritten", got.Content)
	}
	if got.Status != eventlogdomain.StatusCompleted {
		t.Errorf("status: got %q, want completed", got.Status)
	}
}
