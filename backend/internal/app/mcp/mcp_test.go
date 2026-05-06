// mcp_test.go — Service tests using a fake Client (subprocess-free).
// Real subprocess integration with a fake stdio MCP server lives in
// the D6-5 pipeline suite. This file covers lifecycle (Start/Add/
// Remove/Reconnect/Stop), CallTool routing + degraded transition +
// auto-heal, HealthCheck, Import merge, Install validation rejections.
//
// mcp_test.go ——用 fake Client（无子进程）测 Service。真子进程集成在 D6-5
// pipeline 套。本文件覆盖 lifecycle / CallTool 路由 + degraded + 自愈 /
// HealthCheck / Import merge / Install 校验拒绝。
package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"

	"go.uber.org/zap"
	"go.uber.org/zap/zaptest"

	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
	mcpinfra "github.com/sunweilin/forgify/backend/internal/infra/mcp"
)

// ── fakes ────────────────────────────────────────────────────────────

// fakeClient is the test Client.
type fakeClient struct {
	name string

	mu             sync.Mutex
	initErr        error
	listToolsCalls atomic.Int32
	listToolsResp  []mcpdomain.ToolDef
	listToolsErr   error
	callToolErr    error
	callToolResp   string
	callToolFn     func(ctx context.Context, name string, args json.RawMessage) (string, error)
	closed         bool
}

func (f *fakeClient) Initialize(_ context.Context) error { return f.initErr }
func (f *fakeClient) ListTools(_ context.Context) ([]mcpdomain.ToolDef, error) {
	f.listToolsCalls.Add(1)
	return append([]mcpdomain.ToolDef(nil), f.listToolsResp...), f.listToolsErr
}
func (f *fakeClient) CallTool(ctx context.Context, name string, args json.RawMessage) (string, error) {
	if f.callToolFn != nil {
		return f.callToolFn(ctx, name, args)
	}
	return f.callToolResp, f.callToolErr
}
func (f *fakeClient) Close() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.closed = true
	return nil
}
func (f *fakeClient) StderrTail() string { return "" }

// fakeBridge captures every Publish so tests can assert event counts.
type fakeBridge struct {
	mu     sync.Mutex
	events []eventsdomain.Event
}

func (b *fakeBridge) Publish(_ context.Context, _ string, ev eventsdomain.Event) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.events = append(b.events, ev)
}

// Subscribe returns a closed channel + no-op cancel. None of the tests
// in this file consume events; they only assert via Count.
//
// Subscribe 返已关 channel + no-op cancel。本文件测试不消费事件，仅 Count 断言。
func (b *fakeBridge) Subscribe(_ context.Context, _ string) (<-chan eventsdomain.Event, func()) {
	ch := make(chan eventsdomain.Event)
	close(ch)
	return ch, func() {}
}
func (b *fakeBridge) Count() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.events)
}

// testHarness owns the Service + a name→fakeClient registry that
// SetClientFactory pulls from. Tests register per-name fakeClients
// before calling Start/AddServer.
//
// testHarness 持 Service + name→fakeClient 注册表，SetClientFactory 从这
// 里取。测试在调 Start/AddServer 前按 name 注册 fakeClient。
type testHarness struct {
	svc     *Service
	bridge  *fakeBridge
	clients map[string]*fakeClient
	mu      sync.Mutex
}

func newTestHarness(t *testing.T) *testHarness {
	t.Helper()
	bridge := &fakeBridge{}
	h := &testHarness{
		bridge:  bridge,
		clients: map[string]*fakeClient{},
	}
	h.svc = New(
		filepath.Join(t.TempDir(), "mcp.json"),
		NewRegistry(),
		nil, // sandbox — InstallFromRegistry tests inject as needed
		bridge,
		nil, nil, nil, // model picker / keys / factory — Search uses LLM, not exercised here
		zaptest.NewLogger(t),
	)
	h.svc.SetClientFactory(func(cfg mcpdomain.ServerConfig, _ *zap.Logger) mcpinfra.Client {
		h.mu.Lock()
		defer h.mu.Unlock()
		fc, ok := h.clients[cfg.Name]
		if !ok {
			// Default fakeClient with no tools so Initialize → ready works.
			// 默认 fakeClient 无 tools 让 Initialize → ready。
			fc = &fakeClient{name: cfg.Name}
			h.clients[cfg.Name] = fc
		}
		return fc
	})
	return h
}

