// Package forge — integration tests for Store using an in-memory SQLite.
// Covers CRUD, user scoping, version/pending lifecycle, unified execution
// history (run+test), cursor pagination, and the interface satisfaction
// compile-time check.
//
// Package forge — Store 集成测试（内存 SQLite）。
// 覆盖 CRUD、用户隔离、版本/pending 生命周期、统一执行历史（run+test）、
// cursor 分页、接口满足检查。
package forge

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	gormlogger "gorm.io/gorm/logger"

	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// compile-time interface satisfaction check.
var _ forgedomain.Repository = (*Store)(nil)

const (
	userAlice = "u-alice"
	userBob   = "u-bob"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	database, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(database) })
	if err := dbinfra.Migrate(database,
		&forgedomain.Forge{},
		&forgedomain.ForgeVersion{},
		&forgedomain.ForgeTestCase{},
		&forgedomain.ForgeExecution{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return New(database)
}

func ctxFor(userID string) context.Context {
	return reqctxpkg.SetUserID(context.Background(), userID)
}

func mkForge(id, userID, name string) *forgedomain.Forge {
	return &forgedomain.Forge{
		ID:           id,
		UserID:       userID,
		Name:         name,
		Description:  "desc " + name,
		Code:         "def " + name + "(): pass",
		Parameters:   "[]",
		ReturnSchema: "{}",
		Tags:         "[]",
		VersionCount: 1,
	}
}

// ── Forge CRUD ─────────────────────────────────────────────────────────────────

func TestSaveAndGetForge(t *testing.T) {
	s := newStore(t)
	f := mkForge("f_001", userAlice, "parse_csv")
	if err := s.SaveForge(ctxFor(userAlice), f); err != nil {
		t.Fatalf("SaveForge: %v", err)
	}
	got, err := s.GetForge(ctxFor(userAlice), "f_001")
	if err != nil {
		t.Fatalf("GetForge: %v", err)
	}
	if got.Name != "parse_csv" {
		t.Errorf("name: want parse_csv, got %s", got.Name)
	}
}

func TestGetForge_NotFound(t *testing.T) {
	s := newStore(t)
	_, err := s.GetForge(ctxFor(userAlice), "f_missing")
	if !errors.Is(err, forgedomain.ErrNotFound) {
		t.Errorf("expected ErrNotFound, got %v", err)
	}
}

func TestGetForge_UserIsolation(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	_, err := s.GetForge(ctxFor(userBob), "f_001")
	if !errors.Is(err, forgedomain.ErrNotFound) {
		t.Errorf("Bob should not see Alice's forge, got %v", err)
	}
}

func TestDeleteForge_SoftDelete(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	if err := s.DeleteForge(ctxFor(userAlice), "f_001"); err != nil {
		t.Fatalf("DeleteForge: %v", err)
	}
	_, err := s.GetForge(ctxFor(userAlice), "f_001")
	if !errors.Is(err, forgedomain.ErrNotFound) {
		t.Errorf("deleted forge should not be found, got %v", err)
	}
}

func TestListAllForges(t *testing.T) {
	s := newStore(t)
	for _, name := range []string{"forge_a", "forge_b", "forge_c"} {
		if err := s.SaveForge(ctxFor(userAlice), mkForge("f_"+name, userAlice, name)); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.SaveForge(ctxFor(userBob), mkForge("f_bob", userBob, "bob_forge")); err != nil {
		t.Fatal(err)
	}
	forges, err := s.ListAllForges(ctxFor(userAlice))
	if err != nil {
		t.Fatalf("ListAllForges: %v", err)
	}
	if len(forges) != 3 {
		t.Errorf("want 3 forges, got %d", len(forges))
	}
}

func TestGetForgesByIDs_OrderPreserved(t *testing.T) {
	s := newStore(t)
	for _, id := range []string{"f_1", "f_2", "f_3"} {
		if err := s.SaveForge(ctxFor(userAlice), mkForge(id, userAlice, "forge_"+id)); err != nil {
			t.Fatal(err)
		}
	}
	forges, err := s.GetForgesByIDs(ctxFor(userAlice), []string{"f_3", "f_1"})
	if err != nil {
		t.Fatalf("GetForgesByIDs: %v", err)
	}
	if len(forges) != 2 || forges[0].ID != "f_3" || forges[1].ID != "f_1" {
		t.Errorf("order not preserved: %v", forges)
	}
}

// ── Versions ─────────────────────────────────────────────────────────────────

func mkVersion(id, forgeID, userID, status string, version *int) *forgedomain.ForgeVersion {
	return &forgedomain.ForgeVersion{
		ID:           id,
		ForgeID:      forgeID,
		UserID:       userID,
		Version:      version,
		Status:       status,
		Name:         "forge",
		Code:         "def forge(): pass",
		ChangeReason: "initial",
	}
}

func intPtr(n int) *int { return &n }

func TestVersionLifecycle(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}

	pending := mkVersion("fv_p1", "f_001", userAlice, forgedomain.VersionStatusPending, nil)
	if err := s.SaveVersion(ctxFor(userAlice), pending); err != nil {
		t.Fatalf("SaveVersion pending: %v", err)
	}

	got, err := s.GetActivePending(ctxFor(userAlice), "f_001")
	if err != nil {
		t.Fatalf("GetActivePending: %v", err)
	}
	if got.ID != "fv_p1" {
		t.Errorf("want fv_p1, got %s", got.ID)
	}

	if err := s.UpdateVersionStatus(ctxFor(userAlice), "fv_p1", forgedomain.VersionStatusAccepted, intPtr(1)); err != nil {
		t.Fatalf("UpdateVersionStatus: %v", err)
	}

	_, err = s.GetActivePending(ctxFor(userAlice), "f_001")
	if !errors.Is(err, forgedomain.ErrPendingNotFound) {
		t.Errorf("expected ErrPendingNotFound after accept, got %v", err)
	}

	v, err := s.GetVersion(ctxFor(userAlice), "f_001", 1)
	if err != nil {
		t.Fatalf("GetVersion: %v", err)
	}
	if *v.Version != 1 {
		t.Errorf("want version=1, got %d", *v.Version)
	}
}

func TestDeleteOldestAcceptedVersion(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	for i, vid := range []string{"fv_v1", "fv_v2", "fv_v3"} {
		v := mkVersion(vid, "f_001", userAlice, forgedomain.VersionStatusAccepted, intPtr(i+1))
		v.CreatedAt = time.Now().Add(time.Duration(i) * time.Second)
		if err := s.SaveVersion(ctxFor(userAlice), v); err != nil {
			t.Fatal(err)
		}
	}
	n, _ := s.CountAcceptedVersions(ctxFor(userAlice), "f_001")
	if n != 3 {
		t.Fatalf("want 3 versions, got %d", n)
	}
	if err := s.DeleteOldestAcceptedVersion(ctxFor(userAlice), "f_001"); err != nil {
		t.Fatalf("DeleteOldestAcceptedVersion: %v", err)
	}
	n, _ = s.CountAcceptedVersions(ctxFor(userAlice), "f_001")
	if n != 2 {
		t.Errorf("want 2 versions after delete, got %d", n)
	}
	_, err := s.GetVersion(ctxFor(userAlice), "f_001", 1)
	if !errors.Is(err, forgedomain.ErrVersionNotFound) {
		t.Errorf("v1 should be deleted, got %v", err)
	}
}

// ── Test cases ────────────────────────────────────────────────────────────────

func TestTestCaseCRUD(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	tc := &forgedomain.ForgeTestCase{
		ID:             "tc_001",
		ForgeID:        "f_001",
		UserID:         userAlice,
		Name:           "basic",
		InputData:      `{"x":1}`,
		ExpectedOutput: `2`,
	}
	if err := s.SaveTestCase(ctxFor(userAlice), tc); err != nil {
		t.Fatalf("SaveTestCase: %v", err)
	}
	got, err := s.GetTestCase(ctxFor(userAlice), "tc_001")
	if err != nil {
		t.Fatalf("GetTestCase: %v", err)
	}
	if got.Name != "basic" {
		t.Errorf("want name=basic, got %s", got.Name)
	}
	if err := s.DeleteTestCase(ctxFor(userAlice), "tc_001"); err != nil {
		t.Fatalf("DeleteTestCase: %v", err)
	}
	_, err = s.GetTestCase(ctxFor(userAlice), "tc_001")
	if !errors.Is(err, forgedomain.ErrTestCaseNotFound) {
		t.Errorf("expected ErrTestCaseNotFound after delete, got %v", err)
	}
}

// ── Executions (unified run + test history) ───────────────────────────────────

func mkExecution(id, forgeID, userID, kind string, t time.Time) *forgedomain.ForgeExecution {
	return &forgedomain.ForgeExecution{
		ID:           id,
		ForgeID:      forgeID,
		UserID:       userID,
		ForgeVersion: 1,
		Kind:         kind,
		Input:        "{}",
		OK:           true,
		TriggeredBy:  forgedomain.TriggeredByHTTP,
		CreatedAt:    t,
	}
}

func TestExecutionRetention(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	for i := range 3 {
		e := mkExecution(fmt.Sprintf("fe_%02d", i), "f_001", userAlice,
			forgedomain.ExecutionKindRun, time.Now().Add(time.Duration(i)*time.Second))
		if err := s.SaveExecution(ctxFor(userAlice), e); err != nil {
			t.Fatalf("SaveExecution: %v", err)
		}
	}
	n, err := s.CountExecutions(ctxFor(userAlice), "f_001")
	if err != nil || n != 3 {
		t.Fatalf("want count=3, got %d, err=%v", n, err)
	}
	if err := s.DeleteOldestExecution(ctxFor(userAlice), "f_001"); err != nil {
		t.Fatalf("DeleteOldestExecution: %v", err)
	}
	n, _ = s.CountExecutions(ctxFor(userAlice), "f_001")
	if n != 2 {
		t.Errorf("want 2 after delete, got %d", n)
	}
}

func TestExecutionFilter_KindAndBatch(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	pass := true
	now := time.Now()
	// 2 run rows + 3 test rows in one batch.
	// 2 行 run + 3 行同批次 test。
	for i := range 2 {
		e := mkExecution(fmt.Sprintf("fe_run_%02d", i), "f_001", userAlice,
			forgedomain.ExecutionKindRun, now.Add(time.Duration(i)*time.Second))
		if err := s.SaveExecution(ctxFor(userAlice), e); err != nil {
			t.Fatal(err)
		}
	}
	for i := range 3 {
		e := mkExecution(fmt.Sprintf("fe_test_%02d", i), "f_001", userAlice,
			forgedomain.ExecutionKindTest, now.Add(time.Duration(10+i)*time.Second))
		e.TestCaseID = fmt.Sprintf("tc_%02d", i)
		e.BatchID = "batch_001"
		e.Pass = &pass
		if err := s.SaveExecution(ctxFor(userAlice), e); err != nil {
			t.Fatal(err)
		}
	}

	// Kind filter.
	runs, _, err := s.ListExecutions(ctxFor(userAlice), forgedomain.ExecutionFilter{
		ForgeID: "f_001", Kind: forgedomain.ExecutionKindRun,
	})
	if err != nil {
		t.Fatalf("ListExecutions kind=run: %v", err)
	}
	if len(runs) != 2 {
		t.Errorf("want 2 run rows, got %d", len(runs))
	}

	// Batch filter — expect ASC ordering.
	// batch 过滤——预期 ASC 排序。
	batch, _, err := s.ListExecutions(ctxFor(userAlice), forgedomain.ExecutionFilter{
		ForgeID: "f_001", BatchID: "batch_001",
	})
	if err != nil {
		t.Fatalf("ListExecutions batch: %v", err)
	}
	if len(batch) != 3 {
		t.Fatalf("want 3 batch rows, got %d", len(batch))
	}
	if batch[0].ID != "fe_test_00" || batch[2].ID != "fe_test_02" {
		t.Errorf("batch should be ASC, got order %s, %s, %s",
			batch[0].ID, batch[1].ID, batch[2].ID)
	}
}

func TestExecutionFilter_ChatContext(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	for i := range 3 {
		e := mkExecution(fmt.Sprintf("fe_%02d", i), "f_001", userAlice,
			forgedomain.ExecutionKindRun, now.Add(time.Duration(i)*time.Second))
		e.TriggeredBy = forgedomain.TriggeredByChat
		e.ConversationID = "cv_xyz"
		e.MessageID = fmt.Sprintf("msg_%02d", i)
		if err := s.SaveExecution(ctxFor(userAlice), e); err != nil {
			t.Fatal(err)
		}
	}
	// Filter by conversation: all 3.
	conv, _, err := s.ListExecutions(ctxFor(userAlice), forgedomain.ExecutionFilter{
		ConversationID: "cv_xyz",
	})
	if err != nil {
		t.Fatalf("ListExecutions conv: %v", err)
	}
	if len(conv) != 3 {
		t.Errorf("want 3 by conversation, got %d", len(conv))
	}
	// Filter by single message.
	msg, _, err := s.ListExecutions(ctxFor(userAlice), forgedomain.ExecutionFilter{
		MessageID: "msg_01",
	})
	if err != nil {
		t.Fatalf("ListExecutions msg: %v", err)
	}
	if len(msg) != 1 || msg[0].ID != "fe_01" {
		t.Errorf("want 1 row fe_01, got %v", msg)
	}
}

func TestExecutionPagination_Cursor(t *testing.T) {
	s := newStore(t)
	if err := s.SaveForge(ctxFor(userAlice), mkForge("f_001", userAlice, "forge")); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	for i := range 5 {
		e := mkExecution(fmt.Sprintf("fe_%02d", i), "f_001", userAlice,
			forgedomain.ExecutionKindRun, now.Add(time.Duration(i)*time.Second))
		if err := s.SaveExecution(ctxFor(userAlice), e); err != nil {
			t.Fatal(err)
		}
	}
	// First page (DESC; newest first): limit=2 → fe_04, fe_03.
	page1, next, err := s.ListExecutions(ctxFor(userAlice), forgedomain.ExecutionFilter{
		ForgeID: "f_001", Limit: 2,
	})
	if err != nil {
		t.Fatalf("page1: %v", err)
	}
	if len(page1) != 2 || page1[0].ID != "fe_04" || page1[1].ID != "fe_03" {
		t.Fatalf("page1 wrong: %v", page1)
	}
	if next == "" {
		t.Fatal("expected nextCursor on page1")
	}
	// Second page: fe_02, fe_01.
	page2, next2, err := s.ListExecutions(ctxFor(userAlice), forgedomain.ExecutionFilter{
		ForgeID: "f_001", Limit: 2, Cursor: next,
	})
	if err != nil {
		t.Fatalf("page2: %v", err)
	}
	if len(page2) != 2 || page2[0].ID != "fe_02" || page2[1].ID != "fe_01" {
		t.Errorf("page2 wrong: %v", page2)
	}
	if next2 == "" {
		t.Fatal("expected nextCursor on page2")
	}
	// Final page: fe_00, no nextCursor.
	page3, next3, err := s.ListExecutions(ctxFor(userAlice), forgedomain.ExecutionFilter{
		ForgeID: "f_001", Limit: 2, Cursor: next2,
	})
	if err != nil {
		t.Fatalf("page3: %v", err)
	}
	if len(page3) != 1 || page3[0].ID != "fe_00" {
		t.Errorf("page3 wrong: %v", page3)
	}
	if next3 != "" {
		t.Errorf("expected empty cursor on final page, got %q", next3)
	}
}
