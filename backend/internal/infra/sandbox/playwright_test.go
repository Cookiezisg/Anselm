// playwright_test.go — pure-function unit tests for PlaywrightInstaller +
// PlaywrightEnvManager. Real `playwright install chromium` shellout
// (downloads ~300 MB) belongs in the D9 pipeline suite.
//
// playwright_test.go ——PlaywrightInstaller + PlaywrightEnvManager 的
// pure-function 单测。真 `playwright install chromium` shellout（下 ~300 MB）
// 归 D9 pipeline 套。

package sandbox

import (
	"context"
	"path/filepath"
	"runtime"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// ── PlaywrightInstaller ──────────────────────────────────────────────

var _ sandboxdomain.RuntimeInstaller = (*PlaywrightInstaller)(nil)

func TestPlaywrightInstaller_Kind(t *testing.T) {
	pi := NewPlaywrightInstaller("/tmp/playwright")
	if got := pi.Kind(); got != "browsers" {
		t.Errorf("Kind() = %q, want browsers", got)
	}
}

func TestPlaywrightInstaller_ListAvailable(t *testing.T) {
	pi := NewPlaywrightInstaller("/tmp/playwright")
	got, err := pi.ListAvailable(context.Background())
	if err != nil {
		t.Fatalf("ListAvailable: %v", err)
	}
	want := map[string]bool{"chromium": true, "firefox": true, "webkit": true}
	if len(got) != 3 {
		t.Errorf("got %d browsers, want 3 (chromium/firefox/webkit)", len(got))
	}
	for _, b := range got {
		if !want[b] {
			t.Errorf("unexpected browser channel %q", b)
		}
	}
}

func TestPlaywrightInstaller_ResolveDefault_Chromium(t *testing.T) {
	pi := NewPlaywrightInstaller("/tmp/playwright")
	got, err := pi.ResolveDefault(context.Background())
	if err != nil {
		t.Fatalf("ResolveDefault: %v", err)
	}
	if got != "chromium" {
		t.Errorf("ResolveDefault = %q, want chromium (most-used Playwright browser)", got)
	}
}

func TestPlaywrightInstaller_Locate_PointsAtSharedCache(t *testing.T) {
	pi := NewPlaywrightInstaller("/tmp/playwright")
	got, err := pi.Locate("chromium", "/data/sandbox")
	if err != nil {
		t.Fatalf("Locate: %v", err)
	}
	want := filepath.Join("/data/sandbox", playwrightBrowsersSubdir)
	if got != want {
		t.Errorf("Locate = %q, want %q (shared browsers cache root)", got, want)
	}
	// Locate should be invariant in the version arg — Playwright pins
	// browser binary version per playwright npm version, not per channel.
	gotFox, _ := pi.Locate("firefox", "/data/sandbox")
	if gotFox != got {
		t.Errorf("Locate(firefox) = %q, want same path as chromium %q (shared cache)", gotFox, got)
	}
}

// ── PlaywrightEnvManager ─────────────────────────────────────────────

var _ sandboxdomain.EnvManager = (*PlaywrightEnvManager)(nil)

func TestPlaywrightEnvManager_Kind(t *testing.T) {
	pm := NewPlaywrightEnvManager(NewNodeEnvManager(newFakeToolRegistry(map[string]string{"pnpm": "/tmp/pnpm"})), "/data/sandbox")
	if got := pm.Kind(); got != "browsers" {
		t.Errorf("Kind() = %q, want browsers", got)
	}
}

// TestPlaywrightEnvManager_DelegatesToNode verifies that path-derivation
// methods (EnvBin / EnvDir) match the wrapped NodeEnvManager output —
// Playwright env IS a Node env, so the layouts must be identical.
//
// TestPlaywrightEnvManager_DelegatesToNode 验证路径推导方法（EnvBin / EnvDir）
// 输出与包装的 NodeEnvManager 一致——Playwright env 即 Node env，布局必须
// 一样。
func TestPlaywrightEnvManager_DelegatesToNode(t *testing.T) {
	node := NewNodeEnvManager(newFakeToolRegistry(map[string]string{"pnpm": "/tmp/pnpm"}))
	pm := NewPlaywrightEnvManager(node, "/data/sandbox")

	envPath := "/data/envs/mcp/playwright"
	if pm.EnvDir(envPath) != node.EnvDir(envPath) {
		t.Errorf("EnvDir delegation broken: pm=%q node=%q", pm.EnvDir(envPath), node.EnvDir(envPath))
	}
	if pm.EnvBin(envPath, "playwright") != node.EnvBin(envPath, "playwright") {
		t.Errorf("EnvBin delegation broken: pm=%q node=%q", pm.EnvBin(envPath, "playwright"), node.EnvBin(envPath, "playwright"))
	}

	// Sanity: the path actually points into the conventional Node bin shim.
	got := pm.EnvBin(envPath, "playwright")
	var want string
	if runtime.GOOS == "windows" {
		want = filepath.Join(envPath, "node_modules", ".bin", "playwright.cmd")
	} else {
		want = filepath.Join(envPath, "node_modules", ".bin", "playwright")
	}
	if got != want {
		t.Errorf("EnvBin = %q, want %q", got, want)
	}
}
