// flowrun_matrix_test.go — black-box coverage for GET /flowrun-matrix (scheduler 工单⑩), the
// node×run status grid feeding the operations home's top-of-page grid, and for the run-history retention
// contract GET/PATCH /retention (scheduler 工单⑬). Zero tokens, zero sandbox: completed runs come
// from an approval decided "no" with no no-edge (the run settles with nothing ready), failed from an
// action referencing a ghost function — the flowrun_stats_test.go recipe.
//
// RETENTION COVERAGE SPLIT (deliberate, say it out loud): a black box cannot BACKDATE a run —
// every run it makes is seconds old, and the line's tightest legal value is 1 day — so "the old run
// is gone" is unit territory (infra/store/flowrun/retention_test.go pins the cutoff boundary, the
// terminal-only filter and the full cascade with exact timestamps). What only the black box can
// prove is here: the endpoint's real contract over HTTP, and that a tightened line kicking a REAL
// sweep against a REAL server leaves fresh history standing and the process healthy (the sweep is
// kicked from the PATCH's own goroutine — a deadlock or a panic there is exactly what this catches).
//
// flowrun_matrix_test.go——GET /flowrun-matrix（scheduler 工单⑩，喂运营主页页顶格阵的节点×run 状态格阵）
// 与 run 历史保留契约 GET/PATCH /retention（scheduler 工单⑬）的黑盒覆盖。零 token 零 sandbox:completed
// 用「审批决 no 且无 no 边」造、failed 用引用幽灵 function 的 action 造——flowrun_stats_test.go 的配方。
//
// **保留的覆盖切分**（刻意，且大声说出来）：黑盒**没法给 run 倒签日期**——它造的每个 run 都只有几秒大，而线
// 最紧的合法值是 1 天——故「旧 run 没了」归单测（infra/store/flowrun/retention_test.go 用精确时间戳钉死
// cutoff 边界、只终态过滤与完整级联）。**只有**黑盒能证的在这里：端点在 HTTP 上的真实契约，以及收紧的线对
// **真**服务器踢一趟**真**清理后，新鲜历史仍在、进程仍健康（清理是从 PATCH 自己的 goroutine 踢的——那里的
// 死锁或 panic 正是本测试逮的）。
package scenarios

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

type matrixResp struct {
	Cols []struct {
		FlowrunID string `json:"flowrunId"`
		StartedAt string `json:"startedAt"`
		Status    string `json:"status"`
		ElapsedMs *int64 `json:"elapsedMs"`
	} `json:"cols"`
	Rows []struct {
		NodeID string `json:"nodeId"`
		Kind   string `json:"kind"`
	} `json:"rows"`
	Cells []struct {
		FlowrunID  string `json:"flowrunId"`
		NodeID     string `json:"nodeId"`
		Status     string `json:"status"`
		Iteration  int    `json:"iteration"`
		Iterations int    `json:"iterations"`
	} `json:"cells"`
}

