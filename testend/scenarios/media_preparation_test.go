package scenarios

import (
	"bytes"
	"encoding/json"
	"image"
	"image/jpeg"
	"path/filepath"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// mediaPrepAtt is the public attachment projection plus the UI-facing preparation sidecar.
// The test intentionally stays on HTTP: derivative rows and worker internals are not the product
// surface a frontend can rely on.
type mediaPrepAtt struct {
	ID        string    `json:"id"`
	Filename  string    `json:"filename"`
	MimeType  string    `json:"mimeType"`
	SizeBytes int64     `json:"sizeBytes"`
	Kind      string    `json:"kind"`
	Prep      mediaPrep `json:"preparation"`
}

type mediaPrep struct {
	Status    string `json:"status"`
	Phase     string `json:"phase"`
	Target    string `json:"target"`
	Width     int    `json:"width"`
	Height    int    `json:"height"`
	MimeType  string `json:"mimeType"`
	SizeBytes int64  `json:"sizeBytes"`
	ErrorCode string `json:"errorCode"`
	CanCancel bool   `json:"canCancel"`
	CanRetry  bool   `json:"canRetry"`
}

func mediaPrepGET(t *testing.T, wc *harness.Client, id string) mediaPrepAtt {
	t.Helper()
	var out mediaPrepAtt
	wc.GET("/api/v1/attachments/"+id).OK(t, &out)
	return out
}

// TestAttachmentPreparation_ManagedImageLifecycle proves the preparation sidecar is a real
// asynchronous product surface, not merely a static DTO: a valid image reaches ready with
// derivative metadata, while an undecodable image exposes failure and can be cancelled/retried.
// The immutable original remains available throughout the derivative lifecycle.
func TestAttachmentPreparation_ManagedImageLifecycle(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "media-prep-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	validResp := wc.Upload(t, "/api/v1/attachments", "ready.png", "image/png", tinyPNG)
	if validResp.Status != 201 {
		t.Fatalf("valid image upload: want 201, got %d %s", validResp.Status, validResp.Raw)
	}
	var valid mediaPrepAtt
	if err := json.Unmarshal(validResp.Data, &valid); err != nil {
		t.Fatalf("decode valid image response: %v", err)
	}
	if valid.Kind != "image" || valid.Prep.Target != "model-default" {
		t.Fatalf("image upload must expose model-default preparation, got kind=%q prep=%+v", valid.Kind, valid.Prep)
	}
	if valid.Prep.Status != "pending" && valid.Prep.Status != "running" && valid.Prep.Status != "ready" {
		t.Fatalf("new valid image must expose a live preparation status, got %+v", valid.Prep)
	}

	var ready mediaPrepAtt
	harness.Eventually(t, 15000, "valid image model-default derivative reaches ready", func() bool {
		ready = mediaPrepGET(t, wc, valid.ID)
		return ready.Prep.Status == "ready"
	})
	if ready.Prep.Phase != "ready" || ready.Prep.Target != "model-default" || ready.Prep.Width != 1 || ready.Prep.Height != 1 ||
		ready.Prep.MimeType == "" || ready.Prep.SizeBytes <= 0 || ready.Prep.CanCancel || ready.Prep.CanRetry {
		t.Fatalf("ready preparation must expose bounded derivative metadata and no mutations: %+v", ready.Prep)
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+valid.ID+"/content", "", nil); got.Status != 200 || !bytes.Equal(got.Raw, tinyPNG) {
		t.Fatalf("ready derivative must not replace the immutable original: status=%d bytesEqual=%v", got.Status, bytes.Equal(got.Raw, tinyPNG))
	}

	// A syntactically image-typed but undecodable upload exercises the honest failure path. It must
	// not erase or poison the original attachment merely because its optional proxy failed.
	badBytes := []byte("this is not a PNG")
	badResp := wc.Upload(t, "/api/v1/attachments", "broken.png", "image/png", badBytes)
	if badResp.Status != 201 {
		t.Fatalf("undecodable image upload must still create the original row, got %d %s", badResp.Status, badResp.Raw)
	}
	var bad mediaPrepAtt
	if err := json.Unmarshal(badResp.Data, &bad); err != nil {
		t.Fatalf("decode broken image response: %v", err)
	}
	harness.Eventually(t, 15000, "undecodable image preparation reaches failed", func() bool {
		bad = mediaPrepGET(t, wc, bad.ID)
		return bad.Prep.Status == "failed"
	})
	if bad.Prep.Phase != "failed" || bad.Prep.ErrorCode != "MEDIA_DERIVATIVE_FAILED" || !bad.Prep.CanRetry || bad.Prep.CanCancel {
		t.Fatalf("failed preparation must be retryable and explain the failure: %+v", bad.Prep)
	}

	var cancelled mediaPrep
	wc.POST("/api/v1/attachments/"+bad.ID+"/preparation/cancel", nil).OK(t, &cancelled)
	if cancelled.Status != "cancelled" || cancelled.Phase != "cancelled" || !cancelled.CanRetry || cancelled.CanCancel {
		t.Fatalf("cancel must expose cancelled/retryable state, got %+v", cancelled)
	}
	var retried mediaPrep
	wc.POST("/api/v1/attachments/"+bad.ID+"/preparation/retry", nil).OK(t, &retried)
	if retried.Status != "pending" && retried.Status != "running" && retried.Status != "failed" {
		t.Fatalf("retry must requeue preparation rather than report an unrelated state, got %+v", retried)
	}
	harness.Eventually(t, 15000, "retried undecodable image preparation reaches failed again", func() bool {
		retried = mediaPrepGET(t, wc, bad.ID).Prep
		return retried.Status == "failed"
	})
	if retried.ErrorCode != "MEDIA_DERIVATIVE_FAILED" || !retried.CanRetry {
		t.Fatalf("retried failure must remain honest and retryable, got %+v", retried)
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+bad.ID+"/content", "", nil); got.Status != 200 || !bytes.Equal(got.Raw, badBytes) {
		t.Fatalf("derivative failure/retry must preserve original bytes: status=%d bytesEqual=%v", got.Status, bytes.Equal(got.Raw, badBytes))
	}

	textResp := wc.Upload(t, "/api/v1/attachments", "notes.txt", "text/plain", []byte("not media"))
	var text mediaPrepAtt
	textResp.OK(t, &text)
	if text.Prep.Status != "not_required" || text.Prep.Phase != "not_required" || text.Prep.Target != "" {
		t.Fatalf("non-image preparation must be explicitly not_required, got %+v", text.Prep)
	}
}

func mediaBudgetJPEG(t *testing.T) []byte {
	t.Helper()
	const side = 1536
	img := image.NewRGBA(image.Rect(0, 0, side, side))
	state := uint32(0x9e3779b9)
	for i := 0; i < len(img.Pix); i += 4 {
		state = state*1664525 + 1013904223
		img.Pix[i], img.Pix[i+1], img.Pix[i+2], img.Pix[i+3] = byte(state>>24), byte(state>>16), byte(state>>8), 0xff
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 95}); err != nil {
		t.Fatalf("encode media budget fixture: %v", err)
	}
	if buf.Len() <= 1<<20 {
		t.Fatalf("media budget fixture unexpectedly compresses below 1MB: %d bytes", buf.Len())
	}
	return buf.Bytes()
}

