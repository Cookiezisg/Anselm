package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"reflect"
	"strings"
	"testing"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	mcpinfra "github.com/sunweilin/anselm/backend/internal/infra/mcp"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

// --- fakes -----------------------------------------------------------------

type fakeRepo struct {
	byID  map[string]*mcpdomain.Server
	calls []*mcpdomain.Call
}

func newFakeRepo() *fakeRepo { return &fakeRepo{byID: map[string]*mcpdomain.Server{}} }

func (r *fakeRepo) Save(_ context.Context, s *mcpdomain.Server) error {
	cp := *s
	r.byID[s.ID] = &cp
	return nil
}
func (r *fakeRepo) GetByID(_ context.Context, id string) (*mcpdomain.Server, error) {
	if s, ok := r.byID[id]; ok {
		cp := *s
		return &cp, nil
	}
	return nil, mcpdomain.ErrServerNotFound
}
func (r *fakeRepo) GetByName(_ context.Context, name string) (*mcpdomain.Server, error) {
	for _, s := range r.byID {
		if s.Name == name {
			cp := *s
			return &cp, nil
		}
	}
	return nil, mcpdomain.ErrServerNotFound
}
func (r *fakeRepo) List(_ context.Context) ([]*mcpdomain.Server, error) {
	out := make([]*mcpdomain.Server, 0, len(r.byID))
	for _, s := range r.byID {
		cp := *s
		out = append(out, &cp)
	}
	return out, nil
}
func (r *fakeRepo) Delete(_ context.Context, id string) error {
	if _, ok := r.byID[id]; !ok {
		return mcpdomain.ErrServerNotFound
	}
	delete(r.byID, id)
	return nil
}
func (r *fakeRepo) ComputeCallAggregates(_ context.Context, _ mcpdomain.CallFilter) (mcpdomain.CallAggregates, error) {
	return mcpdomain.CallAggregates{}, nil
}

func (r *fakeRepo) SaveCall(_ context.Context, c *mcpdomain.Call) error {
	r.calls = append(r.calls, c)
	return nil
}
func (r *fakeRepo) GetCall(_ context.Context, id string) (*mcpdomain.Call, error) {
	for _, c := range r.calls {
		if c.ID == id {
			return c, nil
		}
	}
	return nil, mcpdomain.ErrCallNotFound
}
func (r *fakeRepo) ListCalls(_ context.Context, _ mcpdomain.CallFilter) ([]*mcpdomain.Call, string, error) {
	return r.calls, "", nil
}

type fakeSandbox struct{ ensureErr error }

func (f *fakeSandbox) EnsureEnv(context.Context, sandboxdomain.Owner, sandboxdomain.EnvSpec, sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error) {
	return &sandboxdomain.Env{}, f.ensureErr
}
func (f *fakeSandbox) SpawnLongLived(context.Context, sandboxdomain.Owner, sandboxdomain.SpawnOpts) (sandboxdomain.LongLivedHandle, error) {
	return &fakeHandle{}, nil
}

type fakeHandle struct{}

func (fakeHandle) Stdin() io.WriteCloser { return nopWC{} }
func (fakeHandle) Stdout() io.ReadCloser { return io.NopCloser(strings.NewReader("")) }
func (fakeHandle) Stderr() io.ReadCloser { return io.NopCloser(strings.NewReader("")) }
func (fakeHandle) Wait() error           { return nil }
func (fakeHandle) Kill() error           { return nil }
func (fakeHandle) PID() int              { return 1234 }

type nopWC struct{}

func (nopWC) Write(p []byte) (int, error) { return len(p), nil }
func (nopWC) Close() error                { return nil }

type fakeClient struct {
	tools      []mcpdomain.ToolDef
	callResult string
	callErr    error
	initErr    error
	closed     bool
	callMedia  []mcpdomain.Media
}

