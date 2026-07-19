package flowrun

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

// mkRun seeds a run + its trigger node (payload = trigger result).
func mkRun(t *testing.T, s *Store, ctx context.Context, runID, wfID string, payload map[string]any) string {
	t.Helper()
	run := &flowrundomain.FlowRun{
		ID:         runID,
		WorkflowID: wfID,
		VersionID:  "wfv_1",
		PinnedRefs: map[string]string{"fn_1": "fnv_1", "ag_2": "agv_3"},
		TriggerID:  "trg_1",
	}
	trig := &flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger", Ref: "trg_1", Result: payload}
	id, err := s.CreateRunWithTrigger(ctx, run, trig)
	if err != nil {
		t.Fatalf("CreateRunWithTrigger %s: %v", runID, err)
	}
	return id
}

func completedNode(flowrunID, nodeID, kind string, iter int, result map[string]any) *flowrundomain.FlowRunNode {
	return &flowrundomain.FlowRunNode{
		FlowRunID: flowrunID, NodeID: nodeID, Iteration: iter, Kind: kind,
		Status: flowrundomain.NodeCompleted, Result: result,
	}
}

func TestRun_RoundTrip_SeedAndPins(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	id := mkRun(t, s, ctx, "fr_1", "wf_1", map[string]any{"orderId": "o-7"})

	run, err := s.GetRun(ctx, id)
	if err != nil {
		t.Fatalf("GetRun: %v", err)
	}
	if run.WorkspaceID != "ws_1" || run.Status != flowrundomain.StatusRunning || run.VersionID != "wfv_1" {
		t.Fatalf("run header lost: %+v", run)
	}
	if run.PinnedRefs["fn_1"] != "fnv_1" || run.PinnedRefs["ag_2"] != "agv_3" {
		t.Fatalf("pinned_refs json round-trip lost: %+v", run.PinnedRefs)
	}
	nodes, err := s.GetNodes(ctx, id)
	if err != nil {
		t.Fatalf("GetNodes: %v", err)
	}
	if len(nodes) != 1 || nodes[0].NodeID != "start" || nodes[0].Kind != "trigger" {
		t.Fatalf("trigger seed missing: %+v", nodes)
	}
	if nodes[0].Result["orderId"] != "o-7" {
		t.Fatalf("trigger payload result lost: %+v", nodes[0].Result)
	}
}

// TestListNodes_PagesAllRows — F168-M7: the REST run-detail node list is keyset-paged (N4), so a long
// loop run's thousands of rows page instead of dumping in one response. Every row appears exactly once
// across the pages and pagination terminates (next == "").
func TestListNodes_PagesAllRows(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	id := mkRun(t, s, ctx, "fr_1", "wf_1", map[string]any{}) // seeds 1 trigger node "start"

	// 5 more node rows (distinct iterations → record-once keeps them all); total = 6.
	for i := 0; i < 5; i++ {
		if ins, err := s.InsertNodeResult(ctx, completedNode(id, "draft", "action", i, map[string]any{"i": i})); err != nil || !ins {
			t.Fatalf("insert iter %d: ins=%v err=%v", i, ins, err)
		}
	}

	seen := map[string]bool{}
	cursor, pages := "", 0
	for {
		nodes, next, err := s.ListNodes(ctx, id, cursor, 2)
		if err != nil {
			t.Fatalf("ListNodes page %d: %v", pages, err)
		}
		pages++
		if len(nodes) > 2 {
			t.Fatalf("page %d returned %d rows, over the limit of 2", pages, len(nodes))
		}
		for _, n := range nodes {
			if seen[n.ID] {
				t.Fatalf("node %q returned on more than one page", n.ID)
			}
			seen[n.ID] = true
		}
		if next == "" {
			break
		}
		cursor = next
		if pages > 10 {
			t.Fatal("pagination did not terminate")
		}
	}
	if len(seen) != 6 {
		t.Fatalf("paged set = %d nodes, want 6 (1 trigger + 5 iterations)", len(seen))
	}
}

// TestGetRunsByIDs — the inbox's bounded join (scheduler 工单④): ONE WhereIn query, missing ids
// absent (never an error), request order preserved, workspace isolation intact, empty ids → nil.
func TestGetRunsByIDs(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkRun(t, s, ctx, "fr_1", "wf_a", map[string]any{})
	mkRun(t, s, ctx, "fr_2", "wf_b", map[string]any{})
	mkRun(t, s, ctxWS("ws_other"), "fr_alien", "wf_x", map[string]any{})

	t.Run("empty ids → nil, no query error", func(t *testing.T) {
		rows, err := s.GetRunsByIDs(ctx, nil)
		if err != nil || rows != nil {
			t.Fatalf("rows=%v err=%v", rows, err)
		}
	})
	t.Run("batch hit + miss absent + request order", func(t *testing.T) {
		rows, err := s.GetRunsByIDs(ctx, []string{"fr_2", "fr_ghost", "fr_1"})
		if err != nil {
			t.Fatalf("GetRunsByIDs: %v", err)
		}
		if len(rows) != 2 || rows[0].ID != "fr_2" || rows[1].ID != "fr_1" {
			t.Fatalf("want [fr_2 fr_1] (miss absent, request order), got %+v", rows)
		}
		if rows[0].WorkflowID != "wf_b" || rows[1].WorkflowID != "wf_a" {
			t.Fatalf("workflow ids lost: %+v", rows)
		}
	})
	t.Run("workspace isolation", func(t *testing.T) {
		rows, err := s.GetRunsByIDs(ctx, []string{"fr_alien"})
		if err != nil || len(rows) != 0 {
			t.Fatalf("another workspace's run must be absent: rows=%+v err=%v", rows, err)
		}
	})
}

