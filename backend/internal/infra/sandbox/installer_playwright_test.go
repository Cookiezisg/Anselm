// installer_playwright_test.go — pure-function unit tests for
// PlaywrightInstaller. Real `playwright install chromium` shellout
// (downloads ~300 MB) belongs in the D9 pipeline suite.
//
// installer_playwright_test.go ——PlaywrightInstaller pure-function 单测。
// 真 `playwright install chromium` shellout（下 ~300 MB）归 D9 pipeline 套。

package sandbox

import (
	"context"
	"path/filepath"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

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
