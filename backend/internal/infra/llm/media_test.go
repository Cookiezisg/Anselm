package llm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

func TestMediaClientUpload_ResumableProofAndProviderURL(t *testing.T) {
	const installID = "ins_test"
	const uploadID = "upl_test"
	data := []byte("abcdefghi")
	var chunks []string
	creates := 0
	expiresAt := time.Now().Add(time.Hour).UTC().Format(time.RFC3339)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get(deviceproofinfra.HeaderInstallID) != installID {
			t.Fatalf("install header = %q", r.Header.Get(deviceproofinfra.HeaderInstallID))
		}
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/v1/media/uploads":
			creates++
			var got struct {
				SHA256     string `json:"sha256"`
				MimeType   string `json:"mimeType"`
				TotalBytes int    `json:"totalBytes"`
			}
			if err := json.NewDecoder(r.Body).Decode(&got); err != nil {
				t.Fatal(err)
			}
			if got.SHA256 == "" || got.MimeType != "image/png" || got.TotalBytes != len(data) {
				t.Fatalf("create = %+v", got)
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"uploadId": uploadID, "chunkMaxBytes": 4})
		case r.Method == http.MethodPut && r.URL.Path == "/v1/media/uploads/"+uploadID:
			body, err := io.ReadAll(r.Body)
			if err != nil {
				t.Fatal(err)
			}
			chunks = append(chunks, r.Header.Get("Upload-Offset")+":"+string(body))
			offset, err := strconv.Atoi(r.Header.Get("Upload-Offset"))
			if err != nil {
				t.Fatal(err)
			}
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(map[string]any{"offset": offset + len(body)})
		case r.Method == http.MethodPost && r.URL.Path == "/v1/media/uploads/"+uploadID+"/complete":
			_ = json.NewEncoder(w).Encode(map[string]any{"fetchPath": "/v1/media/leases/mls_test/content?token=opaque", "expiresAt": expiresAt})
		default:
			t.Fatalf("unexpected %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	client := NewMediaClient(server.Client())
	url, err := client.Upload(context.Background(), server.URL+"/v1", installID, "image/png", data)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if got, want := chunks, []string{"0:abcd", "4:efgh", "8:i"}; len(got) != len(want) || strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("chunks = %#v, want %#v", got, want)
	}
	if want := server.URL + "/v1/media/leases/mls_test/content?token=opaque"; url != want {
		t.Fatalf("fetch URL = %q, want %q", url, want)
	}
	// The next user message rebuilds history, but must reuse the still-valid, install-bound lease
	// rather than stream the immutable attachment through the gateway a second time.
	second, err := client.Upload(context.Background(), server.URL+"/v1", installID, "image/png", data)
	if err != nil || second != url || creates != 1 {
		t.Fatalf("second upload = (%q, %v), creates=%d; want cached URL and one create", second, err, creates)
	}
}