func (h *testHarness) registerClient(name string, fc *fakeClient) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[name] = fc
}

// ── Lifecycle ────────────────────────────────────────────────────────

func TestStart_NoConfigFile_StartsEmpty(t *testing.T) {
	h := newTestHarness(t)
	if err := h.svc.Start(context.Background()); err != nil {
		t.Fatalf("Start: %v", err)
	}
	if got := h.svc.ListServers(context.Background()); len(got) != 0 {
		t.Errorf("ListServers = %d, want 0", len(got))
	}
}

func TestStart_LoadsConfigAndConnects(t *testing.T) {
	h := newTestHarness(t)
	// Pre-seed mcp.json with one server; pre-register a fakeClient that
	// returns one tool from ListTools.
	// 预灌 mcp.json 一个 server；预注册返回一 tool 的 fakeClient。
	configPath := h.svc.configPath
	cfg := mcpdomain.ServerConfig{Name: "github", Command: "true"}
	if err := mcpinfra.Save(configPath, map[string]mcpdomain.ServerConfig{"github": cfg}); err != nil {
		t.Fatalf("seed mcp.json: %v", err)
	}
	h.registerClient("github", &fakeClient{
		listToolsResp: []mcpdomain.ToolDef{
			{ServerName: "github", Name: "list_prs", Description: "List PRs", InputSchema: json.RawMessage(`{}`)},
		},
	})

	if err := h.svc.Start(context.Background()); err != nil {
		t.Fatalf("Start: %v", err)
	}
	servers := h.svc.ListServers(context.Background())
	if len(servers) != 1 {
		t.Fatalf("ListServers = %d, want 1", len(servers))
	}
	gh := servers[0]
	if gh.Status != mcpdomain.StatusReady {
		t.Errorf("github status = %q, want ready", gh.Status)
	}
	if len(gh.Tools) != 1 || gh.Tools[0].Name != "list_prs" {
		t.Errorf("github.Tools = %+v", gh.Tools)
	}
}

func TestStart_ConnectFailureKeepsConfigReturnsFailedStatus(t *testing.T) {
	h := newTestHarness(t)
	configPath := h.svc.configPath
	cfg := mcpdomain.ServerConfig{Name: "broken", Command: "true"}
	_ = mcpinfra.Save(configPath, map[string]mcpdomain.ServerConfig{"broken": cfg})
	h.registerClient("broken", &fakeClient{initErr: errors.New("handshake failed")})

	_ = h.svc.Start(context.Background())
	servers := h.svc.ListServers(context.Background())
	if len(servers) != 1 || servers[0].Status != mcpdomain.StatusFailed {
		t.Fatalf("expected one failed server; got %+v", servers)
	}
	if servers[0].LastError == "" {
		t.Error("LastError should be populated on connect failure")
	}
}

func TestAddServer_ConnectsAndPersists(t *testing.T) {
	h := newTestHarness(t)
	h.registerClient("local", &fakeClient{
		listToolsResp: []mcpdomain.ToolDef{{ServerName: "local", Name: "ping"}},
	})

	if err := h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{
		Name: "local", Command: "echo",
	}); err != nil {
		t.Fatalf("AddServer: %v", err)
	}
	servers := h.svc.ListServers(context.Background())
	if len(servers) != 1 || servers[0].Status != mcpdomain.StatusReady {
		t.Fatalf("expected one ready server, got %+v", servers)
	}
	// mcp.json must have been written.
	// mcp.json 必须已写。
	loaded, err := mcpinfra.Load(h.svc.configPath)
	if err != nil {
		t.Fatalf("re-load mcp.json: %v", err)
	}
	if _, ok := loaded["local"]; !ok {
		t.Errorf("mcp.json missing 'local'; got %+v", loaded)
	}
}

