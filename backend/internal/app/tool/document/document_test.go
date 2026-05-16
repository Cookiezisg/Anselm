package document

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"go.uber.org/zap"
	gormlogger "gorm.io/gorm/logger"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	documentstore "github.com/sunweilin/forgify/backend/internal/infra/store/document"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func newService(t *testing.T) *documentapp.Service {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{LogLevel: gormlogger.Silent})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = dbinfra.Close(db) })
	if err := dbinfra.Migrate(db, documentstore.AutoMigrateModels()...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return documentapp.New(documentstore.New(db), nil, zap.NewNop())
}

func ctxFor() context.Context {
	return reqctxpkg.SetUserID(context.Background(), "local-user")
}

func execTool(t *testing.T, tool toolapp.Tool, args string) (string, error) {
	t.Helper()
	return tool.Execute(ctxFor(), args)
}

func TestDocumentTools_FactoryReturnsAllSeven(t *testing.T) {
	svc := newService(t)
	tools := DocumentTools(svc)
	if len(tools) != 7 {
		t.Fatalf("DocumentTools() = %d tools, want 7", len(tools))
	}
	names := map[string]bool{}
	for _, tl := range tools {
		names[tl.Name()] = true
	}
	want := []string{
		"search_documents", "list_documents", "read_document",
		"create_document", "edit_document", "move_document", "delete_document",
	}
	for _, n := range want {
		if !names[n] {
			t.Errorf("missing tool %q in factory output", n)
		}
	}
}

func TestCreateDocument_Root(t *testing.T) {
	svc := newService(t)
	tl := &CreateDocument{svc: svc}
	out, err := execTool(t, tl, `{"name": "Project Alpha"}`)
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "Created document") || !strings.Contains(out, "/Project Alpha") {
		t.Errorf("unexpected output: %s", out)
	}
}

func TestCreateDocument_Child(t *testing.T) {
	svc := newService(t)
	parent, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "Parent"})
	tl := &CreateDocument{svc: svc}
	args, _ := json.Marshal(map[string]any{"name": "Spec", "parentId": parent.ID})
	out, err := execTool(t, tl, string(args))
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "/Parent/Spec") {
		t.Errorf("child path missing: %s", out)
	}
}

func TestCreateDocument_DuplicateName_GracefulMessage(t *testing.T) {
	svc := newService(t)
	tl := &CreateDocument{svc: svc}
	_, _ = execTool(t, tl, `{"name": "X"}`)
	out, err := execTool(t, tl, `{"name": "X"}`)
	if err != nil {
		t.Fatalf("duplicate should be friendly, not error: %v", err)
	}
	if !strings.Contains(out, "already exists") {
		t.Errorf("expected friendly conflict message; got: %s", out)
	}
}

func TestCreateDocument_ValidateInput_RejectsEmptyName(t *testing.T) {
	tl := &CreateDocument{}
	if err := tl.ValidateInput(json.RawMessage(`{"name": "   "}`)); err == nil {
		t.Error("whitespace-only name should fail validate")
	}
}

func TestReadDocument_NotFound_FriendlyMessage(t *testing.T) {
	svc := newService(t)
	tl := &ReadDocument{svc: svc}
	out, err := execTool(t, tl, `{"id": "doc_missing"}`)
	if err != nil {
		t.Fatalf("not-found should be friendly, not error: %v", err)
	}
	if !strings.Contains(out, "not found") {
		t.Errorf("expected friendly not-found message; got: %s", out)
	}
}

func TestReadDocument_FetchesFullContent(t *testing.T) {
	svc := newService(t)
	d, _ := svc.Create(ctxFor(), documentapp.CreateInput{
		Name:    "API Spec",
		Content: "# API v2\n\nEndpoints:\n- GET /foo",
		Tags:    []string{"api", "spec"},
	})
	tl := &ReadDocument{svc: svc}
	out, err := execTool(t, tl, `{"id": "`+d.ID+`"}`)
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	for _, want := range []string{"API Spec", "/API Spec", "api, spec", "Endpoints"} {
		if !strings.Contains(out, want) {
			t.Errorf("read output missing %q; got: %s", want, out)
		}
	}
}

func TestListDocuments_Root_EmptyMessage(t *testing.T) {
	svc := newService(t)
	tl := &ListDocuments{svc: svc}
	out, err := execTool(t, tl, `{}`)
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "No documents") {
		t.Errorf("empty list should say no docs; got: %s", out)
	}
}

func TestListDocuments_Root_WithChildren(t *testing.T) {
	svc := newService(t)
	_, _ = svc.Create(ctxFor(), documentapp.CreateInput{Name: "A"})
	_, _ = svc.Create(ctxFor(), documentapp.CreateInput{Name: "B"})
	tl := &ListDocuments{svc: svc}
	out, err := execTool(t, tl, ``)
	if err != nil {
		t.Fatalf("empty argsJSON should default to root: %v", err)
	}
	if !strings.Contains(out, "2 document(s)") {
		t.Errorf("expected count 2; got: %s", out)
	}
}

func TestListDocuments_UnderParent(t *testing.T) {
	svc := newService(t)
	parent, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "Parent"})
	_, _ = svc.Create(ctxFor(), documentapp.CreateInput{Name: "child1", ParentID: &parent.ID})
	_, _ = svc.Create(ctxFor(), documentapp.CreateInput{Name: "child2", ParentID: &parent.ID})
	tl := &ListDocuments{svc: svc}
	args, _ := json.Marshal(map[string]any{"parentId": parent.ID})
	out, err := execTool(t, tl, string(args))
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "child1") || !strings.Contains(out, "child2") {
		t.Errorf("children missing: %s", out)
	}
}

