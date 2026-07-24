package attachment

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
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
	return newToolSvcWithExtractor(t, nil)
}

func newToolSvcWithExtractor(t *testing.T, ext attachmentapp.Extractor) (*attachmentapp.Service, context.Context) {
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
	svc := attachmentapp.NewService(attachmentstore.New(ormpkg.Open(sqlDB)), blobfs.New(t.TempDir()), ext, zap.NewNop())
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

func TestReadAttachment_IndexReturnsChunkOffsetsWithoutDumpingBody(t *testing.T) {
	svc, ctx := newToolSvc(t)
	body := strings.Repeat("a", readAttachmentIndexChunkChars*2) +
		strings.Repeat("b", readAttachmentIndexPreviewChars+8) +
		"UNINDEXED_SECRET_AFTER_PREVIEW"
	a, err := svc.Upload(ctx, "long.txt", "text/plain", []byte(body))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","index":true}`)
	if err != nil {
		t.Fatalf("read index: %v", err)
	}
	var idx attachmentTextIndex
	if err := json.Unmarshal([]byte(out), &idx); err != nil {
		t.Fatalf("index should be JSON: %v\n%s", err, out)
	}
	if idx.TotalChars != len([]rune(`Attached file "`+a.Filename+`":`+"\n"+body)) || len(idx.Chunks) < 3 {
		t.Fatalf("index metadata wrong: %+v", idx)
	}
	if idx.Chunks[0].Offset != 0 || idx.Chunks[1].Offset != readAttachmentIndexChunkChars ||
		idx.Chunks[0].Chars != readAttachmentIndexChunkChars {
		t.Fatalf("chunk offsets wrong: %+v", idx.Chunks[:2])
	}
	if strings.Contains(out, "UNINDEXED_SECRET_AFTER_PREVIEW") {
		t.Fatalf("index should not dump full body text: %q", out)
	}
	if !strings.Contains(idx.Usage, "offset") {
		t.Fatalf("index should tell the agent how to continue: %+v", idx)
	}
}

func TestReadAttachment_IndexContinuesFromOffset(t *testing.T) {
	text := strings.Repeat("a", 12) + strings.Repeat("b", 12) + strings.Repeat("c", 12)
	chunks, truncated, next := chunkAttachmentText(text, 0, 10, 2)
	if !truncated || next != 20 || len(chunks) != 2 {
		t.Fatalf("first helper page = chunks=%+v truncated=%v next=%d", chunks, truncated, next)
	}
	continued, truncated, next := chunkAttachmentText(text, next, 10, 2)
	if truncated || next != 0 || len(continued) != 2 ||
		continued[0].Offset != 20 || !strings.HasPrefix(continued[0].Preview, "bb") {
		t.Fatalf("continued helper page = chunks=%+v truncated=%v next=%d", continued, truncated, next)
	}

	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "long.txt", "text/plain", []byte(strings.Repeat("x", readAttachmentIndexChunkChars+20)))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","index":true,"offset":8000}`)
	if err != nil {
		t.Fatalf("read continued index: %v", err)
	}
	var idx attachmentTextIndex
	if err := json.Unmarshal([]byte(out), &idx); err != nil {
		t.Fatalf("index should be JSON: %v\n%s", err, out)
	}
	if idx.Offset != 8000 || len(idx.Chunks) != 1 || idx.Chunks[0].Offset != 8000 {
		t.Fatalf("index should continue from requested offset: %+v", idx)
	}
}