// TestFlowrunMatrix_Grid: 按显式 flowrunIds 批取格阵——列按正典新→旧（与请求顺序无关）带 run 耗时、
// 行是 node id 并集、格稀疏且状态诚实、未知 id 静默缺席、全未知三个空列表、缺 flowrunIds 400、越 50 上限
// 大声 422。
func TestFlowrunMatrix_Grid(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fr-matrix"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	// trigger → approval：决 no 且无 no 边 → run 落定 completed（零 token）。
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "matrix_gate", "template": "ok {{ input.v }}?", "allowReason": true,
	}).Field(t, "id")
	wf := wfCreate(t, wc, "matrix_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID, "input": map[string]any{"v": "start.v"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "human"}},
	})

	var started struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}

	// run #1 → 决 no → completed。
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wf, "payload": map[string]any{"v": "one"}}).OK(t, &started)
	first := started.Flowrun.ID
	wc.POST("/api/v1/flowruns/"+first+"/approvals/human:decide", map[string]any{"decision": "no"}).OK(t, nil)

	// run #2 → 留在 parked 不决（running + 等人）。
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wf, "payload": map[string]any{"v": "two"}}).OK(t, &started)
	second := started.Flowrun.ID
	if !strings.Contains(string(started.Nodes), `"parked"`) {
		t.Fatalf("run #2 应 park 在审批上: %s", started.Nodes)
	}

	var m matrixResp
	// 请求序故意旧在前：输出必须是正典 (started_at, id) DESC、与请求顺序无关。
	wc.GET("/api/v1/flowrun-matrix?flowrunIds="+first+","+second).OK(t, &m)

	// 列新→旧：#2 在前。
	if len(m.Cols) != 2 || m.Cols[0].FlowrunID != second || m.Cols[1].FlowrunID != first {
		t.Fatalf("cols 须新→旧 [#2,#1]，实得 %+v", m.Cols)
	}
	if m.Cols[0].Status != "running" || m.Cols[1].Status != "completed" {
		t.Errorf("列状态: %+v", m.Cols)
	}
	// 落定的 run 有耗时；在跑的 run 无 completed_at → 键缺席（绝不发会被读成「瞬时」的 0）。
	if m.Cols[0].ElapsedMs != nil {
		t.Errorf("running 的列不得带 elapsedMs，实得 %d", *m.Cols[0].ElapsedMs)
	}
	if m.Cols[1].ElapsedMs == nil {
		t.Error("completed 的列须带 elapsedMs")
	}

	// 行 = node id 并集，按最新 run 的执行序（seed trigger 恒在最前）。
	if len(m.Rows) != 2 || m.Rows[0].NodeID != "start" || m.Rows[1].NodeID != "human" {
		t.Fatalf("rows 须为 [start, human] 执行序，实得 %+v", m.Rows)
	}
	if m.Rows[0].Kind != "trigger" || m.Rows[1].Kind != "approval" {
		t.Errorf("行 kind: %+v", m.Rows)
	}

	// 格：两个 run × 两个节点，且状态诚实——#2 的 human 仍 parked、#1 的已决完 completed。
	if len(m.Cells) != 4 {
		t.Fatalf("cells 须 4 个，实得 %d: %+v", len(m.Cells), m.Cells)
	}
	for _, cell := range m.Cells {
		if cell.Iterations != 1 || cell.Iteration != 0 {
			t.Errorf("非 loop 节点须 iteration=0 iterations=1，实得 %+v", cell)
		}
		if cell.FlowrunID == second && cell.NodeID == "human" && cell.Status != "parked" {
			t.Errorf("等人的格须 parked，实得 %q", cell.Status)
		}
		if cell.FlowrunID == first && cell.NodeID == "human" && cell.Status != "completed" {
			t.Errorf("已决的格须 completed，实得 %q", cell.Status)
		}
	}

	// 未知 id 静默缺席：已知的照答、未知的不在——全未知则三个**空列表**、绝不 null。
	var mixed matrixResp
	wc.GET("/api/v1/flowrun-matrix?flowrunIds="+first+",fr_ghost_never_exists").OK(t, &mixed)
	if len(mixed.Cols) != 1 || mixed.Cols[0].FlowrunID != first {
		t.Fatalf("混合已知/未知 id 须只答已知，实得 %+v", mixed.Cols)
	}
	var empty matrixResp
	raw := wc.GET("/api/v1/flowrun-matrix?flowrunIds=fr_ghost_never_exists").OK(t, &empty)
	if len(empty.Cols) != 0 || len(empty.Rows) != 0 || len(empty.Cells) != 0 {
		t.Fatalf("全未知 id 须空，实得 %+v", empty)
	}
	for _, key := range []string{`"cols":[]`, `"rows":[]`, `"cells":[]`} {
		if !strings.Contains(strings.ReplaceAll(string(raw.Raw), " ", ""), key) {
			t.Errorf("空格阵须发空列表而非 null，缺 %s: %s", key, raw.Raw)
		}
	}

	// flowrunIds 是格阵的内容：缺席/全空串即 400，绝不回一个无意义的空答案。
	wc.GET("/api/v1/flowrun-matrix").Fail(t, 400, "INVALID_REQUEST")
	wc.GET("/api/v1/flowrun-matrix?flowrunIds=,,").Fail(t, 400, "INVALID_REQUEST")
	// （去重后）越 50 上限带上限大声拒——绝不静默截断（客户端拿屏上那页与答案对拉）。
	over := make([]string, 51)
	for i := range over {
		over[i] = fmt.Sprintf("fr_%03d", i)
	}
	wc.GET("/api/v1/flowrun-matrix?flowrunIds="+strings.Join(over, ",")).Fail(t, 422, "FLOWRUN_MATRIX_TOO_MANY_IDS")
	// 51 个原始 id 去重后 ≤50 必须放行——重复在封顶检查之前坍缩。
	dup := append([]string{over[0]}, over[:50]...)
	wc.GET("/api/v1/flowrun-matrix?flowrunIds="+strings.Join(dup, ",")).OK(t, nil)
}