func TestSearchDocuments_FindsByName(t *testing.T) {
	svc := newService(t)
	_, _ = svc.Create(ctxFor(), documentapp.CreateInput{Name: "API Spec", Description: "REST contract"})
	_, _ = svc.Create(ctxFor(), documentapp.CreateInput{Name: "Roadmap", Description: "Q1 plan"})
	tl := &SearchDocuments{svc: svc}
	out, err := execTool(t, tl, `{"query": "API"}`)
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "API Spec") {
		t.Errorf("search missing match: %s", out)
	}
}

func TestSearchDocuments_NoMatchFriendly(t *testing.T) {
	svc := newService(t)
	tl := &SearchDocuments{svc: svc}
	out, err := execTool(t, tl, `{"query": "nothing"}`)
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "No documents matched") {
		t.Errorf("expected no-match message: %s", out)
	}
}

func TestEditDocument_PatchSubsetOfFields(t *testing.T) {
	svc := newService(t)
	d, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "Orig", Description: "old"})
	tl := &EditDocument{svc: svc}
	args, _ := json.Marshal(map[string]any{
		"id":          d.ID,
		"description": "fresh",
	})
	out, err := execTool(t, tl, string(args))
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "Updated document") {
		t.Errorf("expected success msg: %s", out)
	}
	// Confirm rename did NOT happen (only description changed).
	got, _ := svc.Get(ctxFor(), d.ID)
	if got.Name != "Orig" {
		t.Errorf("name should be untouched; got %q", got.Name)
	}
	if got.Description != "fresh" {
		t.Errorf("description = %q", got.Description)
	}
}

func TestEditDocument_NothingToUpdate(t *testing.T) {
	svc := newService(t)
	d, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "X"})
	tl := &EditDocument{svc: svc}
	out, _ := execTool(t, tl, `{"id": "`+d.ID+`"}`)
	if !strings.Contains(out, "nothing to update") {
		t.Errorf("expected friendly hint; got: %s", out)
	}
}

func TestMoveDocument_RequiresExplicitParentId(t *testing.T) {
	svc := newService(t)
	d, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "X"})
	tl := &MoveDocument{svc: svc}
	out, _ := execTool(t, tl, `{"id": "`+d.ID+`"}`)
	if !strings.Contains(out, "parentId required") {
		t.Errorf("expected missing-parent hint; got: %s", out)
	}
}

func TestMoveDocument_ToNewParent(t *testing.T) {
	svc := newService(t)
	a, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "A"})
	b, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "B"})
	child, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "child", ParentID: &a.ID})
	tl := &MoveDocument{svc: svc}
	args, _ := json.Marshal(map[string]any{
		"id":       child.ID,
		"parentId": b.ID,
	})
	out, err := execTool(t, tl, string(args))
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "/B/child") {
		t.Errorf("post-move path missing in msg: %s", out)
	}
}

func TestMoveDocument_CycleRejected(t *testing.T) {
	svc := newService(t)
	root, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "root"})
	leaf, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "leaf", ParentID: &root.ID})
	tl := &MoveDocument{svc: svc}
	args, _ := json.Marshal(map[string]any{"id": root.ID, "parentId": leaf.ID})
	out, err := execTool(t, tl, string(args))
	if err != nil {
		t.Fatalf("cycle should be friendly: %v", err)
	}
	if !strings.Contains(out, "cycle") {
		t.Errorf("expected cycle message; got: %s", out)
	}
}

func TestDeleteDocument_Recursive(t *testing.T) {
	svc := newService(t)
	root, _ := svc.Create(ctxFor(), documentapp.CreateInput{Name: "root"})
	_, _ = svc.Create(ctxFor(), documentapp.CreateInput{Name: "child", ParentID: &root.ID})
	tl := &DeleteDocument{svc: svc}
	out, err := execTool(t, tl, `{"id": "`+root.ID+`"}`)
	if err != nil {
		t.Fatalf("exec: %v", err)
	}
	if !strings.Contains(out, "1 descendant") {
		t.Errorf("expected '1 descendant' in msg; got: %s", out)
	}
}

func TestDeleteDocument_NotFoundFriendly(t *testing.T) {
	svc := newService(t)
	tl := &DeleteDocument{svc: svc}
	out, err := execTool(t, tl, `{"id": "doc_missing"}`)
	if err != nil {
		t.Fatalf("should be friendly: %v", err)
	}
	if !strings.Contains(out, "not found") {
		t.Errorf("expected not-found message: %s", out)
	}
}

func TestToolsStaticMetadata(t *testing.T) {
	svc := newService(t)
	cases := []struct {
		t          toolapp.Tool
		name       string
		isReadOnly bool
	}{
		{&SearchDocuments{svc: svc}, "search_documents", true},
		{&ListDocuments{svc: svc}, "list_documents", true},
		{&ReadDocument{svc: svc}, "read_document", true},
		{&CreateDocument{svc: svc}, "create_document", false},
		{&EditDocument{svc: svc}, "edit_document", false},
		{&MoveDocument{svc: svc}, "move_document", false},
		{&DeleteDocument{svc: svc}, "delete_document", false},
	}
	for _, c := range cases {
		if c.t.Name() != c.name {
			t.Errorf("Name() = %q, want %q", c.t.Name(), c.name)
		}
		if c.t.IsReadOnly() != c.isReadOnly {
			t.Errorf("%s IsReadOnly() = %v, want %v", c.name, c.t.IsReadOnly(), c.isReadOnly)
		}
		if c.t.NeedsReadFirst() {
			t.Errorf("%s NeedsReadFirst should be false", c.name)
		}
		if c.t.RequiresWorkspace() {
			t.Errorf("%s RequiresWorkspace should be false", c.name)
		}
	}
}