func (c *fakeClient) Initialize(context.Context) error { return c.initErr }
func (c *fakeClient) ListTools(context.Context) ([]mcpdomain.ToolDef, error) {
	return c.tools, nil
}
func (c *fakeClient) CallTool(context.Context, string, json.RawMessage) (string, []mcpdomain.Media, error) {
	return c.callResult, c.callMedia, c.callErr
}
func (c *fakeClient) Close() error       { c.closed = true; return nil }
func (c *fakeClient) StderrTail() string { return "" }

type statusBridge struct{ events []streamdomain.Event }

func (b *statusBridge) Publish(_ context.Context, e streamdomain.Event) (streamdomain.Envelope, error) {
	b.events = append(b.events, e)
	return streamdomain.Envelope{Event: e}, nil
}

func (b *statusBridge) Subscribe(context.Context, int64) (<-chan streamdomain.Envelope, func(), error) {
	return nil, func() {}, nil
}

type fakeRegistry struct{ entries []mcpdomain.RegistryEntry }

func (r *fakeRegistry) List(context.Context) ([]mcpdomain.RegistryEntry, error) {
	return r.entries, nil
}
func (r *fakeRegistry) Get(_ context.Context, name string) (*mcpdomain.RegistryEntry, error) {
	for i := range r.entries {
		if r.entries[i].Name == name {
			cp := r.entries[i]
			return &cp, nil
		}
	}
	return nil, mcpdomain.ErrRegistryEntryNotFound
}

// svcWith builds a Service with a fixed fake client (so CallTool reaches the same instance).
func svcWith(repo *fakeRepo, reg *fakeRegistry, fc *fakeClient) *Service {
	svc := NewService(repo, reg, &fakeSandbox{}, zap.NewNop())
	svc.SetClientFactory(func(mcpinfra.ClientSpec, *zap.Logger) mcpinfra.Client { return fc })
	return svc
}

func ctx7Registry() *fakeRegistry {
	return &fakeRegistry{entries: []mcpdomain.RegistryEntry{{
		Name:        "io.github.upstash/context7",
		Description: "Fetch latest library docs",
		Packages:    []mcpdomain.Package{{Name: "@upstash/context7-mcp", RuntimeHint: "npx"}},
	}}}
}

// --- tests -----------------------------------------------------------------

func TestInstall_ConnectsAndReportsTools(t *testing.T) {
	fc := &fakeClient{tools: []mcpdomain.ToolDef{{Name: "get-library-docs", Description: "..."}}}
	svc := svcWith(newFakeRepo(), ctx7Registry(), fc)
	st, err := svc.InstallFromRegistry(ctxWS("ws_1"), "io.github.upstash/context7", nil)
	if err != nil {
		t.Fatalf("install: %v", err)
	}
	if st.Name != "context7" {
		t.Fatalf("want short name context7, got %q", st.Name)
	}
	if st.Status != mcpdomain.StatusReady {
		t.Fatalf("want ready, got %q", st.Status)
	}
	if len(st.Tools) != 1 || st.Tools[0].Name != "get-library-docs" {
		t.Fatalf("want 1 tool get-library-docs, got %v", st.Tools)
	}
}

func TestImport_ReturnsNamesInStableOrder(t *testing.T) {
	svc := svcWith(newFakeRepo(), ctx7Registry(), &fakeClient{})
	imported, skipped, err := svc.Import(ctxWS("ws_1"), map[string]mcpinfra.ImportEntry{
		"zeta":  {Command: "npx"},
		"alpha": {Command: "npx"},
	}, false)
	if err != nil {
		t.Fatalf("import: %v", err)
	}
	if !reflect.DeepEqual(imported, []string{"alpha", "zeta"}) {
		t.Fatalf("imported order must be stable, got %v", imported)
	}
	if len(skipped) != 0 {
		t.Fatalf("unexpected skipped entries: %v", skipped)
	}
}

