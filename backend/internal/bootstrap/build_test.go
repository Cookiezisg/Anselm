package bootstrap

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestBuild_ServesHealth is the composition-root smoke test: Build wires the whole backend
// against an in-memory DB (empty DataDir), and the assembled handler serves the health probe
// without a workspace (the onboarding-exempt route). This proves every Service constructor +
// adapter injection + handler registration + middleware chain type-checks AND runs.
//
// TestBuild_ServesHealth 是 composition-root 冒烟测试：Build 用内存 DB 装配整个后端，装好的 handler
// 无需 workspace 即服务 health 探针（onboarding 豁免路由）——证明每个 Service 构造 + 适配器注入 +
// handler 注册 + 中间件链不仅类型对、还能跑。
func TestBuild_ServesHealth(t *testing.T) {
	app, err := Build(Config{})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	srv := httptest.NewServer(app.Handler)
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/api/v1/health")
	if err != nil {
		t.Fatalf("GET health: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("health status = %d, want 200", resp.StatusCode)
	}
	buf := make([]byte, 256)
	n, _ := resp.Body.Read(buf)
	if !strings.Contains(string(buf[:n]), `"status":"ok"`) {
		t.Fatalf("health body = %q, want ok envelope", string(buf[:n]))
	}
}

// TestBuild_GuardsWorkspaceRoutes proves the middleware chain is wired: a /api/v1 resource route
// (not onboarding-exempt) with no workspace header is rejected before reaching the handler.
//
// TestBuild_GuardsWorkspaceRoutes 证明中间件链接好了：非豁免的 /api/v1 资源路由在无 workspace 头时
// 在抵达 handler 前被拒。
func TestBuild_GuardsWorkspaceRoutes(t *testing.T) {
	app, err := Build(Config{})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	srv := httptest.NewServer(app.Handler)
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/api/v1/agents")
	if err != nil {
		t.Fatalf("GET agents: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		t.Fatalf("guarded route returned 200 without a workspace; middleware not wired")
	}
}

// TestApp_BootShutdownNoPanic exercises the full lifecycle, confirming Boot starts + Shutdown stops
// the background work cleanly. No network: runtimes are fetched lazily on first use, never at Boot.
//
// TestApp_BootShutdownNoPanic 跑完整生命周期，确认 Boot 起 + Shutdown 干净停后台工作。不联网：运行时
// 首次使用时才懒拉，Boot 阶段从不拉取。
func TestApp_BootShutdownNoPanic(t *testing.T) {
	// DataDir → a temp dir: Boot's sandbox.Bootstrap preps the sandbox root under it, so the test
	// must not pollute the package dir (t.TempDir auto-cleans).
	app, err := Build(Config{DataDir: t.TempDir()})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	app.Boot(context.Background())
	app.Shutdown(context.Background())
}

// TestBuild_MessagesAroundAndAnchors drives the two W6 navigation endpoints over the fully
// assembled server (real routes + middleware + envelope): the around/dir/cursor mutual-exclusion
// contract rejects cleanly (400 INVALID_REQUEST), an unknown around target on a real conversation
// is 404 MESSAGE_NOT_FOUND, and GET anchors serves the N4 empty page (data:[]) for a fresh
// conversation while a foreign conversation id is 404 CONVERSATION_NOT_FOUND.
//
// TestBuild_MessagesAroundAndAnchors 在整装 server 上驱动两个 W6 导航端点（真路由 + 中间件 +
// envelope）：around/dir/cursor 互斥契约干净拒绝（400 INVALID_REQUEST）、真对话上未知 around 目标
// 404 MESSAGE_NOT_FOUND、新对话 GET anchors 返 N4 空页（data:[]）、外来对话 id 404
// CONVERSATION_NOT_FOUND。
func TestBuild_MessagesAroundAndAnchors(t *testing.T) {
	app, err := Build(Config{})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	srv := httptest.NewServer(app.Handler)
	defer srv.Close()
	client := srv.Client()
	var wsID string

	post := func(path, body string) map[string]any {
		t.Helper()
		req, _ := http.NewRequestWithContext(context.Background(), http.MethodPost, srv.URL+path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if wsID != "" {
			req.Header.Set("X-Anselm-Workspace-ID", wsID)
		}
		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("POST %s: %v", path, err)
		}
		defer resp.Body.Close()
		var out struct {
			Data map[string]any `json:"data"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
			t.Fatalf("POST %s decode: %v", path, err)
		}
		return out.Data
	}
	get := func(path string) (int, string) {
		t.Helper()
		req, _ := http.NewRequestWithContext(context.Background(), http.MethodGet, srv.URL+path, nil)
		req.Header.Set("X-Anselm-Workspace-ID", wsID)
		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("GET %s: %v", path, err)
		}
		defer resp.Body.Close()
		buf := new(strings.Builder)
		_, _ = io.Copy(buf, resp.Body)
		return resp.StatusCode, buf.String()
	}

	ws := post("/api/v1/workspaces", `{"name":"w6"}`)
	wsID, _ = ws["id"].(string)
	if wsID == "" {
		t.Fatalf("workspace create returned no id: %v", ws)
	}
	conv := post("/api/v1/conversations", `{}`)
	convID, _ := conv["id"].(string)
	if convID == "" {
		t.Fatalf("conversation create returned no id: %v", conv)
	}

	// Mutual exclusion + dir validation (the contract pins these verbatim). 互斥 + dir 校验。
	if code, body := get("/api/v1/conversations/" + convID + "/messages?around=msg_x&cursor=abc"); code != http.StatusBadRequest || !strings.Contains(body, "INVALID_REQUEST") {
		t.Fatalf("around+cursor = %d %s, want 400 INVALID_REQUEST", code, body)
	}
	if code, body := get("/api/v1/conversations/" + convID + "/messages?dir=sideways"); code != http.StatusBadRequest || !strings.Contains(body, "INVALID_REQUEST") {
		t.Fatalf("bad dir = %d %s, want 400 INVALID_REQUEST", code, body)
	}
	if code, body := get("/api/v1/conversations/" + convID + "/messages?dir=newer"); code != http.StatusBadRequest || !strings.Contains(body, "INVALID_REQUEST") {
		t.Fatalf("dir=newer without cursor = %d %s, want 400 INVALID_REQUEST", code, body)
	}

	// Identity anchoring: an unknown target on a real conversation is a clean 404. 身份锚点 404。
	if code, body := get("/api/v1/conversations/" + convID + "/messages?around=msg_nope"); code != http.StatusNotFound || !strings.Contains(body, "MESSAGE_NOT_FOUND") {
		t.Fatalf("around unknown target = %d %s, want 404 MESSAGE_NOT_FOUND", code, body)
	}

	// Anchors: fresh conversation → the N4 empty page; unknown conversation → 404. 空页 / 404。
	if code, body := get("/api/v1/conversations/" + convID + "/anchors"); code != http.StatusOK || !strings.Contains(body, `"data":[]`) {
		t.Fatalf("anchors fresh = %d %s, want 200 data:[]", code, body)
	}
	if code, body := get("/api/v1/conversations/cv_nope/anchors"); code != http.StatusNotFound || !strings.Contains(body, "CONVERSATION_NOT_FOUND") {
		t.Fatalf("anchors unknown conv = %d %s, want 404 CONVERSATION_NOT_FOUND", code, body)
	}
}
