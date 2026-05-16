package document

import (
	"context"
	"errors"
	"strings"
	"testing"

	"go.uber.org/zap"
	gormlogger "gorm.io/gorm/logger"

	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	documentstore "github.com/sunweilin/forgify/backend/internal/infra/store/document"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

const testUser = "local-user"

func newService(t *testing.T) *Service {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(db) })
	if err := dbinfra.Migrate(db, documentstore.AutoMigrateModels()...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return New(documentstore.New(db), nil, zap.NewNop())
}

func userCtx() context.Context {
	return reqctxpkg.SetUserID(context.Background(), testUser)
}

func TestService_Create_Root(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	d, err := s.Create(ctx, CreateInput{Name: "Project Alpha"})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if d.Path != "/Project Alpha" {
		t.Errorf("Path = %q, want /Project Alpha", d.Path)
	}
	if d.ParentID != nil {
		t.Errorf("root should have nil ParentID; got %v", d.ParentID)
	}
	if !strings.HasPrefix(d.ID, "doc_") {
		t.Errorf("ID prefix wrong: %s", d.ID)
	}
}

func TestService_Create_Child_PathInherits(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	parent, _ := s.Create(ctx, CreateInput{Name: "ProjA"})
	child, err := s.Create(ctx, CreateInput{Name: "spec", ParentID: &parent.ID})
	if err != nil {
		t.Fatalf("Create child: %v", err)
	}
	if child.Path != "/ProjA/spec" {
		t.Errorf("child Path = %q, want /ProjA/spec", child.Path)
	}
}

func TestService_Create_MissingParent(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	missing := "doc_missing"
	_, err := s.Create(ctx, CreateInput{Name: "x", ParentID: &missing})
	if !errors.Is(err, documentdomain.ErrParentNotFound) {
		t.Errorf("got %v, want ErrParentNotFound", err)
	}
}

func TestService_Create_InvalidName(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	tests := []struct {
		label string
		name  string
	}{
		{"empty", ""},
		{"only spaces", "   "},
		{"contains slash", "foo/bar"},
		{"too long", strings.Repeat("x", documentdomain.MaxNameLength+1)},
	}
	for _, tc := range tests {
		_, err := s.Create(ctx, CreateInput{Name: tc.name})
		if !errors.Is(err, documentdomain.ErrInvalidName) {
			t.Errorf("%s: got %v, want ErrInvalidName", tc.label, err)
		}
	}
}

func TestService_Create_ContentTooLarge(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	big := strings.Repeat("x", documentdomain.MaxContentBytes+1)
	_, err := s.Create(ctx, CreateInput{Name: "huge", Content: big})
	if !errors.Is(err, documentdomain.ErrContentTooLarge) {
		t.Errorf("got %v, want ErrContentTooLarge", err)
	}
}

func TestService_Create_NameConflict(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	if _, err := s.Create(ctx, CreateInput{Name: "Notes"}); err != nil {
		t.Fatalf("first: %v", err)
	}
	_, err := s.Create(ctx, CreateInput{Name: "Notes"})
	if !errors.Is(err, documentdomain.ErrNameConflict) {
		t.Errorf("got %v, want ErrNameConflict", err)
	}
}

func TestService_Update_Rename_CascadesSubtreePaths(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	root, _ := s.Create(ctx, CreateInput{Name: "Original"})
	mid, _ := s.Create(ctx, CreateInput{Name: "Mid", ParentID: &root.ID})
	leaf, _ := s.Create(ctx, CreateInput{Name: "Leaf", ParentID: &mid.ID})

	newName := "Renamed"
	if _, err := s.Update(ctx, root.ID, UpdateInput{Name: &newName}); err != nil {
		t.Fatalf("Update rename: %v", err)
	}

	gotMid, _ := s.Get(ctx, mid.ID)
	if gotMid.Path != "/Renamed/Mid" {
		t.Errorf("mid Path = %q, want /Renamed/Mid (cascade missed)", gotMid.Path)
	}
	gotLeaf, _ := s.Get(ctx, leaf.ID)
	if gotLeaf.Path != "/Renamed/Mid/Leaf" {
		t.Errorf("leaf Path = %q, want /Renamed/Mid/Leaf (deep cascade missed)", gotLeaf.Path)
	}
}

func TestService_Update_ContentSize(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	d, _ := s.Create(ctx, CreateInput{Name: "doc"})
	body := "hello world"
	if _, err := s.Update(ctx, d.ID, UpdateInput{Content: &body}); err != nil {
		t.Fatalf("Update: %v", err)
	}
	got, _ := s.Get(ctx, d.ID)
	if got.SizeBytes != int64(len(body)) {
		t.Errorf("SizeBytes = %d, want %d", got.SizeBytes, len(body))
	}
}

