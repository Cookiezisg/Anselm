package scenarios

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestLiveBYOK_KimiCredentialProbe keeps the current Moonshot/Kimi credential boundary honest.
// A credential that the provider rejects must surface as the typed key-probe failure at the product
// endpoint; it must not be mistaken for a missing model or a generic transport problem. If the
// same key is later restored, the probe is allowed to take the success branch without baking a
// transient provider outage into the test.
func TestLiveBYOK_KimiCredentialProbe(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("KIMI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires KIMI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-kimi-probe"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "moonshot", "displayName": "live-kimi-auth-probe", "key": key,
	}).Field(t, "id")

	probe := wc.Do("POST", "/api/v1/api-keys/"+keyID+":test", nil)
	if probe.Status == 200 {
		t.Log("Kimi credential probe accepted; provider auth is currently available")
		return
	}
	if probe.Status != 422 || probe.Code != "API_KEY_TEST_FAILED" {
		t.Fatalf("Kimi credential rejection must use the key-probe error envelope: status=%d code=%s", probe.Status, probe.Code)
	}
	var env struct {
		Error struct {
			Details struct {
				Reason string `json:"reason"`
			} `json:"details"`
		} `json:"error"`
	}
	if err := json.Unmarshal(probe.Raw, &env); err != nil || !strings.HasPrefix(env.Error.Details.Reason, "HTTP 401") {
		t.Fatalf("Kimi key-probe envelope must preserve the 401 reason without exposing provider secrets: %s", probe.Raw)
	}
	t.Log("Kimi credential is currently rejected by Moonshot; product probe preserved an HTTP 401 reason inside API_KEY_TEST_FAILED")
}