// TestInstall_OptionalEnvNotBlocked verifies a server with a required credential + optional knobs
// installs when only the required one is given — optional envs (the registry's many tuning vars)
// must never block install.
//
// TestInstall_OptionalEnvNotBlocked 验证「必填凭据 + 一堆可选旋钮」的 server 只给必填的就能装——可选 env
// （registry 的一堆调优变量）绝不该拦安装。
func TestInstall_OptionalEnvNotBlocked(t *testing.T) {
	reg := &fakeRegistry{entries: []mcpdomain.RegistryEntry{{
		Name: "x/y",
		Packages: []mcpdomain.Package{{Name: "y-mcp", RuntimeHint: "npx", EnvVars: []mcpdomain.EnvVar{
			{Name: "API_KEY", Required: true},
			{Name: "OPTIONAL_ZONE"}, {Name: "OPTIONAL_TIMEOUT"},
		}}},
	}}}
	svc := svcWith(newFakeRepo(), reg, &fakeClient{})
	if _, err := svc.InstallFromRegistry(ctxWS("ws_1"), "x/y", map[string]string{"API_KEY": "k"}); err != nil {
		t.Fatalf("install with only the required env should succeed, got %v", err)
	}
}

func TestInstall_MissingEnv(t *testing.T) {
	reg := &fakeRegistry{entries: []mcpdomain.RegistryEntry{{
		Name:     "x/y",
		Packages: []mcpdomain.Package{{Name: "y-mcp", RuntimeHint: "npx", EnvVars: []mcpdomain.EnvVar{{Name: "API_KEY", Required: true}}}},
	}}}
	repo := newFakeRepo()
	svc := svcWith(repo, reg, &fakeClient{})
	_, err := svc.InstallFromRegistry(ctxWS("ws_1"), "x/y", nil)
	if !errors.Is(err, mcpdomain.ErrEnvMissing) {
		t.Fatalf("want ErrEnvMissing, got %v", err)
	}
	var structured *errorspkg.Error
	if !errors.As(err, &structured) {
		t.Fatalf("want structured missing-env error, got %T", err)
	}
	missing, ok := structured.Details["missing"].([]string)
	if !ok || len(missing) != 1 || missing[0] != "API_KEY" {
		t.Fatalf("want details.missing=[API_KEY], got %#v", structured.Details["missing"])
	}
	if got, _ := repo.List(ctxWS("ws_1")); len(got) != 0 {
		t.Fatalf("missing env must not persist a partial server, got %d rows", len(got))
	}
}

func TestInstall_NoRunnablePackage(t *testing.T) {
	reg := &fakeRegistry{entries: []mcpdomain.RegistryEntry{{
		Name:     "x/y",
		Packages: []mcpdomain.Package{{Name: "snyk", RuntimeHint: "unsupported-runtime"}},
	}}}
	repo := newFakeRepo()
	svc := svcWith(repo, reg, &fakeClient{})
	_, err := svc.InstallFromRegistry(ctxWS("ws_1"), "x/y", nil)
	if !errors.Is(err, mcpdomain.ErrNoRunnablePackage) {
		t.Fatalf("want ErrNoRunnablePackage, got %v", err)
	}
	if got, _ := repo.List(ctxWS("ws_1")); len(got) != 0 {
		t.Fatalf("no-runnable install must not persist a partial server, got %d rows", len(got))
	}
}

