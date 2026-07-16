// activity_test.go pins ListActivity (scheduler 工单⑤): the four execution-log tables UNIONed by
// flowrun_id in gantt order (started_at, id ASC), the queue stamp joined off the flowrun_nodes
// truth row (工单⑫, absent when no truth row / NULL stamp), keyset pagination without skip or
// duplication, workspace + flowrun isolation, and the empty-run shape.
//
// activity_test.go 钉死 ListActivity（scheduler 工单⑤）：四张执行日志表按 flowrun_id UNION、甘特序
// (started_at, id 升序)，排队戳 join 自 flowrun_nodes 真相行（工单⑫，无真相行/NULL 戳即缺席），keyset
// 分页不漏不重，workspace 与 flowrun 隔离，空 run 形状。
package flowrun

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
	cryptoinfra "github.com/sunweilin/anselm/backend/internal/infra/crypto"
	agentstore "github.com/sunweilin/anselm/backend/internal/infra/store/agent"
	functionstore "github.com/sunweilin/anselm/backend/internal/infra/store/function"
	handlerstore "github.com/sunweilin/anselm/backend/internal/infra/store/handler"
	mcpstore "github.com/sunweilin/anselm/backend/internal/infra/store/mcp"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// activityHarness opens one :memory: DB carrying the flowrun schema PLUS the four execution-log
// schemas (the UNION's source tables) and returns every store bound to it.
//
// activityHarness 开一个 :memory: DB，带 flowrun schema **加**四张执行日志 schema（UNION 的源表），
// 返回绑在其上的各 store。
type activityHarness struct {
	fr *Store
	fn *functionstore.Store
	hd *handlerstore.Store
	ag *agentstore.Store
	mc *mcpstore.Store
	// raw is the underlying handle, so tests can seed rows with EXACT timestamps (orm's ,created
	// stamp always overwrites started_at on Create — history needs raw INSERTs) and count survivors
	// after a destructive path (retention_test.go).
	// raw 是底层句柄，使测试能用**精确**时间戳种行（orm 的 ,created 戳在 Create 时总覆盖 started_at——
	// 历史需要裸 INSERT），并在破坏性路径后数幸存者（retention_test.go）。
	raw *sql.DB
}

func newActivityHarness(t *testing.T) *activityHarness {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	schemas := append([]string{}, Schema...)
	schemas = append(schemas, functionstore.Schema...)
	schemas = append(schemas, handlerstore.Schema...)
	schemas = append(schemas, agentstore.Schema...)
	schemas = append(schemas, mcpstore.Schema...)
	for _, stmt := range schemas {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema %q: %v", stmt[:40], err)
		}
	}
	db := ormpkg.Open(sqlDB)
	enc, err := cryptoinfra.NewAESGCMEncryptor(make([]byte, 32))
	if err != nil {
		t.Fatalf("encryptor: %v", err)
	}
	return &activityHarness{
		fr: New(db), fn: functionstore.New(db), hd: handlerstore.New(db),
		ag: agentstore.New(db), mc: mcpstore.New(db, enc), raw: sqlDB,
	}
}

// seedTruthRow writes a flowrun_nodes truth row with queue stamps (工单⑫) for the join to find.
// seedTruthRow 写一条带排队戳（工单⑫）的 flowrun_nodes 真相行供 join 命中。
func seedTruthRow(t *testing.T, h *activityHarness, ctx context.Context, runID, nodeID string, iter int, readyAt time.Time) {
	t.Helper()
	started := readyAt.Add(5 * time.Millisecond)
	inserted, err := h.fr.InsertNodeResult(ctx, &flowrundomain.FlowRunNode{
		FlowRunID: runID, NodeID: nodeID, Iteration: iter, Kind: "action", Ref: "fn_x",
		Status: flowrundomain.NodeCompleted, Result: map[string]any{},
		ReadyAt: &readyAt, StartedAt: &started,
	})
	if err != nil || !inserted {
		t.Fatalf("seed truth row %s/%d: inserted=%v err=%v", nodeID, iter, inserted, err)
	}
}

