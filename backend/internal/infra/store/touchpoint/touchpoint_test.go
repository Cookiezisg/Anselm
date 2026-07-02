package touchpoint

import (
	"context"
	"database/sql"
	"fmt"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), id)
}

func touch(item, verb string, at time.Time) *touchpointdomain.Touch {
	return &touchpointdomain.Touch{
		ConversationID: "cv_1", ItemKind: "function", ItemID: item, ItemName: item + "-name",
		Verb: verb, Actor: touchpointdomain.ActorAssistant, MessageID: "msg_1", At: at,
	}
}

func TestUpsert_InsertThenBump(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	t0 := time.Date(2026, 7, 2, 10, 0, 0, 0, time.UTC)

	row, err := s.Upsert(ctx, touch("fn_1", touchpointdomain.VerbViewed, t0), "tp_a")
	if err != nil {
		t.Fatalf("insert: %v", err)
	}
	if row.Count != 1 || !row.FirstAt.Equal(t0) || !row.LastAt.Equal(t0) || row.ItemName != "fn_1-name" {
		t.Fatalf("insert row: %+v", row)
	}

	// Second touch of the SAME (cv, item, verb): aggregate bumps, first_at stays, snapshot
	// refreshes, actor/message follow the latest. 同键第二次:聚合递进、first_at 不动、快照/actor 跟最新。
	tc := touch("fn_1", touchpointdomain.VerbViewed, t0.Add(time.Minute))
	tc.ItemName = "renamed"
	tc.Actor = touchpointdomain.ActorSubagent
	tc.MessageID = "msg_2"
	row, err = s.Upsert(ctx, tc, "tp_b")
	if err != nil {
		t.Fatalf("bump: %v", err)
	}
	if row.ID != "tp_a" {
		t.Errorf("bump must reuse the existing row id, got %s", row.ID)
	}
	if row.Count != 2 || !row.FirstAt.Equal(t0) || !row.LastAt.Equal(t0.Add(time.Minute)) {
		t.Errorf("aggregate: %+v", row)
	}
	if row.ItemName != "renamed" || row.LastActor != touchpointdomain.ActorSubagent || row.LastMessageID != "msg_2" {
		t.Errorf("latest-wins fields: %+v", row)
	}

	// Empty incoming name/message keep the existing snapshot. 来名/来信息为空则保留既有。
	tc = touch("fn_1", touchpointdomain.VerbViewed, t0.Add(2*time.Minute))
	tc.ItemName = ""
	tc.MessageID = ""
	row, err = s.Upsert(ctx, tc, "tp_c")
	if err != nil {
		t.Fatalf("bump2: %v", err)
	}
	if row.ItemName != "renamed" || row.LastMessageID != "msg_2" || row.Count != 3 {
		t.Errorf("empty-keeps-snapshot: %+v", row)
	}

	// A different verb on the same item is its own aggregate row. 同物不同动词是另一行。
	row, err = s.Upsert(ctx, touch("fn_1", touchpointdomain.VerbEdited, t0), "tp_d")
	if err != nil {
		t.Fatalf("verb row: %v", err)
	}
	if row.ID != "tp_d" || row.Count != 1 {
		t.Errorf("distinct verb row: %+v", row)
	}
}

func TestUpsert_WorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	t0 := time.Now().UTC()
	if _, err := s.Upsert(ctxWS("ws_1"), touch("fn_1", touchpointdomain.VerbViewed, t0), "tp_1"); err != nil {
		t.Fatalf("ws1: %v", err)
	}
	// Same tuple in another workspace inserts fresh (no cross-ws bump). 异 workspace 同键各自成行。
	row, err := s.Upsert(ctxWS("ws_2"), touch("fn_1", touchpointdomain.VerbViewed, t0), "tp_2")
	if err != nil {
		t.Fatalf("ws2: %v", err)
	}
	if row.ID != "tp_2" || row.Count != 1 {
		t.Errorf("workspace bleed: %+v", row)
	}
}