func TestCallTool_RoutesToClient(t *testing.T) {
	fc := &fakeClient{tools: []mcpdomain.ToolDef{{Name: "get-library-docs"}}, callResult: "DOCS"}
	repo := newFakeRepo()
	svc := svcWith(repo, ctx7Registry(), fc)
	ctx := ctxWS("ws_1")
	st, _ := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	res, err := svc.CallTool(ctx, st.ID, "get-library-docs", json.RawMessage(`{}`), "")
	if err != nil {
		t.Fatalf("call: %v", err)
	}
	if res != "DOCS" {
		t.Fatalf("want DOCS, got %q", res)
	}
	// C4: every invocation records one mcp_calls audit row; "" derives chat off a plain ctx.
	// C4：每次调用记一行 mcp_calls 审计；"" 在裸 ctx 下推为 chat。
	if len(repo.calls) != 1 {
		t.Fatalf("want 1 recorded call, got %d", len(repo.calls))
	}
	c := repo.calls[0]
	if c.ServerID != st.ID || c.Tool != "get-library-docs" || c.Status != mcpdomain.CallStatusOK ||
		c.TriggeredBy != mcpdomain.CallTriggeredByChat || c.Output != "DOCS" {
		t.Fatalf("recorded call wrong: %+v", c)
	}
}

// TestCallTool_DegradesAndSignals proves the health state and the live entity-panel signal move
// together: three consecutive RPC failures produce one ephemeral degraded signal, degraded stays
// callable, and one success emits the recovery signal back to ready.
//
// TestCallTool_DegradesAndSignals 验证健康状态和实体面板实时信号同步变化：连续三次 RPC 失败产生一条
// ephemeral degraded signal，degraded 仍可调用，一次成功再发恢复为 ready 的 signal。
func TestCallTool_DegradesAndSignals(t *testing.T) {
	fc := &fakeClient{tools: []mcpdomain.ToolDef{{Name: "health"}}, callErr: errors.New("upstream boom")}
	repo := newFakeRepo()
	svc := svcWith(repo, ctx7Registry(), fc)
	ctx := ctxWS("ws_1")
	st, err := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	if err != nil {
		t.Fatalf("install: %v", err)
	}
	bridge := &statusBridge{}
	svc.SetEntitiesBridge(bridge)
	for i := 0; i < mcpdomain.DegradedThreshold; i++ {
		if _, err := svc.CallTool(ctx, st.ID, "health", json.RawMessage(`{}`), "manual"); err == nil {
			t.Fatalf("failure %d unexpectedly succeeded", i+1)
		}
	}
	status, err := svc.GetServer(ctx, "context7")
	if err != nil {
		t.Fatalf("get degraded server: %v", err)
	}
	if status.Status != mcpdomain.StatusDegraded || status.ConsecutiveFailures != mcpdomain.DegradedThreshold {
		t.Fatalf("health counters wrong after threshold: %+v", status)
	}
	statusEvents := make([]streamdomain.Event, 0, len(bridge.events))
	for _, event := range bridge.events {
		if signal, ok := event.Frame.(streamdomain.Signal); ok && signal.Node.Type == "status" {
			statusEvents = append(statusEvents, event)
		}
	}
	if len(statusEvents) != 1 {
		t.Fatalf("threshold crossing must emit one status signal, got %d status events out of %d total", len(statusEvents), len(bridge.events))
	}
	first, ok := statusEvents[0].Frame.(streamdomain.Signal)
	if !ok || !first.Ephemeral || first.Node.Type != "status" {
		t.Fatalf("degraded event must be ephemeral status signal, got %#v", statusEvents[0].Frame)
	}
	var degraded map[string]string
	if err := json.Unmarshal(first.Node.Content, &degraded); err != nil {
		t.Fatalf("decode degraded signal: %v", err)
	}
	if degraded["status"] != mcpdomain.StatusDegraded || degraded["prevStatus"] != mcpdomain.StatusReady {
		t.Fatalf("degraded signal payload wrong: %v", degraded)
	}

	fc.callErr = nil
	if _, err := svc.CallTool(ctx, st.ID, "health", json.RawMessage(`{}`), "manual"); err != nil {
		t.Fatalf("recovery call: %v", err)
	}
	status, err = svc.GetServer(ctx, "context7")
	if err != nil || status.Status != mcpdomain.StatusReady || status.ConsecutiveFailures != 0 {
		t.Fatalf("success must restore ready and reset failures: status=%+v err=%v", status, err)
	}
	statusEvents = statusEvents[:0]
	for _, event := range bridge.events {
		if signal, ok := event.Frame.(streamdomain.Signal); ok && signal.Node.Type == "status" {
			statusEvents = append(statusEvents, event)
		}
	}
	if len(statusEvents) != 2 {
		t.Fatalf("recovery must emit one additional status signal, got %d status events out of %d total", len(statusEvents), len(bridge.events))
	}
	recovered, ok := statusEvents[1].Frame.(streamdomain.Signal)
	if !ok || !recovered.Ephemeral || recovered.Node.Type != "status" {
		t.Fatalf("recovery event must be ephemeral status signal, got %#v", statusEvents[1].Frame)
	}
	var ready map[string]string
	if err := json.Unmarshal(recovered.Node.Content, &ready); err != nil {
		t.Fatalf("decode recovery signal: %v", err)
	}
	if ready["status"] != mcpdomain.StatusReady || ready["prevStatus"] != mcpdomain.StatusDegraded {
		t.Fatalf("recovery signal payload wrong: %v", ready)
	}
}

