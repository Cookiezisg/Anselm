package scenarios

import (
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestWorkflow_InvalidCELListsAvailableNodes — regression for F8 (iteration loop): when a node's
// Input CEL references something that is not a node (e.g. "payload.celsius"), the validation error
// must tell the author which node ids it CAN read (its ancestors), not just "invalid CEL". Without
// it, the agent guessed node-id roots blindly (payload/trigger/celsius/input) ~5 times. Zero-token.
func TestWorkflow_InvalidCELListsAvailableNodes(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "wf-celhint"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	// "step" reads "payload.celsius" — payload is not a node, so the first-tier CEL compile fails.
	r := wc.POST("/api/v1/workflows", map[string]any{"name": "bad_cel", "ops": []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "step", "kind": "action", "ref": "fn_x", "input": map[string]any{"x": "payload.celsius"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "step"}},
	}})
	if r.Status < 400 {
		t.Fatalf("invalid CEL must reject, got %d: %s", r.Status, r.Raw)
	}
	body := string(r.Raw)
	if !strings.Contains(body, "may read") || !strings.Contains(body, "start") {
		t.Fatalf("invalid-CEL error must list the available upstream node(s) so the author knows what to reference (F8); got: %s", body)
	}
}