func TestRemoveServer_DisconnectsAndPersists(t *testing.T) {
	h := newTestHarness(t)
	h.registerClient("alpha", &fakeClient{})
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "alpha", Command: "x"})

	if err := h.svc.RemoveServer(context.Background(), "alpha"); err != nil {
		t.Fatalf("RemoveServer: %v", err)
	}
	if got := h.svc.ListServers(context.Background()); len(got) != 0 {
		t.Errorf("ListServers should be empty post-remove, got %+v", got)
	}
	loaded, _ := mcpinfra.Load(h.svc.configPath)
	if _, present := loaded["alpha"]; present {
		t.Errorf("mcp.json still has 'alpha' after Remove")
	}
}

func TestRemoveServer_Unknown_ErrServerNotFound(t *testing.T) {
	h := newTestHarness(t)
	err := h.svc.RemoveServer(context.Background(), "ghost")
	if !errors.Is(err, mcpdomain.ErrServerNotFound) {
		t.Errorf("err = %v, want ErrServerNotFound", err)
	}
}

func TestReconnect_HappyPath(t *testing.T) {
	h := newTestHarness(t)
	h.registerClient("p", &fakeClient{listToolsResp: []mcpdomain.ToolDef{{Name: "x"}}})
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "p", Command: "echo"})

	if err := h.svc.Reconnect(context.Background(), "p"); err != nil {
		t.Fatalf("Reconnect: %v", err)
	}
	st, _ := h.svc.GetServer(context.Background(), "p")
	if st.Status != mcpdomain.StatusReady {
		t.Errorf("status post-reconnect = %q, want ready", st.Status)
	}
}

func TestStop_ClosesEveryClient(t *testing.T) {
	h := newTestHarness(t)
	c1 := &fakeClient{}
	c2 := &fakeClient{}
	h.registerClient("a", c1)
	h.registerClient("b", c2)
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "a", Command: "x"})
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "b", Command: "x"})

	_ = h.svc.Stop(context.Background())
	c1.mu.Lock()
	c2.mu.Lock()
	defer c1.mu.Unlock()
	defer c2.mu.Unlock()
	if !c1.closed || !c2.closed {
		t.Errorf("Stop did not Close every client: c1.closed=%v c2.closed=%v", c1.closed, c2.closed)
	}
}

// ── CallTool ─────────────────────────────────────────────────────────

func TestCallTool_Happy(t *testing.T) {
	h := newTestHarness(t)
	h.registerClient("s", &fakeClient{
		listToolsResp: []mcpdomain.ToolDef{{Name: "echo"}},
		callToolResp:  "hello",
	})
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "s", Command: "x"})

	got, err := h.svc.CallTool(context.Background(), "s", "echo", json.RawMessage(`{}`))
	if err != nil {
		t.Fatalf("CallTool: %v", err)
	}
	if got != "hello" {
		t.Errorf("CallTool result = %q, want 'hello'", got)
	}
	// Counters: TotalCalls=1, ConsecutiveFailures=0, LastSuccessAt set.
	st, _ := h.svc.GetServer(context.Background(), "s")
	if st.TotalCalls != 1 || st.ConsecutiveFailures != 0 || st.LastSuccessAt == nil {
		t.Errorf("counters wrong: %+v", st)
	}
}

func TestCallTool_UnknownServer(t *testing.T) {
	h := newTestHarness(t)
	_, err := h.svc.CallTool(context.Background(), "ghost", "x", json.RawMessage(`{}`))
	if !errors.Is(err, mcpdomain.ErrServerNotFound) {
		t.Errorf("err = %v, want ErrServerNotFound", err)
	}
}

func TestCallTool_UnknownTool(t *testing.T) {
	h := newTestHarness(t)
	h.registerClient("s", &fakeClient{
		listToolsResp: []mcpdomain.ToolDef{{Name: "echo"}},
	})
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "s", Command: "x"})

	_, err := h.svc.CallTool(context.Background(), "s", "nonexistent", json.RawMessage(`{}`))
	if !errors.Is(err, mcpdomain.ErrToolNotFound) {
		t.Errorf("err = %v, want ErrToolNotFound", err)
	}
}