func TestMediaClientUpload_RejectsBadAppendAcknowledgement(t *testing.T) {
	cancels := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/media/uploads":
			_ = json.NewEncoder(w).Encode(map[string]any{"uploadId": "upl_test", "chunkMaxBytes": 4})
		case r.Method == http.MethodPut && r.URL.Path == "/media/uploads/upl_test":
			_ = json.NewEncoder(w).Encode(map[string]any{"offset": 0})
		case r.Method == http.MethodDelete && r.URL.Path == "/media/uploads/upl_test":
			cancels++
			w.WriteHeader(http.StatusNoContent)
		default:
			t.Fatalf("unexpected %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()
	_, err := NewMediaClient(server.Client()).Upload(context.Background(), server.URL, "ins_test", "image/png", []byte("data"))
	if err == nil || !strings.Contains(err.Error(), "acknowledged offset") {
		t.Fatalf("err = %v, want rejected acknowledgement", err)
	}
	if cancels != 1 {
		t.Fatalf("cancel requests = %d, want one cleanup DELETE", cancels)
	}
}

func TestMediaClientUpload_ReconcilesAmbiguousChunkBeforeContinuing(t *testing.T) {
	const installID = "ins_test"
	const uploadID = "upl_test"
	data := []byte("abcdef")
	var offset int
	var statusReads int
	var chunks []string
	firstChunk := true
	expiresAt := time.Now().Add(time.Hour).UTC().Format(time.RFC3339)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get(deviceproofinfra.HeaderInstallID) != installID {
			t.Fatalf("install header = %q", r.Header.Get(deviceproofinfra.HeaderInstallID))
		}
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/media/uploads":
			_ = json.NewEncoder(w).Encode(map[string]any{"uploadId": uploadID, "chunkMaxBytes": 3})
		case r.Method == http.MethodGet && r.URL.Path == "/media/uploads/"+uploadID:
			statusReads++
			_ = json.NewEncoder(w).Encode(map[string]any{"offset": offset})
		case r.Method == http.MethodPut && r.URL.Path == "/media/uploads/"+uploadID:
			body, err := io.ReadAll(r.Body)
			if err != nil {
				t.Fatal(err)
			}
			gotOffset, err := strconv.Atoi(r.Header.Get("Upload-Offset"))
			if err != nil || gotOffset != offset {
				t.Fatalf("chunk offset = %q with cursor %d: %v", r.Header.Get("Upload-Offset"), offset, err)
			}
			chunks = append(chunks, r.Header.Get("Upload-Offset")+":"+string(body))
			offset += len(body) // Simulate fsync + durable cursor advance before the response is lost.
			if firstChunk {
				firstChunk = false
				hj, ok := w.(http.Hijacker)
				if !ok {
					t.Fatal("test server must support connection hijacking")
				}
				conn, _, err := hj.Hijack()
				if err != nil {
					t.Fatal(err)
				}
				_ = conn.Close() // The client cannot know whether this chunk committed.
				return
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"offset": offset})
		case r.Method == http.MethodPost && r.URL.Path == "/media/uploads/"+uploadID+"/complete":
			_ = json.NewEncoder(w).Encode(map[string]any{"fetchPath": "/v1/media/leases/mls_test/content?token=opaque", "expiresAt": expiresAt})
		default:
			t.Fatalf("unexpected %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	got, err := NewMediaClient(server.Client()).Upload(context.Background(), server.URL, installID, "image/png", data)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if want := server.URL + "/v1/media/leases/mls_test/content?token=opaque"; got != want {
		t.Fatalf("fetch URL = %q, want %q", got, want)
	}
	if statusReads != 1 || strings.Join(chunks, ",") != "0:abc,3:def" {
		t.Fatalf("status reads=%d chunks=%v; want one cursor reconciliation without replay", statusReads, chunks)
	}
}

func TestMediaClientUpload_RefreshesLeaseInsideSafetyWindow(t *testing.T) {
	creates := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/media/uploads":
			creates++
			_ = json.NewEncoder(w).Encode(map[string]any{"uploadId": "upl_test", "chunkMaxBytes": 16})
		case r.Method == http.MethodPut:
			body, err := io.ReadAll(r.Body)
			if err != nil {
				t.Fatal(err)
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"offset": len(body)})
		case r.Method == http.MethodPost && strings.HasSuffix(r.URL.Path, "/complete"):
			_ = json.NewEncoder(w).Encode(map[string]any{
				"fetchPath": "/v1/media/leases/mls_test/content?token=opaque",
				"expiresAt": time.Now().Add(leaseRefreshSkew / 2).UTC().Format(time.RFC3339),
			})
		default:
			t.Fatalf("unexpected %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	client := NewMediaClient(server.Client())
	for range 2 {
		if _, err := client.Upload(context.Background(), server.URL, "ins_test", "image/png", []byte("data")); err != nil {
			t.Fatalf("Upload: %v", err)
		}
	}
	if creates != 2 {
		t.Fatalf("creates = %d, want refresh instead of reusing a near-expiry lease", creates)
	}
}
