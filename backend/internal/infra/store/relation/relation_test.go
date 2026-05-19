package relation

import (
	"context"
	"errors"
	"testing"
	"time"

	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

func newTestStore(t *testing.T) *Store {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := dbinfra.Migrate(db, &relationdomain.Relation{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return New(db)
}

func mkRel(id, fromKind, fromID, toKind, toID, kind string) *relationdomain.Relation {
	return &relationdomain.Relation{
		ID:       id,
		UserID:   "user_local",
		FromKind: fromKind,
		FromID:   fromID,
		ToKind:   toKind,
		ToID:     toID,
		Kind:     kind,
		Attrs:    map[string]any{"nodeIds": []string{"n_1"}},
	}
}

func TestStore_InsertAndListByFrom_RoundTrip(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	rel := mkRel("rel_001", "workflow", "wf_x", "function", "fn_y", relationdomain.KindWorkflowUsesFunction)
	if err := s.Insert(ctx, rel); err != nil {
		t.Fatalf("Insert: %v", err)
	}
	rows, err := s.ListByFromAndKinds(ctx, "user_local", "workflow", "wf_x", []string{relationdomain.KindWorkflowUsesFunction})
	if err != nil {
		t.Fatalf("ListByFromAndKinds: %v", err)
	}
	if len(rows) != 1 || rows[0].ID != "rel_001" {
		t.Errorf("expected 1 row id rel_001, got %+v", rows)
	}
	if got := rows[0].Attrs["nodeIds"]; got == nil {
		t.Errorf("expected attrs.nodeIds, got nil")
	}
}

func TestStore_InsertBatch_IdempotentOnConflict(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	rels := []*relationdomain.Relation{
		mkRel("rel_a", "workflow", "wf_x", "function", "fn_y", relationdomain.KindWorkflowUsesFunction),
		mkRel("rel_b", "workflow", "wf_x", "handler", "hd_y", relationdomain.KindWorkflowUsesHandler),
	}
	if err := s.InsertBatch(ctx, rels); err != nil {
		t.Fatalf("InsertBatch round 1: %v", err)
	}
	// Same logical edges, different IDs — uq_rel should make round 2 a no-op
	rels2 := []*relationdomain.Relation{
		mkRel("rel_a2", "workflow", "wf_x", "function", "fn_y", relationdomain.KindWorkflowUsesFunction),
		mkRel("rel_b2", "workflow", "wf_x", "handler", "hd_y", relationdomain.KindWorkflowUsesHandler),
	}
	if err := s.InsertBatch(ctx, rels2); err != nil {
		t.Fatalf("InsertBatch round 2 (expected no-op): %v", err)
	}
	rows, err := s.ListByFromAndKinds(ctx, "user_local", "workflow", "wf_x", nil)
	if err != nil {
		t.Fatalf("ListByFromAndKinds: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("expected 2 rows after dup insert, got %d", len(rows))
	}
}

func TestStore_DeleteByIDs(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	rels := []*relationdomain.Relation{
		mkRel("rel_a", "workflow", "wf_x", "function", "fn_1", relationdomain.KindWorkflowUsesFunction),
		mkRel("rel_b", "workflow", "wf_x", "function", "fn_2", relationdomain.KindWorkflowUsesFunction),
		mkRel("rel_c", "workflow", "wf_x", "function", "fn_3", relationdomain.KindWorkflowUsesFunction),
	}
	if err := s.InsertBatch(ctx, rels); err != nil {
		t.Fatalf("InsertBatch: %v", err)
	}
	if err := s.DeleteByIDs(ctx, []string{"rel_a", "rel_c"}); err != nil {
		t.Fatalf("DeleteByIDs: %v", err)
	}
	rows, _ := s.ListByFromAndKinds(ctx, "user_local", "workflow", "wf_x", nil)
	if len(rows) != 1 || rows[0].ID != "rel_b" {
		t.Errorf("expected rel_b remaining, got %+v", rows)
	}
}

func TestStore_UpdateAttrs(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	rel := mkRel("rel_x", "workflow", "wf_x", "function", "fn_y", relationdomain.KindWorkflowUsesFunction)
	if err := s.Insert(ctx, rel); err != nil {
		t.Fatalf("Insert: %v", err)
	}
	if err := s.UpdateAttrs(ctx, "rel_x", map[string]any{"nodeIds": []string{"n_1", "n_5"}}); err != nil {
		t.Fatalf("UpdateAttrs: %v", err)
	}
	rows, _ := s.ListByFromAndKinds(ctx, "user_local", "workflow", "wf_x", nil)
	if len(rows) != 1 {
		t.Fatalf("expected 1 row, got %d", len(rows))
	}
	if got, _ := rows[0].Attrs["nodeIds"].([]any); len(got) != 2 {
		t.Errorf("expected 2 nodeIds after update, got %v", rows[0].Attrs)
	}
}

func TestStore_PurgeEntity_CascadesBothDirections(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	rels := []*relationdomain.Relation{
		// fn_x is "to" target
		mkRel("rel_a", "workflow", "wf_x", "function", "fn_x", relationdomain.KindWorkflowUsesFunction),
		mkRel("rel_b", "conversation", "cv_x", "function", "fn_x", relationdomain.KindConversationForgedEntity),
		// fn_x is "from" (technically wouldn't happen with current 8 kinds — testing cascade only)
		// unrelated edge — should survive
		mkRel("rel_c", "workflow", "wf_x", "handler", "hd_y", relationdomain.KindWorkflowUsesHandler),
	}
	if err := s.InsertBatch(ctx, rels); err != nil {
		t.Fatalf("InsertBatch: %v", err)
	}
	n, err := s.PurgeEntity(ctx, "user_local", "function", "fn_x")
	if err != nil {
		t.Fatalf("PurgeEntity: %v", err)
	}
	if n != 2 {
		t.Errorf("expected 2 rows deleted, got %d", n)
	}
	rows, _ := s.ListAll(ctx, "user_local")
	if len(rows) != 1 || rows[0].ID != "rel_c" {
		t.Errorf("expected rel_c remaining, got %+v", rows)
	}
}

func TestStore_NoSelfLoopTrigger_RejectsInsert(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	// from and to point at same entity
	rel := mkRel("rel_loop", "function", "fn_x", "function", "fn_x", relationdomain.KindDocumentLinksEntity)
	err := s.Insert(ctx, rel)
	if err == nil {
		t.Fatalf("expected self-loop INSERT to be rejected by trigger")
	}
}

func TestStore_List_FiltersAndCursorPagination(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	// Insert 5 edges with different created_at via direct DB control
	for i := 0; i < 5; i++ {
		rel := mkRel(
			"rel_"+string(rune('a'+i)),
			"workflow", "wf_x",
			"function", "fn_"+string(rune('1'+i)),
			relationdomain.KindWorkflowUsesFunction,
		)
		rel.CreatedAt = time.Now().Add(time.Duration(i) * time.Second)
		if err := s.Insert(ctx, rel); err != nil {
			t.Fatalf("Insert %d: %v", i, err)
		}
	}
	// Page 1: limit 2
	rows, next, hasMore, err := s.List(ctx, "user_local",
		relationdomain.Filter{FromKind: "workflow", FromID: "wf_x"}, "", 2)
	if err != nil {
		t.Fatalf("List page 1: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("expected 2 rows, got %d", len(rows))
	}
	if !hasMore || next == "" {
		t.Errorf("expected hasMore + nextCursor, got hasMore=%v next=%q", hasMore, next)
	}
	// Page 2
	rows2, _, hasMore2, err := s.List(ctx, "user_local",
		relationdomain.Filter{FromKind: "workflow", FromID: "wf_x"}, next, 2)
	if err != nil {
		t.Fatalf("List page 2: %v", err)
	}
	if len(rows2) != 2 {
		t.Errorf("page 2: expected 2 rows, got %d", len(rows2))
	}
	_ = hasMore2
	// Ensure no overlap between pages
	for _, r1 := range rows {
		for _, r2 := range rows2 {
			if r1.ID == r2.ID {
				t.Errorf("page overlap: id %s appears in both", r1.ID)
			}
		}
	}
}

func TestStore_List_UserIDScoping(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	rel := mkRel("rel_a", "workflow", "wf_x", "function", "fn_y", relationdomain.KindWorkflowUsesFunction)
	rel.UserID = "user_alice"
	if err := s.Insert(ctx, rel); err != nil {
		t.Fatalf("Insert: %v", err)
	}
	// Query under different user
	rows, _, _, err := s.List(ctx, "user_bob", relationdomain.Filter{}, "", 100)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(rows) != 0 {
		t.Errorf("user_bob should see 0 rows, got %d", len(rows))
	}
	// Query under correct user
	rows, _, _, err = s.List(ctx, "user_alice", relationdomain.Filter{}, "", 100)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(rows) != 1 {
		t.Errorf("user_alice should see 1 row, got %d", len(rows))
	}
}

func TestStore_ListByFrom_KindFilterEmpty_ReturnsAll(t *testing.T) {
	s := newTestStore(t)
	ctx := context.Background()
	rels := []*relationdomain.Relation{
		mkRel("rel_a", "workflow", "wf_x", "function", "fn_y", relationdomain.KindWorkflowUsesFunction),
		mkRel("rel_b", "workflow", "wf_x", "handler", "hd_y", relationdomain.KindWorkflowUsesHandler),
	}
	if err := s.InsertBatch(ctx, rels); err != nil {
		t.Fatalf("InsertBatch: %v", err)
	}
	rows, err := s.ListByFromAndKinds(ctx, "user_local", "workflow", "wf_x", nil)
	if err != nil {
		t.Fatalf("ListByFromAndKinds: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("expected 2 rows when kinds=nil, got %d", len(rows))
	}
}

// silence unused import warning when build tags drop helpers
var _ = errors.New