func TestCallTool_ConsecutiveFailures_TriggersDegraded(t *testing.T) {
	h := newTestHarness(t)
	h.registerClient("s", &fakeClient{
		listToolsResp: []mcpdomain.ToolDef{{Name: "flaky"}},
		callToolErr:   errors.New("upstream down"),
	})
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "s", Command: "x"})

	for i := 0; i < degradedThreshold; i++ {
		_, err := h.svc.CallTool(context.Background(), "s", "flaky", json.RawMessage(`{}`))
		if err == nil {
			t.Fatalf("call %d: expected error", i)
		}
	}
	st, _ := h.svc.GetServer(context.Background(), "s")
	if st.Status != mcpdomain.StatusDegraded {
		t.Errorf("status = %q, want degraded after %d failures", st.Status, degradedThreshold)
	}
	if st.ConsecutiveFailures != degradedThreshold {
		t.Errorf("ConsecutiveFailures = %d, want %d", st.ConsecutiveFailures, degradedThreshold)
	}
}

func TestCallTool_DegradedAutoHealsOnSuccess(t *testing.T) {
	h := newTestHarness(t)
	flaky := &fakeClient{
		listToolsResp: []mcpdomain.ToolDef{{Name: "x"}},
		callToolErr:   errors.New("boom"),
	}
	h.registerClient("s", flaky)
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "s", Command: "x"})

	// Drive into degraded.
	// 推到 degraded。
	for i := 0; i < degradedThreshold; i++ {
		_, _ = h.svc.CallTool(context.Background(), "s", "x", json.RawMessage(`{}`))
	}
	if st, _ := h.svc.GetServer(context.Background(), "s"); st.Status != mcpdomain.StatusDegraded {
		t.Fatalf("not degraded; status=%q", st.Status)
	}

	// Flip to success.
	// 翻成功。
	flaky.mu.Lock()
	flaky.callToolErr = nil
	flaky.callToolResp = "ok"
	flaky.mu.Unlock()

	if _, err := h.svc.CallTool(context.Background(), "s", "x", json.RawMessage(`{}`)); err != nil {
		t.Fatalf("recovery call: %v", err)
	}
	st, _ := h.svc.GetServer(context.Background(), "s")
	if st.Status != mcpdomain.StatusReady {
		t.Errorf("status post-recover = %q, want ready (auto-heal)", st.Status)
	}
}

// ── HealthCheck ──────────────────────────────────────────────────────

func TestHealthCheck_HealthyDoesNotMutateStatus(t *testing.T) {
	h := newTestHarness(t)
	flaky := &fakeClient{
		listToolsResp: []mcpdomain.ToolDef{{Name: "a"}},
		callToolErr:   errors.New("x"),
	}
	h.registerClient("s", flaky)
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "s", Command: "x"})
	// Drive into degraded.
	for i := 0; i < degradedThreshold; i++ {
		_, _ = h.svc.CallTool(context.Background(), "s", "a", json.RawMessage(`{}`))
	}

	res, err := h.svc.HealthCheck(context.Background(), "s")
	if err != nil {
		t.Fatalf("HealthCheck: %v", err)
	}
	if !res.Healthy {
		t.Errorf("HealthCheck should report healthy when ListTools succeeds; %+v", res)
	}
	// Status must still be degraded — HealthCheck must NOT auto-heal.
	// status 必须仍 degraded——HealthCheck 不能自愈。
	st, _ := h.svc.GetServer(context.Background(), "s")
	if st.Status != mcpdomain.StatusDegraded {
		t.Errorf("HealthCheck mutated status: now %q, expected to stay degraded", st.Status)
	}
}

func TestHealthCheck_UnknownServer(t *testing.T) {
	h := newTestHarness(t)
	_, err := h.svc.HealthCheck(context.Background(), "ghost")
	if !errors.Is(err, mcpdomain.ErrServerNotFound) {
		t.Errorf("err = %v, want ErrServerNotFound", err)
	}
}

// ── Import ───────────────────────────────────────────────────────────