// record-once boundary: a duplicate (flowrun_id, node_id, iteration) is silently ignored,
// first writer wins — never two rows, never an error.
func TestInsertNodeResult_RecordOnce_FirstWins(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	id := mkRun(t, s, ctx, "fr_1", "wf_1", map[string]any{})

	ins, err := s.InsertNodeResult(ctx, completedNode(id, "draft", "action", 0, map[string]any{"text": "v1"}))
	if err != nil || !ins {
		t.Fatalf("first insert: ins=%v err=%v", ins, err)
	}
	// same (run,node,iteration), different result — must be ignored, first wins.
	ins2, err := s.InsertNodeResult(ctx, completedNode(id, "draft", "action", 0, map[string]any{"text": "v2-loser"}))
	if err != nil {
		t.Fatalf("second insert err: %v", err)
	}
	if ins2 {
		t.Fatalf("record-once violated: second insert reported inserted")
	}
	nodes, _ := s.GetNodes(ctx, id)
	var draftRows int
	for _, n := range nodes {
		if n.NodeID == "draft" {
			draftRows++
			if n.Result["text"] != "v1" {
				t.Fatalf("first-wins violated: draft text = %v", n.Result["text"])
			}
		}
	}
	if draftRows != 1 {
		t.Fatalf("record-once violated: %d draft rows", draftRows)
	}
	// a different iteration is a distinct row (loop turn).
	ins3, err := s.InsertNodeResult(ctx, completedNode(id, "draft", "action", 1, map[string]any{"text": "turn-2"}))
	if err != nil || !ins3 {
		t.Fatalf("iteration 1 insert: ins=%v err=%v", ins3, err)
	}
}

// approval first-wins: human decision vs timeout race the same parked row; the conditional
// update on status='parked' lets exactly one win, the loser is a no-op (not an error).
func TestResolveParkedNode_ApprovalFirstWins(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	id := mkRun(t, s, ctx, "fr_1", "wf_1", map[string]any{})

	// park an approval node.
	park := &flowrundomain.FlowRunNode{
		FlowRunID: id, NodeID: "human", Iteration: 0, Kind: "approval",
		Status: flowrundomain.NodeParked, Result: map[string]any{"rendered": "approve $100?", "allowReason": true},
	}
	if _, err := s.InsertNodeResult(ctx, park); err != nil {
		t.Fatalf("park: %v", err)
	}

	// inbox sees it.
	parked, err := s.ListParkedNodes(ctx)
	if err != nil || len(parked) != 1 || parked[0].NodeID != "human" {
		t.Fatalf("inbox: %+v err=%v", parked, err)
	}
	got, err := s.GetParkedNode(ctx, id, "human")
	if err != nil || got.Status != flowrundomain.NodeParked {
		t.Fatalf("GetParkedNode: %+v err=%v", got, err)
	}

	// human approves — wins.
	won, err := s.ResolveParkedNode(ctx, id, "human", flowrundomain.NodeCompleted, flowrundomain.ApprovalDecision("yes", "ok"))
	if err != nil || !won {
		t.Fatalf("first resolve: won=%v err=%v", won, err)
	}
	// timeout reject — loses (already not parked).
	won2, err := s.ResolveParkedNode(ctx, id, "human", flowrundomain.NodeCompleted, flowrundomain.ApprovalDecision("no", "timeout"))
	if err != nil {
		t.Fatalf("second resolve err: %v", err)
	}
	if won2 {
		t.Fatalf("approval first-wins violated: second resolve won")
	}
	// the row reflects the FIRST decision.
	nodes, _ := s.GetNodes(ctx, id)
	for _, n := range nodes {
		if n.NodeID == "human" {
			if n.Result["decision"] != "yes" || n.Status != flowrundomain.NodeCompleted {
				t.Fatalf("first-wins decision lost: %+v", n)
			}
			if n.CompletedAt == nil {
				t.Fatalf("completed_at not set on decision")
			}
		}
	}
	// no longer parked → GetParkedNode 404, inbox empty.
	if _, err := s.GetParkedNode(ctx, id, "human"); !errors.Is(err, flowrundomain.ErrNodeNotParked) {
		t.Fatalf("expected ErrNodeNotParked, got %v", err)
	}
	if p, _ := s.ListParkedNodes(ctx); len(p) != 0 {
		t.Fatalf("inbox should be empty after decision: %+v", p)
	}
}

