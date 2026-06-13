package document

import (
	"context"
	"strings"
	"testing"

	"go.uber.org/zap"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	documentstore "github.com/sunweilin/forgify/backend/internal/infra/store/document"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// newToolSvc spins a real in-memory document Service (store + SQLite) under a workspace
// ctx — the tools are exercised end-to-end (tool → app → store), fully offline.
//
// newToolSvc 起一个真内存 document Service（store + SQLite）在 workspace ctx 下——工具被
// 端到端跑通（tool → app → store），全离线。
func newToolSvc(t *testing.T) (*documentapp.Service, context.Context) {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := dbinfra.Migrate(db, documentstore.Schema...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	svc := documentapp.NewService(documentstore.New(db), nil, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_test")
	return svc, ctx
}

func TestDocumentTools_NamesAndCount(t *testing.T) {
	svc, _ := newToolSvc(t)
	tools := DocumentTools(svc, nil)
	if len(tools) != 7 {
		t.Fatalf("want 7 tools, got %d", len(tools))
	}
	want := []string{"search_documents", "list_documents", "read_document", "create_document", "edit_document", "move_document", "delete_document"}
	names := map[string]bool{}
	for _, tl := range tools {
		names[tl.Name()] = true
	}
	for _, w := range want {
		if !names[w] {
			t.Fatalf("missing tool %s", w)
		}
	}
}

func TestCreateDocument_ToolAndAutoSuffix(t *testing.T) {
	svc, ctx := newToolSvc(t)
	out1, err := (&CreateDocument{svc: svc}).Execute(ctx, `{"name":"Note","content":"# A"}`)
	if err != nil {
		t.Fatalf("create 1: %v", err)
	}
	if !strings.Contains(out1, "Created document \"Note\"") {
		t.Fatalf("create 1 got %q", out1)
	}
	out2, err := (&CreateDocument{svc: svc}).Execute(ctx, `{"name":"Note","content":"# B"}`)
	if err != nil {
		t.Fatalf("create 2: %v", err)
	}
	if !strings.Contains(out2, "auto-renamed") || !strings.Contains(out2, "Note 2") {
		t.Fatalf("expected auto-rename note, got %q", out2)
	}
}

func TestReadDocument_RoundTrip(t *testing.T) {
	svc, ctx := newToolSvc(t)
	d, err := svc.Create(ctx, documentapp.CreateInput{Name: "PRD", Description: "product req", Content: "# Goals\nship it"})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	out, err := (&ReadDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(out, "# Goals") || !strings.Contains(out, d.Path) || !strings.Contains(out, "product req") {
		t.Fatalf("rendered doc missing fields: %q", out)
	}
}

func TestReadDocument_NotFoundSoftFails(t *testing.T) {
	svc, ctx := newToolSvc(t)
	out, err := (&ReadDocument{svc: svc}).Execute(ctx, `{"id":"doc_ghost"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(out, "not found") {
		t.Fatalf("got %q", out)
	}
}

func TestListDocuments_RootAndChild(t *testing.T) {
	svc, ctx := newToolSvc(t)
	root, _ := svc.Create(ctx, documentapp.CreateInput{Name: "Root"})
	if _, err := svc.Create(ctx, documentapp.CreateInput{Name: "Child", ParentID: &root.ID}); err != nil {
		t.Fatalf("seed child: %v", err)
	}
	rootOut, err := (&ListDocuments{svc: svc}).Execute(ctx, `{}`)
	if err != nil {
		t.Fatalf("list root: %v", err)
	}
	if !strings.Contains(rootOut, "Root") || strings.Contains(rootOut, "Child") {
		t.Fatalf("root list should show Root not Child: %q", rootOut)
	}
	childOut, err := (&ListDocuments{svc: svc}).Execute(ctx, `{"parentId":"`+root.ID+`"}`)
	if err != nil {
		t.Fatalf("list child: %v", err)
	}
	if !strings.Contains(childOut, "Child") {
		t.Fatalf("child list should show Child: %q", childOut)
	}
}

func TestSearchDocuments(t *testing.T) {
	svc, ctx := newToolSvc(t)
	if _, err := svc.Create(ctx, documentapp.CreateInput{Name: "Alpha", Description: "about alpha"}); err != nil {
		t.Fatalf("seed: %v", err)
	}
	hit, err := (&SearchDocuments{svc: svc}).Execute(ctx, `{"query":"alpha"}`)
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if !strings.Contains(hit, `"count":1`) || !strings.Contains(hit, "Alpha") {
		t.Fatalf("expected 1 hit for Alpha, got %q", hit)
	}
	miss, err := (&SearchDocuments{svc: svc}).Execute(ctx, `{"query":"zzzznope"}`)
	if err != nil {
		t.Fatalf("search miss: %v", err)
	}
	if !strings.Contains(miss, `"count":0`) {
		t.Fatalf("expected miss (count 0), got %q", miss)
	}
}

func TestEditDocument(t *testing.T) {
	svc, ctx := newToolSvc(t)
	d, _ := svc.Create(ctx, documentapp.CreateInput{Name: "Doc", Content: "old"})
	out, err := (&EditDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`","content":"new body"}`)
	if err != nil {
		t.Fatalf("edit: %v", err)
	}
	if !strings.Contains(out, "Updated document") {
		t.Fatalf("got %q", out)
	}
	got, _ := svc.Get(ctx, d.ID)
	if got.Content != "new body" {
		t.Fatalf("content not updated: %q", got.Content)
	}
	// Empty update is a friendly no-op.
	noop, err := (&EditDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`"}`)
	if err != nil {
		t.Fatalf("edit noop: %v", err)
	}
	if !strings.Contains(noop, "nothing to update") {
		t.Fatalf("got %q", noop)
	}
}

func TestMoveDocument(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, _ := svc.Create(ctx, documentapp.CreateInput{Name: "A"})
	b, _ := svc.Create(ctx, documentapp.CreateInput{Name: "B"})
	out, err := (&MoveDocument{svc: svc}).Execute(ctx, `{"id":"`+b.ID+`","parentId":"`+a.ID+`"}`)
	if err != nil {
		t.Fatalf("move: %v", err)
	}
	if !strings.Contains(out, "/A/B") {
		t.Fatalf("expected new path /A/B, got %q", out)
	}
	// Cycle: move A under B (now a descendant of A).
	cyc, err := (&MoveDocument{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","parentId":"`+b.ID+`"}`)
	if err != nil {
		t.Fatalf("move cycle: %v", err)
	}
	if !strings.Contains(cyc, "cycle") {
		t.Fatalf("expected cycle rejection, got %q", cyc)
	}
	// parentId omitted → friendly required hint.
	miss, err := (&MoveDocument{svc: svc}).Execute(ctx, `{"id":"`+b.ID+`"}`)
	if err != nil {
		t.Fatalf("move no-parent: %v", err)
	}
	if !strings.Contains(miss, "parentId required") {
		t.Fatalf("got %q", miss)
	}
}

func TestDeleteDocument_Cascade(t *testing.T) {
	svc, ctx := newToolSvc(t)
	root, _ := svc.Create(ctx, documentapp.CreateInput{Name: "Root"})
	if _, err := svc.Create(ctx, documentapp.CreateInput{Name: "Child", ParentID: &root.ID}); err != nil {
		t.Fatalf("seed child: %v", err)
	}
	out, err := (&DeleteDocument{svc: svc}).Execute(ctx, `{"id":"`+root.ID+`"}`)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	if !strings.Contains(out, "1 descendant") {
		t.Fatalf("expected cascade count, got %q", out)
	}
}

func TestValidateInput(t *testing.T) {
	if err := (&ReadDocument{}).ValidateInput([]byte(`{"id":""}`)); err == nil {
		t.Fatal("read: empty id should fail")
	}
	if err := (&SearchDocuments{}).ValidateInput([]byte(`{"query":""}`)); err == nil {
		t.Fatal("search: empty query should fail")
	}
	if err := (&CreateDocument{}).ValidateInput([]byte(`{"name":""}`)); err == nil {
		t.Fatal("create: empty name should fail")
	}
	if err := (&ListDocuments{}).ValidateInput(nil); err != nil {
		t.Fatalf("list: empty args should be allowed, got %v", err)
	}
}
