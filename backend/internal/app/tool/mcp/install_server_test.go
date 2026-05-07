// install_server_test.go — covers the install_mcp_server LLM-driven flow:
// phase-1 needs_confirmation envelope shape, alias derivation, error
// envelopes (already_installed / not_in_registry / etc.). Real install
// path (Service.InstallFromRegistry → AddServer → Connect) is exercised
// by app/mcp tests + integration; here we focus on the tool boundary.
//
// install_server_test.go ——覆盖 install_mcp_server 的 LLM 驱动流程：
// 阶段 1 needs_confirmation 信封形态、alias 派生、错误信封
// （already_installed / not_in_registry 等）。真装路径
// （Service.InstallFromRegistry → AddServer → Connect）由 app/mcp 测试 +
// 集成跑；此处聚焦工具边界。
package mcp

import (
	"context"
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"

	"go.uber.org/zap/zaptest"

	mcpapp "github.com/sunweilin/forgify/backend/internal/app/mcp"
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
	mcpinfra "github.com/sunweilin/forgify/backend/internal/infra/mcp"
)

func newInstallTestService(t *testing.T, entries []mcpdomain.RegistryEntry) *mcpapp.Service {
	t.Helper()
	source := mcpinfra.NewFakeRegistrySource(entries)
	return mcpapp.New(
		filepath.Join(t.TempDir(), "mcp.json"),
		source, nil, &nopBridge{}, nil, nil, nil, zaptest.NewLogger(t),
	)
}

// nopBridge implements eventsdomain.Bridge with no-op publish; this test
// doesn't assert on events.
//
// nopBridge 实现 eventsdomain.Bridge 的 no-op publish；本测试不断言事件。
type nopBridge struct{}

func (n *nopBridge) Publish(_ context.Context, _ string, _ eventsdomain.Event) {}
func (n *nopBridge) Subscribe(_ context.Context, _ string) (<-chan eventsdomain.Event, func()) {
	return nil, func() {}
}

func TestInstall_Phase1_NeedsConfirmation(t *testing.T) {
	svc := newInstallTestService(t, []mcpdomain.RegistryEntry{
		{
			Name:        "io.github.x/sample-server",
			DisplayName: "sample-server",
			Description: "A sample server",
			Runtime:     "node",
			InstallCmd:  mcpdomain.InstallCmd{Command: "npx", Args: []string{"-y", "sample"}},
		},
	})
	tool := &InstallMCPServer{svc: svc}

	out, err := tool.Execute(context.Background(),
		`{"name": "io.github.x/sample-server"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}

	var env map[string]any
	if err := json.Unmarshal([]byte(out), &env); err != nil {
		t.Fatalf("decode: %v (raw=%q)", err, out)
	}
	if env["status"] != "needs_confirmation" {
		t.Errorf("status = %v, want needs_confirmation", env["status"])
	}
	if env["proposed_alias"] != "sample-server" {
		t.Errorf("proposed_alias = %v, want sample-server (last segment of namespace)", env["proposed_alias"])
	}
	q, _ := env["suggested_question"].(string)
	if !strings.Contains(q, "sample-server") || !strings.Contains(q, "Proceed?") {
		t.Errorf("suggested_question missing key parts: %q", q)
	}
}

func TestInstall_Phase1_AliasFromShortName(t *testing.T) {
	svc := newInstallTestService(t, []mcpdomain.RegistryEntry{
		{Name: "legacy-name", DisplayName: "legacy", Runtime: "node",
			InstallCmd: mcpdomain.InstallCmd{Command: "npx", Args: []string{"x"}}},
	})
	tool := &InstallMCPServer{svc: svc}

	out, _ := tool.Execute(context.Background(), `{"name": "legacy-name"}`)
	var env map[string]any
	_ = json.Unmarshal([]byte(out), &env)
	if env["proposed_alias"] != "legacy-name" {
		t.Errorf("proposed_alias = %v, want legacy-name (no slash, use as-is)", env["proposed_alias"])
	}
}

func TestInstall_NotInRegistry(t *testing.T) {
	svc := newInstallTestService(t, nil)
	tool := &InstallMCPServer{svc: svc}

	out, _ := tool.Execute(context.Background(), `{"name": "io.github.x/missing"}`)
	var env map[string]any
	_ = json.Unmarshal([]byte(out), &env)
	if env["status"] != "error" || env["error"] != "not_in_registry" {
		t.Errorf("env = %v, want status=error error=not_in_registry", env)
	}
}

func TestInstall_DescriptionMentionsTwoPhases(t *testing.T) {
	tool := &InstallMCPServer{}
	desc := tool.Description()
	if !strings.Contains(desc, "PHASE 1") || !strings.Contains(desc, "PHASE 2") {
		t.Error("Description should mention both phases so LLM understands the flow")
	}
	if !strings.Contains(desc, "ask") {
		t.Error("Description should mention the ask tool for user consent")
	}
}

func TestUninstall_NotInstalled(t *testing.T) {
	svc := newInstallTestService(t, nil)
	tool := &UninstallMCPServer{svc: svc}

	out, _ := tool.Execute(context.Background(), `{"alias": "nonexistent"}`)
	var env map[string]any
	_ = json.Unmarshal([]byte(out), &env)
	if env["status"] != "error" || env["error"] != "not_installed" {
		t.Errorf("env = %v, want status=error error=not_installed", env)
	}
}

func TestSearchMarketplace_Description_MentionsInstallPath(t *testing.T) {
	tool := &SearchMarketplaceMCP{}
	desc := tool.Description()
	if !strings.Contains(desc, "install_mcp_server") {
		t.Error("Description should point LLM at the install_mcp_server next step")
	}
	if !strings.Contains(desc, "needs_confirmation") {
		t.Error("Description should hint at the two-phase install flow")
	}
}