// :replay clears failed rows (keeps completed) + flips the run failed→running + bumps replay_count.
func TestReplay_ClearFailed_ReopenRun(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	id := mkRun(t, s, ctx, "fr_1", "wf_1", map[string]any{})
	if _, err := s.InsertNodeResult(ctx, completedNode(id, "draft", "action", 0, map[string]any{"text": "ok"})); err != nil {
		t.Fatalf("draft: %v", err)
	}
	failed := completedNode(id, "publish", "action", 0, map[string]any{})
	failed.Status = flowrundomain.NodeFailed
	failed.Error = "boom"
	if _, err := s.InsertNodeResult(ctx, failed); err != nil {
		t.Fatalf("failed node: %v", err)
	}
	if won, err := s.MarkRunTerminal(ctx, id, flowrundomain.StatusFailed, "publish failed"); err != nil || !won {
		t.Fatalf("MarkRunTerminal won=%v err=%v", won, err)
	}
	// first-wins: the guard (WHERE running) rejects a second terminal — the recorded one stands.
	// first-wins：守卫（WHERE running）拒绝第二个终态——已记录者为准。
	if won, err := s.MarkRunTerminal(ctx, id, flowrundomain.StatusCancelled, "late cancel"); err != nil || won {
		t.Fatalf("second MarkRunTerminal must lose the guard: won=%v err=%v", won, err)
	}
	if run, _ := s.GetRun(ctx, id); run.Status != flowrundomain.StatusFailed || run.Error != "publish failed" {
		t.Fatalf("terminal clobbered by the guard loser: %+v", run)
	}

	// replay: clear failed rows, reopen.
	removed, err := s.DeleteFailedNodes(ctx, id)
	if err != nil || removed != 1 {
		t.Fatalf("DeleteFailedNodes removed=%d err=%v", removed, err)
	}
	if err := s.ReopenForReplay(ctx, id); err != nil {
		t.Fatalf("ReopenForReplay: %v", err)
	}
	run, _ := s.GetRun(ctx, id)
	if run.Status != flowrundomain.StatusRunning || run.ReplayCount != 1 || run.Error != "" {
		t.Fatalf("reopen state: %+v", run)
	}
	// completed draft survives; failed publish gone.
	nodes, _ := s.GetNodes(ctx, id)
	var haveDraft, havePublish bool
	for _, n := range nodes {
		switch n.NodeID {
		case "draft":
			haveDraft = true
		case "publish":
			havePublish = true
		}
	}
	if !haveDraft || havePublish {
		t.Fatalf("replay kept wrong rows: draft=%v publish=%v", haveDraft, havePublish)
	}

	// replay on a non-failed run is rejected.
	if err := s.ReopenForReplay(ctx, id); !errors.Is(err, flowrundomain.ErrNotReplayable) {
		t.Fatalf("expected ErrNotReplayable on running run, got %v", err)
	}
}

// TestReopenForReplay_GuardsTheReversal — :replay's header write is the ONLY one that reverses a
// terminal, and it carries the same first-wins guard as MarkRunTerminal. Without it, a second
// :replay that read `failed` before the first one finished would land its UPDATE on whatever
// terminal the run had since reached — resurrecting it to running, wiping the completed_at/error it
// just earned, and writing a replay_count from a stale read.
//
// TestReopenForReplay_GuardsTheReversal——:replay 的头写是**唯一**逆转终态的写，它带着与 MarkRunTerminal
// 同款的 first-wins 守卫。没有它，一个在前者完成前就读到 `failed` 的第二次 :replay 会把 UPDATE 落在该 run
// 此后已走到的任何终态上——把它复活成 running、抹掉它刚挣到的 completed_at/error、并写入一个据陈旧读算出
// 的 replay_count。
func TestReopenForReplay_GuardsTheReversal(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	id := "fr_race"
	mkRun(t, s, ctx, id, "wf_1", map[string]any{})
	if won, err := s.MarkRunTerminal(ctx, id, flowrundomain.StatusFailed, "boom"); err != nil || !won {
		t.Fatalf("seed failed terminal: won=%v err=%v", won, err)
	}

	// Winner reopens.
	if err := s.ReopenForReplay(ctx, id); err != nil {
		t.Fatalf("first ReopenForReplay: %v", err)
	}
	// The winner's run reaches a NEW terminal (as its drive would).
	if won, err := s.MarkRunTerminal(ctx, id, flowrundomain.StatusCompleted, ""); err != nil || !won {
		t.Fatalf("winner's new terminal: won=%v err=%v", won, err)
	}

	// The loser — holding the stale `failed` read that passed its own status check — must not land.
	// 输家——手里攥着那个通过了自身状态判断的陈旧 `failed` 读——绝不能落地。
	if err := s.ReopenForReplay(ctx, id); !errors.Is(err, flowrundomain.ErrNotReplayable) {
		t.Fatalf("the racing replay must lose the guard, got %v", err)
	}
	run, _ := s.GetRun(ctx, id)
	if run.Status != flowrundomain.StatusCompleted {
		t.Fatalf("a completed run was resurrected to %s by the guard loser", run.Status)
	}
	if run.CompletedAt == nil {
		t.Fatal("the loser wiped the completed_at the run had just earned")
	}
	if run.ReplayCount != 1 {
		t.Fatalf("replayCount = %d, want 1 — the loser must not bump it", run.ReplayCount)
	}
}

// workspace isolation: a run is invisible cross-workspace; but ListRunningRuns (boot) crosses.
func TestWorkspaceIsolation_AndCrossWsBoot(t *testing.T) {
	s := newStore(t)
	mkRun(t, s, ctxWS("ws_1"), "fr_a", "wf_1", map[string]any{})
	mkRun(t, s, ctxWS("ws_2"), "fr_b", "wf_2", map[string]any{})

	// ws_1 cannot see ws_2's run.
	if _, err := s.GetRun(ctxWS("ws_1"), "fr_b"); !errors.Is(err, flowrundomain.ErrNotFound) {
		t.Fatalf("isolation breach: ws_1 saw fr_b (%v)", err)
	}
	// list is per-workspace.
	rows, _, err := s.ListRuns(ctxWS("ws_1"), flowrundomain.ListFilter{Limit: 10})
	if err != nil || len(rows) != 1 || rows[0].ID != "fr_a" {
		t.Fatalf("ListRuns ws_1: %+v err=%v", rows, err)
	}
	// boot recovery crosses workspaces (no request ctx).
	running, err := s.ListRunningRuns(context.Background())
	if err != nil {
		t.Fatalf("ListRunningRuns: %v", err)
	}
	if len(running) != 2 {
		t.Fatalf("boot recovery should cross workspaces, got %d runs", len(running))
	}
}

