//go:build pipeline

package harness

import (
	"os"
	"testing"
)

// RequireDeepSeekKey returns DEEPSEEK_API_KEY from env or skips the test.
// Use for tests that genuinely need real LLM round-trips (live tier).
//
// RequireDeepSeekKey 返回 env 中的 DEEPSEEK_API_KEY,缺则 skip。
// 用于真需要真 LLM 往返的测试(live 层)。
func RequireDeepSeekKey(t *testing.T) string {
	t.Helper()
	key := os.Getenv("DEEPSEEK_API_KEY")
	if key == "" {
		t.Skip("DEEPSEEK_API_KEY not set; skipping live LLM test (run `make live` or set env)")
	}
	return key
}

// RequireSandboxResources skips the test when v2 sandbox isn't bootstrapped
// (e.g., mise binaries unavailable). Used by lifecycle tier tests.
//
// RequireSandboxResources 在 v2 sandbox 未启动时 skip(如 mise binary 不可用)。
// 给 lifecycle 层测试用。
func RequireSandboxResources(t *testing.T, h *Harness) {
	t.Helper()
	if !h.Sandbox.IsReady() {
		err := h.Sandbox.BootstrapError()
		t.Skipf("sandbox v2 not ready (run `make mise` to fetch mise binaries): %v", err)
	}
}

// RequireForgifyDevResources skips when FORGIFY_DEV_RESOURCES env points
// nowhere. Used by tests that need user-side sandbox toolchains beyond mise.
//
// RequireForgifyDevResources 在 FORGIFY_DEV_RESOURCES 未设时 skip。
// 给需要 mise 之外用户侧 sandbox 工具链的测试用。
func RequireForgifyDevResources(t *testing.T) string {
	t.Helper()
	dir := os.Getenv("FORGIFY_DEV_RESOURCES")
	if dir == "" {
		t.Skip("FORGIFY_DEV_RESOURCES not set; skipping sandbox-heavy test")
	}
	return dir
}
