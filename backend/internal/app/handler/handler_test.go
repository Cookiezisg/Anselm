package handler

import (
	"bytes"
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"
	"go.uber.org/zap/zaptest/observer"

	envfixapp "github.com/sunweilin/anselm/backend/internal/app/envfix"
	mediaartifactapp "github.com/sunweilin/anselm/backend/internal/app/mediaartifact"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	handlerinfra "github.com/sunweilin/anselm/backend/internal/infra/handler"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	handlerstore "github.com/sunweilin/anselm/backend/internal/infra/store/handler"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// --- fakes -----------------------------------------------------------------

type okSandbox struct{}

func (okSandbox) EnsureEnv(_ context.Context, _ sandboxdomain.Owner, spec sandboxdomain.EnvSpec, _ sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error) {
	return &sandboxdomain.Env{Status: sandboxdomain.EnvStatusReady, Deps: spec.Deps}, nil
}

// cancelOnEnsureSandbox models a client disconnect after the entity transaction has committed:
// the first sandbox operation cancels the request and returns that cancellation.
//
// cancelOnEnsureSandbox 模拟实体事务已提交后客户端断连：第一次 sandbox 操作取消请求并返取消错误。
type cancelOnEnsureSandbox struct{ cancel context.CancelFunc }

func (s cancelOnEnsureSandbox) EnsureEnv(ctx context.Context, _ sandboxdomain.Owner, _ sandboxdomain.EnvSpec, _ sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error) {
	s.cancel()
	return nil, ctx.Err()
}

// failAfterSandbox lets the first durable build succeed, then fails a later rebuild. This models
// an already-running handler whose replacement environment cannot be installed.
//
// failAfterSandbox 让首次耐久构建成功、后续重建失败，模拟已有 resident 但替换环境安装失败。
type failAfterSandbox struct {
	calls  int
	failAt int
}

func (s *failAfterSandbox) EnsureEnv(_ context.Context, _ sandboxdomain.Owner, spec sandboxdomain.EnvSpec, _ sandboxdomain.ProgressFunc) (*sandboxdomain.Env, error) {
	s.calls++
	if s.calls >= s.failAt {
		return nil, fmt.Errorf("synthetic environment install failure")
	}
	return &sandboxdomain.Env{Status: sandboxdomain.EnvStatusReady, Deps: spec.Deps}, nil
}

type recordingEmitter struct{ events []string }

func (e *recordingEmitter) Emit(_ context.Context, eventType string, _ map[string]any) error {
	e.events = append(e.events, eventType)
	return nil
}

func (e *recordingEmitter) Broadcast(_ context.Context, eventType string, _ map[string]any) error {
	e.events = append(e.events, eventType)
	return nil
}

func (e *recordingEmitter) has(eventType string) bool {
	for _, got := range e.events {
		if got == eventType {
			return true
		}
	}
	return false
}

type fakePicker struct{}

func (fakePicker) Pick(context.Context, string) (modeldomain.ModelRef, error) {
	return modeldomain.ModelRef{APIKeyID: "ak", ModelID: "m"}, nil
}

type fakeKeys struct{}

func (fakeKeys) ResolveCredentialsByID(context.Context, string) (apikeydomain.Credentials, error) {
	return apikeydomain.Credentials{Provider: "mock"}, nil
}
func (fakeKeys) MarkInvalidByID(context.Context, string, string) error { return nil }

type fakeEncryptor struct{}

func (fakeEncryptor) Encrypt(_ context.Context, pt []byte) ([]byte, error) { return pt, nil }
func (fakeEncryptor) Decrypt(_ context.Context, ct []byte) ([]byte, error) { return ct, nil }

type fakeHandle struct{ killed bool }

func (h *fakeHandle) Stdin() io.WriteCloser { return nopWC{} }
func (h *fakeHandle) Stdout() io.ReadCloser { return io.NopCloser(strings.NewReader("")) }
func (h *fakeHandle) Stderr() io.ReadCloser { return io.NopCloser(strings.NewReader("")) }
func (h *fakeHandle) Wait() error           { return nil }
func (h *fakeHandle) Kill() error           { h.killed = true; return nil }
func (h *fakeHandle) PID() int              { return 4321 }

type nopWC struct{}

func (nopWC) Write(p []byte) (int, error) { return len(p), nil }
func (nopWC) Close() error                { return nil }

type fakeRunner struct {
	spawns       int
	handles      []*fakeHandle
	destroyedEnv []string // owner IDs passed to DestroyEnv (per-version venv reclaim on trim)
}

func (r *fakeRunner) Ready() bool { return true }
func (r *fakeRunner) Spawn(_ context.Context, _ sandboxdomain.Owner, _, _, _ string) (sandboxdomain.LongLivedHandle, error) {
	r.spawns++
	h := &fakeHandle{}
	r.handles = append(r.handles, h)
	return h, nil
}
func (r *fakeRunner) Destroy(context.Context, string) error { return nil }
func (r *fakeRunner) DestroyEnv(_ context.Context, owner sandboxdomain.Owner) error {
	r.destroyedEnv = append(r.destroyedEnv, owner.ID)
	return nil
}

type fakeClient struct {
	calls   int
	crashed bool
	result  any
	callErr error
	initErr error
	// outDir records the per-call artifact directory the service handed to this call (H5); write
	// lets a test act as the sandboxed method and actually produce a file in it.
	// outDir 记下服务交给本次调用的逐调用产物目录(H5);write 让测试扮演沙箱里的 method、真的在里面
	// 产出一个文件。
	outDir string
	write  func(dir string)
}

func (c *fakeClient) Init(context.Context, map[string]any) error { return c.initErr }
func (c *fakeClient) Call(context.Context, string, map[string]any) (any, error) {
	c.calls++
	return c.result, c.callErr
}
func (c *fakeClient) StreamCall(ctx context.Context, m string, a map[string]any, outDir string, _ func(any)) (any, error) {
	c.outDir = outDir
	if c.write != nil && outDir != "" {
		c.write(outDir)
	}
	return c.Call(ctx, m, a)
}
func (c *fakeClient) Shutdown(context.Context) error { return nil }
func (c *fakeClient) Crashed() bool                  { return c.crashed }

// clientLog records every fake client the factory mints (one per spawn).
type clientLog struct {
	clients []*fakeClient
	initErr error // injected onto each minted client's Init (simulate a broken __init__)
}

func (cl *clientLog) factory(io.WriteCloser, io.Reader, *zap.Logger) handlerinfra.Client {
	c := &fakeClient{result: "ok", initErr: cl.initErr}
	cl.clients = append(cl.clients, c)
	return c
}

// --- harness ---------------------------------------------------------------

func newSvc(t *testing.T) (*Service, *fakeRunner, *clientLog, context.Context) {
	return newSvcWithSandbox(t, okSandbox{})
}

func newSvcWithSandbox(t *testing.T, sandbox envfixapp.SandboxPort) (*Service, *fakeRunner, *clientLog, context.Context) {
	return newSvcWithSandboxAndEmitter(t, sandbox, nil)
}

func newSvcWithSandboxAndEmitter(t *testing.T, sandbox envfixapp.SandboxPort, notif notificationdomain.Emitter) (*Service, *fakeRunner, *clientLog, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range handlerstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	repo := handlerstore.New(ormpkg.Open(sqlDB))
	prov := envfixapp.NewProvisioner(sandbox, fakePicker{}, fakeKeys{}, llminfra.NewFactory(), zap.NewNop())
	runner := &fakeRunner{}
	cl := &clientLog{}
	svc := NewService(repo, prov, runner, fakeEncryptor{}, cl.factory, notif, zap.NewNop())
	return svc, runner, cl, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}

func createOps(t *testing.T, name string, reqArg bool) []Op {
	t.Helper()
	arr := `[{"op":"set_meta","name":"` + name + `","description":"d"},{"op":"add_method","method":{"name":"ping","args":[],"body":"return 1"}}`
	if reqArg {
		arr += `,{"op":"set_init_args_schema","args":[{"name":"api_key","type":"string","required":true,"sensitive":true}]}`
	}
	arr += `]`
	ops, err := ParseOps([]byte(arr))
	if err != nil {
		t.Fatalf("createOps: %v", err)
	}
	return ops
}

func TestListIncludesRuntimeState(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	h, _, err := svc.Create(ctx, CreateInput{Ops: createOps(t, "resident", false)})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	items, _, err := svc.List(ctx, handlerdomain.ListFilter{Limit: 20})
	if err != nil {
		t.Fatalf("List before spawn: %v", err)
	}
	if len(items) != 1 || items[0].RuntimeState != handlerdomain.RuntimeStateStopped {
		t.Fatalf("List before spawn = %+v, want one stopped handler", items)
	}

	if _, err := svc.manager.Get(ctx, h.ID); err != nil {
		t.Fatalf("manager.Get: %v", err)
	}
	items, _, err = svc.List(ctx, handlerdomain.ListFilter{Limit: 20})
	if err != nil {
		t.Fatalf("List after spawn: %v", err)
	}
	if len(items) != 1 || items[0].RuntimeState != handlerdomain.RuntimeStateRunning {
		t.Fatalf("List after spawn = %+v, want one running handler", items)
	}
}

// editDepsOps is a non-conflicting edit (changes deps only) for version-bump tests.
func editDepsOps(t *testing.T) []Op {
	t.Helper()
	ops, err := ParseOps([]byte(`[{"op":"set_dependencies","dependencies":["requests"]}]`))
	if err != nil {
		t.Fatalf("editDepsOps: %v", err)
	}
	return ops
}

// --- tests -----------------------------------------------------------------

// TestAddMethod_MisplacedFieldsFailLoud — F136: an add_method op whose method fields sit at the op's
// TOP LEVEL (instead of nested under "method") must fail loud with a corrective message — not silently
// drop the body (an empty-bodied method is a false success) nor mislead with "method.name required".
func TestAddMethod_MisplacedFieldsFailLoud(t *testing.T) {
	mustOp := func(s string) Op {
		t.Helper()
		ops, err := ParseOps([]byte("[" + s + "]"))
		if err != nil {
			t.Fatalf("ParseOps(%s): %v", s, err)
		}
		return ops[0]
	}

	// body misplaced at the top level (name correctly nested) — used to drop the body silently.
	bodyOut := mustOp(`{"op":"add_method","method":{"name":"fetch"},"body":"return 1"}`)
	if err := applyOne(&VersionDraft{}, bodyOut); err == nil ||
		!strings.Contains(err.Error(), "body") || !strings.Contains(err.Error(), "nested under") {
		t.Fatalf("misplaced top-level body must fail loud naming it, got %v", err)
	}

	// everything flat — used to trip the misleading "method.name required".
	flat := mustOp(`{"op":"add_method","name":"fetch","body":"return 1"}`)
	if err := applyOne(&VersionDraft{}, flat); err == nil || !strings.Contains(err.Error(), "nested under") {
		t.Fatalf("all-flat add_method must point at the nesting, got %v", err)
	}

	// the correct nested shape still applies, body and all.
	st := &VersionDraft{}
	if err := applyOne(st, mustOp(`{"op":"add_method","method":{"name":"fetch","body":"return 1"}}`)); err != nil {
		t.Fatalf("correct add_method must succeed: %v", err)
	}
	if len(st.Methods) != 1 || st.Methods[0].Body != "return 1" {
		t.Fatalf("method + body must land, got %+v", st.Methods)
	}
}

func TestCreate_NoEagerSpawn(t *testing.T) {
	svc, runner, _, ctx := newSvc(t)
	h, v, err := svc.Create(ctx, CreateInput{Ops: createOps(t, "alpha", false)})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if v.Version != 1 || h.ActiveVersionID != v.ID {
		t.Fatalf("v1 not active: %+v", v)
	}
	if runner.spawns != 0 {
		t.Fatalf("create should not spawn an instance, got %d", runner.spawns)
	}
	if got := svc.manager.State(h.ID); got != handlerdomain.RuntimeStateStopped {
		t.Fatalf("runtime state = %q, want stopped", got)
	}
}

func TestCreate_CancelledInstallPersistsTerminalEnvState(t *testing.T) {
	ctx, cancel := context.WithCancel(reqctxpkg.SetWorkspaceID(context.Background(), "ws_1"))
	svc, _, _, _ := newSvcWithSandbox(t, cancelOnEnsureSandbox{cancel: cancel})

	h, v, err := svc.Create(ctx, CreateInput{Ops: createOps(t, "cancelled_build", false)})
	if err != nil {
		t.Fatalf("Create should retain the durable entity after install cancellation: %v", err)
	}
	if v.EnvStatus != handlerdomain.EnvStatusFailed {
		t.Fatalf("returned version env status = %q, want failed", v.EnvStatus)
	}

	readCtx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	got, err := svc.Get(readCtx, h.ID)
	if err != nil {
		t.Fatalf("Get after cancelled install: %v", err)
	}
	if got.ActiveVersion.EnvStatus != handlerdomain.EnvStatusFailed {
		t.Fatalf("persisted env status = %q, want failed (must not remain syncing)", got.ActiveVersion.EnvStatus)
	}
}

// TestScrubSecrets — F82: the platform's injected sensitive config value is masked in the call audit
// (a secret user code leaked into a traceback / print), while the rest of the trace stays intact.
func TestScrubSecrets(t *testing.T) {
	got := scrubSecrets("HTTPError: GET https://api.example.com/x?appid=sk-SECRET123&q=1 failed", []string{"sk-SECRET123"})
	if strings.Contains(got, "sk-SECRET123") {
		t.Fatalf("secret not scrubbed: %q", got)
	}
	if !strings.Contains(got, "********") || !strings.Contains(got, "HTTPError") {
		t.Fatalf("scrub must mask the secret AND keep the rest of the trace: %q", got)
	}
	if scrubSecrets("plain text", nil) != "plain text" {
		t.Fatal("no secrets should be a no-op")
	}
}

// TestScrubErr — F164: a structured handler error carrying an injected secret in its traceback Details
// (lifted there by errorspkg.Wrap) must be masked on EVERY surface — Surface (LLM/record/HTTP) AND
// .Error() (logs) — before it is returned to the caller, while errors.Is still matches the outer code.
// This closes the leak where recordCall scrubbed only the persisted copy, so the LIVE error returned to
// the LLM still showed the plaintext secret (and the spawn path bypassed even that with inst==nil).
func TestScrubErr(t *testing.T) {
	secret := "sk-LEAKED-9999"
	inner := errorspkg.New(errorspkg.KindBadGateway, "INIT_FAILED", "init failed").
		WithDetails(map[string]any{"traceback": "ValueError: boom with key " + secret})
	wrapped := errorspkg.Wrap(handlerdomain.ErrInstanceSpawnFailed, inner)

	scrubbed := scrubErr(wrapped, []string{secret})
	if s := errorspkg.Surface(scrubbed); strings.Contains(s, secret) {
		t.Fatalf("Surface (LLM/record/HTTP) must not leak the secret, got: %q", s)
	}
	if strings.Contains(scrubbed.Error(), secret) {
		t.Fatalf(".Error() (logs) must not leak the secret, got: %q", scrubbed.Error())
	}
	if !strings.Contains(errorspkg.Surface(scrubbed), "********") {
		t.Fatalf("the secret must be MASKED (not silently dropped), got: %q", errorspkg.Surface(scrubbed))
	}
	if !errors.Is(scrubbed, handlerdomain.ErrInstanceSpawnFailed) {
		t.Fatal("scrubErr must preserve the outer code so errors.Is keeps matching")
	}
	if got := scrubErr(wrapped, nil); got != wrapped {
		t.Fatal("no secrets must be a no-op (same error returned)")
	}
}

// TestScrubbingWriter — F108: the live progress / SSE path must mask injected secrets AT THE SOURCE,
// not only in the after-the-fact audit copy (F82 covered only recordCall). A secret a handler print()s
// reaches the stderr fan and must be masked before it streams to the messages/entities SSE + the
// persisted progress block.
func TestScrubbingWriter(t *testing.T) {
	var buf bytes.Buffer
	sw := &scrubbingWriter{w: &buf, secrets: []string{"sk-SECRET123"}}
	const line = "connecting with key=sk-SECRET123 ok"
	n, err := sw.Write([]byte(line))
	if err != nil {
		t.Fatalf("write: %v", err)
	}
	if n != len(line) {
		t.Errorf("Write must report the original input length (masking changes byte count), got %d want %d", n, len(line))
	}
	if got := buf.String(); strings.Contains(got, "sk-SECRET123") || !strings.Contains(got, "********") {
		t.Errorf("secret must be masked before reaching the sink, got: %q", got)
	}
}

// TestCaptureStderr_ScrubsJournalAndFan locks the pre-call observation boundary: constructor or
// early method stderr can arrive before a per-call scrubbingWriter is attached, so captureStderr
// must protect both the zap journal and the fan itself.
func TestCaptureStderr_ScrubsJournalAndFan(t *testing.T) {
	secret := "sk-LOGGER-143"
	core, observed := observer.New(zap.InfoLevel)
	fan := newStderrFan()
	sink := &recSink{}
	detach := fan.attach(sink)
	defer detach()

	captureStderr(io.NopCloser(strings.NewReader(secret+"\n")), zap.New(core), fan, []string{secret})
	if got := sink.String(); strings.Contains(got, secret) || !strings.Contains(got, "********") {
		t.Fatalf("stderr fan leaked or dropped the mask: %q", got)
	}
	entries := observed.All()
	if len(entries) != 1 {
		t.Fatalf("observed %d stderr entries, want 1", len(entries))
	}
	line, ok := entries[0].ContextMap()["line"].(string)
	if !ok || strings.Contains(line, secret) || !strings.Contains(line, "********") {
		t.Fatalf("zap journal leaked or dropped the mask: %#v", entries[0].ContextMap()["line"])
	}
}

// TestCall_ScrubsLeakedSecretInAudit — F82 end-to-end wiring: a sensitive api_key the platform
// injected into __init__, if user code leaks it verbatim into a call error, must be masked in the
// persisted call audit (captured at spawn into Instance.SecretValues, scrubbed in recordCall).
func TestCall_ScrubsLeakedSecretInAudit(t *testing.T) {
	svc, _, cl, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "leaky", true)}) // reqArg=true → sensitive api_key
	if err := svc.UpdateConfig(ctx, h.ID, map[string]any{"api_key": "sk-LEAKED-789"}); err != nil {
		t.Fatalf("config: %v", err)
	}
	// Warm call spawns the instance, capturing the decrypted api_key into Instance.SecretValues.
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("warm call: %v", err)
	}
	// Now user code leaks the secret verbatim in an exception message.
	cl.clients[len(cl.clients)-1].callErr = errors.New("RequestError: GET https://api/x?key=sk-LEAKED-789 -> 401")
	_, _ = svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})

	page, _ := svc.SearchCalls(ctx, handlerdomain.CallFilter{HandlerID: h.ID})
	failed := false
	for _, c := range page.Calls {
		if c.Status != handlerdomain.CallStatusFailed {
			continue
		}
		failed = true
		if strings.Contains(c.ErrorMessage, "sk-LEAKED-789") {
			t.Fatalf("leaked secret NOT scrubbed from the call audit: %q", c.ErrorMessage)
		}
		if !strings.Contains(c.ErrorMessage, "********") {
			t.Fatalf("the secret should be masked, keeping the rest: %q", c.ErrorMessage)
		}
	}
	if !failed {
		t.Fatal("no failed call recorded")
	}
}