func TestListActivity_UnionFourTablesInGanttOrder(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	runID := mkRun(t, h.fr, ctx, "fr_act1", "wf_1", map[string]any{})
	base := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)

	// Four nodes, one audit row per family, deliberately seeded OUT of chronological order — the
	// page must come back in (started_at, id) ascending regardless of insertion order.
	// 四节点、每族一条审计行，刻意乱序插入——页必须按 (started_at, id) 升序返回。
	seedTruthRow(t, h, ctx, runID, "n_ag", 0, base.Add(2*time.Second))
	if err := h.ag.SaveExecution(ctx, &agentdomain.Execution{
		ID: "agx_1", AgentID: "ag_1", VersionID: "agv_1", Status: agentdomain.ExecutionStatusOK,
		TriggeredBy: agentdomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 700,
		StartedAt: base.Add(2*time.Second + 10*time.Millisecond), EndedAt: base.Add(3 * time.Second),
		FlowrunID: runID, FlowrunNodeID: "n_ag", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("agent save: %v", err)
	}
	seedTruthRow(t, h, ctx, runID, "n_fn", 0, base)
	if err := h.fn.SaveExecution(ctx, &functiondomain.Execution{
		ID: "fne_1", FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusOK,
		TriggeredBy: functiondomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 100,
		StartedAt: base.Add(10 * time.Millisecond), EndedAt: base.Add(110 * time.Millisecond),
		FlowrunID: runID, FlowrunNodeID: "n_fn", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("fn save: %v", err)
	}
	seedTruthRow(t, h, ctx, runID, "n_mc", 0, base.Add(3*time.Second))
	if err := h.mc.SaveCall(ctx, &mcpdomain.Call{
		ID: "mcl_1", ServerID: "mcp_1", Tool: "fetch", Status: mcpdomain.CallStatusFailed,
		TriggeredBy: mcpdomain.CallTriggeredByWorkflow, ElapsedMs: 40,
		StartedAt: base.Add(3*time.Second + 10*time.Millisecond), EndedAt: base.Add(3*time.Second + 50*time.Millisecond),
		FlowrunID: runID, FlowrunNodeID: "n_mc", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("mcp save: %v", err)
	}
	seedTruthRow(t, h, ctx, runID, "n_hd", 0, base.Add(time.Second))
	if err := h.hd.SaveCall(ctx, &handlerdomain.Call{
		ID: "hcl_1", HandlerID: "hd_1", VersionID: "hdv_1", Method: "run", Status: handlerdomain.CallStatusOK,
		TriggeredBy: handlerdomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 300,
		StartedAt: base.Add(time.Second + 10*time.Millisecond), EndedAt: base.Add(time.Second + 310*time.Millisecond),
		FlowrunID: runID, FlowrunNodeID: "n_hd", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("hd save: %v", err)
	}

	rows, next, err := h.fr.ListActivity(ctx, runID, "", 50)
	if err != nil {
		t.Fatalf("ListActivity: %v", err)
	}
	if next != "" || len(rows) != 4 {
		t.Fatalf("want 4 rows single page, got %d next=%q", len(rows), next)
	}
	wantOrder := []struct{ kind, execID, nodeID, status string }{
		{flowrundomain.ActivityKindFunction, "fne_1", "n_fn", "ok"},
		{flowrundomain.ActivityKindHandler, "hcl_1", "n_hd", "ok"},
		{flowrundomain.ActivityKindAgent, "agx_1", "n_ag", "ok"},
		{flowrundomain.ActivityKindMCP, "mcl_1", "n_mc", "failed"},
	}
	for i, w := range wantOrder {
		r := rows[i]
		if r.Kind != w.kind || r.ExecID != w.execID || r.NodeID != w.nodeID || r.Status != w.status {
			t.Fatalf("row %d = %+v, want %+v", i, r, w)
		}
		if r.ReadyAt == nil {
			t.Fatalf("row %d (%s) must join its truth row's readyAt", i, r.ExecID)
		}
		if !r.ReadyAt.Before(r.StartedAt) {
			t.Fatalf("row %d readyAt %v must precede startedAt %v", i, r.ReadyAt, r.StartedAt)
		}
		if !r.EndedAt.After(r.StartedAt) || r.ElapsedMs <= 0 {
			t.Fatalf("row %d execution segment wrong: started=%v ended=%v elapsed=%d", i, r.StartedAt, r.EndedAt, r.ElapsedMs)
		}
		if r.Iteration != 0 {
			t.Fatalf("row %d iteration = %d", i, r.Iteration)
		}
	}
}

func TestListActivity_KeysetPaginationNoSkipNoDup(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	runID := mkRun(t, h.fr, ctx, "fr_act2", "wf_1", map[string]any{})
	base := time.Date(2026, 7, 16, 11, 0, 0, 0, time.UTC)

	// 5 rows across two families; two share the same started_at so the id tiebreaker is exercised.
	// 5 行跨两族；两行同 started_at，逼出 id tiebreaker。
	ids := []string{"fne_a", "fne_b", "fne_c", "hcl_a", "hcl_b"}
	starts := []time.Time{base, base.Add(time.Second), base.Add(2 * time.Second), base.Add(2 * time.Second), base.Add(3 * time.Second)}
	for i, id := range ids[:3] {
		if err := h.fn.SaveExecution(ctx, &functiondomain.Execution{
			ID: id, FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusOK,
			TriggeredBy: functiondomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 10,
			StartedAt: starts[i], EndedAt: starts[i].Add(10 * time.Millisecond),
			FlowrunID: runID, FlowrunNodeID: "n", FlowrunIteration: i,
		}); err != nil {
			t.Fatalf("fn save %s: %v", id, err)
		}
	}
	for i, id := range ids[3:] {
		if err := h.hd.SaveCall(ctx, &handlerdomain.Call{
			ID: id, HandlerID: "hd_1", VersionID: "hdv_1", Method: "run", Status: handlerdomain.CallStatusOK,
			TriggeredBy: handlerdomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 10,
			StartedAt: starts[3+i], EndedAt: starts[3+i].Add(10 * time.Millisecond),
			FlowrunID: runID, FlowrunNodeID: "m", FlowrunIteration: i,
		}); err != nil {
			t.Fatalf("hd save %s: %v", id, err)
		}
	}

	var got []string
	cursor := ""
	pages := 0
	for {
		rows, next, err := h.fr.ListActivity(ctx, runID, cursor, 2)
		if err != nil {
			t.Fatalf("page %d: %v", pages, err)
		}
		for _, r := range rows {
			got = append(got, r.ExecID)
		}
		pages++
		if next == "" {
			break
		}
		cursor = next
	}
	// (started_at, id) ASC: the base.Add(2s) pair orders fne_c before hcl_a by id.
	// (started_at, id) 升序：同刻对 fne_c 按 id 排在 hcl_a 前。
	want := []string{"fne_a", "fne_b", "fne_c", "hcl_a", "hcl_b"}
	if pages != 3 || len(got) != 5 {
		t.Fatalf("want 5 rows over 3 pages, got %d over %d: %v", len(got), pages, got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("pagination order wrong: got %v want %v", got, want)
		}
	}
}

func TestListActivity_EmptyRunAndIsolation(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	runID := mkRun(t, h.fr, ctx, "fr_act3", "wf_1", map[string]any{})
	otherRun := mkRun(t, h.fr, ctx, "fr_other", "wf_1", map[string]any{})
	base := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)

	// A row on ANOTHER run and a row in ANOTHER workspace must both stay invisible.
	// 别的 run 的行与别的 workspace 的行都必须不可见。
	if err := h.fn.SaveExecution(ctx, &functiondomain.Execution{
		ID: "fne_other", FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusOK,
		TriggeredBy: functiondomain.TriggeredByWorkflow, Input: map[string]any{},
		StartedAt: base, EndedAt: base.Add(time.Millisecond),
		FlowrunID: otherRun, FlowrunNodeID: "x", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("fn save: %v", err)
	}
	if err := h.fn.SaveExecution(ctxWS("ws_2"), &functiondomain.Execution{
		ID: "fne_ws2", FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusOK,
		TriggeredBy: functiondomain.TriggeredByWorkflow, Input: map[string]any{},
		StartedAt: base, EndedAt: base.Add(time.Millisecond),
		FlowrunID: runID, FlowrunNodeID: "x", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("fn save ws2: %v", err)
	}

	rows, next, err := h.fr.ListActivity(ctx, runID, "", 10)
	if err != nil {
		t.Fatalf("ListActivity: %v", err)
	}
	if len(rows) != 0 || next != "" {
		t.Fatalf("empty run must yield an empty page, got %d rows next=%q", len(rows), next)
	}
}

func TestListActivity_ReadyAtAbsentWithoutTruthRow(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	runID := mkRun(t, h.fr, ctx, "fr_act4", "wf_1", map[string]any{})
	base := time.Date(2026, 7, 16, 13, 0, 0, 0, time.UTC)

	// An audit row with NO matching flowrun_nodes truth row (e.g. a crash between the audit write
	// and the frn INSERT, or pre-⑫ data): readyAt is absent, never a zero value.
	// 无对应 flowrun_nodes 真相行的审计行（如审计写与 frn INSERT 之间崩溃、或 ⑫ 前数据）：readyAt
	// 缺席、绝不发零值。
	if err := h.fn.SaveExecution(ctx, &functiondomain.Execution{
		ID: "fne_orphan", FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusFailed,
		TriggeredBy: functiondomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 5,
		StartedAt: base, EndedAt: base.Add(5 * time.Millisecond),
		FlowrunID: runID, FlowrunNodeID: "ghost", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("fn save: %v", err)
	}
	// And a truth row whose stamps are NULL (pre-⑫ row shape) joined by another audit row.
	// 以及一条戳为 NULL 的真相行（⑫ 前行形）被另一审计行 join。
	if _, err := h.fr.InsertNodeResult(ctx, &flowrundomain.FlowRunNode{
		FlowRunID: runID, NodeID: "old", Iteration: 0, Kind: "action", Ref: "fn_x",
		Status: flowrundomain.NodeCompleted, Result: map[string]any{},
	}); err != nil {
		t.Fatalf("truth row: %v", err)
	}
	if err := h.fn.SaveExecution(ctx, &functiondomain.Execution{
		ID: "fne_old", FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusOK,
		TriggeredBy: functiondomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 5,
		StartedAt: base.Add(time.Second), EndedAt: base.Add(time.Second + 5*time.Millisecond),
		FlowrunID: runID, FlowrunNodeID: "old", FlowrunIteration: 0,
	}); err != nil {
		t.Fatalf("fn save old: %v", err)
	}

	rows, _, err := h.fr.ListActivity(ctx, runID, "", 10)
	if err != nil {
		t.Fatalf("ListActivity: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("want 2 rows, got %d", len(rows))
	}
	for _, r := range rows {
		if r.ReadyAt != nil {
			t.Fatalf("row %s must have absent readyAt, got %v", r.ExecID, r.ReadyAt)
		}
	}
}