func TestReadAttachment_LargeDefaultAutoIndexes(t *testing.T) {
	svc, ctx := newToolSvc(t)
	body := strings.Repeat("a", readAttachmentIndexChunkChars*6) +
		strings.Repeat("b", readAttachmentIndexPreviewChars+8) +
		"AUTO_INDEX_SECRET_AFTER_PREVIEW"
	a, err := svc.Upload(ctx, "large.txt", "text/plain", []byte(body))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`"}`)
	if err != nil {
		t.Fatalf("read large default: %v", err)
	}
	var idx attachmentTextIndex
	if err := json.Unmarshal([]byte(out), &idx); err != nil {
		t.Fatalf("large default should auto-index as JSON: %v\n%s", err, out)
	}
	if idx.TotalChars <= readAttachmentAutoIndexChars || len(idx.Chunks) < 2 || idx.ChunkChars != readAttachmentIndexChunkChars {
		t.Fatalf("auto-index metadata wrong: %+v", idx)
	}
	if strings.Contains(out, "AUTO_INDEX_SECRET_AFTER_PREVIEW") || len(out) > 20_000 {
		t.Fatalf("auto-index should stay compact and omit body tail: len=%d out=%q", len(out), out)
	}
	if !strings.Contains(idx.Usage, "offset") || !strings.Contains(idx.Usage, "limitChars") {
		t.Fatalf("auto-index should explain how to fetch slices: %+v", idx)
	}
}

func TestReadAttachment_ExplicitLimitBypassesAutoIndex(t *testing.T) {
	svc, ctx := newToolSvc(t)
	body := "VISIBLE_BEGIN_" + strings.Repeat("x", readAttachmentAutoIndexChars+200)
	a, err := svc.Upload(ctx, "large.txt", "text/plain", []byte(body))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","limitChars":40}`)
	if err != nil {
		t.Fatalf("read large explicit page: %v", err)
	}
	var idx attachmentTextIndex
	if err := json.Unmarshal([]byte(out), &idx); err == nil {
		t.Fatalf("explicit limit should return page text, not index JSON: %+v", idx)
	}
	if !strings.Contains(out, `Attached file "large.txt"`) ||
		!strings.Contains(out, "VISIBLE_BEGIN") ||
		!strings.Contains(out, "nextOffset=40") {
		t.Fatalf("explicit limit should page through body text: %q", out)
	}
}

func TestReadAttachment_TextQueryReturnsBoundedSnippets(t *testing.T) {
	svc, ctx := newToolSvc(t)
	body := strings.Repeat("alpha ", 30) +
		"first TARGET payload " +
		strings.Repeat("middle ", 30) +
		"second target payload " +
		strings.Repeat("tail ", 30)
	a, err := svc.Upload(ctx, "search.txt", "text/plain", []byte(body))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","query":"target","contextChars":8,"maxMatches":1}`)
	if err != nil {
		t.Fatalf("read query: %v", err)
	}
	if !strings.Contains(out, `read_attachment search: query="target"`) ||
		!strings.Contains(out, "matches=2") ||
		!strings.Contains(out, "returned=1") ||
		!strings.Contains(out, "[match 1 offset=") {
		t.Fatalf("query output should include search metadata and first match: %q", out)
	}
	if !strings.Contains(out, "TARGET") || strings.Contains(out, "second target payload") {
		t.Fatalf("query output should return only a bounded first snippet: %q", out)
	}
	if !strings.Contains(out, "search truncated") {
		t.Fatalf("query output should say when more matches exist: %q", out)
	}
}