// TestCancelParkedNodes — when a run is cancelled (:cancel/kill/replace) while parked on an
// approval, its parked node is resolved so it leaves the inbox, recording the row's REAL
// disposition (cancelled — never `failed`, which would invent a failure the run never had and
// contradict its own cancelled header). Scoped to the run; other runs' parked approvals are
// untouched.
func TestCancelParkedNodes(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	park := func(fr string) {
		t.Helper()
		if _, err := s.InsertNodeResult(ctx, &flowrundomain.FlowRunNode{
			FlowRunID: fr, NodeID: "gate", Iteration: 0, Kind: "approval",
			Status: flowrundomain.NodeParked, Result: map[string]any{},
		}); err != nil {
			t.Fatalf("seed parked %s: %v", fr, err)
		}
	}
	park("fr_1")
	park("fr_2")

	n, err := s.CancelParkedNodes(ctx, "fr_1")
	if err != nil {
		t.Fatalf("cancel: %v", err)
	}
	if n != 1 {
		t.Fatalf("should resolve 1 parked node for fr_1, got %d", n)
	}
	// fr_1's parked approval is gone from the inbox; fr_2's remains decidable.
	parked, _ := s.ListParkedNodes(ctx)
	if len(parked) != 1 || parked[0].FlowRunID != "fr_2" {
		t.Fatalf("only fr_2's parked node should remain in the inbox, got %+v", parked)
	}
	// The swept row records cancelled — its own truth — and lands a completed_at: it is terminal now,
	// and a NULL there reads as "still open". `failed` here would be a fabricated failure.
	// 被收的行记 cancelled——它自己的真相——并落 completed_at：它现在是终态，NULL 会被读成「还开着」。
	// 在这里记 `failed` 是**捏造**一次失败。
	swept, _ := s.GetNodes(ctx, "fr_1")
	if len(swept) != 1 || swept[0].Status != flowrundomain.NodeCancelled {
		t.Fatalf("swept row must record cancelled, got %+v", swept)
	}
	if swept[0].CompletedAt == nil {
		t.Fatal("swept row must carry completed_at — it is terminal, not still parked")
	}
}

// TestCancelParkedNodes_CancelledRowIsWritable pins the schema half of the same law: 'cancelled' is
// in flowrun_nodes' CHECK, so the sweep is a real write and not a constraint violation swallowed as
// a logged warning (which would silently leave the dead approval in the inbox forever).
func TestCancelParkedNodes_CancelledRowIsWritable(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	if _, err := s.InsertNodeResult(ctx, &flowrundomain.FlowRunNode{
		FlowRunID: "fr_direct", NodeID: "gate", Iteration: 0, Kind: "approval",
		Status: flowrundomain.NodeCancelled, Result: map[string]any{},
	}); err != nil {
		t.Fatalf("a cancelled node row must be insertable (CHECK must carry the word): %v", err)
	}
}

// TestListRuns_RejectsInvalidStatus pins F168-M2: an out-of-enum status filter (e.g. "parked", which
// is a NODE status, not a run status) is rejected 422 ErrInvalidStatus instead of silently matching
// zero rows — which an agent/REST caller would read as a false "no such runs exist".
func TestListRuns_RejectsInvalidStatus(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	if _, _, err := s.ListRuns(ctx, flowrundomain.ListFilter{Status: "parked"}); !errors.Is(err, flowrundomain.ErrInvalidStatus) {
		t.Fatalf("invalid status must return ErrInvalidStatus, got %v", err)
	}
	if _, _, err := s.ListRuns(ctx, flowrundomain.ListFilter{Status: flowrundomain.StatusCompleted}); err != nil {
		t.Fatalf("valid status must succeed (even with zero rows), got %v", err)
	}
	if _, _, err := s.ListRuns(ctx, flowrundomain.ListFilter{}); err != nil {
		t.Fatalf("empty filter must succeed, got %v", err)
	}
}

