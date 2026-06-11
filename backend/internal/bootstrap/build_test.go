package bootstrap

import (
	"context"
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
