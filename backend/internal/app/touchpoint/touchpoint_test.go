package touchpoint

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"go.uber.org/zap"

	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
)

// --- fakes -----------------------------------------------------------------

type fakeRepo struct {
	upserts []touchpointdomain.Touch
	fail    bool
	lists   []struct{ conv, kind, verb string }
}

func (f *fakeRepo) Upsert(_ context.Context, t *touchpointdomain.Touch, id string) (*touchpointdomain.Touchpoint, error) {
	if f.fail {
		return nil, errors.New("boom")
	}
	f.upserts = append(f.upserts, *t)
	return &touchpointdomain.Touchpoint{
		ID: id, ConversationID: t.ConversationID, ItemKind: t.ItemKind, ItemID: t.ItemID,
		ItemName: t.ItemName, Verb: t.Verb, LastActor: t.Actor, Count: 1, FirstAt: t.At, LastAt: t.At,
	}, nil
}

func (f *fakeRepo) ListByConversation(_ context.Context, conv, kind, verb, _ string, _ int) ([]*touchpointdomain.Touchpoint, string, error) {
	f.lists = append(f.lists, struct{ conv, kind, verb string }{conv, kind, verb})
	return nil, "", nil
}

func (f *fakeRepo) PurgeConversation(context.Context, string) error { return nil }

type fakeBridge struct{ events []streamdomain.Event }

func (f *fakeBridge) Publish(_ context.Context, e streamdomain.Event) (streamdomain.Envelope, error) {
	f.events = append(f.events, e)
	return streamdomain.Envelope{}, nil
}

func (f *fakeBridge) Subscribe(context.Context, int64) (<-chan streamdomain.Envelope, func(), error) {
	return nil, func() {}, nil
}

type fakeNamer map[string]string

func (f fakeNamer) NamesByIDs(_ context.Context, ids []string) (map[string]string, error) {
	out := map[string]string{}
	for _, id := range ids {
		if n, ok := f[id]; ok {
			out[id] = n
		}
	}
	return out, nil
}

func newSvc(repo *fakeRepo, bridge streamdomain.Bridge, namers map[string]Namer) *Service {
	return NewService(Config{Repo: repo, Bridge: bridge, Namers: namers, Log: zap.NewNop()})
}

func validTouch() touchpointdomain.Touch {
	return touchpointdomain.Touch{
		ConversationID: "cv_1", ItemKind: "function", ItemID: "fn_1",
		Verb: touchpointdomain.VerbViewed, Actor: touchpointdomain.ActorAssistant,
	}
}

// --- Record ------------------------------------------------------------------

func TestRecord_PersistsHydratesAndSignals(t *testing.T) {
	repo := &fakeRepo{}
	bridge := &fakeBridge{}
	svc := newSvc(repo, bridge, map[string]Namer{"function": fakeNamer{"fn_1": "fetch-weather"}})

	svc.Record(context.Background(), validTouch())

	if len(repo.upserts) != 1 {
		t.Fatalf("upserts = %d", len(repo.upserts))
	}
	if repo.upserts[0].ItemName != "fetch-weather" {
		t.Errorf("name not hydrated: %+v", repo.upserts[0])
	}
	if repo.upserts[0].At.IsZero() {
		t.Error("At not defaulted")
	}
	if len(bridge.events) != 1 {
		t.Fatalf("signals = %d", len(bridge.events))
	}
	e := bridge.events[0]
	if e.Scope.Kind != streamdomain.KindConversation || e.Scope.ID != "cv_1" {
		t.Errorf("signal scope: %+v", e.Scope)
	}
	sig, ok := e.Frame.(streamdomain.Signal)
	if !ok || sig.Node.Type != "touchpoint" || sig.Ephemeral {
		t.Fatalf("frame must be a durable touchpoint Signal: %+v", e.Frame)
	}
	var row touchpointdomain.Touchpoint
	if err := json.Unmarshal(sig.Node.Content, &row); err != nil || row.ItemID != "fn_1" || row.ItemName != "fetch-weather" {
		t.Errorf("signal payload: %s err=%v", sig.Node.Content, err)
	}
}

func TestRecord_GivenNameSkipsHydration(t *testing.T) {
	repo := &fakeRepo{}
	svc := newSvc(repo, nil, map[string]Namer{"function": fakeNamer{"fn_1": "hydrated"}})
	tc := validTouch()
	tc.ItemName = "given"
	svc.Record(context.Background(), tc)
	if repo.upserts[0].ItemName != "given" {
		t.Errorf("given name must win: %+v", repo.upserts[0])
	}
}