// TestProvenanceColumns_UpgradeAndRoundTrip pins scheduler 工单① at the store: ① an EXISTING
// install (flowruns created before the origin/conversation_id columns) gains them via the Schema's
// ADD COLUMN stanzas and its old rows read back as NULL (nil pointers — the wire's "unknown");
// ② a stamped run round-trips both values; ③ the CHECK rejects an out-of-vocabulary origin.
//
// TestProvenanceColumns_UpgradeAndRoundTrip 在 store 层钉工单①：① 既有安装（两列诞生前建的
// flowruns）经 Schema 的 ADD COLUMN 段补列、旧行读回 NULL（nil 指针——线缆的 unknown）；② 盖章的
// run 两值往返；③ CHECK 拒词表外 origin。
func TestProvenanceColumns_UpgradeAndRoundTrip(t *testing.T) {
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })

	// Phase 1: the pre-provenance table only (every stanza except the ALTERs), with one legacy row.
	// 第一阶段：仅溯源前的表（除 ALTER 外的所有段），插一行旧数据。
	for _, stmt := range Schema {
		if strings.HasPrefix(stmt, "ALTER") {
			continue
		}
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("legacy schema: %v", err)
		}
	}
	if _, err := sqlDB.Exec(`INSERT INTO flowruns (id, workspace_id, workflow_id, version_id, status, started_at, updated_at)
		VALUES ('fr_old', 'ws_1', 'wf_1', 'wfv_1', 'completed', '2026-01-01 00:00:00', '2026-01-01 00:00:00')`); err != nil {
		t.Fatalf("legacy row: %v", err)
	}

	// Phase 2: the upgrade — run the ALTER stanzas (what a boot's Migrate applies on an old DB).
	// 第二阶段：升级——跑 ALTER 段（旧库上 boot 的 Migrate 所应用者）。
	for _, stmt := range Schema {
		if !strings.HasPrefix(stmt, "ALTER") {
			continue
		}
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("upgrade: %v", err)
		}
	}

	s := New(ormpkg.Open(sqlDB))
	ctx := ctxWS("ws_1")

	// ① The legacy row scans (NULL → nil), and lists alongside new rows. 旧行可读、可列。
	old, err := s.GetRun(ctx, "fr_old")
	if err != nil {
		t.Fatalf("GetRun legacy: %v", err)
	}
	if old.Origin != nil || old.ConversationID != nil {
		t.Fatalf("legacy row must read NULL provenance, got origin=%v conv=%v", old.Origin, old.ConversationID)
	}

	// ② A stamped run round-trips. 盖章 run 往返。
	origin, conv := flowrundomain.OriginChat, "cv_7"
	if _, err := s.CreateRunWithTrigger(ctx,
		&flowrundomain.FlowRun{ID: "fr_new", WorkflowID: "wf_1", VersionID: "wfv_1", Origin: &origin, ConversationID: &conv},
		&flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger"}); err != nil {
		t.Fatalf("create stamped run: %v", err)
	}
	got, err := s.GetRun(ctx, "fr_new")
	if err != nil {
		t.Fatalf("GetRun stamped: %v", err)
	}
	if got.Origin == nil || *got.Origin != flowrundomain.OriginChat || got.ConversationID == nil || *got.ConversationID != "cv_7" {
		t.Fatalf("stamped provenance lost: origin=%v conv=%v", got.Origin, got.ConversationID)
	}
	if rows, _, err := s.ListRuns(ctx, flowrundomain.ListFilter{Limit: 10}); err != nil || len(rows) != 2 {
		t.Fatalf("mixed legacy+stamped list: rows=%d err=%v", len(rows), err)
	}

	// ③ The CHECK holds: an out-of-vocabulary origin never lands. CHECK 生效：词表外 origin 落不了。
	if _, err := sqlDB.Exec(`INSERT INTO flowruns (id, workspace_id, workflow_id, version_id, status, origin, started_at, updated_at)
		VALUES ('fr_bad', 'ws_1', 'wf_1', 'wfv_1', 'running', 'gremlin', '2026-01-01 00:00:00', '2026-01-01 00:00:00')`); err == nil {
		t.Fatal("CHECK must reject an out-of-vocabulary origin")
	}
}

// --- 工单⑥ list filters ------------------------------------------------------

// mkRunAt seeds a run with provenance coordinates + a pinned started_at (Create stamps
// started_at=now unconditionally, so the window coordinate is pinned by direct UPDATE — the
// same driver serialization ListRuns' window predicates bind with).
//
// mkRunAt 种一个带溯源坐标 + 钉死 started_at 的 run（Create 无条件盖 started_at=now，故窗口坐标
// 用直接 UPDATE 钉——与 ListRuns 窗口谓词绑定值走同一 driver 序列化）。
func mkRunAt(t *testing.T, s *Store, ctx context.Context, runID, wfID, trgID, origin string, startedAt time.Time) {
	t.Helper()
	run := &flowrundomain.FlowRun{ID: runID, WorkflowID: wfID, VersionID: "wfv_1", TriggerID: trgID}
	if origin != "" {
		run.Origin = &origin
	}
	trig := &flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger", Ref: trgID}
	if _, err := s.CreateRunWithTrigger(ctx, run, trig); err != nil {
		t.Fatalf("seed %s: %v", runID, err)
	}
	if _, err := s.db.Exec(context.Background(), `UPDATE flowruns SET started_at = ? WHERE id = ?`, startedAt, runID); err != nil {
		t.Fatalf("pin started_at %s: %v", runID, err)
	}
}

// listIDs runs ListRuns and returns the matched ids (newest-first order preserved).
//
// listIDs 跑 ListRuns 并返回命中 id（保持最新在前序）。
func listIDs(t *testing.T, s *Store, ctx context.Context, f flowrundomain.ListFilter) []string {
	t.Helper()
	if f.Limit == 0 {
		f.Limit = 50
	}
	rows, _, err := s.ListRuns(ctx, f)
	if err != nil {
		t.Fatalf("ListRuns %+v: %v", f, err)
	}
	ids := make([]string, 0, len(rows))
	for _, r := range rows {
		ids = append(ids, r.ID)
	}
	return ids
}

