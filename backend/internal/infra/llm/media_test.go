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

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

func TestMediaClientUpload_ResumableProofAndProviderURL(t *testing.T) {
	const installID = "ins_test"
	const uploadID = "upl_test"
	data := []byte("abcdefghi")
	var chunks []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get(deviceproofinfra.HeaderInstallID) != installID {
			t.Fatalf("install header = %q", r.Header.Get(deviceproofinfra.HeaderInstallID))
		}
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/v1/media/uploads":
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
			_ = json.NewEncoder(w).Encode(map[string]any{"fetchPath": "/v1/media/leases/mls_test/content?token=opaque"})
		default:
			t.Fatalf("unexpected %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	url, err := NewMediaClient(server.Client()).Upload(context.Background(), server.URL+"/v1", installID, "image/png", data)
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}
	if got, want := chunks, []string{"0:abcd", "4:efgh", "8:i"}; len(got) != len(want) || strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("chunks = %#v, want %#v", got, want)
	}
	if want := server.URL + "/v1/media/leases/mls_test/content?token=opaque"; url != want {
		t.Fatalf("fetch URL = %q, want %q", url, want)
	}
}

func TestMediaClientUpload_RejectsBadAppendAcknowledgement(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			_ = json.NewEncoder(w).Encode(map[string]any{"uploadId": "upl_test", "chunkMaxBytes": 4})
		case http.MethodPut:
			_ = json.NewEncoder(w).Encode(map[string]any{"offset": 0})
		}
	}))
	defer server.Close()
	_, err := NewMediaClient(server.Client()).Upload(context.Background(), server.URL, "ins_test", "image/png", []byte("data"))
	if err == nil || !strings.Contains(err.Error(), "acknowledged offset") {
		t.Fatalf("err = %v, want rejected acknowledgement", err)
	}
}