// TestCatalogSource_ReportsServerWithToolNames: catalog reports the server + ALL its tool
// names as Members (the container-entity contract).
//
// TestCatalogSource_ReportsServerWithToolNames：catalog 报 server + 它全部工具名为 Members（容器
// 实体契约）。
func TestCatalogSource_ReportsServerWithToolNames(t *testing.T) {
	fc := &fakeClient{tools: []mcpdomain.ToolDef{{Name: "get-library-docs"}, {Name: "resolve-id"}}}
	svc := svcWith(newFakeRepo(), ctx7Registry(), fc)
	ctx := ctxWS("ws_1")
	_, _ = svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)

	items, err := svc.AsCatalogSource().ListItems(ctx)
	if err != nil {
		t.Fatalf("catalog: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("want 1 catalog item, got %d", len(items))
	}
	if items[0].Name != "context7" || items[0].Description != "Fetch latest library docs" {
		t.Fatalf("catalog name/desc: %+v", items[0])
	}
	if len(items[0].Members) != 2 || items[0].Members[0] != "get-library-docs" {
		t.Fatalf("want 2 tool-name Members, got %v", items[0].Members)
	}
}

func TestReconnect_RefreshesStatus(t *testing.T) {
	fc := &fakeClient{tools: []mcpdomain.ToolDef{{Name: "t"}}}
	svc := svcWith(newFakeRepo(), ctx7Registry(), fc)
	ctx := ctxWS("ws_1")
	_, _ = svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	st, err := svc.Reconnect(ctx, "context7")
	if err != nil {
		t.Fatalf("reconnect: %v", err)
	}
	if st.Status != mcpdomain.StatusReady {
		t.Fatalf("want ready after reconnect, got %q", st.Status)
	}
}

// recNotif records emitted notifications so a test can inspect the payload.
type recNotif struct{ last map[string]any }

func (r *recNotif) Emit(_ context.Context, _ string, payload map[string]any) error {
	r.last = payload
	return nil
}
func (r *recNotif) Broadcast(ctx context.Context, t string, p map[string]any) error {
	return r.Emit(ctx, t, p)
}