func TestImport_NewEntries_AddsAllAndPersists(t *testing.T) {
	h := newTestHarness(t)
	res, err := h.svc.Import(context.Background(), map[string]mcpdomain.ServerConfig{
		"a": {Command: "x"},
		"b": {Command: "y"},
	}, false)
	if err != nil {
		t.Fatalf("Import: %v", err)
	}
	if len(res.Imported) != 2 || len(res.Conflicts) != 0 {
		t.Errorf("res = %+v", res)
	}
	loaded, _ := mcpinfra.Load(h.svc.configPath)
	if len(loaded) != 2 {
		t.Errorf("mcp.json post-import has %d entries, want 2", len(loaded))
	}
}

func TestImport_ConflictWithoutOverwrite_PreservesExisting(t *testing.T) {
	h := newTestHarness(t)
	// Seed an existing.
	// 灌一个已有。
	_ = h.svc.AddServer(context.Background(), mcpdomain.ServerConfig{Name: "github", Command: "old"})

	res, err := h.svc.Import(context.Background(), map[string]mcpdomain.ServerConfig{
		"github": {Command: "new"},
		"slack":  {Command: "s"},
	}, false)
	if err != nil {
		t.Fatalf("Import: %v", err)
	}
	if !contains(res.Conflicts, "github") {
		t.Errorf("Conflicts should include github; got %v", res.Conflicts)
	}
	if !contains(res.Imported, "slack") {
		t.Errorf("Imported should include slack; got %v", res.Imported)
	}
	loaded, _ := mcpinfra.Load(h.svc.configPath)
	if loaded["github"].Command != "old" {
		t.Errorf("github overwritten despite overwrite=false: cmd=%q", loaded["github"].Command)
	}
}

// ── Install (validation rejections) ──────────────────────────────────

func TestInstall_UnknownEntry(t *testing.T) {
	h := newTestHarness(t)
	_, err := h.svc.InstallFromRegistry(context.Background(), "no-such", nil, nil)
	if !errors.Is(err, mcpdomain.ErrRegistryEntryNotFound) {
		t.Errorf("err = %v, want ErrRegistryEntryNotFound", err)
	}
}

func TestInstall_MissingRequiredArg_SQLite(t *testing.T) {
	// SQLite registry entry requires `dbPath` arg. Calling install
	// without it must fail with ErrRequiredArgsMissing — not silently
	// proceed and let the subprocess fail at runtime with a confusing
	// error.
	//
	// SQLite registry 条目要 `dbPath` arg。无它装必须 ErrRequiredArgsMissing
	// ——不能静默继续让子进程在 runtime 抛迷惑错。
	h := newTestHarness(t)
	_, err := h.svc.InstallFromRegistry(context.Background(), "sqlite", nil, map[string]string{})
	if !errors.Is(err, mcpdomain.ErrRequiredArgsMissing) {
		t.Errorf("err = %v, want ErrRequiredArgsMissing", err)
	}
}

// ── helpers ──────────────────────────────────────────────────────────

func contains(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

// ── Pure helpers (substituteArgs, expandVars) ────────────────────────

func TestExpandVars_HappyPath(t *testing.T) {
	got := expandVars("--db ${path} --mode ${mode}", map[string]string{
		"path": "/tmp/x.db",
		"mode": "ro",
	})
	if got != "--db /tmp/x.db --mode ro" {
		t.Errorf("expand = %q", got)
	}
}

func TestExpandVars_UnknownTokenLeftAsIs(t *testing.T) {
	got := expandVars("${unknown}", map[string]string{})
	if got != "${unknown}" {
		t.Errorf("unknown token mutated: %q", got)
	}
}

func TestExpandVars_NoTokens_Identity(t *testing.T) {
	got := expandVars("plain text", map[string]string{"x": "y"})
	if got != "plain text" {
		t.Errorf("no-token path mutated: %q", got)
	}
}

func TestSubstituteArgs_Slice(t *testing.T) {
	got := substituteArgs([]string{"-y", "@scope/pkg", "--root=${dir}"},
		map[string]string{"dir": "/work"})
	want := []string{"-y", "@scope/pkg", "--root=/work"}
	if len(got) != len(want) {
		t.Fatalf("len = %d, want %d", len(got), len(want))
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("got[%d] = %q, want %q", i, got[i], want[i])
		}
	}
}
