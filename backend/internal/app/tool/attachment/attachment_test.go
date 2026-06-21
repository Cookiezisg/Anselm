package attachment

import (
	"context"
	"database/sql"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	blobfs "github.com/sunweilin/anselm/backend/internal/infra/fs/blob"
	attachmentstore "github.com/sunweilin/anselm/backend/internal/infra/store/attachment"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// newToolSvc wires a real attachment Service (metadata store + temp-dir CAS blob store) under a
// workspace ctx — the tools are exercised end-to-end (tool → app → store/blob), fully offline.
// No extractor is configured: text attachments inline natively, documents would degrade (not
// needed here — read coverage uses a text upload).
//
// newToolSvc 起一个真 attachment Service（元数据 store + temp 目录 CAS blob）在 workspace ctx 下
// ——工具被端到端跑通（tool → app → store/blob），全离线。不配 extractor：文本附件原生内联。
func newToolSvc(t *testing.T) (*attachmentapp.Service, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range attachmentstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	svc := attachmentapp.NewService(attachmentstore.New(ormpkg.Open(sqlDB)), blobfs.New(t.TempDir()), nil, zap.NewNop())
	return svc, reqctxpkg.SetWorkspaceID(context.Background(), "ws_test")
}

func TestAttachmentTools_NamesAndCount(t *testing.T) {
	svc, _ := newToolSvc(t)
	tools := AttachmentTools(svc)
	if len(tools) != 2 {
		t.Fatalf("want 2 tools, got %d", len(tools))
	}
	want := map[string]bool{"list_attachments": false, "read_attachment": false}
	for _, tl := range tools {
		if _, ok := want[tl.Name()]; !ok {
			t.Fatalf("unexpected tool %s", tl.Name())
		}
		want[tl.Name()] = true
	}
	for name, seen := range want {
		if !seen {
			t.Fatalf("missing tool %s", name)
		}
	}
}

func TestListAttachments_ReturnsUploaded(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "notes.txt", "text/plain", []byte("hello world"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ListAttachments{svc: svc}).Execute(ctx, ``)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if !strings.Contains(out, `"count":1`) || !strings.Contains(out, a.ID) || !strings.Contains(out, "notes.txt") {
		t.Fatalf("list should show the uploaded attachment: %q", out)
	}
	if !strings.Contains(out, `"kind":"text"`) || !strings.Contains(out, `"mime":"text/plain"`) {
		t.Fatalf("list missing kind/mime fields: %q", out)
	}
}

func TestReadAttachment_TextContent(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "readme.md", "text/markdown", []byte("# Title\nbody line"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(out, "# Title") || !strings.Contains(out, "body line") {
		t.Fatalf("read should return the text content: %q", out)
	}
}

func TestReadAttachment_BinaryDescriptor(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "photo.png", "image/png", []byte("\x89PNG fake bytes"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	// A descriptor, not bytes: filename + kind + the can't-extract note + the vision-honesty (F151:
	// don't imply attaching guarantees a text-only model can see the image).
	if !strings.Contains(out, "photo.png") || !strings.Contains(out, "image") ||
		!strings.Contains(out, "cannot turn its content into text") || !strings.Contains(out, "vision") {
		t.Fatalf("read of binary should return an honest descriptor: %q", out)
	}
}

func TestReadAttachment_UnknownIDSoftFails(t *testing.T) {
	svc, ctx := newToolSvc(t)
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"att_ghost"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(out, "not found") || !strings.Contains(out, "list_attachments") {
		t.Fatalf("unknown id should soft-fail with a hint: %q", out)
	}
}

func TestReadAttachment_ValidateInput(t *testing.T) {
	if err := (&ReadAttachment{}).ValidateInput([]byte(`{"id":""}`)); err == nil {
		t.Fatal("empty id should fail validation")
	}
	if err := (&ReadAttachment{}).ValidateInput([]byte(`{"id":"att_1"}`)); err != nil {
		t.Fatalf("non-empty id should pass, got %v", err)
	}
	if err := (&ListAttachments{}).ValidateInput(nil); err != nil {
		t.Fatalf("list takes no args, got %v", err)
	}
}