func TestCall_SpawnsRecordsReuses(t *testing.T) {
	svc, runner, cl, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "a", false)})

	res, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})
	if err != nil || res != "ok" {
		t.Fatalf("call: res=%v err=%v", res, err)
	}
	if runner.spawns != 1 || svc.manager.State(h.ID) != handlerdomain.RuntimeStateRunning {
		t.Fatalf("first call should spawn + run: spawns=%d state=%s", runner.spawns, svc.manager.State(h.ID))
	}
	// second call reuses the resident instance
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("call 2: %v", err)
	}
	if runner.spawns != 1 {
		t.Fatalf("second call should reuse instance, spawns=%d", runner.spawns)
	}
	if cl.clients[0].calls != 2 {
		t.Fatalf("client should have served 2 calls, got %d", cl.clients[0].calls)
	}
	// the call was recorded
	page, _ := svc.SearchCalls(ctx, handlerdomain.CallFilter{HandlerID: h.ID})
	if len(page.Calls) != 2 || page.Aggregates.OKCount != 2 {
		t.Fatalf("calls not recorded: %+v", page)
	}
}

func TestRestart_StopsThenRespawns(t *testing.T) {
	svc, runner, cl, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "a", false)})
	_, _ = svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})

	state, err := svc.Restart(ctx, h.ID)
	if err != nil || state != handlerdomain.RuntimeStateRunning {
		t.Fatalf("restart: state=%s err=%v", state, err)
	}
	if runner.spawns != 2 {
		t.Fatalf("restart should respawn: spawns=%d", runner.spawns)
	}
	if !runner.handles[0].killed {
		t.Fatal("restart should have killed the old handle")
	}
	if len(cl.clients) != 2 {
		t.Fatalf("restart should mint a fresh client, got %d", len(cl.clients))
	}
}

