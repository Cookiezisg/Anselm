package scheduler

// provenance_test.go pins scheduler 工单① — run provenance + the run_started birth signal.
// Every creation chokepoint must stamp WHO started the run (manual/chat via StartInput;
// cron/webhook/fsnotify/sensor via the firing's trigger kind) and announce the birth as ONE
// DURABLE run_started signal ({flowrunId, origin}, workflow scope) so a reconnecting scheduler
// surface never misses a run born while it was away.
//
// provenance_test.go 钉 scheduler 工单①——run 溯源 + run_started 出生信号。每个创建咽喉都必须盖
// 「谁起的」章（manual/chat 走 StartInput；cron/webhook/fsnotify/sensor 走 firing 的 trigger kind），
// 并把出生发成**一条 durable** run_started 信号（{flowrunId, origin}、workflow scope），使重连的调度
// 面绝不漏掉断连期间出生的 run。

import (
	"strings"
	"testing"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// TestProvenance_StartRunStampsOriginAndEmitsRunStarted: the manual path stamps origin +
// conversation onto the header row and emits exactly one durable run_started before any terminal.
//
// TestProvenance_StartRunStampsOriginAndEmitsRunStarted：手动路径把 origin + conversation 盖到头行,
// 并在任何终态前恰发一条 durable run_started。
func TestProvenance_StartRunStampsOriginAndEmitsRunStarted(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("start", "trigger", "trg_1", nil),
			node("a", "action", "fn_a", map[string]string{"x": "start.v"}),
		},
		Edges: []workflowdomain.Edge{edge("e1", "start", "", "a")},
	}
	disp := newDisp()
	svc, store := mkSvc(t, g, disp, nil, nil, "")
	b := &sigBridge{}
	svc.SetEntitiesBridge(b)
	ctx := ctxWS("ws_1")

	id, err := svc.StartRun(ctx, StartInput{
		WorkflowID: "wf_1", Payload: map[string]any{"v": "hi"},
		Origin: flowrundomain.OriginChat, ConversationID: "cv_42",
	})
	if err != nil {
		t.Fatalf("StartRun: %v", err)
	}

	run, err := store.GetRun(ctx, id)
	if err != nil {
		t.Fatalf("GetRun: %v", err)
	}
	if run.Origin == nil || *run.Origin != flowrundomain.OriginChat {
		t.Fatalf("origin = %v, want chat", run.Origin)
	}
	if run.ConversationID == nil || *run.ConversationID != "cv_42" {
		t.Fatalf("conversationId = %v, want cv_42", run.ConversationID)
	}

	starts := b.signals(entitystreamapp.NodeRunStarted)
	if len(starts) != 1 {
		t.Fatalf("want exactly 1 run_started signal, got %d", len(starts))
	}
	if starts[0].Ephemeral {
		t.Fatal("run_started must be durable (survive reconnect)")
	}
	c := string(starts[0].Node.Content)
	if !strings.Contains(c, id) || !strings.Contains(c, `"origin":"chat"`) {
		t.Fatalf("run_started content = %s, want {flowrunId:%s, origin:chat}", c, id)
	}
}

// TestProvenance_UnstampedRunStaysNull: a StartInput without provenance (test/legacy path) leaves
// both columns NULL — the "unknown" the wire omits — and never invents a word.
//
// TestProvenance_UnstampedRunStaysNull：不带溯源的 StartInput（测试/旧径）两列留 NULL——线缆不发的
// unknown——绝不编造词。
func TestProvenance_UnstampedRunStaysNull(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{node("start", "trigger", "trg_1", nil)},
	}
	svc, store := mkSvc(t, g, newDisp(), nil, nil, "")
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{})

	run, err := store.GetRun(ctx, id)
	if err != nil {
		t.Fatalf("GetRun: %v", err)
	}
	if run.Origin != nil || run.ConversationID != nil {
		t.Fatalf("unstamped run must stay NULL, got origin=%v conversationId=%v", run.Origin, run.ConversationID)
	}
}