func TestRecord_BestEffort(t *testing.T) {
	// Invalid touch drops without panic; repo failure drops without panic; nil bridge is fine.
	// 非法 touch 静默丢;repo 失败静默丢;nil bridge 正常。
	repo := &fakeRepo{}
	svc := newSvc(repo, nil, nil)
	bad := validTouch()
	bad.Verb = "poked"
	svc.Record(context.Background(), bad)
	if len(repo.upserts) != 0 {
		t.Error("invalid touch must not persist")
	}

	svc = newSvc(&fakeRepo{fail: true}, nil, nil)
	svc.Record(context.Background(), validTouch()) // must not panic 不炸即过
}

func TestRecord_HydrationMissThenSnapshotStaysEmpty(t *testing.T) {
	repo := &fakeRepo{}
	svc := newSvc(repo, nil, map[string]Namer{}) // no namer for kind 无该类 namer
	svc.Record(context.Background(), validTouch())
	if repo.upserts[0].ItemName != "" {
		t.Errorf("miss must leave name empty: %+v", repo.upserts[0])
	}
}

// --- ResolveName ---------------------------------------------------------------

func TestResolveName(t *testing.T) {
	svc := newSvc(&fakeRepo{}, nil, map[string]Namer{
		"function": fakeNamer{"fn_1": "sync_inventory"},
		"agent":    fakeNamer{"ag_1": "report_writer"},
	})
	ctx := context.Background()

	// An exec tool resolves its ARGS id → the entity name PRE-execution (output not needed). exec 工具执行前解析。
	if got := svc.ResolveName(ctx, "run_function", map[string]any{"functionId": "fn_1"}); got != "sync_inventory" {
		t.Errorf("run_function name = %q, want sync_inventory", got)
	}
	if got := svc.ResolveName(ctx, "invoke_agent", map[string]any{"agentId": "ag_1"}); got != "report_writer" {
		t.Errorf("invoke_agent name = %q, want report_writer", got)
	}
	// A nameIsID kind (create_skill) carries its name in the arg itself — no namer needed. 名即 id 的 kind 直取。
	if got := svc.ResolveName(ctx, "create_skill", map[string]any{"name": "deploy"}); got != "deploy" {
		t.Errorf("create_skill name = %q, want deploy", got)
	}
	// Falls back to "" (caller keeps the id) for: unknown tool / absent arg / id-miss / no namer for kind.
	// 回退 ""(调用方留 id):未知工具 / 缺参 / id 查不到 / 该类无 namer。
	for _, c := range []struct {
		name, tool string
		args       map[string]any
	}{
		{"unknown tool", "no_such_tool", map[string]any{"x": "y"}},
		{"absent arg", "run_function", map[string]any{}},
		{"id not in namer", "run_function", map[string]any{"functionId": "fn_missing"}},
		{"no namer for kind", "trigger_workflow", map[string]any{"workflowId": "wf_1"}},
	} {
		if got := svc.ResolveName(ctx, c.tool, c.args); got != "" {
			t.Errorf("%s: name = %q, want empty", c.name, got)
		}
	}
}

// --- List --------------------------------------------------------------------

func TestList_FilterValidation(t *testing.T) {
	repo := &fakeRepo{}
	svc := newSvc(repo, nil, nil)
	if _, _, err := svc.List(context.Background(), "cv_1", "gizmo", "", "", 10); !errors.Is(err, touchpointdomain.ErrInvalidKind) {
		t.Errorf("bad kind: %v", err)
	}
	if _, _, err := svc.List(context.Background(), "cv_1", "", "poked", "", 10); !errors.Is(err, touchpointdomain.ErrInvalidVerb) {
		t.Errorf("bad verb: %v", err)
	}
	if _, _, err := svc.List(context.Background(), "cv_1", "function", touchpointdomain.VerbViewed, "", 10); err != nil {
		t.Errorf("valid filters: %v", err)
	}
	if len(repo.lists) != 1 {
		t.Fatalf("repo hit count: %d", len(repo.lists))
	}
}

// --- ctx carrier ---------------------------------------------------------------

func TestCtxCarrier(t *testing.T) {
	if _, ok := From(context.Background()); ok {
		t.Error("empty ctx must have no recorder")
	}
	svc := newSvc(&fakeRepo{}, nil, nil)
	ctx := With(context.Background(), svc)
	got, ok := From(ctx)
	if !ok || got != svc {
		t.Error("carrier round-trip failed")
	}
}

// keep time import used in helpers even if cases change 保 time 引用
var _ = time.Now