func TestCrash_RespawnsOnNextCall(t *testing.T) {
	svc, runner, cl, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "a", false)})
	_, _ = svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})

	cl.clients[0].crashed = true // process died
	if got := svc.manager.State(h.ID); got != handlerdomain.RuntimeStateCrashed {
		t.Fatalf("state should be crashed, got %q", got)
	}
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("call after crash: %v", err)
	}
	if runner.spawns != 2 {
		t.Fatalf("crashed instance should respawn on next call: spawns=%d", runner.spawns)
	}
}

func TestEdit_BumpsVersionAndRestarts(t *testing.T) {
	notif := &recordingEmitter{}
	svc, runner, _, ctx := newSvcWithSandboxAndEmitter(t, okSandbox{}, notif)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "a", false)})
	_, _ = svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}) // running (spawns=1)

	v2, err := svc.Edit(ctx, EditInput{ID: h.ID, Ops: editDepsOps(t)})
	if err != nil {
		t.Fatalf("edit: %v", err)
	}
	if v2.Version != 2 {
		t.Fatalf("edit version = %d, want 2", v2.Version)
	}
	if runner.spawns != 2 {
		t.Fatalf("edit should restart the resident instance: spawns=%d", runner.spawns)
	}
}

func TestEdit_EmptyOpsRebuildsEnvEmitsNotification(t *testing.T) {
	notif := &recordingEmitter{}
	svc, runner, _, ctx := newSvcWithSandboxAndEmitter(t, okSandbox{}, notif)
	h, _, err := svc.Create(ctx, CreateInput{Ops: createOps(t, "rebuild", false)})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("warm call: %v", err)
	}
	if _, err := svc.Edit(ctx, EditInput{ID: h.ID, Ops: nil}); err != nil {
		t.Fatalf("empty-ops edit: %v", err)
	}
	if runner.spawns != 2 {
		t.Fatalf("successful empty-ops rebuild should restart the resident, got %d spawns", runner.spawns)
	}
	if !notif.has("handler.env_rebuilt") {
		t.Fatal("successful empty-ops rebuild must emit handler.env_rebuilt")
	}
}