func TestReadAttachment_TextQueryNoMatchSelfCorrects(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "notes.txt", "text/plain", []byte("alpha beta gamma"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	out, err := (&ReadAttachment{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","query":"delta"}`)
	if err != nil {
		t.Fatalf("read query: %v", err)
	}
	if !strings.Contains(out, `No matches for query "delta"`) || !strings.Contains(out, "offset/limitChars") {
		t.Fatalf("no-match query should self-correct: %q", out)
	}
}

type fakeTextCache struct {
	calls int
	text  string
	err   error
}

func (f *fakeTextCache) DocumentText(ctx context.Context, attachmentID string, extract func(context.Context, *attachmentdomain.Attachment, []byte) (string, error)) (string, error) {
	f.calls++
	if f.err != nil {
		return "", f.err
	}
	if f.text != "" {
		return f.text, nil
	}
	return extract(ctx, &attachmentdomain.Attachment{ID: attachmentID}, nil)
}

func TestReadAttachment_DocumentUsesTextCache(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF bytes"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	cache := &fakeTextCache{text: "# Page 1\ncached document text"}
	out, err := (&ReadAttachment{svc: svc, textCache: cache}).Execute(ctx, `{"id":"`+a.ID+`"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if cache.calls != 1 || !strings.Contains(out, "cached document text") || strings.Contains(out, "extraction is unavailable") {
		t.Fatalf("document read should use text cache; calls=%d out=%q", cache.calls, out)
	}
}

func TestReadAttachment_IndexIncludesDocumentPageMarkers(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF bytes"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	cache := &fakeTextCache{text: "# Page 1\nintro\n\n# Page 2\ntarget evidence\n\n# Page 3\nappendix"}
	out, err := (&ReadAttachment{svc: svc, textCache: cache}).Execute(ctx, `{"id":"`+a.ID+`","index":true}`)
	if err != nil {
		t.Fatalf("read index: %v", err)
	}
	var idx attachmentTextIndex
	if err := json.Unmarshal([]byte(out), &idx); err != nil {
		t.Fatalf("index should be JSON: %v\n%s", err, out)
	}
	if cache.calls != 1 || len(idx.Chunks) < 3 {
		t.Fatalf("document index should use cache and expose chunks; calls=%d idx=%+v", cache.calls, idx)
	}
	var foundPage2 bool
	for _, chunk := range idx.Chunks {
		if chunk.PageStart == 2 && strings.Contains(chunk.Preview, "# Page 2") {
			foundPage2 = true
		}
	}
	if !foundPage2 {
		t.Fatalf("page 2 chunk missing from index: %+v", idx.Chunks)
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
	if err := (&ReadAttachment{}).ValidateInput([]byte(`{"id":"att_1","query":"` + strings.Repeat("x", readAttachmentMaxQueryChars+1) + `"}`)); err == nil {
		t.Fatal("oversized query should fail validation")
	}
	if err := (&ReadAttachment{}).ValidateInput([]byte(`{"id":"att_1","contextChars":2001}`)); err == nil {
		t.Fatal("oversized contextChars should fail validation")
	}
	if err := (&ReadAttachment{}).ValidateInput([]byte(`{"id":"att_1","maxMatches":11}`)); err == nil {
		t.Fatal("oversized maxMatches should fail validation")
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

func TestInspectMedia_ImageTilesReturnsCropMapWithoutCallingModel(t *testing.T) {
	svc, ctx := newToolSvc(t)
	img := image.NewNRGBA(image.Rect(0, 0, 20, 100))
	for y := 0; y < 100; y++ {
		for x := 0; x < 20; x++ {
			img.SetNRGBA(x, y, color.NRGBA{R: 255, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	a, err := svc.Upload(ctx, "long.png", "image/png", buf.Bytes())
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	client := llminfra.NewMockClient()
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{Client: client, Vision: true}}}
	out, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"map the screenshot","tiles":true}`)
	if err != nil {
		t.Fatalf("inspect tiles: %v", err)
	}
	var got inspectImageTilesResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("tiles should be JSON: %v\n%s", err, out)
	}
	if got.Width != 20 || got.Height != 100 || got.TileRows < 2 || got.TileCols != 1 || len(got.Tiles) != got.TileRows {
		t.Fatalf("unexpected tile map: %+v", got)
	}
	first := got.Tiles[0]
	if first.Index != 1 || first.Row != 1 || first.Col != 1 ||
		first.Crop.X != 0 || first.Crop.Y != 0 || first.Crop.Width != 1 || first.Crop.Height <= 0 {
		t.Fatalf("first tile crop wrong: %+v", first)
	}
	if client.CallCount() != 0 {
		t.Fatalf("tiles mode must not call the vision model, calls=%d", client.CallCount())
	}
	if !strings.Contains(got.Usage, "crop") || !strings.Contains(got.Usage, "does not call a vision model") {
		t.Fatalf("usage should guide follow-up crop inspection: %+v", got)
	}
}

func TestInspectMedia_TextQueryReturnsBoundedEvidenceWithoutCallingModel(t *testing.T) {
	svc, ctx := newToolSvc(t)
	body := strings.Repeat("alpha ", 20) + "needle payload " + strings.Repeat("tail ", 20)
	a, err := svc.Upload(ctx, "notes.txt", "text/plain", []byte(body))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	client := llminfra.NewMockClient()
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{Client: client, Vision: true}}}
	out, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"find the relevant line","query":"needle","contextChars":6,"maxMatches":1}`)
	if err != nil {
		t.Fatalf("inspect: %v", err)
	}
	if !strings.Contains(out, `"mode":"query"`) ||
		!strings.Contains(out, `read_attachment search: query=\"needle\"`) ||
		!strings.Contains(out, "needle paylo") ||
		client.CallCount() != 0 {
		t.Fatalf("text inspect should return bounded local evidence without LLM call; out=%q calls=%d", out, client.CallCount())
	}
}