// TestRetention_ConfigContract: 保留线的 HTTP 契约——默认 90、PATCH 合并落盘、显式 0=永久、负数与拼错的
// 键大声拒；且收紧的线对真服务器踢真清理后，新鲜历史仍在、进程仍健康。
func TestRetention_ConfigContract(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "retention"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	type retention struct {
		RunRetentionDays int `json:"runRetentionDays"`
	}

	// 全新安装读回服务端自持的默认——客户端永不硬编它。
	var got retention
	wc.GET("/api/v1/retention").OK(t, &got)
	if got.RunRetentionDays != 90 {
		t.Fatalf("默认保留线须 90d，实得 %d", got.RunRetentionDays)
	}

	// 造两个真 run（一个 completed、一个 running+等人）——它们是「新鲜历史」，收紧的线绝不能碰。
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "ret_gate", "template": "ok?", "allowReason": false,
	}).Field(t, "id")
	wf := wfCreate(t, wc, "retention_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "human"}},
	})
	var started struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
	}
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wf}).OK(t, &started)
	done := started.Flowrun.ID
	wc.POST("/api/v1/flowruns/"+done+"/approvals/human:decide", map[string]any{"decision": "no"}).OK(t, nil)
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wf}).OK(t, &started)
	live := started.Flowrun.ID

	// 收紧到 30d：PATCH 回显新值 **并踢一趟真清理**（在这个 handler 自己的 goroutine 上）。
	var patched retention
	wc.PATCH("/api/v1/retention", map[string]any{"runRetentionDays": 30}).OK(t, &patched)
	if patched.RunRetentionDays != 30 {
		t.Fatalf("PATCH 须回显新线，实得 %d", patched.RunRetentionDays)
	}
	wc.GET("/api/v1/retention").OK(t, &got)
	if got.RunRetentionDays != 30 {
		t.Fatalf("PATCH 未落盘：GET 实得 %d", got.RunRetentionDays)
	}

	// 清理跑过之后：服务器还活着（PATCH 的钩子在锁外触发——死锁/panic 在此现形），且**两个新鲜 run 都在**
	// （落定的与在飞的都远在 30d 线之内；一个吃掉它们的清理是灾难性 bug）。
	for _, id := range []string{done, live} {
		wc.GET("/api/v1/flowruns/"+id).OK(t, nil)
	}

	// 显式 0 = 永久保留，且**往返存活**（若它被读回成默认，用户刻意的「永久」会变成一场删除）。
	wc.PATCH("/api/v1/retention", map[string]any{"runRetentionDays": 0}).OK(t, &patched)
	if patched.RunRetentionDays != 0 {
		t.Fatalf("显式 0（永久）须原样回显，实得 %d", patched.RunRetentionDays)
	}
	wc.GET("/api/v1/retention").OK(t, &got)
	if got.RunRetentionDays != 0 {
		t.Fatalf("永久未持久化：GET 实得 %d", got.RunRetentionDays)
	}

	// 空 patch = 忠实的 no-op（合并基底是当前值，绝不是默认值）。
	wc.PATCH("/api/v1/retention", map[string]any{}).OK(t, &patched)
	if patched.RunRetentionDays != 0 {
		t.Fatalf("空 patch 须保持当前线，实得 %d", patched.RunRetentionDays)
	}

	// 唯一的物理约束：线不能倒着走。
	wc.PATCH("/api/v1/retention", map[string]any{"runRetentionDays": -1}).Fail(t, 400, "SETTINGS_RETENTION_INVALID")
	// 拼错的键必须 400、而非静默 no-op 返 200。
	wc.PATCH("/api/v1/retention", map[string]any{"runRetentionDay": 30}).Fail(t, 400, "SETTINGS_RETENTION_INVALID")

	// UI 菜单外但物理合法的天数照收——30/90/180 是产品可供性、不是物理界限（设计原则 #6）。
	wc.PATCH("/api/v1/retention", map[string]any{"runRetentionDays": 60}).OK(t, &patched)
	if patched.RunRetentionDays != 60 {
		t.Errorf("菜单外但合法的值须被接受，实得 %d", patched.RunRetentionDays)
	}
}