// TestReconnect_NotifiesOutcome — reconnect fires whether the attempt succeeded or failed,
// so the notification MUST carry the resulting status (else the center can't tell a recovery
// from a still-broken server). reconnect 成败都发,故通知须带结局 status。
func TestReconnect_NotifiesOutcome(t *testing.T) {
	// success case: fresh client connects → status ready in the payload. 成功:status=ready。
	rn := &recNotif{}
	svc := svcWith(newFakeRepo(), ctx7Registry(), &fakeClient{tools: []mcpdomain.ToolDef{{Name: "t"}}})
	svc.SetNotifier(rn)
	ctx := ctxWS("ws_1")
	if _, err := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil); err != nil {
		t.Fatalf("install: %v", err)
	}
	if _, err := svc.Reconnect(ctx, "context7"); err != nil {
		t.Fatalf("reconnect: %v", err)
	}
	if rn.last["name"] != "context7" || rn.last["status"] != mcpdomain.StatusReady {
		t.Fatalf("reconnected payload must carry name + ready status, got %+v", rn.last)
	}

	// failure case: a client that errors on connect → status failed + lastError surfaced.
	// 失败:status=failed + lastError 冒出。
	rn2 := &recNotif{}
	svc2 := svcWith(newFakeRepo(), ctx7Registry(), &fakeClient{initErr: errors.New("boom")})
	svc2.SetNotifier(rn2)
	if _, err := svc2.InstallFromRegistry(ctx, "io.github.upstash/context7", nil); err != nil {
		// install may surface the connect error; the row still exists — reconnect below is what we test.
		_ = err
	}
	_, _ = svc2.Reconnect(ctx, "context7")
	if rn2.last["status"] != mcpdomain.StatusFailed {
		t.Fatalf("failed reconnect must carry status=failed, got %+v", rn2.last)
	}
	if _, ok := rn2.last["lastError"]; !ok {
		t.Errorf("failed reconnect payload should surface lastError, got %+v", rn2.last)
	}
}

func TestRemove_StopsAndDeletes(t *testing.T) {
	svc := svcWith(newFakeRepo(), ctx7Registry(), &fakeClient{})
	ctx := ctxWS("ws_1")
	_, _ = svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	if err := svc.RemoveServer(ctx, "context7"); err != nil {
		t.Fatalf("remove: %v", err)
	}
	if _, err := svc.GetServer(ctx, "context7"); !errors.Is(err, mcpdomain.ErrServerNotFound) {
		t.Fatalf("removed server should be NotFound, got %v", err)
	}
}

func TestRemove_AcceptsMarketplaceRegistryAlias(t *testing.T) {
	svc := svcWith(newFakeRepo(), ctx7Registry(), &fakeClient{})
	ctx := ctxWS("ws_1")
	if _, err := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil); err != nil {
		t.Fatalf("install: %v", err)
	}
	if err := svc.RemoveServer(ctx, "io.github.upstash/context7"); err != nil {
		t.Fatalf("remove by registry alias: %v", err)
	}
	if _, err := svc.GetServer(ctx, "context7"); !errors.Is(err, mcpdomain.ErrServerNotFound) {
		t.Fatalf("removed server should be NotFound, got %v", err)
	}
}

// fakeRelSyncer records every PurgeEntity key so a test can assert which keys RemoveServer purged.
type fakeRelSyncer struct{ purged []string }

func (f *fakeRelSyncer) PurgeEntity(_ context.Context, _, id string) error {
	f.purged = append(f.purged, id)
	return nil
}

// TestRemove_PurgesRelationsByIdAndName — F166: an MCP equip edge is keyed by the server NAME (the common
// mcp:<name>/tool form computeMountEdges strips to) OR the mcp_ id, so RemoveServer must purge relations
// under BOTH. Purging by id alone left a dangling agent/workflow→mcp edge orphaned after the server was
// removed (the relation graph then claimed a dependency that no longer existed).
func TestRemove_PurgesRelationsByIdAndName(t *testing.T) {
	svc := svcWith(newFakeRepo(), ctx7Registry(), &fakeClient{})
	rel := &fakeRelSyncer{}
	svc.SetRelationSyncer(rel)
	ctx := ctxWS("ws_1")
	if _, err := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil); err != nil {
		t.Fatalf("install: %v", err)
	}
	if err := svc.RemoveServer(ctx, "context7"); err != nil {
		t.Fatalf("remove: %v", err)
	}
	hasID, hasName := false, false
	for _, k := range rel.purged {
		if strings.HasPrefix(k, "mcp_") {
			hasID = true
		}
		if k == "context7" {
			hasName = true
		}
	}
	if !hasID || !hasName {
		t.Fatalf("RemoveServer must purge by BOTH the mcp_ id and the name (name-keyed edges orphan otherwise), purged=%v", rel.purged)
	}
}