func TestService_Move_ToNewParent_CascadesPaths(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	a, _ := s.Create(ctx, CreateInput{Name: "A"})
	b, _ := s.Create(ctx, CreateInput{Name: "B"})
	aChild, _ := s.Create(ctx, CreateInput{Name: "spec", ParentID: &a.ID})
	aGrand, _ := s.Create(ctx, CreateInput{Name: "deep", ParentID: &aChild.ID})

	if _, err := s.Move(ctx, aChild.ID, MoveInput{ParentID: &b.ID}); err != nil {
		t.Fatalf("Move: %v", err)
	}
	gotChild, _ := s.Get(ctx, aChild.ID)
	if gotChild.Path != "/B/spec" {
		t.Errorf("moved child Path = %q, want /B/spec", gotChild.Path)
	}
	gotGrand, _ := s.Get(ctx, aGrand.ID)
	if gotGrand.Path != "/B/spec/deep" {
		t.Errorf("moved grandchild Path = %q, want /B/spec/deep", gotGrand.Path)
	}
}

func TestService_Move_RejectsSelfParent(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	d, _ := s.Create(ctx, CreateInput{Name: "x"})
	_, err := s.Move(ctx, d.ID, MoveInput{ParentID: &d.ID})
	if !errors.Is(err, documentdomain.ErrInvalidParent) {
		t.Errorf("self-parent: got %v, want ErrInvalidParent", err)
	}
}

func TestService_Move_RejectsDescendantAsParent(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	root, _ := s.Create(ctx, CreateInput{Name: "root"})
	mid, _ := s.Create(ctx, CreateInput{Name: "mid", ParentID: &root.ID})
	leaf, _ := s.Create(ctx, CreateInput{Name: "leaf", ParentID: &mid.ID})

	_, err := s.Move(ctx, root.ID, MoveInput{ParentID: &leaf.ID})
	if !errors.Is(err, documentdomain.ErrInvalidParent) {
		t.Errorf("cycle: got %v, want ErrInvalidParent", err)
	}
}

func TestService_Move_ToRoot(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	a, _ := s.Create(ctx, CreateInput{Name: "A"})
	child, _ := s.Create(ctx, CreateInput{Name: "child", ParentID: &a.ID})
	if _, err := s.Move(ctx, child.ID, MoveInput{ParentID: nil}); err != nil {
		t.Fatalf("Move to root: %v", err)
	}
	got, _ := s.Get(ctx, child.ID)
	if got.ParentID != nil {
		t.Errorf("moved-to-root ParentID = %v, want nil", got.ParentID)
	}
	if got.Path != "/child" {
		t.Errorf("Path = %q, want /child", got.Path)
	}
}

func TestService_Delete_Recursive(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	root, _ := s.Create(ctx, CreateInput{Name: "root"})
	mid, _ := s.Create(ctx, CreateInput{Name: "mid", ParentID: &root.ID})
	_, _ = s.Create(ctx, CreateInput{Name: "leaf", ParentID: &mid.ID})
	_, _ = s.Create(ctx, CreateInput{Name: "sib", ParentID: &root.ID})

	n, err := s.Delete(ctx, root.ID)
	if err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if n != 4 {
		t.Errorf("deletedCount = %d, want 4", n)
	}
	if _, err := s.Get(ctx, root.ID); !errors.Is(err, documentdomain.ErrNotFound) {
		t.Errorf("root should be soft-deleted; got %v", err)
	}
}

func TestService_CountDescendants_BeforeDelete(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	root, _ := s.Create(ctx, CreateInput{Name: "root"})
	_, _ = s.Create(ctx, CreateInput{Name: "a", ParentID: &root.ID})
	b, _ := s.Create(ctx, CreateInput{Name: "b", ParentID: &root.ID})
	_, _ = s.Create(ctx, CreateInput{Name: "b1", ParentID: &b.ID})

	n, err := s.CountDescendants(ctx, root.ID)
	if err != nil {
		t.Fatalf("CountDescendants: %v", err)
	}
	if n != 3 {
		t.Errorf("count = %d, want 3", n)
	}
}

func TestService_ListAll_OrderedByPath(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	_, _ = s.Create(ctx, CreateInput{Name: "Zeta"})
	_, _ = s.Create(ctx, CreateInput{Name: "Alpha"})
	_, _ = s.Create(ctx, CreateInput{Name: "Beta"})
	rows, err := s.ListAll(ctx)
	if err != nil {
		t.Fatalf("ListAll: %v", err)
	}
	if len(rows) != 3 {
		t.Fatalf("len = %d, want 3", len(rows))
	}
	if rows[0].Name != "Alpha" || rows[2].Name != "Zeta" {
		t.Errorf("ListAll not path-sorted: got %s, %s, %s", rows[0].Name, rows[1].Name, rows[2].Name)
	}
}

func TestService_MissingUserID(t *testing.T) {
	s := newService(t)
	_, err := s.Create(context.Background(), CreateInput{Name: "x"})
	if !errors.Is(err, reqctxpkg.ErrMissingUserID) {
		t.Errorf("got %v, want ErrMissingUserID", err)
	}
}
