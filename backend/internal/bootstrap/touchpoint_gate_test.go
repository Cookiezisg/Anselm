package bootstrap

import (
	"testing"

	touchpointapp "github.com/sunweilin/anselm/backend/internal/app/touchpoint"
)

// TestTouchpointCatalog_CoversEveryTool is the ledger's drift fence: every tool in the REAL
// assembled toolset (resident + lazy + Subagent/trace) must have a reviewed stance in the
// touch catalog — either an extraction rule or an explicit no-touch entry. A new tool that
// ships without declaring whether it touches the conversation ledger fails here, not in
// production silence.
//
// TestTouchpointCatalog_CoversEveryTool 是台账的漂移围栏:**真**装配工具集(resident + lazy +
// Subagent/trace)里的每个工具都必须在触碰目录里有审视过的表态——提取规则或显式 no-touch。
// 新工具不表态就在这里红,而不是在生产环境静默漏账。
func TestTouchpointCatalog_CoversEveryTool(t *testing.T) {
	app, err := Build(Config{})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	if len(app.svc.toolNames) == 0 {
		t.Fatal("toolset name inventory is empty — wiring broke")
	}
	for _, name := range app.svc.toolNames {
		if !touchpointapp.Covers(name) {
			t.Errorf("tool %q has no touch-catalog stance (add an extraction rule or an explicit no-touch entry in app/touchpoint/catalog.go)", name)
		}
	}
}