func TestStderrTail_UsesByteCapAndKeepsNewestBytes(t *testing.T) {
	const capBytes = 8 * 1024
	input := strings.Repeat("old-", capBytes) + "newest stderr marker"
	got := stderrTail(input, capBytes)
	if len([]byte(got)) != capBytes {
		t.Fatalf("stderr tail byte length = %d, want %d", len([]byte(got)), capBytes)
	}
	if !strings.HasSuffix(got, "newest stderr marker") {
		t.Fatalf("stderr tail must preserve newest bytes, got suffix %q", got[len(got)-len("newest stderr marker"):])
	}
}

func TestInstall_NameConflict(t *testing.T) {
	svc := svcWith(newFakeRepo(), ctx7Registry(), &fakeClient{})
	ctx := ctxWS("ws_1")
	_, _ = svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	_, err := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	if !errors.Is(err, mcpdomain.ErrNameConflict) {
		t.Fatalf("want ErrNameConflict on re-install, got %v", err)
	}
}

// TestPlanFromRegistry: the wire plan mirrors Plan()'s pick without installing anything; envVars is
// [] never nil; unknown entries error. 计划投影一致且零副作用;envVars 恒 [] 非 nil;未知条目报错。
func TestPlanFromRegistry(t *testing.T) {
	repo := newFakeRepo()
	svc := svcWith(repo, ctx7Registry(), &fakeClient{})
	plan, err := svc.PlanFromRegistry(ctxWS("ws_1"), "io.github.upstash/context7")
	if err != nil {
		t.Fatalf("plan: %v", err)
	}
	if plan.Transport != mcpdomain.TransportStdio {
		t.Errorf("transport = %q, want stdio", plan.Transport)
	}
	if plan.EnvVars == nil {
		t.Error("envVars must be [] not nil")
	}
	if n := len(repo.byID); n != 0 {
		t.Errorf("plan must not install: repo has %d rows", n)
	}
	if _, err := svc.PlanFromRegistry(ctxWS("ws_1"), "io.github.nope/none"); err == nil {
		t.Error("unknown entry must error")
	}
}

// --- WRK-082 批B' MCP 媒体入口 media inlet ---------------------------------------

type fakeUploader struct{ uploaded []string }

func (f *fakeUploader) Upload(_ context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	f.uploaded = append(f.uploaded, filename)
	return &attachmentdomain.Attachment{ID: "att_00aa00aa00aa00aa", Filename: filename, MimeType: mime, SizeBytes: int64(len(data))}, nil
}

type selectiveUploader struct {
	uploaded []string
	failAt   int
}

func (u *selectiveUploader) Upload(_ context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	index := len(u.uploaded)
	u.uploaded = append(u.uploaded, filename)
	if index == u.failAt {
		return nil, errors.New("attachment store temporarily unavailable")
	}
	return &attachmentdomain.Attachment{
		ID:        fmt.Sprintf("att_%016x", index+1),
		Filename:  filename,
		MimeType:  mime,
		SizeBytes: int64(len(data)),
	}, nil
}