func TestEdit_FailedEnvironmentStopsResidentWithoutSecondProvision(t *testing.T) {
	cases := []struct {
		name string
		ops  func(*testing.T) []Op
	}{
		{name: "empty ops", ops: func(*testing.T) []Op { return nil }},
		{name: "new version", ops: editDepsOps},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			sbx := &failAfterSandbox{failAt: 2}
			notif := &recordingEmitter{}
			svc, runner, _, ctx := newSvcWithSandboxAndEmitter(t, sbx, notif)
			h, _, err := svc.Create(ctx, CreateInput{Ops: createOps(t, "rebuild_failure", false)})
			if err != nil {
				t.Fatalf("create: %v", err)
			}
			if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
				t.Fatalf("warm call: %v", err)
			}
			if runner.spawns != 1 {
				t.Fatalf("setup should have one resident spawn, got %d", runner.spawns)
			}

			v, err := svc.Edit(ctx, EditInput{ID: h.ID, Ops: tc.ops(t)})
			if err != nil {
				t.Fatalf("edit: %v", err)
			}
			if v.EnvStatus != handlerdomain.EnvStatusFailed {
				t.Fatalf("env status = %q, want failed", v.EnvStatus)
			}
			if sbx.calls != 2 {
				t.Fatalf("one edit must provision exactly once after the initial build, got %d calls", sbx.calls)
			}
			if runner.spawns != 1 {
				t.Fatalf("failed replacement must not spawn a second resident, got %d spawns", runner.spawns)
			}
			if got := svc.manager.State(h.ID); got != handlerdomain.RuntimeStateStopped {
				t.Fatalf("failed replacement must stop the old resident, got state %q", got)
			}
			if notif.has("handler.env_rebuilt") {
				t.Fatal("failed environment rebuild must not emit handler.env_rebuilt")
			}
		})
	}
}

