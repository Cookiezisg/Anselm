package attachment

import (
	"bytes"
	"context"
	"database/sql"
	"image"
	"image/color"
	"image/png"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	blobfs "github.com/sunweilin/anselm/backend/internal/infra/fs/blob"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
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
	tools := AttachmentTools(svc, nil)
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

func TestAttachmentTools_WithInspectMedia(t *testing.T) {
	svc, _ := newToolSvc(t)
	tools := AttachmentTools(svc, fakeInspectResolver{})
	if len(tools) != 3 {
		t.Fatalf("want 3 tools, got %d", len(tools))
	}
	want := map[string]bool{"list_attachments": false, "read_attachment": false, "inspect_media": false}
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

func TestReadAttachment_TextPagination(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "long.txt", "text/plain", []byte(strings.Repeat("abcdef", 10)))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","limitChars":40}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(out, `Attached file "long.txt"`) ||
		!strings.Contains(out, "nextOffset=40") ||
		!strings.Contains(out, "totalChars=") {
		t.Fatalf("first page should preserve the template and advertise nextOffset: %q", out)
	}
	next, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","offset":40,"limitChars":40}`)
	if err != nil {
		t.Fatalf("read next: %v", err)
	}
	if strings.Contains(next, `Attached file "long.txt"`) || !strings.Contains(next, "offset=40") {
		t.Fatalf("offset page should return the requested slice with pagination footer: %q", next)
	}
	empty, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","offset":999,"limitChars":40}`)
	if err != nil {
		t.Fatalf("read empty: %v", err)
	}
	if !strings.Contains(empty, "No attachment text at offset 999") {
		t.Fatalf("out-of-range offset should self-correct: %q", empty)
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
	if err := (&ReadAttachment{}).ValidateInput([]byte(`{"id":"att_1","offset":-1}`)); err == nil {
		t.Fatal("negative offset should fail validation")
	}
	if err := (&ReadAttachment{}).ValidateInput([]byte(`{"id":"att_1","limitChars":120001}`)); err == nil {
		t.Fatal("oversized limit should fail validation")
	}
	if err := (&ListAttachments{}).ValidateInput(nil); err != nil {
		t.Fatalf("list takes no args, got %v", err)
	}
}

func TestInspectMedia_ImageUsesVisionModelAndReturnsBoundedTextEvidence(t *testing.T) {
	svc, ctx := newToolSvc(t)
	img := testPNG(t, color.NRGBA{R: 255, A: 255})
	a, err := svc.Upload(ctx, "red.png", "image/png", img)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	client := llminfra.NewMockClient()
	client.PushScript(llminfra.MockScript{Events: []llminfra.StreamEvent{
		{Type: llminfra.EventText, Delta: "The image shows a red square."},
		{Type: llminfra.EventFinish},
	}})
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{
		Client: client,
		Request: llminfra.Request{
			ModelID: "anselm-auto",
			Tools:   []llminfra.ToolDef{{Name: "should_not_leak"}},
		},
		Vision: true,
	}}}

	out, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"What color is it?"}`)
	if err != nil {
		t.Fatalf("inspect: %v", err)
	}
	if !strings.Contains(out, "red square") || !strings.Contains(out, `"attachmentId":"`+a.ID+`"`) {
		t.Fatalf("inspect output should contain bounded text evidence and metadata: %q", out)
	}
	req := client.LastRequest()
	if req.ModelID != "anselm-auto" || len(req.Tools) != 0 || req.MaxTokens != inspectMediaMaxOutputTokens {
		t.Fatalf("unexpected inspect request: model=%q tools=%d max=%d", req.ModelID, len(req.Tools), req.MaxTokens)
	}
	if len(req.Messages) != 1 || len(req.Messages[0].Parts) != 2 {
		t.Fatalf("inspect request should send text + one image part: %+v", req.Messages)
	}
	if req.Messages[0].Parts[1].Type != llminfra.PartImageURL ||
		!strings.HasPrefix(req.Messages[0].Parts[1].ImageURL, "data:image/") {
		t.Fatalf("inspect image part should be a bounded data image URL, got %+v", req.Messages[0].Parts[1])
	}
}

func TestInspectMedia_ManagedGatewayStagesBoundedProxy(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "red.png", "image/png", testPNG(t, color.NRGBA{R: 255, A: 255}))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	client := llminfra.NewMockClient()
	client.PushScript(llminfra.MockScript{Events: []llminfra.StreamEvent{{Type: llminfra.EventText, Delta: "ok"}}})
	uploader := &fakeUploader{url: "https://media.example/lease"}
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{
		Client:  client,
		Request: llminfra.Request{ModelID: "anselm-auto"},
		Vision:  true,
		RemoteMedia: &attachmentapp.RemoteMedia{
			BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader,
		},
	}}}
	if _, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"describe it","crop":{"x":0,"y":0,"width":0.5,"height":0.5},"detail":"high"}`); err != nil {
		t.Fatalf("inspect: %v", err)
	}
	req := client.LastRequest()
	if got := req.Messages[0].Parts[1].ImageURL; got != uploader.url {
		t.Fatalf("image should use managed URL, got %q", got)
	}
	if uploader.mime == "" || len(uploader.data) == 0 {
		t.Fatalf("uploader should receive rendered proxy bytes")
	}
}

func TestInspectMedia_NonImageSoftFailsWithoutCallingModel(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "notes.txt", "text/plain", []byte("hello"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	client := llminfra.NewMockClient()
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{Client: client, Vision: true}}}
	out, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"what is it?"}`)
	if err != nil {
		t.Fatalf("inspect: %v", err)
	}
	if !strings.Contains(out, "supports image attachments only") || client.CallCount() != 0 {
		t.Fatalf("non-image should soft-fail without LLM call; out=%q calls=%d", out, client.CallCount())
	}
}

func TestInspectMedia_ValidateInput(t *testing.T) {
	tool := &InspectMedia{}
	if err := tool.ValidateInput([]byte(`{"attachmentId":"","question":"x"}`)); err == nil {
		t.Fatal("empty attachmentId should fail")
	}
	if err := tool.ValidateInput([]byte(`{"attachmentId":"att_1","question":""}`)); err == nil {
		t.Fatal("empty question should fail")
	}
	if err := tool.ValidateInput([]byte(`{"attachmentId":"att_1","question":"x","crop":{"x":0,"y":0,"width":0,"height":1}}`)); err == nil {
		t.Fatal("empty crop width should fail")
	}
	if err := tool.ValidateInput([]byte(`{"attachmentId":"att_1","question":"x","detail":"high"}`)); err != nil {
		t.Fatalf("valid input should pass: %v", err)
	}
}

type fakeInspectResolver struct {
	bundle InspectMediaBundle
	err    error
}

func (f fakeInspectResolver) ResolveInspectMedia(context.Context) (InspectMediaBundle, error) {
	return f.bundle, f.err
}

type fakeUploader struct {
	url  string
	mime string
	data []byte
}

func (f *fakeUploader) Upload(_ context.Context, _, _, mime string, data []byte) (string, error) {
	f.mime = mime
	f.data = append([]byte(nil), data...)
	return f.url, nil
}

func testPNG(t *testing.T, c color.NRGBA) []byte {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, 24, 24))
	for y := 0; y < 24; y++ {
		for x := 0; x < 24; x++ {
			img.SetNRGBA(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buf.Bytes()
}
