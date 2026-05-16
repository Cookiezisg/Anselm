package document

import (
	"context"
	"errors"
	"testing"

	gormlogger "gorm.io/gorm/logger"

	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(db) })
	if err := dbinfra.Migrate(db, AutoMigrateModels()...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return New(db)
}

func ctxFor() context.Context { return context.Background() }

const testUser = "local-user"

func mkRoot(id, name string) *documentdomain.Document {
	return &documentdomain.Document{
		ID:     id,
		UserID: testUser,
		Name:   name,
		Path:   "/" + name,
		Tags:   []string{},
	}
}

func mkChild(id, name, parentID, parentPath string) *documentdomain.Document {
	pid := parentID
	return &documentdomain.Document{
		ID:       id,
		UserID:   testUser,
		ParentID: &pid,
		Name:     name,
		Path:     parentPath + "/" + name,
		Tags:     []string{},
	}
}

func TestInsert_AndGet(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	d := mkRoot("doc_1", "Project Alpha")
	if err := s.Insert(ctx, d); err != nil {
		t.Fatalf("Insert: %v", err)
	}
	got, err := s.Get(ctx, testUser, "doc_1")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.Name != "Project Alpha" || got.Path != "/Project Alpha" {
		t.Errorf("Get mismatch: %+v", got)
	}
}

func TestGet_NotFound(t *testing.T) {
	s := newStore(t)
	_, err := s.Get(ctxFor(), testUser, "doc_missing")
	if !errors.Is(err, documentdomain.ErrNotFound) {
		t.Errorf("got %v, want ErrNotFound", err)
	}
}

func TestInsert_DuplicateName_SameParent(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	if err := s.Insert(ctx, mkRoot("doc_1", "Notes")); err != nil {
		t.Fatalf("first Insert: %v", err)
	}
	err := s.Insert(ctx, mkRoot("doc_2", "Notes"))
	if !errors.Is(err, documentdomain.ErrNameConflict) {
		t.Errorf("dupe root: got %v, want ErrNameConflict", err)
	}
}

func TestInsert_DuplicateName_RootLevel_TripsCOALESCEGuard(t *testing.T) {
	// Without COALESCE(parent_id, '') in the partial UNIQUE index, two roots with
	// the same name would slip through because SQLite treats NULL != NULL.
	//
	// 不加 COALESCE 时根级两条同名会漏(SQLite 视 NULL != NULL)。本测验证守卫到位。
	s := newStore(t)
	ctx := ctxFor()
	if err := s.Insert(ctx, mkRoot("doc_1", "Notes")); err != nil {
		t.Fatalf("first: %v", err)
	}
	if err := s.Insert(ctx, mkRoot("doc_2", "Notes")); !errors.Is(err, documentdomain.ErrNameConflict) {
		t.Errorf("second root same name: got %v, want ErrNameConflict", err)
	}
}

func TestInsert_SameName_DifferentParents_OK(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	if err := s.Insert(ctx, mkRoot("doc_p1", "Folder1")); err != nil {
		t.Fatalf("p1: %v", err)
	}
	if err := s.Insert(ctx, mkRoot("doc_p2", "Folder2")); err != nil {
		t.Fatalf("p2: %v", err)
	}
	if err := s.Insert(ctx, mkChild("doc_c1", "Notes", "doc_p1", "/Folder1")); err != nil {
		t.Fatalf("c1: %v", err)
	}
	if err := s.Insert(ctx, mkChild("doc_c2", "Notes", "doc_p2", "/Folder2")); err != nil {
		t.Errorf("same name under different parent should succeed: %v", err)
	}
}

func TestInsert_SoftDeletedReleasesName(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	if err := s.Insert(ctx, mkRoot("doc_1", "Notes")); err != nil {
		t.Fatalf("first: %v", err)
	}
	if _, err := s.SoftDeleteSubtree(ctx, testUser, "doc_1"); err != nil {
		t.Fatalf("SoftDelete: %v", err)
	}
	if err := s.Insert(ctx, mkRoot("doc_2", "Notes")); err != nil {
		t.Errorf("after soft-delete name should be reusable: %v", err)
	}
}