// TestEdit_MetaOnlyNoVersionNoRestart — F-handler-meta-restart (round-7/8): a meta-only edit (rename
// via set_meta, zero class change) must NOT mint a redundant identical-code version NOR restart the
// resident instance — a restart would needlessly wipe the stateful handler's in-memory state, with no
// other rename path available to the agent.
// TestSpawn_BrokenInitSurfacesTraceback — F131-init (round-15 handlertrace): a broken __init__'s Python
// traceback must reach the agent through the FULL app spawn path, not just the infra error in isolation.
// spawn.go wraps the structured init error via errorspkg.Wrap, which lifts its Details onto the
// spawn-failure sentinel — else Surface picks the detail-less ErrInstanceSpawnFailed and the agent sees
// an opaque "spawn failed". (The unit test passing while THIS integration was broken is how F131-init shipped.)
func TestSpawn_BrokenInitSurfacesTraceback(t *testing.T) {
	svc, _, cl, ctx := newSvc(t)
	cl.initErr = errorspkg.New(errorspkg.KindBadGateway, "HANDLER_CLIENT_INIT_FAILED", "init failed").
		WithDetails(map[string]any{"traceback": "RuntimeError: INIT distinctive ABC"})

	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "broken", false)}) // no required config → spawns on first call
	_, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})
	if err == nil {
		t.Fatal("a broken __init__ must fail the call")
	}
	if surfaced := errorspkg.Surface(err); !strings.Contains(surfaced, "INIT distinctive ABC") {
		t.Fatalf("the broken __init__ traceback must reach the agent surface, got opaque: %q", surfaced)
	}
}

