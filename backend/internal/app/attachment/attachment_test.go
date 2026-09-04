package attachment

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	blobfs "github.com/sunweilin/anselm/backend/internal/infra/fs/blob"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	attachmentstore "github.com/sunweilin/anselm/backend/internal/infra/store/attachment"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// newSvc wires the Service over a real in-memory metadata store + a real temp-dir CAS blob
// store, exercising the full upload→hash→store→download pipeline offline.
//
// newSvc 把 Service 接在真 in-memory 元数据 store + 真 temp 目录 CAS blob 上，离线走完整
// 上传→哈希→存储→下载链。
func newSvc(t *testing.T) (*Service, *blobfs.Store, context.Context) {
	return newSvcWith(t, nil)
}

func newSvcWith(t *testing.T, ext Extractor) (*Service, *blobfs.Store, context.Context) {
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
	blobs := blobfs.New(t.TempDir())
	svc := NewService(attachmentstore.New(ormpkg.Open(sqlDB)), blobs, ext, zap.NewNop())
	return svc, blobs, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}

func sha(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func TestUpload_RoundTrip_AndKind(t *testing.T) {
	svc, _, ctx := newSvc(t)
	data := []byte("\x89PNG fake image bytes")
	a, err := svc.Upload(ctx, "photo.png", "image/png", data)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	if a.Kind != attachmentdomain.KindImage {
		t.Errorf("kind = %q, want image", a.Kind)
	}
	if a.SHA256 != sha(data) || a.SizeBytes != int64(len(data)) {
		t.Errorf("meta: sha=%s size=%d", a.SHA256, a.SizeBytes)
	}
	if len(a.ID) < 4 || a.ID[:4] != "att_" {
		t.Errorf("id prefix: %s", a.ID)
	}
	gotA, gotData, err := svc.Download(ctx, a.ID)
	if err != nil {
		t.Fatalf("download: %v", err)
	}
	if gotA.ID != a.ID || !bytes.Equal(gotData, data) {
		t.Errorf("download mismatch")
	}
}

func TestUpload_KindClassification(t *testing.T) {
	svc, _, ctx := newSvc(t)
	cases := []struct{ name, mime, want string }{
		{"a.pdf", "application/pdf", attachmentdomain.KindDocument},
		{"a.docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", attachmentdomain.KindDocument},
		{"a.txt", "text/plain", attachmentdomain.KindText},
		{"a.json", "application/json", attachmentdomain.KindText},
		{"a.mp3", "audio/mpeg", attachmentdomain.KindAudio},
		{"weird.bin", "application/octet-stream", attachmentdomain.KindOther},
		{"code.go", "application/octet-stream", attachmentdomain.KindText}, // ext fallback
	}
	for _, c := range cases {
		a, err := svc.Upload(ctx, c.name, c.mime, []byte("data-"+c.name))
		if err != nil {
			t.Fatalf("upload %s: %v", c.name, err)
		}
		if a.Kind != c.want {
			t.Errorf("%s (%s): kind = %q, want %q", c.name, c.mime, a.Kind, c.want)
		}
	}
}

func TestUpload_Empty(t *testing.T) {
	svc, _, ctx := newSvc(t)
	if _, err := svc.Upload(ctx, "e.txt", "text/plain", nil); !errors.Is(err, attachmentdomain.ErrEmpty) {
		t.Errorf("err = %v, want ErrEmpty", err)
	}
}

func TestUpload_TooLarge(t *testing.T) {
	svc, _, ctx := newSvc(t)
	// Size is checked before hashing, so the oversized buffer is never read.
	big := make([]byte, int64(limitspkg.Current().Guards.AttachmentMaxMB)<<20+1)
	if _, err := svc.Upload(ctx, "big.bin", "application/octet-stream", big); !errors.Is(err, attachmentdomain.ErrTooLarge) {
		t.Errorf("err = %v, want ErrTooLarge", err)
	}
}

func TestUpload_DedupSameBytes(t *testing.T) {
	svc, blobs, ctx := newSvc(t)
	data := []byte("identical content")
	a1, _ := svc.Upload(ctx, "first.txt", "text/plain", data)
	a2, _ := svc.Upload(ctx, "second.txt", "text/plain", data)
	if a1.ID == a2.ID {
		t.Error("two uploads should yield distinct attachment ids")
	}
	if a1.SHA256 != a2.SHA256 {
		t.Error("identical bytes should share one sha (dedup)")
	}
	if ok, _ := blobs.Exists(ctx, a1.SHA256); !ok {
		t.Error("blob missing")
	}
}

func TestDelete_KeepsBlobUntilGC(t *testing.T) {
	svc, blobs, ctx := newSvc(t)
	a, _ := svc.Upload(ctx, "x.txt", "text/plain", []byte("bye"))
	if err := svc.Delete(ctx, a.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := svc.Get(ctx, a.ID); !errors.Is(err, attachmentdomain.ErrNotFound) {
		t.Errorf("get after delete = %v, want ErrNotFound", err)
	}
	if ok, _ := blobs.Exists(ctx, a.SHA256); !ok {
		t.Error("blob removed before GC")
	}
}

func TestGC_RefcountBySHA(t *testing.T) {
	svc, blobs, ctx := newSvc(t)
	shared := []byte("shared bytes")
	a1, _ := svc.Upload(ctx, "one.txt", "text/plain", shared) // both reference one blob (dedup)
	a2, _ := svc.Upload(ctx, "two.txt", "text/plain", shared)
	lone, _ := svc.Upload(ctx, "lone.bin", "application/octet-stream", []byte("unique"))

	// Delete one of the two shared-blob rows + the lone row.
	_ = svc.Delete(ctx, a1.ID)
	_ = svc.Delete(ctx, lone.ID)

	removed, err := svc.GC(ctx)
	if err != nil {
		t.Fatalf("gc: %v", err)
	}
	if removed != 1 { // only the lone blob is orphaned; the shared blob is still referenced by a2
		t.Errorf("removed = %d, want 1", removed)
	}
	if ok, _ := blobs.Exists(ctx, a2.SHA256); !ok {
		t.Error("shared blob GC'd while still referenced by a live row")
	}
	if ok, _ := blobs.Exists(ctx, lone.SHA256); ok {
		t.Error("orphan blob survived GC")
	}
}

func TestToContentParts_ByKind(t *testing.T) {
	svc, _, ctx := newSvc(t)
	imgBytes := []byte("\x89PNG pixels")
	pdfBytes := []byte("%PDF-1.7 body")
	img, _ := svc.Upload(ctx, "pic.png", "image/png", imgBytes)
	txt, _ := svc.Upload(ctx, "notes.txt", "text/plain", []byte("hello world"))
	pdf, _ := svc.Upload(ctx, "doc.pdf", "application/pdf", pdfBytes)

	// Vision + native-docs: image → image_url (data-URL), text → inlined text, PDF → file part
	// (handed over raw). Order follows the id slice, not the DB's IN-clause order.
	parts, err := svc.ToContentParts(ctx, []string{img.ID, txt.ID, pdf.ID}, Capabilities{Vision: true, NativeDocs: true})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 3 {
		t.Fatalf("parts = %d, want 3", len(parts))
	}
	if parts[0].Type != llminfra.PartImageURL || !strings.HasPrefix(parts[0].ImageURL, "data:image/png;base64,") {
		t.Errorf("part[0] = %+v, want image_url data-URL", parts[0])
	}
	if parts[1].Type != llminfra.PartText || !strings.Contains(parts[1].Text, "hello world") || !strings.Contains(parts[1].Text, "notes.txt") {
		t.Errorf("part[1] = %+v, want inlined text with filename", parts[1])
	}
	if parts[2].Type != llminfra.PartFile || parts[2].MediaType != "application/pdf" ||
		parts[2].Filename != "doc.pdf" || parts[2].Data != base64.StdEncoding.EncodeToString(pdfBytes) {
		t.Errorf("part[2] = %+v, want file part with base64 PDF", parts[2])
	}
}

func TestToContentParts_NonVisionDegradesImage(t *testing.T) {
	svc, _, ctx := newSvc(t)
	img, _ := svc.Upload(ctx, "pic.png", "image/png", []byte("\x89PNG"))

	parts, err := svc.ToContentParts(ctx, []string{img.ID}, Capabilities{})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartText {
		t.Fatalf("parts = %+v, want one text note", parts)
	}
	for _, want := range []string{
		"[UNAVAILABLE IMAGE]",
		"pic.png",
		"cannot see or inspect its pixels",
		"Do not ask the user to re-attach it",
		"switch to a vision-capable model",
		"describe or paste the relevant content here",
		"Do not add a generic upload acknowledgement",
	} {
		if !strings.Contains(parts[0].Text, want) {
			t.Errorf("degraded note = %q, want %q", parts[0].Text, want)
		}
	}
}

func TestToContentParts_NativeVideoAndAudioRespectCapabilities(t *testing.T) {
	svc, _, ctx := newSvc(t)
	videoBytes := []byte("\x00\x00\x00\x18ftypisom video")
	audioBytes := []byte("ID3\x04\x00\x00 audio")
	video, _ := svc.Upload(ctx, "walkthrough.mp4", "video/mp4", videoBytes)
	audio, _ := svc.Upload(ctx, "voice.mp3", "audio/mpeg", audioBytes)

	parts, err := svc.ToContentParts(ctx, []string{video.ID, audio.ID}, Capabilities{Video: true, Audio: true})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 2 {
		t.Fatalf("parts = %d, want 2", len(parts))
	}
	if parts[0].Type != llminfra.PartVideoURL || !strings.HasPrefix(parts[0].VideoURL, "data:video/mp4;base64,") {
		t.Errorf("video part = %+v, want video_url data URI", parts[0])
	}
	if parts[1].Type != llminfra.PartInputAudio || parts[1].MediaType != "audio/mpeg" ||
		parts[1].Data != base64.StdEncoding.EncodeToString(audioBytes) {
		t.Errorf("audio part = %+v, want input_audio base64 payload", parts[1])
	}
}

type fakeRemoteMediaUploader struct {
	calls int
	got   []struct {
		baseURL, installID, mime string
		data                     []byte
	}
	url string
	err error
}

func (f *fakeRemoteMediaUploader) Upload(_ context.Context, baseURL, installID, mime string, data []byte) (string, error) {
	f.calls++
	f.got = append(f.got, struct {
		baseURL, installID, mime string
		data                     []byte
	}{baseURL: baseURL, installID: installID, mime: mime, data: append([]byte(nil), data...)})
	return f.url, f.err
}

type fakeImageProxy struct {
	data  []byte
	mime  string
	ready bool
	err   error
}

func (f fakeImageProxy) ModelDefaultImage(context.Context, string) ([]byte, string, bool, error) {
	return f.data, f.mime, f.ready, f.err
}

func TestToContentParts_ManagedMediaStagesImageAndVideoOnce(t *testing.T) {
	svc, _, ctx := newSvc(t)
	imageData := []byte("\x89PNG image")
	videoData := []byte("\x00\x00\x00\x18ftypisom video")
	image, _ := svc.Upload(ctx, "photo.png", "image/png", imageData)
	video, _ := svc.Upload(ctx, "clip.mp4", "video/mp4", videoData)
	uploader := &fakeRemoteMediaUploader{url: "/v1/media/leases/mls_1/content?token=t"}
	caps := Capabilities{
		Vision: true, Video: true,
		RemoteMedia: &RemoteMedia{BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader},
	}

	// Repeat the image id deliberately: one turn reuses its expiring source instead of re-uploading
	// the immutable CAS bytes. Video must use the same mechanism, while no data URL survives.
	parts, err := svc.ToContentParts(ctx, []string{image.ID, video.ID, image.ID}, caps)
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 3 || parts[0].ImageURL != uploader.url || parts[1].VideoURL != uploader.url || parts[2].ImageURL != uploader.url {
		t.Fatalf("parts = %+v, want remote image/video URLs", parts)
	}
	if uploader.calls != 2 {
		t.Fatalf("uploads = %d, want one each for image and video", uploader.calls)
	}
	if uploader.got[0].baseURL != "https://api.example/v1" || uploader.got[0].installID != "ins_1" ||
		uploader.got[0].mime != "image/png" || !bytes.Equal(uploader.got[0].data, imageData) ||
		uploader.got[1].mime != "video/mp4" || !bytes.Equal(uploader.got[1].data, videoData) {
		t.Fatalf("upload inputs = %+v", uploader.got)
	}
}

func TestToContentParts_ManagedImageStagesModelDefaultProxyWhenReady(t *testing.T) {
	svc, _, ctx := newSvc(t)
	image, _ := svc.Upload(ctx, "photo.png", "image/png", []byte("original image"))
	uploader := &fakeRemoteMediaUploader{url: "/v1/media/leases/mls_1/content?token=t"}
	parts, err := svc.ToContentParts(ctx, []string{image.ID}, Capabilities{
		Vision: true,
		RemoteMedia: &RemoteMedia{
			BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader,
			Images: fakeImageProxy{data: []byte("proxy image"), mime: "image/jpeg", ready: true},
		},
	})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].ImageURL != uploader.url {
		t.Fatalf("parts = %+v", parts)
	}
	if uploader.calls != 1 || uploader.got[0].mime != "image/jpeg" || !bytes.Equal(uploader.got[0].data, []byte("proxy image")) {
		t.Fatalf("upload inputs = %+v", uploader.got)
	}
}

func TestToContentParts_ManagedImageProxyObeysEnvelope(t *testing.T) {
	svc, _, ctx := newSvc(t)
	// The compressed original fits, but the ready model proxy does not. The gateway receives the
	// proxy bytes, so the renderer must fall back to the original instead of staging the proxy.
	// 原图压缩后能装下,但已 ready 的模型代理装不下。网关收到的是代理字节,所以 renderer 必须退回原图,
	// 不能把代理 staging 出去。
	image, _ := svc.Upload(ctx, "detailed.png", "image/png", []byte("small original"))
	uploader := &fakeRemoteMediaUploader{url: "/v1/media/leases/mls_1/content?token=t"}
	parts, err := svc.ToContentParts(ctx, []string{image.ID}, Capabilities{
		Vision:        true,
		MaxMediaBytes: 1024,
		RemoteMedia: &RemoteMedia{
			BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader,
			Images: fakeImageProxy{data: bytes.Repeat([]byte("x"), 1025), mime: "image/png", ready: true},
		},
	})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartImageURL || parts[0].ImageURL != uploader.url {
		t.Fatalf("parts = %+v, want one managed image part using the original fallback", parts)
	}
	if uploader.calls != 1 || !bytes.Equal(uploader.got[0].data, []byte("small original")) {
		t.Fatalf("uploads = %d data=%q, want one upload of the fitting original", uploader.calls, uploader.got)
	}
}

func TestToContentParts_ManagedMediaFailureStopsTurn(t *testing.T) {
	svc, _, ctx := newSvc(t)
	image, _ := svc.Upload(ctx, "photo.png", "image/png", []byte("\x89PNG image"))
	uploader := &fakeRemoteMediaUploader{err: errors.New("gateway unavailable")}
	_, err := svc.ToContentParts(ctx, []string{image.ID}, Capabilities{
		Vision: true, RemoteMedia: &RemoteMedia{BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader},
	})
	if err == nil || !strings.Contains(err.Error(), "gateway unavailable") || uploader.calls != 1 {
		t.Fatalf("err = %v; uploads = %d, want surfaced staging failure", err, uploader.calls)
	}
	if !errors.Is(err, errorspkg.ErrAttachmentStagingFailed) {
		t.Fatalf("err = %v, want ATTACHMENT_STAGING_FAILED classification", err)
	}
}

func TestToContentParts_ManagedMediaRejectsAbsoluteLeasePath(t *testing.T) {
	svc, _, ctx := newSvc(t)
	image, _ := svc.Upload(ctx, "photo.png", "image/png", []byte("\x89PNG image"))
	uploader := &fakeRemoteMediaUploader{url: "https://media.example/v1/media/leases/mls_1/content?token=t"}
	_, err := svc.ToContentParts(ctx, []string{image.ID}, Capabilities{
		Vision:      true,
		RemoteMedia: &RemoteMedia{BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader},
	})
	if err == nil || !strings.Contains(err.Error(), "invalid relative lease path") || uploader.calls != 1 {
		t.Fatalf("err = %v; uploads = %d, want absolute lease path rejected at application boundary", err, uploader.calls)
	}
}

func TestToContentParts_MediaEnvelopeDegradesWithoutDroppingOrder(t *testing.T) {
	svc, _, ctx := newSvc(t)
	first, _ := svc.Upload(ctx, "first.png", "image/png", []byte("one"))
	second, _ := svc.Upload(ctx, "second.png", "image/png", []byte("two"))

	parts, err := svc.ToContentParts(ctx, []string{first.ID, second.ID}, Capabilities{Vision: true, MaxMediaParts: 1})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 2 || parts[0].Type != llminfra.PartImageURL || parts[1].Type != llminfra.PartText {
		t.Fatalf("parts = %+v, want native first image + note for second", parts)
	}
	if !strings.Contains(parts[1].Text, "item limit") || !strings.Contains(parts[1].Text, "second.png") ||
		!strings.Contains(parts[1].Text, "original position") || !strings.Contains(parts[1].Text, "authoritative") {
		t.Errorf("budget note = %q, want second image + item limit", parts[1].Text)
	}
}

func TestToContentParts_DistinctNativeMediaKindLimitDegradesMixedTurn(t *testing.T) {
	svc, _, ctx := newSvc(t)
	image, _ := svc.Upload(ctx, "photo.png", "image/png", []byte("image bytes"))
	audio, _ := svc.Upload(ctx, "voice.wav", "audio/wav", []byte("audio bytes"))

	parts, err := svc.ToContentParts(ctx, []string{image.ID, audio.ID}, Capabilities{
		Vision: true, Audio: true, MaxDistinctMediaKinds: 1,
	})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 2 || parts[0].Type != llminfra.PartImageURL || parts[1].Type != llminfra.PartText {
		t.Fatalf("parts = %+v, want native image + explanatory audio note", parts)
	}
	if !strings.Contains(parts[1].Text, "at most 1 distinct native media type") ||
		!strings.Contains(parts[1].Text, "voice.wav") || strings.Contains(parts[1].Text, base64.StdEncoding.EncodeToString([]byte("audio bytes"))) {
		t.Fatalf("mixed-media note = %q, want clear cross-kind note without audio payload", parts[1].Text)
	}
}

func TestToContentParts_NativeDocCountsAgainstMediaEnvelope(t *testing.T) {
	svc, _, ctx := newSvc(t)
	pdfBytes := []byte("%PDF bytes")
	pdf, _ := svc.Upload(ctx, "report.pdf", "application/pdf", pdfBytes)

	parts, err := svc.ToContentParts(ctx, []string{pdf.ID}, Capabilities{NativeDocs: true, MaxMediaParts: 1})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartFile {
		t.Fatalf("parts = %+v, want native document file part", parts)
	}

	parts, err = svc.ToContentParts(ctx, []string{pdf.ID, pdf.ID}, Capabilities{NativeDocs: true, MaxMediaParts: 1})
	if err != nil {
		t.Fatalf("ToContentParts repeated: %v", err)
	}
	if len(parts) != 2 || parts[0].Type != llminfra.PartFile || parts[1].Type != llminfra.PartText {
		t.Fatalf("parts = %+v, want second document degraded after item budget", parts)
	}
	if !strings.Contains(parts[1].Text, "item limit") || !strings.Contains(parts[1].Text, "authoritative") ||
		strings.Contains(parts[1].Text, base64.StdEncoding.EncodeToString(pdfBytes)) {
		t.Fatalf("budget note = %q, want item-limit note without base64 payload", parts[1].Text)
	}
}

func TestToContentParts_NotesMissingPreservingOrder(t *testing.T) {
	svc, _, ctx := newSvc(t)
	txt, _ := svc.Upload(ctx, "a.txt", "text/plain", []byte("A"))

	// A stale id between real ones now yields a placeholder note (F78), not a silent drop; the turn
	// survives and order is preserved (the note first, then the live text).
	parts, err := svc.ToContentParts(ctx, []string{"att_deadbeefdeadbeef", txt.ID}, Capabilities{Vision: true})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 2 {
		t.Fatalf("parts = %d, want 2 (missing-attachment note + live text)", len(parts))
	}
	if parts[0].Type != llminfra.PartText || !strings.Contains(parts[0].Text, "no longer available") {
		t.Errorf("part[0] = %+v, want a missing-attachment placeholder note", parts[0])
	}
	if parts[1].Type != llminfra.PartText || !strings.Contains(parts[1].Text, "A") {
		t.Errorf("part[1] = %+v, want the live text part", parts[1])
	}
}

func TestToContentParts_NotesUnreadableBlobPreservingOrder(t *testing.T) {
	svc, blobs, ctx := newSvc(t)
	missing, err := svc.Upload(ctx, "gone.png", "image/png", []byte("PNG"))
	if err != nil {
		t.Fatalf("upload missing blob candidate: %v", err)
	}
	if removed, err := blobs.Sweep(ctx, map[string]bool{}); err != nil || removed != 1 {
		t.Fatalf("remove blob: removed=%d err=%v", removed, err)
	}
	live, err := svc.Upload(ctx, "live.txt", "text/plain", []byte("still here"))
	if err != nil {
		t.Fatalf("upload live attachment: %v", err)
	}

	parts, err := svc.ToContentParts(ctx, []string{missing.ID, live.ID}, Capabilities{Vision: true})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 2 {
		t.Fatalf("parts = %d, want 2 (unreadable-blob note + live text)", len(parts))
	}
	if parts[0].Type != llminfra.PartText || !strings.Contains(parts[0].Text, "gone.png") || !strings.Contains(parts[0].Text, "no longer available") {
		t.Errorf("part[0] = %+v, want an unreadable-blob placeholder note", parts[0])
	}
	if parts[1].Type != llminfra.PartText || !strings.Contains(parts[1].Text, "still here") {
		t.Errorf("part[1] = %+v, want the live text part", parts[1])
	}
}

func TestToContentParts_EmptyIDs(t *testing.T) {
	svc, _, ctx := newSvc(t)
	parts, err := svc.ToContentParts(ctx, nil, Capabilities{Vision: true})
	if err != nil || parts != nil {
		t.Errorf("empty ids = (%v, %v), want (nil, nil)", parts, err)
	}
}

// fakeExtractor is an Extractor stub: it records the mime it saw and returns a canned text/err.
//
// fakeExtractor 是 Extractor 桩：记录看到的 mime，返回预设 text/err。
type fakeExtractor struct {
	text string
	err  error
	mime string
}

func (f *fakeExtractor) Extract(_ context.Context, mime string, _ []byte) (string, error) {
	f.mime = mime
	return f.text, f.err
}

func TestToContentParts_NonNativeDocExtracts(t *testing.T) {
	ext := &fakeExtractor{text: "extracted body text"}
	svc, _, ctx := newSvcWith(t, ext)
	pdf, _ := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF bytes"))

	// NativeDocs=false → the document is text-extracted and inlined instead of handed over raw.
	parts, err := svc.ToContentParts(ctx, []string{pdf.ID}, Capabilities{})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartText {
		t.Fatalf("parts = %+v, want one text part", parts)
	}
	if ext.mime != "application/pdf" {
		t.Errorf("extractor saw mime %q, want application/pdf", ext.mime)
	}
	if !strings.Contains(parts[0].Text, "extracted body text") ||
		!strings.Contains(parts[0].Text, "report.pdf") || !strings.Contains(parts[0].Text, "text-extracted") {
		t.Errorf("text part = %q, want extracted body + filename + label", parts[0].Text)
	}
}

func TestToContentParts_NativeDocOverBudgetFallsBackToExtraction(t *testing.T) {
	ext := &fakeExtractor{text: "bounded extracted evidence"}
	svc, _, ctx := newSvcWith(t, ext)
	pdf, _ := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF bytes"))

	parts, err := svc.ToContentParts(ctx, []string{pdf.ID}, Capabilities{NativeDocs: true, MaxMediaBytes: 1})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartText {
		t.Fatalf("parts = %+v, want text extraction fallback", parts)
	}
	if parts[0].Data != "" || !strings.Contains(parts[0].Text, "bounded extracted evidence") {
		t.Fatalf("fallback = %+v, want extracted text without native base64", parts[0])
	}
}

func TestToContentParts_DocDegradesWhenNoExtractor(t *testing.T) {
	svc, _, ctx := newSvc(t) // nil extractor
	pdf, _ := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF"))

	parts, err := svc.ToContentParts(ctx, []string{pdf.ID}, Capabilities{})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartText || !strings.Contains(parts[0].Text, "unavailable") {
		t.Errorf("parts = %+v, want placeholder note (extraction unavailable)", parts)
	}
}

func TestToContentParts_ExtractionFailureDegrades(t *testing.T) {
	ext := &fakeExtractor{err: errors.New("boom")}
	svc, _, ctx := newSvcWith(t, ext)
	pdf, _ := svc.Upload(ctx, "report.pdf", "application/pdf", []byte("%PDF"))

	parts, _ := svc.ToContentParts(ctx, []string{pdf.ID}, Capabilities{})
	if len(parts) != 1 || parts[0].Type != llminfra.PartText || !strings.Contains(parts[0].Text, "could not be extracted") {
		t.Errorf("parts = %+v, want degraded note on extraction failure", parts)
	}
}

// fakeSandbox is a SandboxRunner stub recording the EnsureEnv spec + Spawn opts it received.
//
// fakeSandbox 是 SandboxRunner 桩，记录收到的 EnsureEnv spec + Spawn opts。
type fakeSandbox struct {
	ensured  sandboxdomain.EnvSpec
	spawned  sandboxdomain.SpawnOpts
	status   string
	stdout   string
	ok       bool
	spawnErr error
}

func (f *fakeSandbox) EnsureEnv(_ context.Context, _ sandboxdomain.Owner, spec sandboxdomain.EnvSpec, _ sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error) {
	f.ensured = spec
	st := f.status
	if st == "" {
		st = sandboxdomain.EnvStatusReady
	}
	return &sandboxdomain.Env{Status: st}, nil
}

func (f *fakeSandbox) Spawn(_ context.Context, _ sandboxdomain.Owner, opts sandboxdomain.SpawnOpts) (*sandboxdomain.ExecutionResult, error) {
	f.spawned = opts
	if f.spawnErr != nil {
		return nil, f.spawnErr
	}
	return &sandboxdomain.ExecutionResult{Ok: f.ok, Stdout: []byte(f.stdout)}, nil
}

func TestSandboxExtractor_Success(t *testing.T) {
	sb := &fakeSandbox{ok: true, stdout: `{"text":"hello from pdf"}`}
	text, err := NewSandboxExtractor(sb).Extract(context.Background(), "application/pdf", []byte("rawpdf"))
	if err != nil {
		t.Fatalf("Extract: %v", err)
	}
	if text != "hello from pdf" {
		t.Errorf("text = %q, want hello from pdf", text)
	}
	if sb.ensured.Runtime.Kind != "python" || len(sb.ensured.Deps) == 0 {
		t.Errorf("EnsureEnv spec = %+v, want python + extraction deps", sb.ensured)
	}
	// Spawn: python -c <script> <mime>; raw bytes on stdin.
	if sb.spawned.Cmd != "python" || len(sb.spawned.Args) != 3 ||
		sb.spawned.Args[0] != "-c" || sb.spawned.Args[2] != "application/pdf" {
		t.Errorf("spawn args = %+v, want [-c <script> application/pdf]", sb.spawned.Args)
	}
	if string(sb.spawned.Stdin) != "rawpdf" {
		t.Errorf("stdin = %q, want rawpdf", sb.spawned.Stdin)
	}
}

func TestSandboxExtractor_UnsupportedMimeShortCircuits(t *testing.T) {
	sb := &fakeSandbox{ok: true, stdout: `{"text":"x"}`}
	_, err := NewSandboxExtractor(sb).Extract(context.Background(), "audio/mpeg", []byte("data"))
	if !errors.Is(err, ErrExtractionUnsupported) {
		t.Errorf("err = %v, want ErrExtractionUnsupported", err)
	}
	if sb.ensured.Runtime.Kind != "" { // must short-circuit before any env work
		t.Error("EnsureEnv called for unsupported mime; should short-circuit")
	}
}

func TestSandboxExtractor_PythonErrorWrapped(t *testing.T) {
	sb := &fakeSandbox{ok: true, stdout: `{"error":"PdfError: corrupt"}`}
	_, err := NewSandboxExtractor(sb).Extract(context.Background(), "application/pdf", []byte("x"))
	if err == nil || !strings.Contains(err.Error(), "corrupt") {
		t.Errorf("err = %v, want wrapped python-side error", err)
	}
}

func TestSandboxExtractor_NonZeroExitErrors(t *testing.T) {
	sb := &fakeSandbox{ok: false} // interpreter crashed (e.g. missing package)
	_, err := NewSandboxExtractor(sb).Extract(context.Background(), "application/pdf", []byte("x"))
	if err == nil {
		t.Error("want error on non-zero python exit")
	}
}

// TestInlineText_CapsOversized — F77: oversized inline text is capped (like extracted documents),
// not passed whole into the model context; small text is inlined unchanged.
func TestInlineText_CapsOversized(t *testing.T) {
	out := inlineText("big.txt", []byte(strings.Repeat("x", maxExtractedChars+100)))
	if !strings.Contains(out, "(truncated)") {
		t.Fatalf("oversized text must be marked truncated, got prefix %q", out[:60])
	}
	if len(out) > maxExtractedChars+200 {
		t.Fatalf("oversized text not capped: len=%d", len(out))
	}
	if small := inlineText("s.txt", []byte("hello")); strings.Contains(small, "truncated") || !strings.Contains(small, "hello") {
		t.Fatalf("small text should be inlined whole, got %q", small)
	}
}

// A managed-route image whose format the staging endpoint cannot accept must degrade to an honest
// note — never abort the turn. HEIC is the case that matters: it is the iPhone default, the image
// proxy's decoder cannot read it, so the ORIGINAL bytes are what would be offered, and the gateway
// would 400 them. Before this guard, a user attaching a photo straight from their phone lost the
// entire answer to an opaque failure.
//
// The note is deliberately not silence: dropping the image and answering anyway would let the model
// speak as if it had seen it.
//
// 受管路由下 staging 端点无法接受其格式的图片必须降级为一句诚实注记,**绝不**中断回合。HEIC 是要害:它是
// iPhone 默认格式,图片代理的解码器读不了它,故被送出的是**原件**字节、网关会 400。有这道守卫之前,用户从
// 手机随手附一张照片就会把整个回答赔进一个不知所云的失败里。
//
// 注记刻意不是「沉默」:丢掉图片照常回答,会让模型表现得像看过它一样。
func TestToContentParts_ManagedUndeliverableFormatDegradesInsteadOfStoppingTurn(t *testing.T) {
	svc, _, ctx := newSvc(t)
	heic, _ := svc.Upload(ctx, "IMG_0001.HEIC", "image/heic", []byte("heic-bytes"))
	uploader := &fakeRemoteMediaUploader{}
	parts, err := svc.ToContentParts(ctx, []string{heic.ID}, Capabilities{
		Vision: true, RemoteMedia: &RemoteMedia{BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader},
	})
	if err != nil {
		t.Fatalf("an undeliverable format must not fail the turn: %v", err)
	}
	if uploader.calls != 0 {
		t.Fatalf("an undeliverable format must never be uploaded (the gateway would 400 it), calls=%d", uploader.calls)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartText {
		t.Fatalf("want exactly one text note, got %+v", parts)
	}
	if !strings.Contains(parts[0].Text, "IMG_0001.HEIC") || !strings.Contains(parts[0].Text, "image/heic") {
		t.Fatalf("the note must name the file and its format so the answer stays honest, got %q", parts[0].Text)
	}
}

// TestToContentParts_RemoteMediaObeysTheEnvelope is the regression for a real production failure.
//
// Lease media used to be exempt from the decoded-bytes envelope: it travelled as a reference the
// PROVIDER fetched, so it cost the request nothing. ADR 0012 changed that — the gateway now INLINES
// the lease content into the upstream body — and the check here was never updated. A 3.2MB
// generated clip therefore sailed past this function and died at the gateway with
// "media exceeds the per-request decoded size limit", killing the whole turn AFTER the video had
// been generated and paid for.
//
// Skipping the check never made the limit go away; it only moved the failure somewhere that costs
// the user their turn instead of one honest sentence.
//
// TestToContentParts_RemoteMediaObeysTheEnvelope 是一次**真实生产故障**的回归。
//
// lease 媒体过去免受解码字节信封的约束:它是由**上游**去取的引用,对本请求零成本。ADR 0012 改了这件事
// ——网关现在**把 lease 内容内联进上游请求体**——而这里的检查从没跟着更新。于是一段 3.2MB 的生成片子
// 一路穿过本函数,在网关以「media exceeds the per-request decoded size limit」死掉,而那时视频**已经生成、
// 已经付过钱**,整个回合报废。
//
// 不查这道闸从来不会让上限消失,只会把失败挪到一个「代价是用户的一整轮」而非「一句诚实的话」的地方。
func TestToContentParts_RemoteMediaObeysTheEnvelope(t *testing.T) {
	svc, _, ctx := newSvc(t)
	big := append([]byte("\x00\x00\x00\x18ftypisom"), make([]byte, 4096)...)
	video, _ := svc.Upload(ctx, "big.mp4", "video/mp4", big)
	huge := append([]byte("\x89PNG"), make([]byte, 4096)...)
	image, _ := svc.Upload(ctx, "big.png", "image/png", huge)
	uploader := &fakeRemoteMediaUploader{url: "/v1/media/leases/mls_1/content?token=t"}
	caps := Capabilities{
		Vision: true, Video: true,
		MaxMediaBytes: 1024, // smaller than either artifact / 比任一产物都小
		RemoteMedia:   &RemoteMedia{BaseURL: "https://api.example/v1", InstallID: "ins_1", Uploader: uploader},
	}

	parts, err := svc.ToContentParts(ctx, []string{video.ID, image.ID}, caps)
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	for _, p := range parts {
		if p.Type == llminfra.PartVideoURL || p.Type == llminfra.PartImageURL {
			t.Fatalf("an over-envelope artifact was still sent as a media part: %+v", parts)
		}
	}
	if len(parts) != 2 {
		t.Fatalf("parts = %d, want an honest note for each", len(parts))
	}
	if uploader.calls != 0 {
		t.Fatalf("uploads = %d — an artifact that cannot be sent must not be uploaded either", uploader.calls)
	}
}

// TestUpload_StampsProvenanceFromContext pins the H5.7 debt-payment: every attachment records WHO
// minted it and INSIDE WHAT, taken from ctx at the one place all producers funnel through.
//
// It is a recording-only feature, which is exactly why it needs a guard: nothing reads these columns
// yet, so a producer that forgets to name itself breaks no test and shows no symptom — it just
// silently writes a row that can never be back-filled. The evidence has to be right the first time,
// because the day it is needed is the day it is too late to collect.
//
// TestUpload_StampsProvenanceFromContext 钉住 H5.7 还的那笔债:每份附件都记下**谁**铸的、铸在**什么
// 之内**,在所有产地必经的那一处从 ctx 取。
//
// 它是一个**只记录**的能力,而这恰恰是它需要守卫的理由:今天没有任何地方读这几列,故一个忘了给自己
// 署名的产地**不会让任何测试变红、也不会有任何症状**——它只是静默地写下一行**永远补不回来**的数据。
// 证据必须一次就对,因为需要它的那天,正是再也收集不到它的那天。
func TestUpload_StampsProvenanceFromContext(t *testing.T) {
	svc, _, ctx := newSvc(t)

	// A plain user upload: no producer, no execution. "" is a fact, not a gap.
	// 普通用户上传:没有产地、没有执行。"" 是一个事实,不是一处缺失。
	plain, err := svc.Upload(ctx, "photo.png", "image/png", []byte("\x89PNG bytes"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	if plain.Source != "" || plain.OriginConversationID != "" || plain.OriginFlowrunID != "" {
		t.Fatalf("a user upload invented provenance: %+v", plain)
	}

	// A tool-minted artifact inside a conversation and a run.
	toolCtx := reqctxpkg.SetMediaSource(ctx, "generate_video")
	toolCtx = reqctxpkg.SetConversationID(toolCtx, "cv_1111111111111111")
	toolCtx = reqctxpkg.SetFlowrunID(toolCtx, "frn_2222222222222222")
	made, err := svc.Upload(toolCtx, "clip.mp4", "video/mp4", []byte("\x00\x00\x00\x18ftypisom v"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	if made.Source != "generate_video" {
		t.Fatalf("source = %q, want the producer's own name", made.Source)
	}
	if made.OriginConversationID != "cv_1111111111111111" || made.OriginFlowrunID != "frn_2222222222222222" {
		t.Fatalf("origin = %q/%q, want the ctx scope", made.OriginConversationID, made.OriginFlowrunID)
	}

	// And it SURVIVES the round trip — a column stamped but not persisted would look identical here
	// unless the row is actually read back.
	// 而且它**活过往返**——一个盖上了却没落盘的列,只有真把行读回来才看得出区别。
	got, err := svc.Get(ctx, made.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Source != "generate_video" || got.OriginConversationID != "cv_1111111111111111" {
		t.Fatalf("provenance lost on the round trip: %+v", got)
	}
}

// TestToolResultContentParts_OnlyWhatThisCallMinted is the H5.8 lockdown.
//
// A receipt is text a tool writes, so any tool can name any attachment id and the expander would
// dutifully inline it. Inside one workspace the only thing between a third-party MCP server and
// someone else's file was that it had to guess a 64-bit id — thin, and free to remove: every
// producer that legitimately wants its media seen minted it during the call being expanded.
//
// The two tools that DO legitimately echo an id they did not mint — inspect_media and
// read_attachment — both say in their own descriptions that they must NOT dump bytes into the
// conversation. So this filter fixes two contracts that were quietly being violated, rather than
// breaking anything.
//
// TestToolResultContentParts_OnlyWhatThisCallMinted 是 H5.8 的收口。
//
// receipt 是工具写的文本,故任何工具都能点名任何附件 id,而展开器会老老实实内联它。在同一个 workspace 内,
// 横在第三方 MCP server 与别人的文件之间的只剩「得猜中一个 64 位 id」——很细,而且拿掉它不花代价:每个
// 正当地希望自己的媒体被看到的产地,都是在**正被展开的这次调用中**铸出它的。
//
// 确实会回显自己没铸的 id 的那两个工具——inspect_media 与 read_attachment——在各自的描述里都写明**不得**
// 把字节倾倒进对话。故本过滤器是**修好了两份正被静默违反的契约**,而不是弄坏了什么。
func TestToolResultContentParts_OnlyWhatThisCallMinted(t *testing.T) {
	svc, _, ctx := newSvc(t)
	caps := Capabilities{Vision: true}

	mineCtx := reqctxpkg.SetToolCallID(ctx, "tc_mine")
	mine, err := svc.Upload(mineCtx, "mine.png", "image/png", []byte("\x89PNG mine"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	// Someone else's artifact: minted by a DIFFERENT call, exactly what an echoed or guessed id is.
	// 别人的产物:由**另一次**调用铸出——回显的 id 与猜中的 id 都正是这个形状。
	theirs, err := svc.Upload(reqctxpkg.SetToolCallID(ctx, "tc_theirs"), "theirs.png", "image/png", []byte("\x89PNG theirs"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}

	parts, err := svc.ToolResultContentParts(ctx, "tc_mine", []string{mine.ID, theirs.ID}, caps)
	if err != nil {
		t.Fatalf("ToolResultContentParts: %v", err)
	}
	if len(parts) != 1 || parts[0].Type != llminfra.PartImageURL {
		t.Fatalf("parts = %+v, want exactly this call's own artifact", parts)
	}

	// The unnarrowed entry still sees both — the payload and document halves legitimately expand
	// media nobody minted in a tool call, and narrowing THEM would break attaching a file at all.
	// 未收窄的入口仍然两个都看得见——payload 与文档那两半正当地展开「没有任何工具调用铸过」的媒体,
	// 收窄它们会让「附一个文件」这件事整个坏掉。
	both, err := svc.ToContentParts(mineCtx, []string{mine.ID, theirs.ID}, caps)
	if err != nil || len(both) != 2 {
		t.Fatalf("ToContentParts = %+v (%v), want both — the other entries must stay unnarrowed", both, err)
	}

	// An empty tool call id is not a tool_result expansion at all; refuse rather than silently widen.
	//
	// **This assertion used to read the id off ctx, and that is exactly how the branch died in
	// production.** The test seeded ctx by hand; the loop never did, so every real expansion took
	// this "refuse" path and no model was ever handed a tool's artifact. The id is a parameter now,
	// which is why a call site that forgets it cannot compile.
	//
	// 空 tool call id 根本不是一次 tool_result 展开;宁可拒绝也不静默放宽。
	//
	// **这条断言过去是从 ctx 读那个 id 的,而那正是这条分支在生产里死掉的方式。** 测试**手工**种了 ctx,
	// 而 loop 从来不种,于是每一次真实展开都走了这条「拒绝」路径、没有任何模型拿到过工具的产物。现在 id
	// 是**参数**,所以忘了传的调用点根本编译不过。
	if got, _ := svc.ToolResultContentParts(ctx, "", []string{mine.ID}, caps); len(got) != 0 {
		t.Fatalf("expanded outside a tool call: %+v", got)
	}
}