func TestListByConversation_RecencyOrderFiltersPaging(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 2, 10, 0, 0, 0, time.UTC)
	for i := 0; i < 5; i++ {
		tc := touch(fmt.Sprintf("fn_%d", i), touchpointdomain.VerbViewed, base.Add(time.Duration(i)*time.Minute))
		if i == 4 {
			tc.ItemKind = "document"
			tc.ItemID = "doc_x"
			tc.Verb = touchpointdomain.VerbEdited
		}
		if _, err := s.Upsert(ctx, tc, fmt.Sprintf("tp_%d", i)); err != nil {
			t.Fatalf("seed %d: %v", i, err)
		}
	}

	// Recency DESC. 新鲜度降序。
	rows, next, err := s.ListByConversation(ctx, "cv_1", "", "", "", 3)
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	if len(rows) != 3 || rows[0].ItemID != "doc_x" || rows[1].ItemID != "fn_3" || next == "" {
		t.Fatalf("page1 order: %v next=%q", ids(rows), next)
	}
	rows, next, err = s.ListByConversation(ctx, "cv_1", "", "", next, 3)
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if len(rows) != 2 || rows[0].ItemID != "fn_1" || rows[1].ItemID != "fn_0" || next != "" {
		t.Fatalf("page2: %v next=%q", ids(rows), next)
	}

	// kind / verb filters. 过滤。
	rows, _, err = s.ListByConversation(ctx, "cv_1", "document", "", "", 10)
	if err != nil || len(rows) != 1 || rows[0].ItemID != "doc_x" {
		t.Fatalf("kind filter: %v %v", ids(rows), err)
	}
	rows, _, err = s.ListByConversation(ctx, "cv_1", "", touchpointdomain.VerbEdited, "", 10)
	if err != nil || len(rows) != 1 || rows[0].Verb != touchpointdomain.VerbEdited {
		t.Fatalf("verb filter: %v %v", ids(rows), err)
	}

	// Foreign conversation is empty, not an error. 异对话空页非错误。
	rows, _, err = s.ListByConversation(ctx, "cv_other", "", "", "", 10)
	if err != nil || len(rows) != 0 {
		t.Fatalf("foreign conversation: %v %v", ids(rows), err)
	}
}

func TestUpsert_DeletedRowBorrowsSiblingName(t *testing.T) {
	// A `deleted` touch is its tuple's first row and hydration misses (the entity is gone) —
	// the snapshot must come from the sibling `viewed` row. 删除行借兄弟行的名字快照。
	s := newStore(t)
	ctx := ctxWS("ws_1")
	t0 := time.Now().UTC()
	if _, err := s.Upsert(ctx, touch("fn_1", touchpointdomain.VerbViewed, t0), "tp_v"); err != nil {
		t.Fatalf("seed viewed: %v", err)
	}
	del := touch("fn_1", touchpointdomain.VerbDeleted, t0.Add(time.Minute))
	del.ItemName = "" // hydration missed — entity already gone 实体已删,hydrate 落空
	row, err := s.Upsert(ctx, del, "tp_d")
	if err != nil {
		t.Fatalf("deleted: %v", err)
	}
	if row.ItemName != "fn_1-name" {
		t.Errorf("deleted row must borrow the sibling snapshot: %+v", row)
	}
	// No sibling at all → honest empty (frontend falls back to the id). 无兄弟则诚实空名。
	orphan := touch("fn_ghost", touchpointdomain.VerbDeleted, t0)
	orphan.ItemName = ""
	row, err = s.Upsert(ctx, orphan, "tp_g")
	if err != nil || row.ItemName != "" {
		t.Errorf("orphan deleted row: %+v err=%v", row, err)
	}
}

func TestPurgeConversation(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	t0 := time.Now().UTC()
	if _, err := s.Upsert(ctx, touch("fn_1", touchpointdomain.VerbViewed, t0), "tp_1"); err != nil {
		t.Fatalf("seed: %v", err)
	}
	other := touch("fn_2", touchpointdomain.VerbViewed, t0)
	other.ConversationID = "cv_2"
	if _, err := s.Upsert(ctx, other, "tp_2"); err != nil {
		t.Fatalf("seed2: %v", err)
	}
	if err := s.PurgeConversation(ctx, "cv_1"); err != nil {
		t.Fatalf("purge: %v", err)
	}
	rows, _, _ := s.ListByConversation(ctx, "cv_1", "", "", "", 10)
	if len(rows) != 0 {
		t.Errorf("cv_1 ledger not purged: %v", ids(rows))
	}
	rows, _, _ = s.ListByConversation(ctx, "cv_2", "", "", "", 10)
	if len(rows) != 1 {
		t.Errorf("purge crossed conversations: %v", ids(rows))
	}
}

func ids(rows []*touchpointdomain.Touchpoint) []string {
	out := make([]string, len(rows))
	for i, r := range rows {
		out[i] = r.ItemID
	}
	return out
}