func TestEdit_MetaOnlyNoVersionNoRestart(t *testing.T) {
	svc, runner, _, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "counter", false)})
	_, _ = svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}) // resident, spawns=1
	if runner.spawns != 1 {
		t.Fatalf("setup: want 1 spawn, got %d", runner.spawns)
	}

	metaOps, err := ParseOps([]byte(`[{"op":"set_meta","name":"renamed_counter"}]`))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	v, err := svc.Edit(ctx, EditInput{ID: h.ID, Ops: metaOps})
	if err != nil {
		t.Fatalf("meta-only edit: %v", err)
	}
	if v.Version != 1 {
		t.Fatalf("meta-only edit must NOT mint a new version, got version %d", v.Version)
	}
	if runner.spawns != 1 {
		t.Fatalf("meta-only edit must NOT restart the resident instance (would wipe state), spawns=%d", runner.spawns)
	}
	if got, _ := svc.Get(ctx, h.ID); got.Name != "renamed_counter" {
		t.Fatalf("meta-only edit must persist the rename, got name %q", got.Name)
	}
	if _, err := svc.GetVersionByNumber(ctx, h.ID, 2); err == nil {
		t.Fatal("meta-only edit must not create version 2")
	}
}

func TestRevert_PointerOnly(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "a", false)})
	if _, err := svc.Edit(ctx, EditInput{ID: h.ID, Ops: editDepsOps(t)}); err != nil {
		t.Fatalf("edit: %v", err)
	}
	if _, err := svc.Revert(ctx, h.ID, 1); err != nil {
		t.Fatalf("revert: %v", err)
	}
	got, _ := svc.Get(ctx, h.ID)
	if got.ActiveVersion == nil || got.ActiveVersion.Version != 1 {
		t.Fatalf("active should be v1 after revert, got %+v", got.ActiveVersion)
	}
	if _, err := svc.GetVersionByNumber(ctx, h.ID, 2); err != nil {
		t.Fatalf("v2 must survive revert, got %v", err)
	}
}

func TestConfig_GatesSpawn(t *testing.T) {
	svc, runner, _, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "a", true)}) // requires api_key

	// call before config → ErrConfigIncomplete, no spawn
	_, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})
	if !errors.Is(err, handlerdomain.ErrConfigIncomplete) {
		t.Fatalf("want ErrConfigIncomplete, got %v", err)
	}
	if runner.spawns != 0 {
		t.Fatalf("should not spawn without config, spawns=%d", runner.spawns)
	}
	// F-spawn-fail-audit (round-7/8): a spawn/config-gate failure must leave a failed handler_calls
	// row (visible in call history + failedCount + :triage), not vanish with no audit trace.
	res, serr := svc.SearchCalls(ctx, handlerdomain.CallFilter{HandlerID: h.ID})
	if serr != nil {
		t.Fatalf("search calls: %v", serr)
	}
	if res.Aggregates.FailedCount != 1 {
		t.Fatalf("spawn failure must record a failed call row (failedCount=1), got %d", res.Aggregates.FailedCount)
	}
	if len(res.Calls) != 1 || res.Calls[0].Status != handlerdomain.CallStatusFailed || res.Calls[0].Method != "ping" {
		t.Fatalf("failed call row must record method=ping status=failed, got %+v", res.Calls)
	}

	// set config → UpdateConfig restarts → now running
	if err := svc.UpdateConfig(ctx, h.ID, map[string]any{"api_key": "secret"}); err != nil {
		t.Fatalf("update config: %v", err)
	}
	if svc.manager.State(h.ID) != handlerdomain.RuntimeStateRunning {
		t.Fatalf("config complete should start the instance, state=%s", svc.manager.State(h.ID))
	}
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("call after config: %v", err)
	}
}

