package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"go.uber.org/zap"

	mediaapp "github.com/sunweilin/anselm/backend/internal/app/media"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
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