// TestListRuns_Filters — 工单⑥: triggerId / origin equality, the half-open started_at window
// [after, before), AND-composition with workflowId/status, NULL-origin rows never matching an
// origin filter, and the loud 422 on an out-of-enum origin (F168-M2 stance).
//
// TestListRuns_Filters — 工单⑥：triggerId / origin 等值、started_at 半开窗 [after, before)、与
// workflowId/status 的 AND 组合、NULL origin 旧行不匹配任何 origin 过滤、枚举外 origin 的 422 大声拒。
func TestListRuns_Filters(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	t1 := time.Date(2026, 7, 1, 8, 0, 0, 0, time.UTC)
	t2 := time.Date(2026, 7, 5, 8, 0, 0, 0, time.UTC)
	t3 := time.Date(2026, 7, 10, 8, 0, 0, 0, time.UTC)
	t4 := time.Date(2026, 7, 12, 8, 0, 0, 0, time.UTC)

	mkRunAt(t, s, ctx, "fr_a", "wf_1", "trg_1", flowrundomain.OriginCron, t1)
	mkRunAt(t, s, ctx, "fr_b", "wf_1", "trg_2", flowrundomain.OriginWebhook, t2)
	mkRunAt(t, s, ctx, "fr_c", "wf_2", "", flowrundomain.OriginManual, t3)
	mkRunAt(t, s, ctx, "fr_d", "wf_2", "", "", t4) // pre-provenance row (NULL origin). 溯源前旧行。
	if won, err := s.MarkRunTerminal(ctx, "fr_c", flowrundomain.StatusCompleted, ""); err != nil || !won {
		t.Fatalf("terminal fr_c: won=%v err=%v", won, err)
	}

	eq := func(what string, got, want []string) {
		t.Helper()
		if len(got) != len(want) {
			t.Fatalf("%s: got %v, want %v", what, got, want)
		}
		for i := range want {
			if got[i] != want[i] {
				t.Fatalf("%s: got %v, want %v", what, got, want)
			}
		}
	}

	// Equality filters. 等值过滤。
	eq("triggerId=trg_1", listIDs(t, s, ctx, flowrundomain.ListFilter{TriggerID: "trg_1"}), []string{"fr_a"})
	eq("origin=webhook", listIDs(t, s, ctx, flowrundomain.ListFilter{Origin: flowrundomain.OriginWebhook}), []string{"fr_b"})
	// A NULL-origin row matches NO origin filter (it is unknown, not manual). NULL 行不匹配任何 origin 过滤。
	eq("origin=manual excludes NULL row", listIDs(t, s, ctx, flowrundomain.ListFilter{Origin: flowrundomain.OriginManual}), []string{"fr_c"})

	// Half-open window [t2, t4): the lower bound is inclusive (fr_b at exactly t2 matches), the
	// upper exclusive (fr_d at exactly t4 does not) — adjacent windows tile without overlap.
	// 半开窗 [t2, t4)：下界含（恰在 t2 的 fr_b 命中）、上界不含（恰在 t4 的 fr_d 不命中）——相邻窗无缝拼接。
	eq("window [t2,t4)", listIDs(t, s, ctx, flowrundomain.ListFilter{StartedAfter: t2, StartedBefore: t4}), []string{"fr_c", "fr_b"})
	eq("startedAfter only", listIDs(t, s, ctx, flowrundomain.ListFilter{StartedAfter: t3}), []string{"fr_d", "fr_c"})
	eq("startedBefore only", listIDs(t, s, ctx, flowrundomain.ListFilter{StartedBefore: t2}), []string{"fr_a"})

	// AND-composition with the pre-existing filters. 与既有过滤的 AND 组合。
	eq("workflowId+origin", listIDs(t, s, ctx, flowrundomain.ListFilter{WorkflowID: "wf_1", Origin: flowrundomain.OriginCron}), []string{"fr_a"})
	eq("workflowId+origin mismatch", listIDs(t, s, ctx, flowrundomain.ListFilter{WorkflowID: "wf_1", Origin: flowrundomain.OriginManual}), []string{})
	eq("status+origin", listIDs(t, s, ctx, flowrundomain.ListFilter{Status: flowrundomain.StatusCompleted, Origin: flowrundomain.OriginManual}), []string{"fr_c"})
	eq("status+window", listIDs(t, s, ctx, flowrundomain.ListFilter{Status: flowrundomain.StatusRunning, StartedAfter: t2}), []string{"fr_d", "fr_b"})

	// An out-of-enum origin is a loud 422, never a silent empty page. 枚举外 origin 大声 422、绝不静默空页。
	if _, _, err := s.ListRuns(ctx, flowrundomain.ListFilter{Origin: "gremlin", Limit: 10}); !errors.Is(err, flowrundomain.ErrInvalidListFilter) {
		t.Fatalf("origin=gremlin must reject with ErrInvalidListFilter, got %v", err)
	}
}

// pinCompleted forces completed_at to an exact instant (MarkRunTerminal stamps now()). Mirrors
// mkRunAt's raw pin of started_at. pinCompleted 把 completed_at 钉到精确时刻（MarkRunTerminal 盖 now()）。
func pinCompleted(t *testing.T, s *Store, ctx context.Context, id string, at time.Time) {
	t.Helper()
	if _, err := s.db.Exec(ctx, `UPDATE flowruns SET completed_at = ? WHERE id = ?`, at, id); err != nil {
		t.Fatalf("pin completed_at %s: %v", id, err)
	}
}