func TestShutdown_StopsAll(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "a", false)})
	_, _ = svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})
	svc.Shutdown(ctx)
	if got := svc.manager.State(h.ID); got != handlerdomain.RuntimeStateStopped {
		t.Fatalf("after shutdown state = %q, want stopped", got)
	}
}

func TestAssembleClass(t *testing.T) {
	d := &VersionDraft{
		Imports:        "import requests",
		InitBody:       "self.session = requests.Session()",
		ShutdownBody:   "self.session.close()",
		InitArgsSchema: []handlerdomain.InitArgSpec{{Name: "api_key", Type: "string", Required: true}},
		Methods:        []handlerdomain.MethodSpec{{Name: "fetch", Inputs: []schemapkg.Field{{Name: "url", Type: schemapkg.TypeString}}, Body: "return self.session.get(url).json()"}},
	}
	out := AssembleClass(d)
	for _, want := range []string{"class HandlerImpl:", "def __init__(self, api_key: str):", "def shutdown(self):", "def fetch(self, url: str):", "import requests"} {
		if !strings.Contains(out, want) {
			t.Fatalf("assembled class missing %q:\n%s", want, out)
		}
	}
}

// --- media artifacts (WRK-082 H5) -------------------------------------------

// artifactUploader is the minimal attachment store stand-in: it records what landed and hands
// back an id, so the test can assert on the receipt rather than on a real blob path.
type artifactUploader struct {
	got []string
}

func (u *artifactUploader) Upload(_ context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	u.got = append(u.got, filename+" "+mime)
	return &attachmentdomain.Attachment{
		ID: "att_00112233445566aa", Filename: filename, MimeType: mime, SizeBytes: int64(len(data)),
	}, nil
}

// tinyPNGBytes is a real 8-byte PNG signature — the collector SNIFFS content, so a fake payload
// would be refused for the right reason and make this test pass for the wrong one.
var tinyPNGBytes = []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n', 0, 0, 0, 0}

// TestCall_HandlerArtifactBecomesReceipt is the H5 contract: a long-lived handler gets a fresh
// EMPTY directory per CALL, and a file it declares there comes back as a MediaRef receipt marked
// with the handler source — the same currency function's artifacts use (不变量①), through the same
// collector, into the same store (不变量②).
//
// TestCall_HandlerArtifactBecomesReceipt 是 H5 的契约:长跑 handler **每次调用**拿到一个全新的空目录,
// 它在里面声明的文件带着 handler 产地作为 MediaRef receipt 回来——与 function 的产物**同一种货币**
// (不变量①)、经**同一个**采集器、进**同一间**库(不变量②)。
func TestCall_HandlerArtifactBecomesReceipt(t *testing.T) {
	svc, _, cl, ctx := newSvc(t)
	up := &artifactUploader{}
	svc.SetArtifactUploader(up)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "drawer", false)})

	// Warm the instance, then script the next call to behave like a method that wrote a chart.
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("warm call: %v", err)
	}
	c := cl.clients[len(cl.clients)-1]
	var seenDir string
	c.write = func(dir string) {
		seenDir = dir
		if err := os.WriteFile(filepath.Join(dir, "chart.png"), tinyPNGBytes, 0o644); err != nil {
			t.Fatalf("write artifact: %v", err)
		}
	}
	c.result = map[string]any{"chart": map[string]any{mediaartifactapp.MediaKey: "chart.png"}, "rows": float64(7)}

	res, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})
	if err != nil {
		t.Fatalf("call: %v", err)
	}
	m, _ := res.(map[string]any)
	chart, _ := m["chart"].(map[string]any)
	if chart["attachmentId"] != "att_00112233445566aa" {
		t.Fatalf("declaration was not replaced by a receipt: %+v", m)
	}
	if chart["source"] != string(mediaartifactapp.SourceHandler) {
		t.Fatalf("receipt source = %v, want the handler source (a reader must tell it from a function's)", chart["source"])
	}
	if chart["mime"] != "image/png" {
		t.Fatalf("mime = %v, want the SNIFFED image/png", chart["mime"])
	}
	if m["rows"] != float64(7) {
		t.Fatalf("sibling data mangled: %+v", m)
	}
	if len(up.got) != 1 {
		t.Fatalf("store received %v", up.got)
	}
	// The directory is the call's own and is gone once the call returns — "which files did THIS
	// call produce" must not be answerable by a later call rummaging in a shared place.
	// 目录属于**这次调用**,调用一返回就没了——「哪些文件是**这次调用**产出的」不能靠后来的调用去一个
	// 共享地方翻找来回答。
	if seenDir == "" {
		t.Fatal("no per-call directory was handed to the method")
	}
	if _, statErr := os.Stat(seenDir); !os.IsNotExist(statErr) {
		t.Fatalf("the per-call directory outlived the call: %v", statErr)
	}
}

