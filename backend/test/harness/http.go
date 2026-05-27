//go:build pipeline

package harness

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"testing"
	"time"
)

// URL returns the test server's base URL.
//
// URL 返回 test server base URL。
func (h *Harness) URL() string { return h.server.URL }

// HTTPClient returns a client for short-lived requests; SSE uses SubscribeSSE.
//
// Timeout sized for slowest legitimate sync path: first-ever function POST
// triggers mise to fetch + install Python runtime (15-25s typical, up to ~40s
// under load / cold disk). 30s here previously caused flake when env sync
// raced the deadline — bumped to 120s with 4x safety margin.
//
// HTTPClient 返回短请求 client;SSE 走 SubscribeSSE。
// timeout 按最慢合法同步路径设:首次 function POST 触发 mise 下载装 Python
// (典型 15-25s,负载 / 冷盘下到 ~40s)。原 30s 偶发卡 env sync 死线,改 120s。
func (h *Harness) HTTPClient() *http.Client {
	return &http.Client{Timeout: 120 * time.Second}
}

// PostJSON POSTs body as JSON and decodes into out; fatals on non-2xx.
//
// PostJSON POST JSON 解到 out，非 2xx 直接 fatal。
func (h *Harness) PostJSON(path string, body, out any) *http.Response {
	h.t.Helper()
	return h.requestJSON("POST", path, body, out)
}

// GetJSON GETs path and decodes into out.
//
// GetJSON GET path 解到 out。
func (h *Harness) GetJSON(path string, out any) *http.Response {
	h.t.Helper()
	return h.requestJSON("GET", path, nil, out)
}

// PatchJSON PATCHes body to path and decodes into out.
//
// PatchJSON PATCH body 到 path 解到 out。
func (h *Harness) PatchJSON(path string, body, out any) *http.Response {
	h.t.Helper()
	return h.requestJSON("PATCH", path, body, out)
}

// Delete DELETEs path; fatals on non-2xx.
//
// Delete DELETE path，非 2xx 直接 fatal。
func (h *Harness) Delete(path string) *http.Response {
	h.t.Helper()
	return h.requestJSON("DELETE", path, nil, nil)
}

// requestJSON drives PostJSON / GetJSON / PatchJSON / Delete; auto-injects
// X-Forgify-User-ID so IdentifyUser middleware stamps ctx with the seeded
// test user (harness.New 启动期已 seed).
//
// requestJSON 是 Post/Get/Patch/Delete 的共用底层;自动注 X-Forgify-User-ID
// 头让 IdentifyUser middleware 在 ctx 打 user id(harness.New 启动期已 seed)。
func (h *Harness) requestJSON(method, path string, body, out any) *http.Response {
	h.t.Helper()
	var rdr io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			h.t.Fatalf("marshal %s %s body: %v", method, path, err)
		}
		rdr = bytes.NewReader(buf)
	}
	req, err := http.NewRequest(method, h.server.URL+path, rdr)
	if err != nil {
		h.t.Fatalf("build %s %s: %v", method, path, err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("X-Forgify-User-ID", SeedTestUserID)
	resp, err := h.HTTPClient().Do(req)
	if err != nil {
		h.t.Fatalf("%s %s: %v", method, path, err)
	}
	if resp.StatusCode >= 300 {
		raw, _ := io.ReadAll(resp.Body)
		_ = resp.Body.Close()
		h.t.Fatalf("%s %s: status %d: %s", method, path, resp.StatusCode, raw)
	}
	if out != nil {
		defer resp.Body.Close()
		if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
			h.t.Fatalf("%s %s: decode response: %v", method, path, err)
		}
	} else {
		_ = resp.Body.Close()
	}
	return resp
}

// DoRequest sends a JSON request and returns the status without fatal on non-2xx.
// Auto-injects X-Forgify-User-ID header (harness.New pre-seeds this user).
//
// DoRequest 发 JSON 请求返状态码,非 2xx 不 fatal;自动注 X-Forgify-User-ID
// header(harness.New 已 pre-seed 此 user)。
func DoRequest(t *testing.T, h *Harness, method, path string, body, out any) int {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("DoRequest: marshal body: %v", err)
		}
		rdr = bytes.NewReader(buf)
	}
	req, err := http.NewRequest(method, h.URL()+path, rdr)
	if err != nil {
		t.Fatalf("DoRequest: build request: %v", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("X-Forgify-User-ID", SeedTestUserID)
	resp, err := h.HTTPClient().Do(req)
	if err != nil {
		t.Fatalf("DoRequest: %s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	if out != nil {
		raw, _ := io.ReadAll(resp.Body)
		if err := json.Unmarshal(raw, out); err != nil {
			t.Logf("DoRequest: decode response (status=%d): %v; body=%s", resp.StatusCode, err, raw)
		}
	}
	return resp.StatusCode
}

// UploadFile uploads data as a multipart file to POST /api/v1/attachments.
// Auto-injects X-Forgify-User-ID header.
//
// UploadFile 把 data 作 multipart 上传到 /api/v1/attachments;自动注 user header。
func UploadFile(t *testing.T, h *Harness, filename, mimeType string, data []byte) string {
	t.Helper()
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	header := make(textproto.MIMEHeader)
	header.Set("Content-Disposition",
		fmt.Sprintf(`form-data; name="file"; filename="%s"`, filename))
	header.Set("Content-Type", mimeType)
	part, err := mw.CreatePart(header)
	if err != nil {
		t.Fatalf("UploadFile: create part: %v", err)
	}
	if _, err := part.Write(data); err != nil {
		t.Fatalf("UploadFile: write data: %v", err)
	}
	mw.Close()

	req, err := http.NewRequest("POST", h.URL()+"/api/v1/attachments", &body)
	if err != nil {
		t.Fatalf("UploadFile: build request: %v", err)
	}
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.Header.Set("X-Forgify-User-ID", SeedTestUserID)

	resp, err := h.HTTPClient().Do(req)
	if err != nil {
		t.Fatalf("UploadFile: do: %v", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("UploadFile: status=%d, want 201; body=%s", resp.StatusCode, raw)
	}
	var out struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &out); err != nil || out.Data.ID == "" {
		t.Fatalf("UploadFile: decode response: %v; body=%s", err, raw)
	}
	return out.Data.ID
}