// TestListRuns_CompletedWindow — 工单⑮: the completed_at window is the Overview's 「24h 失败」 card
// made clickable. Three things it must do, and one it must NOT: (1) half-open [after, before) on
// completed_at, independent of the started_at window; (2) exclude the unlanded — a running / parked
// run has completed_at = NULL and belongs to NO completed window; (3) compose with status; and
// crucially (4) count the SAME set failedSince counts, because the card's number and the list it
// opens are one fact — 「牌上写 3、点开列表显示 4」 is the bug this whole ocean is legislated against.
//
// TestListRuns_CompletedWindow — 工单⑮：completed_at 窗 = Overview「24h 失败」牌变得可点。它必须做三件、
// 且必须**不**做一件：(1) completed_at 上半开窗 [after, before)、与 started_at 窗独立；(2) 剔除未落定的——
// 在跑/parked 的 run completed_at 为 NULL、不属于任何 completed 窗；(3) 与 status 组合；关键 (4) 数**与
// failedSince 相同**的集合，因为牌的数与它点开的列表是**同一个事实**——「牌上写 3、点开列表显示 4」正是本
// 海洋立法所禁的 bug。
func TestListRuns_CompletedWindow(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	// Five failed runs, landing at distinct instants; one run still running (no completed_at).
	// started_at is set well BEFORE completed_at so a started_at window could never stand in for a
	// completed_at one. 五个失败 run、落定时刻各异；一个仍在跑（无 completed_at）。started_at 远早于
	// completed_at，故 started_at 窗永远替代不了 completed_at 窗。
	c1 := time.Date(2026, 7, 10, 8, 0, 0, 0, time.UTC)
	c2 := time.Date(2026, 7, 11, 8, 0, 0, 0, time.UTC)
	c3 := time.Date(2026, 7, 12, 8, 0, 0, 0, time.UTC)
	c4 := time.Date(2026, 7, 13, 8, 0, 0, 0, time.UTC)
	c5 := time.Date(2026, 7, 14, 8, 0, 0, 0, time.UTC)
	longAgo := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	for _, r := range []struct {
		id string
		at time.Time
	}{{"fr_1", c1}, {"fr_2", c2}, {"fr_3", c3}, {"fr_4", c4}, {"fr_5", c5}} {
		mkRunAt(t, s, ctx, r.id, "wf_1", "trg_1", flowrundomain.OriginCron, longAgo)
		if won, err := s.MarkRunTerminal(ctx, r.id, flowrundomain.StatusFailed, "boom"); err != nil || !won {
			t.Fatalf("terminal %s: won=%v err=%v", r.id, won, err)
		}
		pinCompleted(t, s, ctx, r.id, r.at)
	}
	// A still-running run: no completed_at. It must vanish under ANY completed window. 在跑 run：无
	// completed_at，任一 completed 窗下都必须消失。
	mkRunAt(t, s, ctx, "fr_run", "wf_1", "trg_1", flowrundomain.OriginCron, c3)

	eq := func(what string, got, want []string) {
		t.Helper()
		if len(got) != len(want) {
			t.Fatalf("%s: got %v, want %v", what, got, want)
		}
		for i := range want {
			if got[i] != want[i] {
				t.Fatalf("%s: got %v, want %v", what, got, want)
			}
		}
	}

	// Half-open [c2, c4): c2 inclusive, c4 exclusive — newest-first. 半开 [c2,c4)：c2 含、c4 不含。
	eq("completed [c2,c4)", listIDs(t, s, ctx, flowrundomain.ListFilter{CompletedAfter: c2, CompletedBefore: c4}), []string{"fr_3", "fr_2"})
	eq("completedAfter c3", listIDs(t, s, ctx, flowrundomain.ListFilter{CompletedAfter: c3}), []string{"fr_5", "fr_4", "fr_3"})
	eq("completedBefore c2", listIDs(t, s, ctx, flowrundomain.ListFilter{CompletedBefore: c2}), []string{"fr_1"})

	// The unlanded run never appears — under a wide-open completedAfter it is still excluded, because
	// NULL >= ? is never true. This is the surprising-but-correct behavior a future reader must not
	// "fix". 未落定 run 永不出现——即便极宽的 completedAfter 也剔除它，因 NULL >= ? 永不为真。
	eq("wide completedAfter excludes the running run",
		listIDs(t, s, ctx, flowrundomain.ListFilter{CompletedAfter: longAgo}),
		[]string{"fr_5", "fr_4", "fr_3", "fr_2", "fr_1"})
	eq("status=running + completedAfter is empty (running has no completed_at)",
		listIDs(t, s, ctx, flowrundomain.ListFilter{Status: flowrundomain.StatusRunning, CompletedAfter: longAgo}),
		[]string{})

	// Compose with status: only failed runs that ALSO landed in the window. 与 status 组合。
	eq("status=failed + completed [c2,c4)",
		listIDs(t, s, ctx, flowrundomain.ListFilter{Status: flowrundomain.StatusFailed, CompletedAfter: c2, CompletedBefore: c4}),
		[]string{"fr_3", "fr_2"})

	// (4) THE point: the list the card opens counts the same runs failedSince counts. Same predicate,
	// same instant → the number on the card equals the length of the list, at every boundary.
	// (4) 要害：牌点开的列表数着 failedSince 数的那些 run。同谓词、同时刻 → 牌上的数 == 列表的长度。
	for _, since := range []time.Time{c1, c2, c3, c4, c5, c3.Add(-time.Nanosecond), c3.Add(time.Nanosecond)} {
		stats, err := s.RunStats(ctx, flowrundomain.StatsQuery{Since: since})
		if err != nil {
			t.Fatalf("RunStats since=%s: %v", since, err)
		}
		list := listIDs(t, s, ctx, flowrundomain.ListFilter{Status: flowrundomain.StatusFailed, CompletedAfter: since})
		if len(list) != stats.Totals.FailedSince {
			t.Fatalf("SAME PREDICATE broken at since=%s: failedSince=%d but list has %d (%v) — "+
				"「牌上写 %d、点开列表显示 %d」", since.Format(time.RFC3339Nano),
				stats.Totals.FailedSince, len(list), list, stats.Totals.FailedSince, len(list))
		}
	}
}

// offsetIDs runs ListRunsOffset and returns the matched ids (newest-first) + total, for terse asserts.
//
// offsetIDs 跑 ListRunsOffset 返命中 id（最新在前）+ total，供简洁断言。
func offsetIDs(t *testing.T, s *Store, ctx context.Context, f flowrundomain.ListFilter) ([]string, int) {
	t.Helper()
	f.UseOffset = true
	rows, total, err := s.ListRunsOffset(ctx, f)
	if err != nil {
		t.Fatalf("ListRunsOffset %+v: %v", f, err)
	}
	ids := make([]string, 0, len(rows))
	for _, r := range rows {
		ids = append(ids, r.ID)
	}
	return ids, total
}