// TestCall_EachCallGetsAFreshDirectory: a long-lived instance must not let call N see call N-1's
// files. This is the ONE property that distinguishes handler from function — function's run IS the
// unit, so it got this for free; handler has to be given it.
//
// TestCall_EachCallGetsAFreshDirectory:长跑实例不得让第 N 次调用看见第 N-1 次的文件。这是 handler
// 与 function **唯一**的区别所在——function 的一次运行**就是**那个单位,它白得这条;handler 必须被
// 主动给予。
func TestCall_EachCallGetsAFreshDirectory(t *testing.T) {
	svc, _, cl, ctx := newSvc(t)
	svc.SetArtifactUploader(&artifactUploader{})
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "twice", false)})
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("warm call: %v", err)
	}
	c := cl.clients[len(cl.clients)-1]

	var dirs []string
	var leaked bool
	c.write = func(dir string) {
		dirs = append(dirs, dir)
		entries, _ := os.ReadDir(dir)
		if len(entries) != 0 {
			leaked = true
		}
		_ = os.WriteFile(filepath.Join(dir, "left-behind.png"), tinyPNGBytes, 0o644)
	}
	c.result = map[string]any{"ok": true}
	for i := 0; i < 3; i++ {
		if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
			t.Fatalf("call %d: %v", i, err)
		}
	}
	if leaked {
		t.Fatal("a call saw a previous call's artifacts — the directory is not per-call")
	}
	if len(dirs) != 3 || dirs[0] == dirs[1] || dirs[1] == dirs[2] {
		t.Fatalf("directories were reused across calls: %v", dirs)
	}
}

// TestCall_WithoutUploaderIsUnchanged: an un-wired service creates no directory and passes media
// declarations through untouched. The capability is additive — it must never become a new way for
// an existing caller to fail.
//
// TestCall_WithoutUploaderIsUnchanged:未接线的服务**不建目录**、媒体声明原样通过。这是增量能力——
// 它绝不能变成既有调用方失败的一种新方式。
func TestCall_WithoutUploaderIsUnchanged(t *testing.T) {
	svc, _, cl, ctx := newSvc(t)
	h, _, _ := svc.Create(ctx, CreateInput{Ops: createOps(t, "plain", false)})
	if _, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}}); err != nil {
		t.Fatalf("warm call: %v", err)
	}
	c := cl.clients[len(cl.clients)-1]
	c.result = map[string]any{"chart": map[string]any{mediaartifactapp.MediaKey: "chart.png"}}

	res, err := svc.Call(ctx, CallInput{HandlerID: h.ID, Method: "ping", Args: map[string]any{}})
	if err != nil {
		t.Fatalf("call: %v", err)
	}
	if c.outDir != "" {
		t.Fatalf("a service with no uploader still created %q", c.outDir)
	}
	m, _ := res.(map[string]any)
	chart, _ := m["chart"].(map[string]any)
	if chart[mediaartifactapp.MediaKey] != "chart.png" {
		t.Fatalf("declaration was rewritten without an uploader: %+v", m)
	}
}

// TestDriverScript_IsValidPython compiles the driver the way Python will. It exists because the
// driver is a Go string constant: no compiler, no linter and no unit test in this package ever
// parses it — every test here talks to fakeClient instead. A stray indentation error would ship
// green and only surface when a real handler spawns, as an opaque "subprocess crashed".
//
// TestDriverScript_IsValidPython 用 Python 自己的方式编译 driver。它存在,是因为 driver 是一个 Go
// 字符串常量:本包里没有编译器、没有 linter、也没有任何单测**解析过它**——这里的测试全是对 fakeClient
// 说话。一个跑偏的缩进会一路绿着发出去,只在真 handler 起进程时以一句不透明的「子进程崩了」现形。
func TestDriverScript_IsValidPython(t *testing.T) {
	py, err := exec.LookPath("python3")
	if err != nil {
		t.Skip("python3 not on PATH")
	}
	path := filepath.Join(t.TempDir(), "driver.py")
	if err := os.WriteFile(path, []byte(DriverScript), 0o644); err != nil {
		t.Fatal(err)
	}
	if out, err := exec.Command(py, "-m", "py_compile", path).CombinedOutput(); err != nil {
		t.Fatalf("driver.py does not compile:\n%s", out)
	}
}

func TestNamesByOwnerIDs_ResolvesParentHandler(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	h, _, err := svc.Create(ctx, CreateInput{Ops: createOps(t, "reporter", false)})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	names, err := svc.NamesByOwnerIDs(ctx, []string{
		h.ID + "_hdenv_old",
		"hd_missing_hdenv_old",
		"not-a-handler-owner",
	})
	if err != nil {
		t.Fatalf("NamesByOwnerIDs: %v", err)
	}
	if names[h.ID+"_hdenv_old"] != "reporter" {
		t.Fatalf("resolved names = %#v, want parent handler name", names)
	}
	if _, ok := names["hd_missing_hdenv_old"]; ok {
		t.Fatalf("missing parent unexpectedly resolved: %#v", names)
	}
}