type fakeToolExtractor struct{ text string }

func (f fakeToolExtractor) Extract(context.Context, string, []byte) (string, error) {
	return f.text, nil
}

func TestInspectMedia_DocumentPageReturnsMarkedExtractedPage(t *testing.T) {
	svc, ctx := newToolSvcWithExtractor(t, fakeToolExtractor{text: "# Page 1\nintro\n\n# Page 2\ntarget evidence\n\n# Page 3\nappendix"})
	a, err := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF bytes"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	client := llminfra.NewMockClient()
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{Client: client, Vision: true}}}
	out, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"what is on page 2?","page":2,"limitChars":200}`)
	if err != nil {
		t.Fatalf("inspect: %v", err)
	}
	if !strings.Contains(out, `"mode":"page"`) ||
		!strings.Contains(out, "# Page 2") ||
		!strings.Contains(out, "target evidence") ||
		strings.Contains(out, "# Page 3") ||
		client.CallCount() != 0 {
		t.Fatalf("document page inspect should return the requested extracted page only; out=%q calls=%d", out, client.CallCount())
	}
}

func TestInspectMedia_DocumentUsesTextCachePage(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF bytes"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	cache := &fakeTextCache{text: "# Page 1\nintro\n\n# Page 2\ncached page evidence\n\n# Page 3\nappendix"}
	client := llminfra.NewMockClient()
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{Client: client, Vision: true}}, textCache: cache}
	out, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"what is on page 2?","page":2}`)
	if err != nil {
		t.Fatalf("inspect: %v", err)
	}
	if cache.calls != 1 ||
		!strings.Contains(out, "cached page evidence") ||
		strings.Contains(out, "# Page 3") ||
		client.CallCount() != 0 {
		t.Fatalf("document inspect should use text cache page without LLM call; calls=%d out=%q llm=%d", cache.calls, out, client.CallCount())
	}
}

func TestInspectMedia_AudioSoftFailsWithoutCallingModel(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, err := svc.Upload(ctx, "voice.mp3", "audio/mpeg", []byte("ID3 audio"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	client := llminfra.NewMockClient()
	tool := &InspectMedia{svc: svc, resolver: fakeInspectResolver{bundle: InspectMediaBundle{Client: client, Vision: true}}}
	out, err := tool.Execute(ctx, `{"attachmentId":"`+a.ID+`","question":"what is it?"}`)
	if err != nil {
		t.Fatalf("inspect: %v", err)
	}
	if !strings.Contains(out, "Audio/video time-range inspection is not implemented yet") || client.CallCount() != 0 {
		t.Fatalf("audio should soft-fail without LLM call; out=%q calls=%d", out, client.CallCount())
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
	if err := tool.ValidateInput([]byte(`{"attachmentId":"att_1","question":"x","limitChars":40001}`)); err == nil {
		t.Fatal("oversized inspect text limit should fail")
	}
	if err := tool.ValidateInput([]byte(`{"attachmentId":"att_1","question":"x","query":"` + strings.Repeat("x", readAttachmentMaxQueryChars+1) + `"}`)); err == nil {
		t.Fatal("oversized inspect query should fail")
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