// TestProvenance_ClaimFiringStampsTriggerKind: the firing path resolves the trigger's kind and
// stamps it verbatim as origin (one vocabulary), and announces the birth durably at claim commit.
//
// TestProvenance_ClaimFiringStampsTriggerKind：firing 路径解析 trigger 的 kind、逐字盖成 origin
// （同一词表），并在 claim 提交时 durable 宣布出生。
func TestProvenance_ClaimFiringStampsTriggerKind(t *testing.T) {
	for _, kind := range []string{triggerdomain.KindCron, triggerdomain.KindWebhook, triggerdomain.KindFsnotify, triggerdomain.KindSensor} {
		t.Run(kind, func(t *testing.T) {
			disp := newDisp()
			svc, store, trg := mkSvcWithInbox(t, firingGraph(), disp, workflowdomain.ConcurrencyAllowAll)
			b := &sigBridge{}
			svc.SetEntitiesBridge(b)
			ctx := ctxWS("ws_1")

			if err := trg.SaveTrigger(ctx, &triggerdomain.Trigger{
				ID: "trg_1", WorkspaceID: "ws_1", Name: "src_" + kind, Kind: kind,
				Config: map[string]any{},
			}); err != nil {
				t.Fatalf("SaveTrigger: %v", err)
			}
			if _, err := trg.AppendFiring(ctx, &triggerdomain.Firing{
				WorkspaceID: "ws_1", TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: "k1",
				Payload: map[string]any{"orderId": "o-1"},
			}); err != nil {
				t.Fatalf("AppendFiring: %v", err)
			}
			if err := svc.DrainFirings(ctx); err != nil {
				t.Fatalf("DrainFirings: %v", err)
			}

			rows, _, _ := store.ListRuns(ctx, flowrundomain.ListFilter{Limit: 10})
			if len(rows) != 1 {
				t.Fatalf("want 1 run, got %d", len(rows))
			}
			if rows[0].Origin == nil || *rows[0].Origin != kind {
				t.Fatalf("origin = %v, want %q (the trigger kind)", rows[0].Origin, kind)
			}
			if rows[0].ConversationID != nil {
				t.Fatalf("a fired run must carry no conversation, got %v", rows[0].ConversationID)
			}

			starts := b.signals(entitystreamapp.NodeRunStarted)
			if len(starts) != 1 || starts[0].Ephemeral {
				t.Fatalf("want exactly 1 durable run_started, got %d (ephemeral=%v)", len(starts), len(starts) == 1 && starts[0].Ephemeral)
			}
			if !strings.Contains(string(starts[0].Node.Content), `"origin":"`+kind+`"`) {
				t.Fatalf("run_started content = %s, want origin %q", starts[0].Node.Content, kind)
			}
		})
	}
}

// TestProvenance_ClaimFiringMissingTriggerIsBestEffort: a firing whose trigger row is gone (deleted
// after firing) still runs — origin stays NULL, provenance never stalls the run.
//
// TestProvenance_ClaimFiringMissingTriggerIsBestEffort：trigger 行已不在（firing 后被删）的 firing
// 照样跑——origin 留 NULL,溯源绝不拖垮 run。
func TestProvenance_ClaimFiringMissingTriggerIsBestEffort(t *testing.T) {
	disp := newDisp()
	svc, store, trg := mkSvcWithInbox(t, firingGraph(), disp, workflowdomain.ConcurrencyAllowAll)
	ctx := ctxWS("ws_1")

	// No trigger row saved — TriggerKind will miss. 不存 trigger 行——TriggerKind 必失。
	if _, err := trg.AppendFiring(ctx, &triggerdomain.Firing{
		WorkspaceID: "ws_1", TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: "k1",
		Payload: map[string]any{"orderId": "o-1"},
	}); err != nil {
		t.Fatalf("AppendFiring: %v", err)
	}
	if err := svc.DrainFirings(ctx); err != nil {
		t.Fatalf("DrainFirings: %v", err)
	}

	rows, _, _ := store.ListRuns(ctx, flowrundomain.ListFilter{Limit: 10})
	if len(rows) != 1 || rows[0].Status != flowrundomain.StatusCompleted {
		t.Fatalf("run must still complete without provenance: %+v", rows)
	}
	if rows[0].Origin != nil {
		t.Fatalf("origin must stay NULL on lookup failure, got %q", *rows[0].Origin)
	}
}
