package router

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"go.uber.org/zap"
)

// TestChainExemptVsGuarded verifies the workspace gate: with a nil resolver no workspace is
// ever stamped, so guarded routes 401 while exempt (onboarding/liveness/static) routes pass.
//
// TestChainExemptVsGuarded 验证 workspace 门：resolver 为 nil 时永不写入 workspace，故受守
// 路由 401，而豁免（onboarding/健康检查/静态）路由放过。
func TestChainExemptVsGuarded(t *testing.T) {
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	h := Chain(inner, zap.NewNop(), nil)

	cases := []struct {
		path string
		want int
	}{
		{"/api/v1/health", http.StatusOK},                  // liveness — exempt
		{"/api/v1/workspaces", http.StatusOK},              // onboarding — exempt
		{"/api/v1/providers", http.StatusOK},               // static metadata — exempt
		{"/api/v1/scenarios", http.StatusOK},               // static metadata — exempt
		{"/api/v1/conversations", http.StatusUnauthorized}, // guarded, no workspace → 401
		{"/api/v1/webhooks/trg_x/push", http.StatusOK},     // external webhook — exempt (own secret/HMAC auth)
		{"/healthz", http.StatusOK},                        // non-/api/v1 passes through to inner
	}
	for _, c := range cases {
		w := httptest.NewRecorder()
		h.ServeHTTP(w, httptest.NewRequest("GET", c.path, nil))
		if w.Code != c.want {
			t.Errorf("%s → %d, want %d", c.path, w.Code, c.want)
		}
	}
}