// TestCallTool_MediaLandsAsReceipt: an MCP tool returning binary image content produces a
// first-class attachment and a MediaRef receipt line in the result — never a bare placeholder.
// Without an uploader wired, the call still succeeds with the placeholder story (honest degrade).
func TestCallTool_MediaLandsAsReceipt(t *testing.T) {
	png := []byte{0x89, 0x50, 0x4E, 0x47}
	fc := &fakeClient{
		tools:      []mcpdomain.ToolDef{{Name: "screenshot"}},
		callResult: "[image: image/png]",
		callMedia:  []mcpdomain.Media{{MimeType: "image/png", Data: png}},
	}
	repo := newFakeRepo()
	svc := svcWith(repo, ctx7Registry(), fc)
	up := &fakeUploader{}
	svc.SetUploader(up)
	ctx := ctxWS("ws_1")
	st, _ := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)

	res, err := svc.CallTool(ctx, st.ID, "screenshot", json.RawMessage(`{}`), "")
	if err != nil {
		t.Fatalf("call: %v", err)
	}
	if !strings.Contains(res, `"attachmentId":"att_00aa00aa00aa00aa"`) ||
		!strings.Contains(res, `"source":"mcp_media"`) {
		t.Fatalf("result lacks the MediaRef receipt: %q", res)
	}
	if len(up.uploaded) != 1 || !strings.HasPrefix(up.uploaded[0], "mcp-screenshot-0") {
		t.Fatalf("uploaded = %v", up.uploaded)
	}

	// No uploader → the call still works, placeholder story intact (best-effort inlet).
	svc2 := svcWith(newFakeRepo(), ctx7Registry(), fc)
	st2, _ := svc2.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	res2, err := svc2.CallTool(ctx, st2.ID, "screenshot", json.RawMessage(`{}`), "")
	if err != nil || strings.Contains(res2, "attachmentId") {
		t.Fatalf("uploaderless call = %q, %v — want placeholder story, no receipt", res2, err)
	}
}

// TestCallTool_MediaUploadBestEffortPerItem proves one failed attachment upload does not poison
// the MCP call: successful items receive receipts, while the failed item's original placeholder
// remains in the result for an honest partial outcome.
//
// TestCallTool_MediaUploadBestEffortPerItem 验证附件逐件 best-effort：一件上传失败不污染整次 MCP 调用，
// 成功项得到 receipt，失败项保留原始占位叙事，诚实表达部分成功。
func TestCallTool_MediaUploadBestEffortPerItem(t *testing.T) {
	fc := &fakeClient{
		tools:      []mcpdomain.ToolDef{{Name: "mixed-media"}},
		callResult: "[image: first]\n[audio: failed]\n[image: third]",
		callMedia: []mcpdomain.Media{
			{MimeType: "image/png", Data: []byte("first")},
			{MimeType: "audio/mpeg", Data: []byte("failed")},
			{MimeType: "image/jpeg", Data: []byte("third")},
		},
	}
	repo := newFakeRepo()
	svc := svcWith(repo, ctx7Registry(), fc)
	uploader := &selectiveUploader{failAt: 1}
	svc.SetUploader(uploader)
	ctx := ctxWS("ws_1")
	st, err := svc.InstallFromRegistry(ctx, "io.github.upstash/context7", nil)
	if err != nil {
		t.Fatalf("install: %v", err)
	}

	result, err := svc.CallTool(ctx, st.ID, "mixed-media", json.RawMessage(`{}`), "")
	if err != nil {
		t.Fatalf("one upload failure must not fail MCP call: %v", err)
	}
	if !strings.Contains(result, "[audio: failed]") {
		t.Fatalf("failed media item must retain placeholder, got %q", result)
	}
	if strings.Count(result, `"source":"mcp_media"`) != 2 {
		t.Fatalf("two successful media items must produce two receipts, got %q", result)
	}
	if len(uploader.uploaded) != 3 || !strings.HasSuffix(uploader.uploaded[0], ".png") ||
		!strings.HasSuffix(uploader.uploaded[1], ".mp3") || !strings.HasSuffix(uploader.uploaded[2], ".jpg") {
		t.Fatalf("per-item uploads must preserve media type/order, got %v", uploader.uploaded)
	}
	if len(repo.calls) != 1 || repo.calls[0].Status != mcpdomain.CallStatusOK {
		t.Fatalf("partial media upload must still record one successful MCP call, got %+v", repo.calls)
	}
}
