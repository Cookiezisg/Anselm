package trigger

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/foryx/backend/internal/domain/trigger"
	triggerstore "github.com/sunweilin/foryx/backend/internal/infra/store/trigger"
	triggerinfra "github.com/sunweilin/foryx/backend/internal/infra/trigger"
	ormpkg "github.com/sunweilin/foryx/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

// fakeListener stands in for a real source listener so tests can observe the reference-counted
// register/unregister without touching cron/fsnotify/webhook machinery.
type fakeListener struct {
	registers   int
	unregisters int
	lastConfig  map[string]any
}

func (f *fakeListener) Register(_, _ string, config map[string]any) error {
	f.registers++
	f.lastConfig = config
	return nil
}
func (f *fakeListener) Unregister(string) { f.unregisters++ }
func (f *fakeListener) Start()            {}
func (f *fakeListener) Stop()             {}

type nopInvoker struct{}

func (nopInvoker) Invoke(context.Context, string, string, string) (map[string]any, error) {
	return nil, nil
}

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

func newTestService(t *testing.T) (*Service, *triggerstore.Store) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range triggerstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	st := triggerstore.New(ormpkg.Open(sqlDB))
	s := NewService(st, http.NewServeMux(), nopInvoker{}, zap.NewNop())
	return s, st
}

func mkCron(t *testing.T, s *Service, ctx context.Context, name string) *triggerdomain.Trigger {
	t.Helper()
	tr, err := s.Create(ctx, CreateInput{Name: name, Kind: triggerdomain.KindCron, Config: map[string]any{"expression": "* * * * *"}})
	if err != nil {
		t.Fatalf("create %s: %v", name, err)
	}
	return tr
}

func TestAttach_NWorkflowsShareOneListener(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "daily")

	if err := s.Attach(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("attach wf_1: %v", err)
	}
	if err := s.Attach(ctx, tr.ID, "wf_2"); err != nil {
		t.Fatalf("attach wf_2: %v", err)
	}
	// The whole point of independent triggers: two workflows referencing one trigger run ONE listener.
	if fake.registers != 1 {
		t.Fatalf("2 workflows should share 1 listener register, got %d", fake.registers)
	}
	s.Detach(tr.ID, "wf_1")
	if fake.unregisters != 0 {
		t.Fatalf("listener must stay up while wf_2 still listens")
	}
	s.Detach(tr.ID, "wf_2")
	if fake.unregisters != 1 {
		t.Fatalf("listener must stop when the last reference detaches, got %d", fake.unregisters)
	}
}

func TestOnReport_FiredFansOutToEveryWorkflow(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCron(t, s, ctx, "t")
	_ = s.Attach(ctx, tr.ID, "wf_1")
	_ = s.Attach(ctx, tr.ID, "wf_2")

	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, Payload: map[string]any{"x": float64(1)}, DedupKey: "k1"})

	firings, err := st.ListPendingFirings(ctx, 0)
	if err != nil || len(firings) != 2 {
		t.Fatalf("a fired trigger should write one Firing per listening workflow: n=%d err=%v", len(firings), err)
	}
	acts, _, _ := st.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: tr.ID})
	if len(acts) != 1 || !acts[0].Fired || acts[0].FiringCount != 2 {
		t.Fatalf("one activation with FiringCount=2 expected: %+v", acts)
	}
}

func TestOnReport_NotFired_RecordsActivationOnly(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCron(t, s, ctx, "t")
	_ = s.Attach(ctx, tr.ID, "wf_1")

	s.onReport(tr.ID, triggerinfra.Activity{Fired: false, ReturnValue: map[string]any{"count": float64(0)}, Detail: "condition evaluated false"})

	firings, _ := st.ListPendingFirings(ctx, 0)
	if len(firings) != 0 {
		t.Fatalf("a non-fired report must produce 0 firings, got %d", len(firings))
	}
	acts, _, _ := st.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: tr.ID})
	if len(acts) != 1 || acts[0].Fired || acts[0].ReturnValue["count"] != float64(0) {
		t.Fatalf("non-fired activation must be recorded with its return value: %+v", acts)
	}
}

func TestCreate_RejectsBadConfig(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	if _, err := s.Create(ctx, CreateInput{Name: "x", Kind: triggerdomain.KindCron, Config: map[string]any{}}); !errors.Is(err, triggerdomain.ErrInvalidCron) {
		t.Fatalf("empty cron expression should be ErrInvalidCron, got %v", err)
	}
	_, err := s.Create(ctx, CreateInput{Name: "y", Kind: triggerdomain.KindSensor, Config: map[string]any{
		"targetKind": "function", "targetId": "fn_1", "intervalSec": float64(10),
		"condition": "this is not ))) valid", "output": "payload",
	}})
	if !errors.Is(err, triggerdomain.ErrInvalidCEL) {
		t.Fatalf("invalid CEL condition should be ErrInvalidCEL, got %v", err)
	}
}

func TestEdit_RestartsListenerWhenHot(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "t")
	_ = s.Attach(ctx, tr.ID, "wf_1") // registers == 1

	newExpr := "0 9 * * *"
	if _, err := s.Edit(ctx, tr.ID, EditInput{Config: map[string]any{"expression": newExpr}}); err != nil {
		t.Fatalf("edit: %v", err)
	}
	if fake.registers != 2 {
		t.Fatalf("editing a hot trigger should re-register its listener, got %d", fake.registers)
	}
	if fake.lastConfig["expression"] != newExpr {
		t.Fatalf("re-register should carry the new config: %+v", fake.lastConfig)
	}
}

func TestDelete_StopsListenerAndRemovesTrigger(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "t")
	_ = s.Attach(ctx, tr.ID, "wf_1")

	if err := s.Delete(ctx, tr.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if fake.unregisters != 1 {
		t.Fatalf("delete should stop the listener, got %d", fake.unregisters)
	}
	if _, err := s.Get(ctx, tr.ID); !errors.Is(err, triggerdomain.ErrNotFound) {
		t.Fatalf("deleted trigger should be NotFound, got %v", err)
	}
}

func TestCatalogSource_ListsTriggers(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	mkCron(t, s, ctx, "alpha")
	mkCron(t, s, ctx, "beta")
	items, err := s.AsCatalogSource().ListItems(ctx)
	if err != nil || len(items) != 2 {
		t.Fatalf("catalog should list 2 triggers: n=%d err=%v", len(items), err)
	}
	if items[0].Source != "trigger" {
		t.Fatalf("catalog item source should be 'trigger', got %q", items[0].Source)
	}
}
