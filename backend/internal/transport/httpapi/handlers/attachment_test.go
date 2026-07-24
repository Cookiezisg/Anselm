package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
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
