package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestSubmitVideoAnselm_UsesAnimationRouteForFirstFrame(t *testing.T) {
	var gotPath string
	var gotBody map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		raw, _ := io.ReadAll(r.Body)
		if err := json.Unmarshal(raw, &gotBody); err != nil {
			t.Fatalf("request body is not JSON: %v", err)
		}
		if r.Header.Get("X-Anselm-Install-ID") != "ins_test" {
			t.Fatalf("install id header = %q, want ins_test", r.Header.Get("X-Anselm-Install-ID"))
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		_, _ = io.WriteString(w, `{"id":"vh_test"}`)
	}))
	defer server.Close()

	job, err := SubmitVideoAnselm(context.Background(), http.DefaultClient, server.URL+"/v1", "ins_test", VideoRequest{
		Prompt:      "slow push in",
		DurationSec: 5,
		Aspect:      "landscape",
		Resolution:  "720p",
		FirstFrame:  &DataURL{Mime: "image/png", Bytes: []byte("PNG")},
	})
	if err != nil {
		t.Fatalf("submit animation: %v", err)
	}
	if job.Handle != "vh_test" {
		t.Fatalf("handle = %q, want vh_test", job.Handle)
	}
	if gotPath != "/v1/videos/animations" {
		t.Fatalf("path = %q, want /v1/videos/animations", gotPath)
	}
	image, ok := gotBody["image"].(string)
	if !ok || image != "data:image/png;base64,UE5H" {
		t.Fatalf("image = %v, want the exact data URL", gotBody["image"])
	}
	if gotBody["prompt"] != "slow push in" || gotBody["seconds"] != float64(5) {
		t.Fatalf("payload lost animation intent: %#v", gotBody)
	}
}

func TestSubmitVideoAnselm_TextRouteOmitsFirstFrame(t *testing.T) {
	var gotPath string
	var gotRaw []byte
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotRaw, _ = io.ReadAll(r.Body)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		_, _ = io.WriteString(w, `{"id":"vh_text"}`)
	}))
	defer server.Close()

	if _, err := SubmitVideoAnselm(context.Background(), http.DefaultClient, server.URL+"/v1", "ins_test", VideoRequest{
		Prompt: "a lighthouse", DurationSec: 5, Aspect: "landscape", Resolution: "720p",
	}); err != nil {
		t.Fatalf("submit text video: %v", err)
	}
	if gotPath != "/v1/videos/generations" {
		t.Fatalf("path = %q, want /v1/videos/generations", gotPath)
	}
	if strings.Contains(string(gotRaw), `"image"`) {
		t.Fatalf("text route must not carry an image: %s", gotRaw)
	}
}
