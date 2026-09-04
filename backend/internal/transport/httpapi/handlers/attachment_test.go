package handlers

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	mediaapp "github.com/sunweilin/anselm/backend/internal/app/media"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	blobfs "github.com/sunweilin/anselm/backend/internal/infra/fs/blob"
	attachmentstore "github.com/sunweilin/anselm/backend/internal/infra/store/attachment"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

type fakeAttachmentPreparation struct {
	calls []string
	prep  mediaapp.Preparation
	err   error
}

func (f *fakeAttachmentPreparation) Preparation(context.Context, string) (mediaapp.Preparation, error) {
	return f.prep, f.err
}

func (f *fakeAttachmentPreparation) CancelPreparation(_ context.Context, attachmentID string) (mediaapp.Preparation, error) {
	f.calls = append(f.calls, "cancel:"+attachmentID)
	return f.prep, f.err
}

func (f *fakeAttachmentPreparation) RetryPreparation(_ context.Context, attachmentID string) (mediaapp.Preparation, error) {
	f.calls = append(f.calls, "retry:"+attachmentID)
	return f.prep, f.err
}

func TestAttachmentHandlerPreparationActions(t *testing.T) {
	for _, tc := range []struct {
		name   string
		path   string
		want   string
		status string
	}{
		{name: "cancel", path: "/api/v1/attachments/att_1/preparation/cancel", want: "cancel:att_1", status: mediadomain.StatusCancelled},
		{name: "retry", path: "/api/v1/attachments/att_2/preparation/retry", want: "retry:att_2", status: mediadomain.StatusPending},
	} {
		t.Run(tc.name, func(t *testing.T) {
			media := &fakeAttachmentPreparation{prep: mediaapp.Preparation{
				Status: tc.status,
				Target: mediaapp.DerivativeModelDefault,
			}}
			h := &AttachmentHandler{media: media, log: zap.NewNop()}
			mux := http.NewServeMux()
			h.Register(mux)

			rec := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodPost, tc.path, nil)
			mux.ServeHTTP(rec, req)
			if rec.Code != http.StatusOK {
				t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
			}
			if len(media.calls) != 1 || media.calls[0] != tc.want {
				t.Fatalf("calls = %v, want %q", media.calls, tc.want)
			}

			var body struct {
				Data mediaapp.Preparation `json:"data"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("decode response: %v", err)
			}
			if body.Data.Status != tc.status || body.Data.Target != mediaapp.DerivativeModelDefault {
				t.Fatalf("preparation response = %+v", body.Data)
			}
		})
	}
}

func TestAttachmentHandlerPreparationUnavailableWithoutMediaService(t *testing.T) {
	h := &AttachmentHandler{log: zap.NewNop()}
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/attachments/att_1/preparation/cancel", nil)
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		Data mediaapp.Preparation `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Data.Status != mediaapp.PreparationStatusUnavailable || body.Data.ErrorCode != "MEDIA_PREPARATION_UNAVAILABLE" {
		t.Fatalf("unavailable preparation = %+v", body.Data)
	}
}

func TestAttachmentHandlerUploadRoundTrip(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	h := NewAttachmentHandler(svc, nil, zap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	req := newAttachmentMultipartRequest(t, ctx, "notes.txt", []byte("upload-round-trip"))
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("upload status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		Data struct {
			ID       string `json:"id"`
			Filename string `json:"filename"`
			MimeType string `json:"mimeType"`
			Kind     string `json:"kind"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode upload response: %v", err)
	}
	if body.Data.ID == "" || body.Data.Filename != "notes.txt" || !strings.HasPrefix(body.Data.MimeType, "text/plain") || body.Data.Kind != "text" {
		t.Fatalf("upload metadata = %+v", body.Data)
	}

	content := httptest.NewRecorder()
	get := httptest.NewRequest(http.MethodGet, "/api/v1/attachments/"+body.Data.ID+"/content", nil).WithContext(ctx)
	mux.ServeHTTP(content, get)
	if content.Code != http.StatusOK || content.Body.String() != "upload-round-trip" {
		t.Fatalf("content status=%d body=%q", content.Code, content.Body.String())
	}
}

func TestAttachmentHandlerGetReturnsMetadataAndPreparation(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	a, err := svc.Upload(ctx, "photo.jpg", "image/jpeg", []byte("image-bytes"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	updatedAt := time.Date(2026, 8, 10, 1, 0, 0, 0, time.UTC)
	media := &fakeAttachmentPreparation{prep: mediaapp.Preparation{
		Status:    mediadomain.StatusReady,
		Phase:     "ready",
		Target:    mediaapp.DerivativeModelDefault,
		Width:     640,
		Height:    480,
		MimeType:  "image/webp",
		SizeBytes: 1234,
		UpdatedAt: &updatedAt,
	}}
	h := NewAttachmentHandler(svc, media, zap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/attachments/"+a.ID, nil).WithContext(ctx)
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("get status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		Data attachmentResponse `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode get response: %v", err)
	}
	if body.Data.ID != a.ID || body.Data.Filename != a.Filename || body.Data.MimeType != a.MimeType || body.Data.SizeBytes != a.SizeBytes || body.Data.Kind != a.Kind {
		t.Fatalf("metadata = %+v, want %+v", body.Data.Attachment, a)
	}
	if body.Data.Preparation == nil || body.Data.Preparation.Status != mediadomain.StatusReady || body.Data.Preparation.Target != mediaapp.DerivativeModelDefault || body.Data.Preparation.Width != 640 || body.Data.Preparation.Height != 480 || body.Data.Preparation.MimeType != "image/webp" || body.Data.Preparation.SizeBytes != 1234 || body.Data.Preparation.UpdatedAt == nil {
		t.Fatalf("preparation = %+v", body.Data.Preparation)
	}
}

func TestAttachmentHandlerGetKeepsMetadataWhenPreparationUnavailable(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	a, err := svc.Upload(ctx, "notes.txt", "text/plain", []byte("metadata survives"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	media := &fakeAttachmentPreparation{err: errors.New("media worker unavailable")}
	h := NewAttachmentHandler(svc, media, zap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/attachments/"+a.ID, nil).WithContext(ctx)
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("get status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		Data attachmentResponse `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode get response: %v", err)
	}
	if body.Data.ID != a.ID || body.Data.Filename != a.Filename || body.Data.SizeBytes != a.SizeBytes {
		t.Fatalf("metadata was lost with unavailable preparation: %+v", body.Data.Attachment)
	}
	if body.Data.Preparation == nil || body.Data.Preparation.Status != mediaapp.PreparationStatusUnavailable || body.Data.Preparation.Phase != "unavailable" || body.Data.Preparation.ErrorCode != "MEDIA_PREPARATION_UNAVAILABLE" {
		t.Fatalf("unavailable preparation = %+v", body.Data.Preparation)
	}
}

func TestAttachmentHandlerContentStreamsRangeAndSafeFilename(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	a, err := svc.Upload(ctx, "报告\\\"\r\n.txt", "text/plain", []byte("0123456789"))
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	h := NewAttachmentHandler(svc, nil, zap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	full := httptest.NewRecorder()
	mux.ServeHTTP(full, httptest.NewRequest(http.MethodGet, "/api/v1/attachments/"+a.ID+"/content", nil).WithContext(ctx))
	if full.Code != http.StatusOK || full.Body.String() != "0123456789" {
		t.Fatalf("full content status=%d body=%q", full.Code, full.Body.String())
	}
	if got := full.Header().Get("Content-Type"); got != "text/plain" {
		t.Fatalf("content type = %q", got)
	}
	if got := full.Header().Get("Content-Disposition"); got != "inline; filename*=utf-8''%E6%8A%A5%E5%91%8A%5C%22%0D%0A.txt" {
		t.Fatalf("content disposition = %q", got)
	}
	if got := full.Header().Get("Content-Length"); got != "10" {
		t.Fatalf("content length = %q", got)
	}

	ranged := httptest.NewRecorder()
	rangeReq := httptest.NewRequest(http.MethodGet, "/api/v1/attachments/"+a.ID+"/content", nil).WithContext(ctx)
	rangeReq.Header.Set("Range", "bytes=2-5")
	mux.ServeHTTP(ranged, rangeReq)
	if ranged.Code != http.StatusPartialContent || ranged.Body.String() != "2345" {
		t.Fatalf("range status=%d body=%q", ranged.Code, ranged.Body.String())
	}
	if got := ranged.Header().Get("Content-Range"); got != "bytes 2-5/10" {
		t.Fatalf("content range = %q", got)
	}

	conditional := httptest.NewRecorder()
	conditionalReq := httptest.NewRequest(http.MethodGet, "/api/v1/attachments/"+a.ID+"/content", nil).WithContext(ctx)
	conditionalReq.Header.Set("If-Modified-Since", a.CreatedAt.UTC().Format(http.TimeFormat))
	mux.ServeHTTP(conditional, conditionalReq)
	if conditional.Code != http.StatusNotModified || conditional.Body.Len() != 0 {
		t.Fatalf("conditional status=%d body=%q", conditional.Code, conditional.Body.String())
	}
}

func TestAttachmentHandlerUploadMalformedMultipartIsBadUpload(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	h := NewAttachmentHandler(svc, nil, zap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	req := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/attachments",
		strings.NewReader("--broken\r\nnot a complete multipart body"),
	).WithContext(ctx)
	req.Header.Set("Content-Type", "multipart/form-data; boundary=broken")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("malformed upload status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode malformed response: %v", err)
	}
	if body.Error.Code != "ATTACHMENT_BAD_UPLOAD" {
		t.Fatalf("malformed upload code = %q", body.Error.Code)
	}
}

func TestAttachmentHandlerUploadCleansMultipartTempFile(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("TMPDIR", tmp)
	svc, ctx := newAttachmentHandlerTestService(t)
	h := NewAttachmentHandler(svc, nil, zap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	// 32 MiB is ParseMultipartForm's in-memory threshold; this forces a real temp-backed part.
	data := bytes.Repeat([]byte{'x'}, 33<<20)
	req := newAttachmentMultipartRequest(t, ctx, "large.txt", data)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("large upload status = %d, body=%s", rec.Code, rec.Body.String())
	}
	entries, err := os.ReadDir(tmp)
	if err != nil {
		t.Fatalf("read multipart temp dir: %v", err)
	}
	if len(entries) != 0 {
		t.Fatalf("multipart temp files leaked: %v", entries)
	}
}

func newAttachmentMultipartRequest(t *testing.T, ctx context.Context, filename string, data []byte) *http.Request {
	t.Helper()
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		t.Fatalf("create multipart part: %v", err)
	}
	if _, err := part.Write(data); err != nil {
		t.Fatalf("write multipart part: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart body: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/api/v1/attachments", &body).WithContext(ctx)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	return req
}

func TestAttachmentHandlerPlaybackLeaseServesAudioWithoutBearerHeader(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	a, err := svc.Upload(ctx, "voice.mp3", "audio/mpeg", []byte("audio-bytes"))
	if err != nil {
		t.Fatalf("upload audio: %v", err)
	}
	now := time.Date(2026, 7, 25, 12, 0, 0, 0, time.UTC)
	h := NewAttachmentHandler(svc, nil, zap.NewNop())
	h.now = func() time.Time { return now }
	h.playbackLeaseTTL = time.Minute
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/attachments/"+a.ID+"/playback-lease", nil).WithContext(ctx)
	req.Host = "127.0.0.1:9876"
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("lease status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		Data struct {
			URL       string    `json:"url"`
			ExpiresAt time.Time `json:"expiresAt"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode lease response: %v", err)
	}
	if body.Data.ExpiresAt != now.Add(time.Minute) {
		t.Fatalf("expiresAt = %s", body.Data.ExpiresAt)
	}
	u, err := url.Parse(body.Data.URL)
	if err != nil {
		t.Fatalf("lease url parse: %v", err)
	}
	if u.Host != "127.0.0.1:9876" || u.Path == "" {
		t.Fatalf("lease url = %q", body.Data.URL)
	}

	fetch := httptest.NewRecorder()
	// Intentionally no Authorization or workspace header: native player URL fetches cannot attach them.
	mux.ServeHTTP(fetch, httptest.NewRequest(http.MethodGet, u.Path, nil))
	if fetch.Code != http.StatusOK {
		t.Fatalf("fetch status = %d, body=%s", fetch.Code, fetch.Body.String())
	}
	if got := fetch.Body.String(); got != "audio-bytes" {
		t.Fatalf("fetch body = %q", got)
	}
	if ct := fetch.Header().Get("Content-Type"); ct != "audio/mpeg" {
		t.Fatalf("content-type = %q", ct)
	}

	ranged := httptest.NewRecorder()
	rangeReq := httptest.NewRequest(http.MethodGet, u.Path, nil)
	rangeReq.Header.Set("Range", "bytes=0-4")
	mux.ServeHTTP(ranged, rangeReq)
	if ranged.Code != http.StatusPartialContent {
		t.Fatalf("range status = %d, body=%s", ranged.Code, ranged.Body.String())
	}
	if got := ranged.Body.String(); got != "audio" {
		t.Fatalf("range body = %q", got)
	}
}

func TestPlaybackLeaseTTLFromEnv(t *testing.T) {
	t.Setenv(rigPlaybackLeaseTTLEnv, "1500")
	if got := playbackLeaseTTLFromEnv(zap.NewNop()); got != 1500*time.Millisecond {
		t.Fatalf("TTL = %s, want 1.5s", got)
	}

	t.Setenv(rigPlaybackLeaseTTLEnv, "not-a-duration")
	if got := playbackLeaseTTLFromEnv(zap.NewNop()); got != 0 {
		t.Fatalf("invalid TTL = %s, want production default sentinel 0", got)
	}
}

func TestAttachmentHandlerPlaybackLeaseRejectsNonAudio(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	a, err := svc.Upload(ctx, "note.txt", "text/plain", []byte("hello"))
	if err != nil {
		t.Fatalf("upload text: %v", err)
	}
	h := NewAttachmentHandler(svc, nil, zap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/attachments/"+a.ID+"/playback-lease", nil).WithContext(ctx)
	req.Host = "127.0.0.1:9876"
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("status = %d, body=%s", rec.Code, rec.Body.String())
	}
}

func TestAttachmentHandlerPlaybackLeaseExpires(t *testing.T) {
	svc, ctx := newAttachmentHandlerTestService(t)
	a, err := svc.Upload(ctx, "voice.mp3", "audio/mpeg", []byte("audio-bytes"))
	if err != nil {
		t.Fatalf("upload audio: %v", err)
	}
	now := time.Date(2026, 7, 25, 12, 0, 0, 0, time.UTC)
	h := NewAttachmentHandler(svc, nil, zap.NewNop())
	h.now = func() time.Time { return now }
	h.playbackLeaseTTL = time.Second
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/attachments/"+a.ID+"/playback-lease", nil).WithContext(ctx)
	req.Host = "127.0.0.1:9876"
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("lease status = %d, body=%s", rec.Code, rec.Body.String())
	}
	var body struct {
		Data struct {
			URL string `json:"url"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode lease response: %v", err)
	}
	u, _ := url.Parse(body.Data.URL)

	now = now.Add(2 * time.Second)
	fetch := httptest.NewRecorder()
	mux.ServeHTTP(fetch, httptest.NewRequest(http.MethodGet, u.Path, nil))
	if fetch.Code != http.StatusNotFound {
		t.Fatalf("expired fetch status = %d, body=%s", fetch.Code, fetch.Body.String())
	}
}

func newAttachmentHandlerTestService(t *testing.T) (*attachmentapp.Service, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range attachmentstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	svc := attachmentapp.NewService(
		attachmentstore.New(ormpkg.Open(sqlDB)),
		blobfs.New(t.TempDir()),
		nil,
		zap.NewNop(),
	)
	return svc, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}