// TestListRunsOffset — WRK-070 B4: the offset/page-number pagination counterpart of ListRuns. It
// must (1) skip Offset rows and return Limit of them in the SAME canonical (started_at, id) DESC
// order as ListRuns (so page N under offset shows what keyset paging would); (2) return `total` =
// the row count under the SAME filter (not the whole table); (3) share ListRuns' filter guards
// (an out-of-enum status is still a loud 422); (4) survive an Offset past the end (empty page, total
// unchanged). Built on the SHARED buildRunQuery, so a window/filter added to one is never missing here.
//
// TestListRunsOffset — WRK-070 B4：ListRuns 的 offset/页码分页对应物。必须 (1) 跳过 Offset 行、返
// Limit 行，且与 ListRuns 同一正典 (started_at, id) DESC 序（故 offset 下第 N 页显示 keyset 分页会显示
// 的）；(2) 返 `total` = **同过滤**下的行数（非整表）；(3) 共享 ListRuns 的过滤守卫（枚举外 status 仍
// 大声 422）；(4) Offset 越界仍安全（空页、total 不变）。建在**共享**的 buildRunQuery 上，故一处加的
// 窗/过滤绝不在此缺席。
func TestListRunsOffset(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")

	// Five runs, distinct started_at so the canonical newest-first order is deterministic. wf_1 gets
	// four, wf_2 gets one — so a workflowId filter's total differs from the workspace total.
	// 五个 run、started_at 各异，故正典最新在前序确定。wf_1 四个、wf_2 一个——故 workflowId 过滤的 total 异于全 ws total。
	base := time.Date(2026, 7, 1, 8, 0, 0, 0, time.UTC)
	for i, r := range []struct {
		id, wf string
	}{
		{"fr_1", "wf_1"}, {"fr_2", "wf_1"}, {"fr_3", "wf_2"}, {"fr_4", "wf_1"}, {"fr_5", "wf_1"},
	} {
		mkRunAt(t, s, ctx, r.id, r.wf, "trg_1", flowrundomain.OriginManual, base.Add(time.Duration(i)*time.Hour))
	}
	// Canonical newest-first (started_at DESC): fr_5, fr_4, fr_3, fr_2, fr_1.
	newest := []string{"fr_5", "fr_4", "fr_3", "fr_2", "fr_1"}

	eq := func(what string, got, want []string) {
		t.Helper()
		if len(got) != len(want) {
			t.Fatalf("%s: got %v, want %v", what, got, want)
		}
		for i := range want {
			if got[i] != want[i] {
				t.Fatalf("%s: got %v, want %v", what, got, want)
			}
		}
	}

	// (1)+(2) First page, whole workspace: offset 0, limit 2 → two newest, total 5.
	ids, total := offsetIDs(t, s, ctx, flowrundomain.ListFilter{Limit: 2, Offset: 0})
	eq("page 0 rows", ids, newest[0:2])
	if total != 5 {
		t.Fatalf("page 0 total = %d, want 5", total)
	}
	// Second page: offset 2, limit 2 → next two, total still 5.
	ids, total = offsetIDs(t, s, ctx, flowrundomain.ListFilter{Limit: 2, Offset: 2})
	eq("page 1 rows", ids, newest[2:4])
	if total != 5 {
		t.Fatalf("page 1 total = %d, want 5", total)
	}
	// Last (partial) page: offset 4, limit 2 → the single oldest, total 5.
	ids, total = offsetIDs(t, s, ctx, flowrundomain.ListFilter{Limit: 2, Offset: 4})
	eq("page 2 rows", ids, newest[4:5])
	if total != 5 {
		t.Fatalf("page 2 total = %d, want 5", total)
	}

	// The offset page's order is byte-for-byte what ListRuns returns (whole set, one page).
	// offset 页的顺序与 ListRuns 逐字节相同（全集一页）。
	full, _, err := s.ListRuns(ctx, flowrundomain.ListFilter{Limit: 50})
	if err != nil {
		t.Fatalf("ListRuns full: %v", err)
	}
	fullIDs := make([]string, len(full))
	for i, r := range full {
		fullIDs[i] = r.ID
	}
	allOffset, _ := offsetIDs(t, s, ctx, flowrundomain.ListFilter{Limit: 50, Offset: 0})
	eq("offset order == keyset order", allOffset, fullIDs)

	// (2) total tracks the FILTER, not the whole table: wf_1 has four runs.
	// total 跟随**过滤**、非整表：wf_1 有四个 run。
	ids, total = offsetIDs(t, s, ctx, flowrundomain.ListFilter{WorkflowID: "wf_1", Limit: 2, Offset: 0})
	eq("wf_1 page 0", ids, []string{"fr_5", "fr_4"})
	if total != 4 {
		t.Fatalf("wf_1 total = %d, want 4 (filtered count, not table count)", total)
	}

	// (4) Offset past the end: empty page, total unchanged (the client learns it overshot).
	// Offset 越界：空页、total 不变（客户端据此知道翻过头了）。
	ids, total = offsetIDs(t, s, ctx, flowrundomain.ListFilter{Limit: 2, Offset: 99})
	eq("overshoot rows", ids, []string{})
	if total != 5 {
		t.Fatalf("overshoot total = %d, want 5", total)
	}

	// (3) The shared filter guard holds: an out-of-enum status is a loud 422, same as ListRuns.
	// 共享过滤守卫生效：枚举外 status 大声 422，与 ListRuns 一致。
	if _, _, err := s.ListRunsOffset(ctx, flowrundomain.ListFilter{Status: "parked", UseOffset: true}); !errors.Is(err, flowrundomain.ErrInvalidStatus) {
		t.Fatalf("invalid status must reject with ErrInvalidStatus, got %v", err)
	}
}