func TestListByParent_RootAndChildren(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	_ = s.Insert(ctx, mkRoot("doc_r1", "ProjA"))
	_ = s.Insert(ctx, mkRoot("doc_r2", "ProjB"))
	_ = s.Insert(ctx, mkChild("doc_c1", "spec", "doc_r1", "/ProjA"))
	_ = s.Insert(ctx, mkChild("doc_c2", "tasks", "doc_r1", "/ProjA"))

	roots, err := s.ListByParent(ctx, testUser, nil)
	if err != nil {
		t.Fatalf("ListByParent(nil): %v", err)
	}
	if len(roots) != 2 {
		t.Errorf("roots count = %d, want 2", len(roots))
	}

	pa := "doc_r1"
	children, err := s.ListByParent(ctx, testUser, &pa)
	if err != nil {
		t.Fatalf("ListByParent(doc_r1): %v", err)
	}
	if len(children) != 2 {
		t.Errorf("children count = %d, want 2", len(children))
	}
}

func TestGetBatch_PreservesUserScope(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	_ = s.Insert(ctx, mkRoot("doc_1", "A"))
	_ = s.Insert(ctx, mkRoot("doc_2", "B"))
	rows, err := s.GetBatch(ctx, testUser, []string{"doc_1", "doc_2", "doc_missing"})
	if err != nil {
		t.Fatalf("GetBatch: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("GetBatch len = %d, want 2 (silent miss for unknown id)", len(rows))
	}
	// Cross-user query returns nothing.
	other, err := s.GetBatch(ctx, "another-user", []string{"doc_1"})
	if err != nil {
		t.Fatalf("GetBatch cross-user: %v", err)
	}
	if len(other) != 0 {
		t.Errorf("cross-user leak: got %d rows", len(other))
	}
}

func TestSearch_NameAndDescription(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	d1 := mkRoot("doc_1", "API spec")
	d1.Description = "REST API contract"
	d2 := mkRoot("doc_2", "Roadmap")
	d2.Description = "Q1 plan"
	d3 := mkRoot("doc_3", "Daily log")
	d3.Description = "API call notes"
	for _, d := range []*documentdomain.Document{d1, d2, d3} {
		if err := s.Insert(ctx, d); err != nil {
			t.Fatalf("Insert %s: %v", d.Name, err)
		}
	}
	rows, err := s.Search(ctx, testUser, "API", 10)
	if err != nil {
		t.Fatalf("Search: %v", err)
	}
	if len(rows) != 2 {
		t.Errorf("Search hits = %d, want 2 (name match + description match)", len(rows))
	}
}

func TestIsAncestor_PositiveAndNegative(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	_ = s.Insert(ctx, mkRoot("doc_root", "Root"))
	_ = s.Insert(ctx, mkChild("doc_mid", "Mid", "doc_root", "/Root"))
	_ = s.Insert(ctx, mkChild("doc_leaf", "Leaf", "doc_mid", "/Root/Mid"))

	tests := []struct {
		anc, desc string
		want      bool
		label     string
	}{
		{"doc_root", "doc_leaf", true, "root is ancestor of leaf"},
		{"doc_mid", "doc_leaf", true, "mid is ancestor of leaf"},
		{"doc_leaf", "doc_root", false, "leaf is not ancestor of root"},
		{"doc_leaf", "doc_leaf", true, "self counts as ancestor (cycle detection)"},
		{"doc_root", "doc_missing", false, "descendant missing → false"},
	}
	for _, tc := range tests {
		got, err := s.IsAncestor(ctx, testUser, tc.anc, tc.desc)
		if err != nil {
			t.Errorf("%s: err %v", tc.label, err)
			continue
		}
		if got != tc.want {
			t.Errorf("%s: got %v, want %v", tc.label, got, tc.want)
		}
	}
}

func TestSoftDeleteSubtree_CascadesToDescendants(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	_ = s.Insert(ctx, mkRoot("doc_root", "Root"))
	_ = s.Insert(ctx, mkChild("doc_mid", "Mid", "doc_root", "/Root"))
	_ = s.Insert(ctx, mkChild("doc_leaf", "Leaf", "doc_mid", "/Root/Mid"))
	_ = s.Insert(ctx, mkChild("doc_sib", "Sib", "doc_root", "/Root"))

	n, err := s.SoftDeleteSubtree(ctx, testUser, "doc_root")
	if err != nil {
		t.Fatalf("SoftDeleteSubtree: %v", err)
	}
	if n != 4 {
		t.Errorf("deletedCount = %d, want 4 (root + 3 descendants)", n)
	}

	if _, err := s.Get(ctx, testUser, "doc_leaf"); !errors.Is(err, documentdomain.ErrNotFound) {
		t.Errorf("descendant should be soft-deleted: %v", err)
	}
}

func TestSoftDeleteSubtree_RootMissing_ReturnsNotFound(t *testing.T) {
	s := newStore(t)
	_, err := s.SoftDeleteSubtree(ctxFor(), testUser, "doc_missing")
	if !errors.Is(err, documentdomain.ErrNotFound) {
		t.Errorf("got %v, want ErrNotFound", err)
	}
}

func TestCountChildren_AndCountDescendants(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	_ = s.Insert(ctx, mkRoot("doc_root", "Root"))
	_ = s.Insert(ctx, mkChild("doc_a", "A", "doc_root", "/Root"))
	_ = s.Insert(ctx, mkChild("doc_b", "B", "doc_root", "/Root"))
	_ = s.Insert(ctx, mkChild("doc_a1", "A1", "doc_a", "/Root/A"))

	if n, _ := s.CountChildren(ctx, testUser, "doc_root"); n != 2 {
		t.Errorf("CountChildren(root) = %d, want 2 (direct only)", n)
	}
	if n, _ := s.CountDescendants(ctx, testUser, "doc_root"); n != 3 {
		t.Errorf("CountDescendants(root) = %d, want 3 (A + B + A1)", n)
	}
	if n, _ := s.CountDescendants(ctx, testUser, "doc_a"); n != 1 {
		t.Errorf("CountDescendants(A) = %d, want 1 (A1)", n)
	}
}

func TestMaxSiblingPosition(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	d1 := mkRoot("doc_1", "First")
	d1.Position = 0
	d2 := mkRoot("doc_2", "Second")
	d2.Position = 1
	d3 := mkRoot("doc_3", "Third")
	d3.Position = 4
	for _, d := range []*documentdomain.Document{d1, d2, d3} {
		if err := s.Insert(ctx, d); err != nil {
			t.Fatalf("Insert: %v", err)
		}
	}
	max, err := s.MaxSiblingPosition(ctx, testUser, nil)
	if err != nil {
		t.Fatalf("MaxSiblingPosition: %v", err)
	}
	if max != 4 {
		t.Errorf("max = %d, want 4", max)
	}

	emptyMax, err := s.MaxSiblingPosition(ctx, testUser, ptr("doc_no_kids"))
	if err != nil {
		t.Fatalf("empty MaxSiblingPosition: %v", err)
	}
	if emptyMax != -1 {
		t.Errorf("empty siblings should return -1; got %d", emptyMax)
	}
}

func TestUpdate_ContentAndName(t *testing.T) {
	s := newStore(t)
	ctx := ctxFor()
	d := mkRoot("doc_1", "Original")
	if err := s.Insert(ctx, d); err != nil {
		t.Fatalf("Insert: %v", err)
	}
	d.Name = "Renamed"
	d.Path = "/Renamed"
	d.Content = "new body"
	if err := s.Update(ctx, d); err != nil {
		t.Fatalf("Update: %v", err)
	}
	got, _ := s.Get(ctx, testUser, "doc_1")
	if got.Name != "Renamed" || got.Content != "new body" {
		t.Errorf("Update lost fields: %+v", got)
	}
}

func ptr[T any](v T) *T { return &v }
