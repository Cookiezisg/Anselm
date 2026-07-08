package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"testing"

	"go.uber.org/zap"

	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	mcpinfra "github.com/sunweilin/anselm/backend/internal/infra/mcp"
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
	initErr    error
	closed     bool
}

func (c *fakeClient) Initialize(context.Context) error { return c.initErr }
func (c *fakeClient) ListTools(context.Context) ([]mcpdomain.ToolDef, error) {
	return c.tools, nil
}
func (c *fakeClient) CallTool(context.Context, string, json.RawMessage) (string, error) {
	return c.callResult, nil
}
func (c *fakeClient) Close() error       { c.closed = true; return nil }
func (c *fakeClient) StderrTail() string { return "" }

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
	svc := svcWith(newFakeRepo(), reg, &fakeClient{})
	_, err := svc.InstallFromRegistry(ctxWS("ws_1"), "x/y", nil)
	if !errors.Is(err, mcpdomain.ErrEnvMissing) {
		t.Fatalf("want ErrEnvMissing, got %v", err)
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