// TestAttachmentPreparation_MediaBudgetEvictsAndRegenerates proves resource hygiene at the
// lifecycle boundary: boot GC evicts ready derivative bytes over the configured cap, marks the
// durable row failed with a recoverable code, and never touches the user-visible original.
func TestAttachmentPreparation_MediaBudgetEvictsAndRegenerates(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "media-budget-ws"}).Field(t, "id")
	wc := c.WS(wsID)
	wc.PATCH("/api/v1/limits", map[string]any{"guards": map[string]any{"mediaCacheMaxMB": 1}}).OK(t, nil)

	original := mediaBudgetJPEG(t)
	resp := wc.Upload(t, "/api/v1/attachments", "budget.jpg", "image/jpeg", original)
	if resp.Status != 201 {
		t.Fatalf("budget image upload: want 201, got %d %s", resp.Status, resp.Raw)
	}
	var att mediaPrepAtt
	resp.OK(t, &att)
	harness.Eventually(t, 30000, "over-budget image derivative reaches ready before restart", func() bool {
		att = mediaPrepGET(t, wc, att.ID)
		return att.Prep.Status == "ready"
	})
	if att.Prep.SizeBytes <= 1<<20 {
		t.Fatalf("ready derivative must exceed the 1MB cache cap for an eviction probe: %+v", att.Prep)
	}

	// media GC is deliberately boot-time (delete-time GC races an in-flight upload), so restart is
	// the public lifecycle boundary that should reclaim the regenerated bytes.
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)
	var evicted mediaPrepAtt
	harness.Eventually(t, 15000, "boot media GC exposes evicted derivative", func() bool {
		evicted = mediaPrepGET(t, wc, att.ID)
		return evicted.Prep.Status == "failed"
	})
	if evicted.Prep.ErrorCode != "MEDIA_ARTIFACT_EVICTED" || !evicted.Prep.CanRetry || evicted.Prep.CanCancel {
		t.Fatalf("evicted derivative must be failed and retryable: %+v", evicted.Prep)
	}
	mediaFiles, _ := filepath.Glob(filepath.Join(srv.DataDir, "workspaces", wsID, "media", "*", "*"))
	for _, p := range mediaFiles {
		if !strings.HasSuffix(p, ".tmp") {
			t.Fatalf("boot media GC left a derived artifact behind: %s", p)
		}
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+att.ID+"/content", "", nil); got.Status != 200 || !bytes.Equal(got.Raw, original) {
		t.Fatalf("media eviction must preserve original attachment: status=%d bytesEqual=%v", got.Status, bytes.Equal(got.Raw, original))
	}

	// The failed row is intentionally recoverable: retry reuses the exact source/transform identity
	// and the worker can rebuild the proxy after eviction.
	var retried mediaPrep
	wc.POST("/api/v1/attachments/"+att.ID+"/preparation/retry", nil).OK(t, &retried)
	harness.Eventually(t, 30000, "evicted derivative regenerates after retry", func() bool {
		retried = mediaPrepGET(t, wc, att.ID).Prep
		return retried.Status == "ready"
	})
	if retried.SizeBytes <= 1<<20 || retried.MimeType == "" {
		t.Fatalf("retry must rebuild a usable derivative, got %+v", retried)
	}
}
