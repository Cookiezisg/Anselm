// contract_workflow_test.go — Phase 1 REST 契约全扫 · p1_workflow 批次。
//
// 覆盖 workflow / trigger / control / approval 四域的 unprobed 契约面：
// versions cursor 往返、软删名字复用、未知字段拒收、动作动词、环纪律、手动 :trigger 绕并发策略、
// 活监听重绑、deactivate draining、引用计数监听、webhook 明文双载体 + signatureHeader、
// Edit 热更路径、control 分支校验 + 钉死版本求值、approval 空 timeout + ParseTimeout d/w。
// 断言全部以 docs/references/backend/{api,error-codes,domains/*}.md 为准（契约 = 文档说的）。
package scenarios

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	neturl "net/url"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// ---------------------------------------------------------------------------
// helpers (workflowC_ 前缀，批次约定)
// ---------------------------------------------------------------------------

// workflowC_ws boots a workspace on srv and returns a bound client.
//
// workflowC_ws 在 srv 上开一个 workspace 并返回绑定客户端。
func workflowC_ws(t *testing.T, srv *harness.Server, name string) *harness.Client {
	t.Helper()
	c := srv.Client(t)
	return c.WS(c.POST("/api/v1/workspaces", map[string]any{"name": name}).OK(t, nil).Field(t, "id"))
}

// workflowC_trgOnly builds a one-node workflow (single trigger node "start" on trgRef).
// Runs on it complete instantly — perfect for listener-face scenarios.
//
// workflowC_trgOnly 建单节点 workflow（唯一 trigger 节点 "start" 指 trgRef）。其 run 立即完成——
// 适合监听面场景。
func workflowC_trgOnly(t *testing.T, wc *harness.Client, name, trgRef string, extraOps ...map[string]any) string {
	t.Helper()
	ops := append([]map[string]any{}, extraOps...)
	ops = append(ops, map[string]any{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgRef}})
	return wfCreate(t, wc, name, ops)
}

// workflowC_apf creates a minimal approval form (static template, no inputs, no timeout).
//
// workflowC_apf 建最小审批表（静态模板、无声明 input、无 timeout）。
func workflowC_apf(t *testing.T, wc *harness.Client, name string) string {
	t.Helper()
	return wc.POST("/api/v1/approvals", map[string]any{"name": name, "template": "proceed?"}).Field(t, "id")
}

// workflowC_apfGraph builds trigger→approval ("start"→"hold"); the approval node is a legal
// terminal (yes/no both end the run) so parked runs need no downstream entities.
//
// workflowC_apfGraph 建 trigger→approval 图（"start"→"hold"）；approval 节点是合法终端
// （yes/no 都收尾），parked run 不需要任何下游实体。
func workflowC_apfGraph(t *testing.T, wc *harness.Client, name, trgRef, apfID string, extraOps ...map[string]any) string {
	t.Helper()
	ops := append([]map[string]any{}, extraOps...)
	ops = append(ops,
		map[string]any{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgRef}},
		map[string]any{"op": "add_node", "node": map[string]any{"id": "hold", "kind": "approval", "ref": apfID}},
		map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "hold"}},
	)
	return wfCreate(t, wc, name, ops)
}

// workflowC_startRun starts a manual run via POST /flowruns and returns the run id.
//
// workflowC_startRun 经 POST /flowruns 手动起 run 并返回 run id。
func workflowC_startRun(t *testing.T, wc *harness.Client, wfID string) string {
	t.Helper()
	var started struct {
		Flowrun struct {
			ID string `json:"id"`
		} `json:"flowrun"`
	}
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{}}).OK(t, &started)
	return started.Flowrun.ID
}

// workflowC_run reads one run: (status, nodes raw JSON text).
//
// workflowC_run 读一个 run：（status、节点原始 JSON 文本）。
func workflowC_run(t *testing.T, wc *harness.Client, runID string) (string, string) {
	t.Helper()
	r := wc.GET("/api/v1/flowruns/" + runID)
	if r.Status != 200 {
		t.Fatalf("GET flowrun %s: %d %s", runID, r.Status, r.Raw)
	}
	var got struct {
		Flowrun struct {
			Status string `json:"status"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	if err := json.Unmarshal(r.Data, &got); err != nil {
		t.Fatalf("decode flowrun: %v %s", err, r.Data)
	}
	return got.Flowrun.Status, string(got.Nodes)
}

// workflowC_waitParked polls until the run is running with a parked node.
//
// workflowC_waitParked 轮询直到 run 处于 running 且有 parked 节点。
func workflowC_waitParked(t *testing.T, wc *harness.Client, runID string, timeoutMS int) {
	t.Helper()
	harness.Eventually(t, timeoutMS, "run "+runID+" parks at approval", func() bool {
		s, nodes := workflowC_run(t, wc, runID)
		return s == "running" && strings.Contains(nodes, `"parked"`)
	})
}

// workflowC_waitRunStatus polls until the run reaches the wanted status.
//
// workflowC_waitRunStatus 轮询直到 run 到达目标 status。
func workflowC_waitRunStatus(t *testing.T, wc *harness.Client, runID, want string, timeoutMS int) {
	t.Helper()
	harness.Eventually(t, timeoutMS, "run "+runID+" reaches "+want, func() bool {
		s, _ := workflowC_run(t, wc, runID)
		return s == want
	})
}

// workflowC_runsOf lists runs of one workflow (optionally filtered by status).
//
// workflowC_runsOf 列一个 workflow 的 run（可按 status 过滤）。
func workflowC_runsOf(t *testing.T, wc *harness.Client, wfID, status string) []struct {
	ID     string `json:"id"`
	Status string `json:"status"`
} {
	t.Helper()
	url := "/api/v1/flowruns?workflowId=" + wfID
	if status != "" {
		url += "&status=" + status
	}
	var rows []struct {
		ID     string `json:"id"`
		Status string `json:"status"`
	}
	wc.GET(url).OK(t, &rows)
	return rows
}

// workflowC_pageIDs walks a paged list endpoint with the given limit and returns every id,
// asserting N4 invariants: page size ≤ limit, nextCursor/hasMore agree, terminates.
//
// workflowC_pageIDs 用给定 limit 走完一个分页端点并返回全部 id，同时断言 N4 不变量：
// 页大小 ≤ limit、nextCursor/hasMore 一致、可终止。
func workflowC_pageIDs(t *testing.T, wc *harness.Client, path string, limit int) []string {
	t.Helper()
	sep := "?"
	if strings.Contains(path, "?") {
		sep = "&"
	}
	var ids []string
	cursor := ""
	for i := 0; i < 50; i++ {
		url := fmt.Sprintf("%s%slimit=%d", path, sep, limit)
		if cursor != "" {
			url += "&cursor=" + neturl.QueryEscape(cursor)
		}
		r := wc.GET(url)
		if r.Status != 200 {
			t.Fatalf("page %s: %d %s", url, r.Status, r.Raw)
		}
		var rows []struct {
			ID string `json:"id"`
		}
		if err := json.Unmarshal(r.Data, &rows); err != nil {
			t.Fatalf("page decode %s: %v %s", url, err, r.Data)
		}
		if len(rows) > limit {
			t.Fatalf("page %s returned %d rows > limit %d", url, len(rows), limit)
		}
		for _, row := range rows {
			ids = append(ids, row.ID)
		}
		if r.NextCursor == "" {
			if r.HasMore {
				t.Fatalf("page %s: hasMore=true with empty nextCursor", url)
			}
			return ids
		}
		if !r.HasMore {
			t.Fatalf("page %s: nextCursor set but hasMore=false", url)
		}
		cursor = r.NextCursor
	}
	t.Fatalf("pagination never terminated: %s", path)
	return nil
}

// workflowC_assertDistinct fails on duplicate ids (cursor must not revisit rows).
//
// workflowC_assertDistinct 有重复 id 即失败（游标不得重访行）。
func workflowC_assertDistinct(t *testing.T, what string, ids []string) {
	t.Helper()
	seen := map[string]bool{}
	for _, id := range ids {
		if seen[id] {
			t.Fatalf("%s: duplicate id %s in cursor walk %v", what, id, ids)
		}
		seen[id] = true
	}
}

// workflowC_rawPost fires a bare HTTP POST (webhook inbound face — no workspace header) and
// returns the status code.
//
// workflowC_rawPost 发裸 HTTP POST（webhook 入站面——不带 workspace 头）并返回状态码。
func workflowC_rawPost(t *testing.T, url, body string, hdr map[string]string) int {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost, url, strings.NewReader(body))
	if err != nil {
		t.Fatalf("rawPost new request: %v", err)
	}
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("rawPost %s: %v", url, err)
	}
	resp.Body.Close()
	return resp.StatusCode
}

// workflowC_fire hits POST /triggers/{id}:fire and returns the activation id (202 {data:{id}}).
//
// workflowC_fire 打 POST /triggers/{id}:fire 并返回 activation id（202 {data:{id}}）。
func workflowC_fire(t *testing.T, wc *harness.Client, trgID string) string {
	t.Helper()
	r := wc.POST("/api/v1/triggers/"+trgID+":fire", map[string]any{})
	if r.Status != 202 {
		t.Fatalf(":fire must 202 (api.md 异步动作铁律), got %d %s", r.Status, r.Raw)
	}
	return r.Field(t, "id")
}

// workflowC_activationFiringCount reads one activation's firingCount.
//
// workflowC_activationFiringCount 读一条 activation 的 firingCount。
func workflowC_activationFiringCount(t *testing.T, wc *harness.Client, actID string) int {
	t.Helper()
	var act struct {
		ID          string `json:"id"`
		FiringCount int    `json:"firingCount"`
	}
	wc.GET("/api/v1/trigger-activations/"+actID).OK(t, &act)
	if act.ID != actID {
		t.Fatalf("activation id roundtrip: want %s got %s", actID, act.ID)
	}
	return act.FiringCount
}

// workflowC_wfState reads (lifecycleState, active, activeVersion.version) of a workflow.
//
// workflowC_wfState 读 workflow 的（lifecycleState、active、activeVersion.version）。
func workflowC_wfState(t *testing.T, wc *harness.Client, wfID string) (string, bool, int) {
	t.Helper()
	var wf struct {
		LifecycleState string `json:"lifecycleState"`
		Active         bool   `json:"active"`
		ActiveVersion  struct {
			Version int `json:"version"`
		} `json:"activeVersion"`
	}
	wc.GET("/api/v1/workflows/"+wfID).OK(t, &wf)
	return wf.LifecycleState, wf.Active, wf.ActiveVersion.Version
}

// ---------------------------------------------------------------------------
// A-wf-3 — workflow versions/list cursor 往返
// ---------------------------------------------------------------------------

func TestContractWorkflow_VersionsCursorRoundtrip(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-versions")

	wfID := workflowC_trgOnly(t, wc, "versioned_wf", "trg_x")
	// 3 edits → 4 versions total. 3 次编辑 → 共 4 个版本。
	for i := 2; i <= 4; i++ {
		var v struct {
			Version int `json:"version"`
		}
		wc.POST("/api/v1/workflows/"+wfID+":edit", map[string]any{"ops": []map[string]any{
			{"op": "update_node", "id": "start", "patch": map[string]any{"notes": fmt.Sprintf("rev %d", i)}},
		}}).OK(t, &v)
		if v.Version != i {
			t.Fatalf(":edit must mint version %d, got %d", i, v.Version)
		}
	}

	// cursor walk at limit=2 → 4 distinct rows, N4 invariants held by the helper.
	// limit=2 游标走全 → 4 条不重复行，N4 不变量由 helper 把关。
	ids := workflowC_pageIDs(t, wc, "/api/v1/workflows/"+wfID+"/versions", 2)
	if len(ids) != 4 {
		t.Fatalf("cursor walk must yield all 4 versions, got %d: %v", len(ids), ids)
	}
	workflowC_assertDistinct(t, "workflow versions", ids)
	for _, id := range ids {
		if !strings.HasPrefix(id, "wfv_") {
			t.Fatalf("version id shape must be wfv_*: %s", id)
		}
	}
	// first page carries a cursor (hasMore) — pinned explicitly for the N4 face.
	// 首页必带游标（hasMore）——显式钉 N4 面。
	r := wc.GET("/api/v1/workflows/" + wfID + "/versions?limit=2")
	if !r.HasMore || r.NextCursor == "" {
		t.Fatalf("first page of 4 at limit=2 must set hasMore+nextCursor: hasMore=%v cursor=%q", r.HasMore, r.NextCursor)
	}
	// GET by version number closes the loop. 按版本号单读闭环。
	var v3 struct {
		Version int `json:"version"`
	}
	wc.GET("/api/v1/workflows/"+wfID+"/versions/3").OK(t, &v3)
	if v3.Version != 3 {
		t.Fatalf("GET versions/3 must return version 3, got %d", v3.Version)
	}
}

// ---------------------------------------------------------------------------
// A-wf-6 软删名字复用 + A-wf-8 未知字段 + B-wf-2 环纪律 (合租一台)
// ---------------------------------------------------------------------------

func TestContractWorkflow_SoftDeleteUnknownFieldBackEdge(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-hygiene")

	// --- A-wf-6: soft delete frees the name; deleted row leaves list + 404s ---
	id1 := workflowC_trgOnly(t, wc, "phoenix_wf", "trg_x")
	r := wc.Do("POST", "/api/v1/workflows", map[string]any{"name": "phoenix_wf", "ops": []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_x"}},
	}})
	r.Fail(t, 409, "WORKFLOW_NAME_DUPLICATE")

	if del := wc.DELETE("/api/v1/workflows/" + id1); del.Status != 204 {
		t.Fatalf("DELETE must 204, got %d %s", del.Status, del.Raw)
	}
	wc.Do("GET", "/api/v1/workflows/"+id1, nil).Fail(t, 404, "WORKFLOW_NOT_FOUND")
	list := wc.GET("/api/v1/workflows")
	if strings.Contains(string(list.Data), id1) {
		t.Fatalf("soft-deleted workflow must not appear in list: %s", list.Data)
	}
	id2 := workflowC_trgOnly(t, wc, "phoenix_wf", "trg_x") // 名字复用成功
	if id2 == id1 {
		t.Fatalf("recreated workflow must get a fresh id")
	}

	// --- A-wf-8: unknown top-level fields rejected (strict decode, INVALID_REQUEST) ---
	r = wc.Do("POST", "/api/v1/workflows", map[string]any{
		"name": "junk_wf", "bogusField": true,
		"ops": []map[string]any{{"op": "add_node", "node": map[string]any{"id": "t", "kind": "trigger", "ref": "trg_x"}}},
	})
	r.Fail(t, 400, "INVALID_REQUEST")
	r = wc.Do("PATCH", "/api/v1/workflows/"+id2, map[string]any{"bogusField": 1})
	r.Fail(t, 400, "INVALID_REQUEST")

	// --- B-wf-2: back edge must originate from control/approval — fn→fn loop rejected ---
	// 回边必须出自 control/approval——fn→fn 回环创建即拒 WORKFLOW_INVALID_GRAPH。
	r = wc.Do("POST", "/api/v1/workflows", map[string]any{"name": "loop_wf", "ops": []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "t", "kind": "trigger", "ref": "trg_x"}},
		{"op": "add_node", "node": map[string]any{"id": "a", "kind": "action", "ref": "fn_a"}},
		{"op": "add_node", "node": map[string]any{"id": "b", "kind": "action", "ref": "fn_b"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "t", "to": "a"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "a", "to": "b"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e3", "from": "b", "to": "a"}}, // action 源回边
	}})
	r.Fail(t, 422, "WORKFLOW_INVALID_GRAPH")
}

// ---------------------------------------------------------------------------
// A-wf-7 — 执行生命周期动词 REST 面（:trigger/:edit/:revert/:capability-check/
//          :activate 门控/:stage 409/:deactivate）
// ---------------------------------------------------------------------------

func TestContractWorkflow_LifecycleVerbFaces(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-verbs")

	trgID := trgCreate(t, wc, "face_hook", "webhook", map[string]any{"path": "face"})
	wfGood := workflowC_trgOnly(t, wc, "verb_wf", trgID)

	// :trigger — 202 {data:{id}}, run reachable + completes (any lifecycle). api.md 异步动作铁律。
	tr := wc.POST("/api/v1/workflows/"+wfGood+":trigger", map[string]any{"payload": map[string]any{}})
	if tr.Status != 202 {
		t.Fatalf(":trigger must 202, got %d %s", tr.Status, tr.Raw)
	}
	runID := tr.Field(t, "id")
	workflowC_waitRunStatus(t, wc, runID, "completed", 20000)

	// :edit → v2; :revert → active pointer back to v1.
	var v2 struct {
		Version int `json:"version"`
	}
	wc.POST("/api/v1/workflows/"+wfGood+":edit", map[string]any{"ops": []map[string]any{
		{"op": "update_node", "id": "start", "patch": map[string]any{"notes": "second"}},
	}}).OK(t, &v2)
	if v2.Version != 2 {
		t.Fatalf(":edit must mint v2, got %d", v2.Version)
	}
	if _, _, av := workflowC_wfState(t, wc, wfGood); av != 2 {
		t.Fatalf("edit must move active pointer to v2, got %d", av)
	}
	var vr struct {
		Version int `json:"version"`
	}
	wc.POST("/api/v1/workflows/"+wfGood+":revert", map[string]any{"version": 1}).OK(t, &vr)
	if vr.Version != 1 {
		t.Fatalf(":revert must return v1, got %d", vr.Version)
	}
	if _, _, av := workflowC_wfState(t, wc, wfGood); av != 1 {
		t.Fatalf("revert must move active pointer to v1, got %d", av)
	}

	// :capability-check — sound graph reports no problems; dangling ref graph lists them.
	var rep struct {
		StructurallyValid bool     `json:"structurallyValid"`
		Resolved          bool     `json:"resolved"`
		Problems          []string `json:"problems"`
	}
	wc.POST("/api/v1/workflows/"+wfGood+":capability-check", map[string]any{}).OK(t, &rep)
	if !rep.StructurallyValid || !rep.Resolved || len(rep.Problems) != 0 {
		t.Fatalf("sound graph capability report wrong: %+v", rep)
	}
	wfBad := workflowC_trgOnly(t, wc, "dangling_wf", "trg_deadbeefdeadbeef")
	wc.POST("/api/v1/workflows/"+wfBad+":capability-check", map[string]any{}).OK(t, &rep)
	if len(rep.Problems) == 0 {
		t.Fatalf("dangling ref must surface in problems: %+v", rep)
	}

	// F135 待命门控：非健全图 :activate/:stage 拒 WORKFLOW_NOT_RUNNABLE、不上线。
	wc.Do("POST", "/api/v1/workflows/"+wfBad+":activate", map[string]any{}).Fail(t, 422, "WORKFLOW_NOT_RUNNABLE")
	wc.Do("POST", "/api/v1/workflows/"+wfBad+":stage", map[string]any{}).Fail(t, 422, "WORKFLOW_NOT_RUNNABLE")

	// :activate green → active; :stage on active → 409 WORKFLOW_ALREADY_ACTIVE; :deactivate
	// with no runs in flight → inactive (not draining).
	var wfResp struct {
		LifecycleState string `json:"lifecycleState"`
		Active         bool   `json:"active"`
	}
	wc.POST("/api/v1/workflows/"+wfGood+":activate", map[string]any{}).OK(t, &wfResp)
	if wfResp.LifecycleState != "active" || !wfResp.Active {
		t.Fatalf(":activate must flip active, got %+v", wfResp)
	}
	wc.Do("POST", "/api/v1/workflows/"+wfGood+":stage", map[string]any{}).Fail(t, 409, "WORKFLOW_ALREADY_ACTIVE")
	wc.POST("/api/v1/workflows/"+wfGood+":deactivate", map[string]any{}).OK(t, &wfResp)
	if wfResp.LifecycleState != "inactive" {
		t.Fatalf(":deactivate with no runs must land inactive, got %+v", wfResp)
	}

	// unknown :action → 404 (dispatch default). 未知动词 → 404。
	if r := wc.Do("POST", "/api/v1/workflows/"+wfGood+":bogusverb", map[string]any{}); r.Status != 404 {
		t.Fatalf("unknown action must 404, got %d %s", r.Status, r.Raw)
	}
}

// ---------------------------------------------------------------------------
// A-wf-7 (续) — :stage 一次性待命真触发 + :kill 取消在途 run
// ---------------------------------------------------------------------------

func TestContractWorkflow_StageOneShotAndKill(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-stagekill")

	// --- :stage arms exactly one real fire, then auto-disarms ---
	trgOnce := trgCreate(t, wc, "once_hook", "webhook", map[string]any{"path": "once"})
	wfOnce := workflowC_trgOnly(t, wc, "staged_wf", trgOnce)
	wc.POST("/api/v1/workflows/"+wfOnce+":stage", map[string]any{}).OK(t, nil)

	aid1 := workflowC_fire(t, wc, trgOnce)
	if n := workflowC_activationFiringCount(t, wc, aid1); n != 1 {
		t.Fatalf("staged workflow must receive the first fire (firingCount=1), got %d", n)
	}
	harness.Eventually(t, 30000, "staged one-shot run completes", func() bool {
		return len(workflowC_runsOf(t, wc, wfOnce, "completed")) == 1
	})
	// second fire after auto-disarm reaches nobody. 撤防后第二次 fire 无人接。
	aid2 := workflowC_fire(t, wc, trgOnce)
	if n := workflowC_activationFiringCount(t, wc, aid2); n != 0 {
		t.Fatalf("stage must auto-disarm after one fire; second fire fanned to %d listeners", n)
	}

	// --- :kill cancels every in-flight run + lands inactive ---
	trgKill := trgCreate(t, wc, "kill_hook", "webhook", map[string]any{"path": "kill"})
	apfID := workflowC_apf(t, wc, "kill_gate")
	wfKill := workflowC_apfGraph(t, wc, "kill_wf", trgKill, apfID)
	wc.POST("/api/v1/workflows/"+wfKill+":activate", map[string]any{}).OK(t, nil)

	runID := workflowC_startRun(t, wc, wfKill) // parks at approval — a run in flight. 停在审批——在途 run。
	workflowC_waitParked(t, wc, runID, 15000)

	kr := wc.POST("/api/v1/workflows/"+wfKill+":kill", map[string]any{})
	if kr.Status != 200 {
		t.Fatalf(":kill must 200, got %d %s", kr.Status, kr.Raw)
	}
	// :kill 返回 workflow 实体快照（含 lifecycleState），遵 ADR 0003「状态变更动作返动作后实体完整
	// 快照」铁律——api.md 已同批订正（原写「返被杀数」与实现及全局契约不符）。
	if !strings.Contains(string(kr.Data), `"lifecycleState"`) {
		t.Fatalf(":kill must return the post-action workflow entity snapshot (ADR 0003), got: %s", kr.Raw)
	}
	workflowC_waitRunStatus(t, wc, runID, "cancelled", 20000)
	harness.Eventually(t, 15000, "killed workflow lands inactive", func() bool {
		ls, active, _ := workflowC_wfState(t, wc, wfKill)
		return ls == "inactive" && !active
	})
	// listener detached: a manual fire reaches nobody. 监听已摘：fire 无人接。
	aid3 := workflowC_fire(t, wc, trgKill)
	if n := workflowC_activationFiringCount(t, wc, aid3); n != 0 {
		t.Fatalf(":kill must detach the listener; fire fanned to %d", n)
	}
}

// B-wf-24/B-trg-19 — :kill is a hard execution stop, not merely a listener detach. A firing
// accepted before the kill but still waiting behind a parked serial run must be settled as neutral
// `shed`; it must not wake up after the cancelled run disappears and create a post-kill flowrun.
//
// B-wf-24/B-trg-19 —— :kill 是执行面的硬停，不只是摘 listener。kill 前已接受、但因 serial 停泊 run
// 而 pending 的 firing 必须中性收口为 `shed`；不能等被取消的 run 消失后在 kill 之后偷偷铸造新 run。
func TestContractWorkflow_KillShedsQueuedFiring(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-kill-queued")

	trgID := trgCreate(t, wc, "kill_queued_hook", "webhook", map[string]any{"path": "kill-queued"})
	apfID := workflowC_apf(t, wc, "kill_queued_gate")
	wfID := workflowC_apfGraph(t, wc, "kill_queued_wf", trgID, apfID,
		map[string]any{"op": "set_meta", "concurrency": "serial"})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	fireConcurrencyWebhook(t, srv, trgID, "kill-queued", `{"seq":1}`)
	var firstRunID string
	harness.Eventually(t, 20000, "kill-queued first run parks", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 {
			return false
		}
		firstRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, firstRunID)
		return strings.Contains(nodes, `"parked"`)
	})
	fireConcurrencyWebhook(t, srv, trgID, "kill-queued", `{"seq":2}`)
	harness.Eventually(t, 20000, "kill-queued second firing is pending", func() bool {
		rows := listConcurrencyFirings(t, wc, trgID)
		counts := countFiringStatuses(rows)
		return len(rows) == 2 && counts["started"] == 1 && counts["pending"] == 1
	})

	resp := wc.POST("/api/v1/workflows/"+wfID+":kill", map[string]any{})
	if resp.Status != 200 {
		t.Fatalf(":kill must 200, got %d %s", resp.Status, resp.Raw)
	}
	state, active, _ := workflowC_wfState(t, wc, wfID)
	if state != "inactive" || active {
		t.Fatalf(":kill must land inactive before queued firing can drain: state=%q active=%v", state, active)
	}
	workflowC_waitRunStatus(t, wc, firstRunID, "cancelled", 20000)

	var finalFirings []firingRow
	harness.Eventually(t, 15000, "kill sheds queued firing", func() bool {
		finalFirings = listFirings(t, wc, trgID, "limit=50")
		counts := map[string]int{}
		for _, firing := range finalFirings {
			counts[firing.Status]++
		}
		return len(finalFirings) == 2 && counts["started"] == 1 && counts["shed"] == 1
	})
	if rows := workflowC_runsOf(t, wc, wfID, ""); len(rows) != 1 || rows[0].ID != firstRunID || rows[0].Status != "cancelled" {
		t.Fatalf("hard-killed workflow must not create a post-kill run from queued firing, got %+v", rows)
	}
	if code := workflowC_rawPost(t, srv.BaseURL+"/api/v1/webhooks/"+trgID+"/kill-queued", `{"seq":3}`, nil); code != 404 {
		t.Fatalf("killed workflow listener must stay detached, got webhook status %d", code)
	}
}

// B-wf-14/B-trg-10 — 多入口 :stage 是“任一入口下一次触发”，而不是每个入口各跑一次。
// Staging a workflow with two trigger refs arms both sources, but the first fire must consume the
// single trial-run budget and detach the workflow from every source. Otherwise a second source
// can silently produce an extra run after the user believes the trial has ended.
//
// B-wf-14/B-trg-10 —— 多入口 :stage 语义是「任一入口的下一次触发」，而非每个入口各跑一次：两条
// source 都待命，但第一火消耗唯一试跑额度，并从所有 source 摘除；否则用户以为试跑结束后，第二条
// source 仍会悄悄再跑一遍。
func TestContractWorkflow_StageMultiTriggerDisarmsAllEntries(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-stage-multi")

	trgA := trgCreate(t, wc, "stage_multi_a", "webhook", map[string]any{"path": "stage-multi-a"})
	trgB := trgCreate(t, wc, "stage_multi_b", "webhook", map[string]any{"path": "stage-multi-b"})
	wfID := wfCreate(t, wc, "stage_multi_wf", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "entry_a", "kind": "trigger", "ref": trgA}},
		{"op": "add_node", "node": map[string]any{"id": "entry_b", "kind": "trigger", "ref": trgB}},
	})
	wc.POST("/api/v1/workflows/"+wfID+":stage", map[string]any{}).OK(t, nil)

	readRuntime := func(triggerID string) (int, bool) {
		t.Helper()
		var got struct {
			RefCount  int  `json:"refCount"`
			Listening bool `json:"listening"`
		}
		wc.GET("/api/v1/triggers/"+triggerID).OK(t, &got)
		return got.RefCount, got.Listening
	}
	if rc, listening := readRuntime(trgA); rc != 1 || !listening {
		t.Fatalf("stage must arm A exactly once, got refCount/listening=%d/%v", rc, listening)
	}
	if rc, listening := readRuntime(trgB); rc != 1 || !listening {
		t.Fatalf("stage must arm B exactly once, got refCount/listening=%d/%v", rc, listening)
	}

	urlA := srv.BaseURL + "/api/v1/webhooks/" + trgA + "/stage-multi-a"
	urlB := srv.BaseURL + "/api/v1/webhooks/" + trgB + "/stage-multi-b"
	if code := workflowC_rawPost(t, urlA, `{"entry":"first"}`, nil); code != 202 {
		t.Fatalf("first staged entry must return 202, got %d", code)
	}
	harness.Eventually(t, 30000, "staged multi-entry run completes", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 1
	})

	// The first fire consumes the one-shot on BOTH refs, not only on the source that fired.
	harness.Eventually(t, 5000, "first staged fire disarms every entry", func() bool {
		rcA, listeningA := readRuntime(trgA)
		rcB, listeningB := readRuntime(trgB)
		return rcA == 0 && !listeningA && rcB == 0 && !listeningB
	})
	if code := workflowC_rawPost(t, urlB, `{"entry":"second"}`, nil); code != 404 {
		t.Fatalf("second staged entry must be detached after first fire, got %d", code)
	}
	aid := workflowC_fire(t, wc, trgB)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 0 {
		t.Fatalf("manual fire after staged budget is consumed must fan out to 0, got %d", n)
	}
	if n := len(workflowC_runsOf(t, wc, wfID, "")); n != 1 {
		t.Fatalf("multi-entry stage must create exactly one run, got %d", n)
	}
}

// ---------------------------------------------------------------------------
// B-wf-7 — 手动 :trigger 绕过并发策略：replace 下两手动 run 同途、互不取消
// ---------------------------------------------------------------------------

func TestContractWorkflow_ManualTriggerBypassesReplace(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-bypass")

	apfID := workflowC_apf(t, wc, "bypass_gate")
	wfID := workflowC_apfGraph(t, wc, "replace_wf", "trg_manualonly0000", apfID,
		map[string]any{"op": "set_meta", "concurrency": "replace"})
	var wf struct {
		Concurrency string `json:"concurrency"`
	}
	wc.GET("/api/v1/workflows/"+wfID).OK(t, &wf)
	if wf.Concurrency != "replace" {
		t.Fatalf("precondition: concurrency must be replace, got %q", wf.Concurrency)
	}

	// two manual runs back-to-back — both park, neither is replace-cancelled (workflow.md:
	// 手动 StartRun 绕过策略立即建 run，两手动 run 可同时在途即便 replace)。两条手动入口
	// 各走一次：POST /flowruns 与 POST :trigger（api.md 注明等价）。
	run1 := workflowC_startRun(t, wc, wfID)
	workflowC_waitParked(t, wc, run1, 15000)
	tr := wc.POST("/api/v1/workflows/"+wfID+":trigger", map[string]any{"payload": map[string]any{}})
	if tr.Status != 202 {
		t.Fatalf(":trigger must 202, got %d %s", tr.Status, tr.Raw)
	}
	run2 := tr.Field(t, "id")
	workflowC_waitParked(t, wc, run2, 15000)

	s1, _ := workflowC_run(t, wc, run1)
	s2, _ := workflowC_run(t, wc, run2)
	if s1 != "running" || s2 != "running" {
		t.Fatalf("both manual runs must be in flight under replace: run1=%s run2=%s", s1, s2)
	}
	if n := len(workflowC_runsOf(t, wc, wfID, "running")); n != 2 {
		t.Fatalf("want 2 concurrent manual runs, got %d", n)
	}
}

// ---------------------------------------------------------------------------
// B-wf-10 — 活监听重绑：active workflow :edit 换入口 trigger ref 即 detach 旧 attach 新
// ---------------------------------------------------------------------------

func TestContractWorkflow_EditRebindsActiveListener(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-rebind")

	trgOld := trgCreate(t, wc, "old_hook", "webhook", map[string]any{"path": "old"})
	trgNew := trgCreate(t, wc, "new_hook", "webhook", map[string]any{"path": "new"})
	wfID := workflowC_trgOnly(t, wc, "rebind_wf", trgOld)
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	// baseline: old trigger reaches the workflow. 基线：旧 trigger 打得到。
	aid := workflowC_fire(t, wc, trgOld)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 1 {
		t.Fatalf("baseline fire must fan out to 1 workflow, got %d", n)
	}
	harness.Eventually(t, 30000, "baseline run completes", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 1
	})

	// edit swaps the entry trigger ref while active → rebind (workflow.md 活监听重绑).
	wc.POST("/api/v1/workflows/"+wfID+":edit", map[string]any{"ops": []map[string]any{
		{"op": "update_node", "id": "start", "patch": map[string]any{"ref": trgNew}},
	}}).OK(t, nil)

	// old trigger detached — its fire reaches nobody. 旧 trigger 已摘——fire 无人接。
	aid = workflowC_fire(t, wc, trgOld)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 0 {
		t.Fatalf("after rebind the OLD trigger must be detached; fanned to %d", n)
	}
	// new trigger attached — fires and runs. 新 trigger 已挂——触发即跑。
	aid = workflowC_fire(t, wc, trgNew)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 1 {
		t.Fatalf("after rebind the NEW trigger must be attached; fanned to %d", n)
	}
	harness.Eventually(t, 30000, "run via new trigger completes", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 2
	})
	if n := len(workflowC_runsOf(t, wc, wfID, "")); n != 2 {
		t.Fatalf("old-trigger fire after rebind must not create a run: total %d", n)
	}
}

// ---------------------------------------------------------------------------
// B-wf-12 — :deactivate 在途不杀：draining → run 结算收口翻 inactive
// (:kill 半边在 TestContractWorkflow_StageOneShotAndKill)
// ---------------------------------------------------------------------------

func TestContractWorkflow_DeactivateDrainsToInactive(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-drain")

	trgID := trgCreate(t, wc, "drain_hook", "webhook", map[string]any{"path": "drain"})
	apfID := workflowC_apf(t, wc, "drain_gate")
	wfID := workflowC_apfGraph(t, wc, "drain_wf", trgID, apfID)
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	runID := workflowC_startRun(t, wc, wfID)
	workflowC_waitParked(t, wc, runID, 15000)

	// deactivate with a run in flight → draining (run NOT killed). 在途 → draining、不杀。
	var wfResp struct {
		LifecycleState string `json:"lifecycleState"`
	}
	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, &wfResp)
	if wfResp.LifecycleState != "draining" {
		t.Fatalf(":deactivate with in-flight run must land draining, got %q", wfResp.LifecycleState)
	}
	if s, _ := workflowC_run(t, wc, runID); s != "running" {
		t.Fatalf("draining must NOT kill the in-flight run, got %s", s)
	}

	// the run settles (decision) → scheduler reconciles draining → inactive.
	// run 结算（决策）→ 调度器收口 draining → inactive。
	wc.POST("/api/v1/flowruns/"+runID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, runID, "completed", 20000)
	harness.Eventually(t, 20000, "draining workflow flips inactive after last run settles", func() bool {
		ls, _, _ := workflowC_wfState(t, wc, wfID)
		return ls == "inactive"
	})
}

// ---------------------------------------------------------------------------
// A-trg-3 + A-trg-4 — :fire 202 单 id 闭环 + activations/firings cursor 往返 + ?status 枚举
// ---------------------------------------------------------------------------

func TestContractWorkflow_TriggerFireLedgerAndCursor(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "trgc-ledger")

	trgID := trgCreate(t, wc, "ledger_hook", "webhook", map[string]any{"path": "ledger"})
	// allow_all so one drain tick starts all pending firings (serial would take a tick each).
	// allow_all 使一个 drain tick 启动全部 pending firing（serial 要一 tick 一条）。
	wfID := workflowC_trgOnly(t, wc, "ledger_wf", trgID,
		map[string]any{"op": "set_meta", "concurrency": "allow_all"})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	// A-trg-4: 202 {data:{id}} → id 直查 activation 闭环。
	aid1 := workflowC_fire(t, wc, trgID)
	if !strings.HasPrefix(aid1, "tra_") {
		t.Fatalf("activation id shape must be tra_*: %s", aid1)
	}
	var act struct {
		ID          string `json:"id"`
		TriggerID   string `json:"triggerId"`
		Fired       bool   `json:"fired"`
		FiringCount int    `json:"firingCount"`
	}
	wc.GET("/api/v1/trigger-activations/"+aid1).OK(t, &act)
	if act.ID != aid1 || act.TriggerID != trgID || !act.Fired || act.FiringCount != 1 {
		t.Fatalf("activation closure wrong: %+v", act)
	}

	aid2 := workflowC_fire(t, wc, trgID)
	aid3 := workflowC_fire(t, wc, trgID)
	if aid1 == aid2 || aid2 == aid3 || aid1 == aid3 {
		t.Fatalf("each :fire must mint a distinct activation: %s %s %s", aid1, aid2, aid3)
	}

	// all 3 firings drain to started (trigger-only graph completes instantly).
	harness.Eventually(t, 30000, "all 3 firings reach started", func() bool {
		var rows []struct {
			ID string `json:"id"`
		}
		r := wc.GET("/api/v1/firings?triggerId=" + trgID + "&status=started")
		if r.Status != 200 {
			return false
		}
		_ = json.Unmarshal(r.Data, &rows)
		return len(rows) == 3
	})

	// A-trg-3: firings cursor walk at limit=1 → 3 distinct rows; rows carry activationId.
	fids := workflowC_pageIDs(t, wc, "/api/v1/firings?triggerId="+trgID, 1)
	if len(fids) != 3 {
		t.Fatalf("firings cursor walk must yield 3, got %d: %v", len(fids), fids)
	}
	workflowC_assertDistinct(t, "firings", fids)
	var firstFirings []struct {
		ID           string `json:"id"`
		ActivationID string `json:"activationId"`
		WorkflowID   string `json:"workflowId"`
		Status       string `json:"status"`
	}
	wc.GET("/api/v1/firings?triggerId="+trgID).OK(t, &firstFirings)
	found := false
	for _, f := range firstFirings {
		if !strings.HasPrefix(f.ID, "trf_") || f.WorkflowID != wfID {
			t.Fatalf("firing row shape wrong: %+v", f)
		}
		if f.ActivationID == aid1 {
			found = true
		}
	}
	if !found {
		t.Fatalf("no firing links back to activation %s: %+v", aid1, firstFirings)
	}

	// ?status 全枚举合法（error-codes.md: pending/claimed/started/skipped/superseded/shed）；
	// 非法值 422 TRIGGER_FIRING_INVALID_STATUS 而非静默空页（F175-M7）。
	for _, s := range []string{"pending", "claimed", "started", "skipped", "superseded", "shed"} {
		if r := wc.GET("/api/v1/firings?triggerId=" + trgID + "&status=" + s); r.Status != 200 {
			t.Fatalf("status=%s must be a legal filter, got %d %s", s, r.Status, r.Raw)
		}
	}
	wc.Do("GET", "/api/v1/firings?triggerId="+trgID+"&status=yolo", nil).Fail(t, 422, "TRIGGER_FIRING_INVALID_STATUS")

	// activations cursor walk at limit=2 → 3 distinct rows; firedOnly=true keeps all (all fired).
	aids := workflowC_pageIDs(t, wc, "/api/v1/triggers/"+trgID+"/activations", 2)
	if len(aids) != 3 {
		t.Fatalf("activations cursor walk must yield 3, got %d: %v", len(aids), aids)
	}
	workflowC_assertDistinct(t, "activations", aids)
	var firedRows []struct {
		ID string `json:"id"`
	}
	wc.GET("/api/v1/triggers/"+trgID+"/activations?firedOnly=true").OK(t, &firedRows)
	if len(firedRows) != 3 {
		t.Fatalf("firedOnly=true must keep all 3 fired activations, got %d", len(firedRows))
	}
}

// ---------------------------------------------------------------------------
// A-trg-6 — trigger 软删：名字复用；activation/firing 是 Log 表、删后旧账仍可读
// ---------------------------------------------------------------------------

func TestContractWorkflow_TriggerSoftDeleteKeepsLog(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "trgc-resurrect")

	// inert cron (fires Jan 1 00:00 only; no listener anyway). 惰性 cron。
	trgID := trgCreate(t, wc, "resurrect_trg", "cron", map[string]any{"expression": "0 0 1 1 *"})
	r := wc.Do("POST", "/api/v1/triggers", map[string]any{
		"name": "resurrect_trg", "kind": "cron", "config": map[string]any{"expression": "0 0 1 1 *"},
	})
	r.Fail(t, 409, "TRIGGER_NAME_DUPLICATE")

	aid := workflowC_fire(t, wc, trgID) // 0 listeners → 只是一条 0 firing 的 activation
	if n := workflowC_activationFiringCount(t, wc, aid); n != 0 {
		t.Fatalf("no-listener fire must fan out to 0, got %d", n)
	}

	if del := wc.DELETE("/api/v1/triggers/" + trgID); del.Status != 204 {
		t.Fatalf("DELETE must 204, got %d %s", del.Status, del.Raw)
	}
	wc.Do("GET", "/api/v1/triggers/"+trgID, nil).Fail(t, 404, "TRIGGER_NOT_FOUND")
	list := wc.GET("/api/v1/triggers")
	if strings.Contains(string(list.Data), trgID) {
		t.Fatalf("soft-deleted trigger must not appear in list: %s", list.Data)
	}

	// name reuse after soft delete. 软删后名字复用。
	trgID2 := trgCreate(t, wc, "resurrect_trg", "cron", map[string]any{"expression": "0 0 1 1 *"})
	if trgID2 == trgID {
		t.Fatalf("recreated trigger must get a fresh id")
	}

	// activation is a Log row (D1 无软删) — still readable after its trigger died.
	// activation 是 Log 行（D1 无软删）——trigger 死后旧账仍可读。
	var oldAct struct {
		ID        string `json:"id"`
		TriggerID string `json:"triggerId"`
	}
	wc.GET("/api/v1/trigger-activations/"+aid).OK(t, &oldAct)
	if oldAct.ID != aid || oldAct.TriggerID != trgID {
		t.Fatalf("old activation must survive trigger deletion: %+v", oldAct)
	}
}

// ---------------------------------------------------------------------------
// A-trg-8 — trigger 拒未知顶层字段；config 是自由 map、杂键宽容（F14 族）
// ---------------------------------------------------------------------------

func TestContractWorkflow_TriggerUnknownFieldAndConfigTolerance(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "trgc-junk")

	// unknown TOP-LEVEL field → strict decode 400 INVALID_REQUEST.
	r := wc.Do("POST", "/api/v1/triggers", map[string]any{
		"name": "junk_trg", "kind": "cron", "config": map[string]any{"expression": "0 0 1 1 *"},
		"bogusField": true,
	})
	r.Fail(t, 400, "INVALID_REQUEST")

	// unknown keys INSIDE config tolerated by design (Config 自由 map——加 source 种类不改列).
	id := trgCreate(t, wc, "tolerant_trg", "webhook", map[string]any{"path": "tol", "extraKnob": "kept"})
	var trg struct {
		Config map[string]any `json:"config"`
	}
	wc.GET("/api/v1/triggers/"+id).OK(t, &trg)
	if trg.Config["extraKnob"] != "kept" {
		t.Fatalf("free-map config must keep unknown keys: %+v", trg.Config)
	}

	// PATCH with unknown top-level field → 400.
	wc.Do("PATCH", "/api/v1/triggers/"+id, map[string]any{"bogusField": 1}).Fail(t, 400, "INVALID_REQUEST")

	// unknown kind → 422 TRIGGER_INVALID_KIND (枚举面顺手钉死).
	wc.Do("POST", "/api/v1/triggers", map[string]any{
		"name": "weird_trg", "kind": "yolo", "config": map[string]any{},
	}).Fail(t, 422, "TRIGGER_INVALID_KIND")
}

// ---------------------------------------------------------------------------
// A-wf-7/A-trg-7/A-ctl-7/A-apv-7 (:iterate 面) — 四实体 :iterate 202 {id} 开对话
// ---------------------------------------------------------------------------

func TestContractWorkflow_IterateVerbs(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "wfc-iterate"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	// llmmock as dialogue default so the spawned conversation's first turn costs zero tokens.
	// llmmock 作 dialogue 默认——被 spawn 的对话首回合零 token。
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "llmmock", "key": "sk-mock", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4o"}).OK(t, nil)

	wfID := workflowC_trgOnly(t, wc, "iter_wf", "trg_x")
	trgID := trgCreate(t, wc, "iter_trg", "cron", map[string]any{"expression": "0 0 1 1 *"})
	ctlID := wc.POST("/api/v1/controls", map[string]any{
		"name":     "iter_ctl",
		"branches": []map[string]any{{"port": "out", "when": "true"}},
	}).Field(t, "id")
	apfID := workflowC_apf(t, wc, "iter_apf")

	for _, tc := range []struct{ path, name string }{
		{"/api/v1/workflows/" + wfID + ":iterate", "workflow"},
		{"/api/v1/triggers/" + trgID + ":iterate", "trigger"},
		{"/api/v1/controls/" + ctlID + ":iterate", "control"},
		{"/api/v1/approvals/" + apfID + ":iterate", "approval"},
	} {
		r := wc.POST(tc.path, map[string]any{"request": "make it better"})
		if r.Status != 202 {
			t.Fatalf("%s :iterate must 202 (api.md :iterate→conversation 铁律), got %d %s", tc.name, r.Status, r.Raw)
		}
		convID := r.Field(t, "id")
		if !strings.HasPrefix(convID, "cv_") {
			t.Fatalf("%s :iterate must return a conversation id (cv_*), got %s", tc.name, convID)
		}
		// closure: the conversation exists. 闭环：对话真实存在。
		if g := wc.GET("/api/v1/conversations/" + convID); g.Status != 200 {
			t.Fatalf("%s :iterate conversation not readable: %d %s", tc.name, g.Status, g.Raw)
		}
	}

	// empty request → 400 EMPTY_ITERATE_REQUEST; missing target → 404 (spawn 前校验目标, aispawn).
	wc.Do("POST", "/api/v1/workflows/"+wfID+":iterate", map[string]any{}).Fail(t, 400, "EMPTY_ITERATE_REQUEST")
	wc.Do("POST", "/api/v1/workflows/wf_ffffffffffffffff:iterate", map[string]any{"request": "x"}).
		Fail(t, 404, "WORKFLOW_NOT_FOUND")
}

// ---------------------------------------------------------------------------
// A-ctl-3/4/6/8 — control 空列表[]/versions cursor/软删名字复用/未知字段
// ---------------------------------------------------------------------------

func TestContractWorkflow_ControlListVersionsSoftDeleteUnknown(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "ctlc-face")

	// A-ctl-4: 零 control 空列表必须是 [] 非 null（N1/N4，F170 族）。
	r := wc.GET("/api/v1/controls")
	if r.Status != 200 || string(r.Data) != "[]" {
		t.Fatalf("empty control list must be data:[] — got %d %s", r.Status, r.Raw)
	}

	catchall := []map[string]any{{"port": "out", "when": "true"}}
	ctlID := wc.POST("/api/v1/controls", map[string]any{"name": "cursor_ctl", "branches": catchall}).Field(t, "id")

	// versions shape: one v1 row, ctlv_ id, controlId back-links.
	var vrows []struct {
		ID        string `json:"id"`
		ControlID string `json:"controlId"`
		Version   int    `json:"version"`
	}
	wc.GET("/api/v1/controls/"+ctlID+"/versions").OK(t, &vrows)
	if len(vrows) != 1 || !strings.HasPrefix(vrows[0].ID, "ctlv_") || vrows[0].ControlID != ctlID || vrows[0].Version != 1 {
		t.Fatalf("version row shape wrong: %+v", vrows)
	}

	// A-ctl-3: 2 edits → 3 versions; cursor walk at limit=1.
	for i := 0; i < 2; i++ {
		wc.POST("/api/v1/controls/"+ctlID+":edit", map[string]any{"branches": []map[string]any{
			{"port": "out", "when": "true", "emit": map[string]string{"rev": fmt.Sprintf("'%d'", i+2)}},
		}}).OK(t, nil)
	}
	ids := workflowC_pageIDs(t, wc, "/api/v1/controls/"+ctlID+"/versions", 1)
	if len(ids) != 3 {
		t.Fatalf("control versions cursor walk must yield 3, got %d: %v", len(ids), ids)
	}
	workflowC_assertDistinct(t, "control versions", ids)

	// A-ctl-6: dup name 409 → soft delete → 404/list 过滤 → 同名重建成功。
	wc.Do("POST", "/api/v1/controls", map[string]any{"name": "cursor_ctl", "branches": catchall}).
		Fail(t, 409, "CONTROL_NAME_DUPLICATE")
	if del := wc.DELETE("/api/v1/controls/" + ctlID); del.Status != 204 {
		t.Fatalf("DELETE must 204, got %d %s", del.Status, del.Raw)
	}
	wc.Do("GET", "/api/v1/controls/"+ctlID, nil).Fail(t, 404, "CONTROL_NOT_FOUND")
	list := wc.GET("/api/v1/controls")
	if strings.Contains(string(list.Data), ctlID) {
		t.Fatalf("soft-deleted control must not appear in list: %s", list.Data)
	}
	ctlID2 := wc.POST("/api/v1/controls", map[string]any{"name": "cursor_ctl", "branches": catchall}).Field(t, "id")
	if ctlID2 == ctlID {
		t.Fatalf("recreated control must get a fresh id")
	}

	// A-ctl-8: unknown top-level field → 400 INVALID_REQUEST (create + PATCH).
	wc.Do("POST", "/api/v1/controls", map[string]any{
		"name": "junk_ctl", "branches": catchall, "bogusField": 1,
	}).Fail(t, 400, "INVALID_REQUEST")
	wc.Do("PATCH", "/api/v1/controls/"+ctlID2, map[string]any{"bogusField": 1}).Fail(t, 400, "INVALID_REQUEST")
}

// ---------------------------------------------------------------------------
// B-ctl-2 + B-ctl-3 — 末条兜底 CONTROL_NO_CATCHALL；Port 非空且唯一 CONTROL_INVALID_BRANCHES
// ---------------------------------------------------------------------------

func TestContractWorkflow_ControlBranchValidation(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "ctlc-branches")

	// B-ctl-2: last branch must be when:"true". 无兜底 → CONTROL_NO_CATCHALL。
	wc.Do("POST", "/api/v1/controls", map[string]any{
		"name":   "no_catchall",
		"inputs": []map[string]any{{"name": "x", "type": "number"}},
		"branches": []map[string]any{
			{"port": "hi", "when": "input.x > 1.0"},
		},
	}).Fail(t, 422, "CONTROL_NO_CATCHALL")

	// B-ctl-3: duplicate port → CONTROL_INVALID_BRANCHES。
	wc.Do("POST", "/api/v1/controls", map[string]any{
		"name":   "dup_port",
		"inputs": []map[string]any{{"name": "x", "type": "number"}},
		"branches": []map[string]any{
			{"port": "same", "when": "input.x > 1.0"},
			{"port": "same", "when": "true"},
		},
	}).Fail(t, 422, "CONTROL_INVALID_BRANCHES")

	// B-ctl-3: empty port → CONTROL_INVALID_BRANCHES。
	wc.Do("POST", "/api/v1/controls", map[string]any{
		"name": "blank_port",
		"branches": []map[string]any{
			{"port": "", "when": "true"},
		},
	}).Fail(t, 422, "CONTROL_INVALID_BRANCHES")
}

// ---------------------------------------------------------------------------
// A-ctl-7 (:edit/:revert) + B-ctl-8 — 运行时 Resolve 按钉死版本求值
// ---------------------------------------------------------------------------

func TestContractWorkflow_ControlRevertAndPinnedResolve(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "ctlc-pin")

	// --- A-ctl-7: :edit → v2 可读回; :revert → active 指针回 v1 ---
	ctlID := wc.POST("/api/v1/controls", map[string]any{
		"name": "revert_ctl",
		"branches": []map[string]any{
			{"port": "out", "when": "true", "emit": map[string]string{"rev": "'one'"}},
		},
	}).Field(t, "id")
	wc.POST("/api/v1/controls/"+ctlID+":edit", map[string]any{"branches": []map[string]any{
		{"port": "out", "when": "true", "emit": map[string]string{"rev": "'two'"}},
	}}).OK(t, nil)
	var detail struct {
		ActiveVersion struct {
			Version  int `json:"version"`
			Branches []struct {
				Emit map[string]string `json:"emit"`
			} `json:"branches"`
		} `json:"activeVersion"`
	}
	wc.GET("/api/v1/controls/"+ctlID).OK(t, &detail)
	if detail.ActiveVersion.Version != 2 || detail.ActiveVersion.Branches[0].Emit["rev"] != "'two'" {
		t.Fatalf(":edit must activate v2 with new emit: %+v", detail.ActiveVersion)
	}
	var vr struct {
		Version int `json:"version"`
	}
	wc.POST("/api/v1/controls/"+ctlID+":revert", map[string]any{"version": 1}).OK(t, &vr)
	if vr.Version != 1 {
		t.Fatalf(":revert must return v1, got %d", vr.Version)
	}
	wc.GET("/api/v1/controls/"+ctlID).OK(t, &detail)
	if detail.ActiveVersion.Version != 1 || detail.ActiveVersion.Branches[0].Emit["rev"] != "'one'" {
		t.Fatalf(":revert must restore v1 branches: %+v", detail.ActiveVersion)
	}

	// --- B-ctl-8: park 期间编辑 control，续跑仍走 run 起跑时钉死的旧版本 ---
	pinCtl := wc.POST("/api/v1/controls", map[string]any{
		"name": "pin_ctl",
		"branches": []map[string]any{
			{"port": "out", "when": "true", "emit": map[string]string{"pinned": "'old'"}},
		},
	}).Field(t, "id")
	apfID := workflowC_apf(t, wc, "pin_hold")
	wfID := wfCreate(t, wc, "pin_wf", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_pin0000000000"}},
		{"op": "add_node", "node": map[string]any{"id": "hold", "kind": "approval", "ref": apfID}},
		{"op": "add_node", "node": map[string]any{"id": "gate", "kind": "control", "ref": pinCtl}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "hold"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "hold", "to": "gate", "fromPort": "yes"}},
	})

	runID := workflowC_startRun(t, wc, wfID)
	workflowC_waitParked(t, wc, runID, 15000)

	// edit while parked → v2 active on the ENTITY, but the run pinned v1 at start.
	// park 期间编辑 → 实体 active 指到 v2，但 run 起跑时已钉 v1。
	wc.POST("/api/v1/controls/"+pinCtl+":edit", map[string]any{"branches": []map[string]any{
		{"port": "out", "when": "true", "emit": map[string]string{"pinned": "'new'"}},
	}}).OK(t, nil)

	wc.POST("/api/v1/flowruns/"+runID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, runID, "completed", 20000)
	_, nodes := workflowC_run(t, wc, runID)
	if !strings.Contains(nodes, `"pinned":"old"`) {
		t.Fatalf("resumed run must evaluate the PINNED v1 control (emit old): %s", nodes)
	}
	if strings.Contains(nodes, `"pinned":"new"`) {
		t.Fatalf("in-flight run must NOT see the post-edit v2 branches: %s", nodes)
	}
}

// ---------------------------------------------------------------------------
// A-apv-3/4/6/8 — approval 空列表[]/versions cursor/软删名字复用/未知字段
// ---------------------------------------------------------------------------

func TestContractWorkflow_ApprovalListVersionsSoftDeleteUnknown(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "apvc-face")

	// A-apv-4: 零 approval 空列表必须是 [] 非 null。
	r := wc.GET("/api/v1/approvals")
	if r.Status != 200 || string(r.Data) != "[]" {
		t.Fatalf("empty approval list must be data:[] — got %d %s", r.Status, r.Raw)
	}

	apfID := wc.POST("/api/v1/approvals", map[string]any{"name": "cursor_apf", "template": "ok v1?"}).Field(t, "id")

	// versions shape: apfv_ id + back-link + v1.
	var vrows []struct {
		ID         string `json:"id"`
		ApprovalID string `json:"approvalId"`
		Version    int    `json:"version"`
	}
	wc.GET("/api/v1/approvals/"+apfID+"/versions").OK(t, &vrows)
	if len(vrows) != 1 || !strings.HasPrefix(vrows[0].ID, "apfv_") || vrows[0].ApprovalID != apfID || vrows[0].Version != 1 {
		t.Fatalf("approval version row shape wrong: %+v", vrows)
	}

	// A-apv-3: 2 edits → 3 versions; cursor walk at limit=1.
	for i := 2; i <= 3; i++ {
		wc.POST("/api/v1/approvals/"+apfID+":edit", map[string]any{"template": fmt.Sprintf("ok v%d?", i)}).OK(t, nil)
	}
	ids := workflowC_pageIDs(t, wc, "/api/v1/approvals/"+apfID+"/versions", 1)
	if len(ids) != 3 {
		t.Fatalf("approval versions cursor walk must yield 3, got %d: %v", len(ids), ids)
	}
	workflowC_assertDistinct(t, "approval versions", ids)

	// A-apv-6: dup name 409 → soft delete → 404/list 过滤 → 同名重建成功。
	wc.Do("POST", "/api/v1/approvals", map[string]any{"name": "cursor_apf", "template": "x"}).
		Fail(t, 409, "APPROVAL_NAME_DUPLICATE")
	if del := wc.DELETE("/api/v1/approvals/" + apfID); del.Status != 204 {
		t.Fatalf("DELETE must 204, got %d %s", del.Status, del.Raw)
	}
	wc.Do("GET", "/api/v1/approvals/"+apfID, nil).Fail(t, 404, "APPROVAL_NOT_FOUND")
	list := wc.GET("/api/v1/approvals")
	if strings.Contains(string(list.Data), apfID) {
		t.Fatalf("soft-deleted approval must not appear in list: %s", list.Data)
	}
	apfID2 := wc.POST("/api/v1/approvals", map[string]any{"name": "cursor_apf", "template": "reborn?"}).Field(t, "id")
	if apfID2 == apfID {
		t.Fatalf("recreated approval must get a fresh id")
	}

	// A-apv-8: unknown top-level field → 400 INVALID_REQUEST (create + PATCH).
	wc.Do("POST", "/api/v1/approvals", map[string]any{
		"name": "junk_apf", "template": "x", "bogusField": 1,
	}).Fail(t, 400, "INVALID_REQUEST")
	wc.Do("PATCH", "/api/v1/approvals/"+apfID2, map[string]any{"bogusField": 1}).Fail(t, 400, "INVALID_REQUEST")
}

// ---------------------------------------------------------------------------
// B-apf-9 (ParseTimeout d/w + 0s 拒) + A-apv-7 (:edit/:revert 面)
// ---------------------------------------------------------------------------

func TestContractWorkflow_ApprovalTimeoutParsingAndRevert(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "apvc-timeout")

	// B-apf-9: coarse units accepted + read back verbatim. 粗粒度单位接受 + 原样读回。
	for i, timeout := range []string{"2d", "1w"} {
		id := wc.POST("/api/v1/approvals", map[string]any{
			"name": fmt.Sprintf("coarse_%d", i), "template": "ok?",
			"timeout": timeout, "timeoutBehavior": "reject",
		}).Field(t, "id")
		var detail struct {
			ActiveVersion struct {
				Timeout         string `json:"timeout"`
				TimeoutBehavior string `json:"timeoutBehavior"`
			} `json:"activeVersion"`
		}
		wc.GET("/api/v1/approvals/"+id).OK(t, &detail)
		if detail.ActiveVersion.Timeout != timeout || detail.ActiveVersion.TimeoutBehavior != "reject" {
			t.Fatalf("timeout %q must read back verbatim: %+v", timeout, detail.ActiveVersion)
		}
	}

	// 显式零时长被拒（approval.md：会永 park 却配 behavior，用 "" 表永不）。
	wc.Do("POST", "/api/v1/approvals", map[string]any{
		"name": "zero_apf", "template": "x", "timeout": "0s", "timeoutBehavior": "reject",
	}).Fail(t, 422, "APPROVAL_INVALID_TIMEOUT")
	// 垃圾时长拒。
	wc.Do("POST", "/api/v1/approvals", map[string]any{
		"name": "garbage_apf", "template": "x", "timeout": "3fortnights", "timeoutBehavior": "reject",
	}).Fail(t, 422, "APPROVAL_INVALID_TIMEOUT")
	// timeout 非空必须配 behavior。
	wc.Do("POST", "/api/v1/approvals", map[string]any{
		"name": "nobehavior_apf", "template": "x", "timeout": "1d",
	}).Fail(t, 422, "APPROVAL_INVALID_TIMEOUT")

	// A-apv-7: :edit → v2; :revert → v1（模板读回验证指针真动了）。
	apfID := wc.POST("/api/v1/approvals", map[string]any{"name": "revert_apf", "template": "v1 body"}).Field(t, "id")
	wc.POST("/api/v1/approvals/"+apfID+":edit", map[string]any{"template": "v2 body"}).OK(t, nil)
	var detail struct {
		ActiveVersion struct {
			Version  int    `json:"version"`
			Template string `json:"template"`
		} `json:"activeVersion"`
	}
	wc.GET("/api/v1/approvals/"+apfID).OK(t, &detail)
	if detail.ActiveVersion.Version != 2 || detail.ActiveVersion.Template != "v2 body" {
		t.Fatalf(":edit must activate v2: %+v", detail.ActiveVersion)
	}
	var vr struct {
		Version int `json:"version"`
	}
	wc.POST("/api/v1/approvals/"+apfID+":revert", map[string]any{"version": 1}).OK(t, &vr)
	if vr.Version != 1 {
		t.Fatalf(":revert must return v1, got %d", vr.Version)
	}
	wc.GET("/api/v1/approvals/"+apfID).OK(t, &detail)
	if detail.ActiveVersion.Version != 1 || detail.ActiveVersion.Template != "v1 body" {
		t.Fatalf(":revert must restore v1 template: %+v", detail.ActiveVersion)
	}
}

// ---------------------------------------------------------------------------
// B-apf-4 — timeout=""=永不超时：长 park 不被任何定时器决策
// ---------------------------------------------------------------------------

func TestContractWorkflow_ApprovalEmptyTimeoutNeverDecides(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "apvc-forever")

	apfID := workflowC_apf(t, wc, "forever_gate") // timeout 未设 = ""
	wfID := workflowC_apfGraph(t, wc, "forever_wf", "trg_forever00000000", apfID)

	runID := workflowC_startRun(t, wc, wfID)
	workflowC_waitParked(t, wc, runID, 15000)

	// continuous observation window (~7s, covers >1 scheduler tick): the run must STAY
	// parked — no timer may decide it. This is a poll-loop that asserts on EVERY beat
	// (the inverse of Eventually), not a bare sleep-then-assert-once.
	// 连续观察窗（约 7s、覆盖 >1 个调度 tick）：run 必须一直 parked——不许任何定时器替它决策。
	// 每一拍都断言的轮询环（Eventually 的反面），非裸 sleep 后单点断言。
	for i := 0; i < 14; i++ {
		s, nodes := workflowC_run(t, wc, runID)
		if s != "running" || !strings.Contains(nodes, `"parked"`) {
			t.Fatalf("empty-timeout approval must stay parked forever; left at tick %d: status=%s nodes=%s", i, s, nodes)
		}
		time.Sleep(500 * time.Millisecond)
	}

	// still decidable by a human afterwards. 之后仍可人工决策。
	wc.POST("/api/v1/flowruns/"+runID+"/approvals/hold:decide", map[string]any{"decision": "no"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, runID, "completed", 20000)
}

// ---------------------------------------------------------------------------
// B-trg-5 — 引用计数监听：N active workflow 共享一个 listener（0→1 起、1→0 停）
// ---------------------------------------------------------------------------

func TestContractWorkflow_TriggerRefCountedListener(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "trgc-refcount")

	trgID := trgCreate(t, wc, "shared_hook", "webhook", map[string]any{"path": "shared"})
	wfA := workflowC_trgOnly(t, wc, "listener_a", trgID)
	wfB := workflowC_trgOnly(t, wc, "listener_b", trgID)
	hookURL := srv.BaseURL + "/api/v1/webhooks/" + trgID + "/shared"

	readTrg := func() (int, bool) {
		var trg struct {
			RefCount  int  `json:"refCount"`
			Listening bool `json:"listening"`
		}
		wc.GET("/api/v1/triggers/"+trgID).OK(t, &trg)
		return trg.RefCount, trg.Listening
	}

	// 0 listeners → webhook path unregistered → 404 (listener 只在 0→1 时启动).
	if code := workflowC_rawPost(t, hookURL, `{"n":0}`, nil); code != 404 {
		t.Fatalf("webhook with no listeners must 404, got %d", code)
	}
	if rc, ln := readTrg(); rc != 0 || ln {
		t.Fatalf("idle trigger must be refCount=0 listening=false, got %d/%v", rc, ln)
	}

	// activate both → one shared listener, refCount 2. 双激活 → 共享单 listener、计数 2。
	wc.POST("/api/v1/workflows/"+wfA+":activate", map[string]any{}).OK(t, nil)
	if rc, ln := readTrg(); rc != 1 || !ln {
		t.Fatalf("after first activate: want 1/true, got %d/%v", rc, ln)
	}
	wc.POST("/api/v1/workflows/"+wfB+":activate", map[string]any{}).OK(t, nil)
	if rc, ln := readTrg(); rc != 2 || !ln {
		t.Fatalf("after second activate: want 2/true, got %d/%v", rc, ln)
	}

	// one physical POST fans out to BOTH workflows. 一次 POST 扇给两个 workflow。
	if code := workflowC_rawPost(t, hookURL, `{"n":1}`, nil); code != 202 {
		t.Fatalf("webhook with listeners must 202, got %d", code)
	}
	harness.Eventually(t, 30000, "both listeners run from one fire", func() bool {
		return len(workflowC_runsOf(t, wc, wfA, "completed")) == 1 &&
			len(workflowC_runsOf(t, wc, wfB, "completed")) == 1
	})

	// 2→1: listener survives; only B runs on the next fire. 2→1：listener 活着、只有 B 跑。
	wc.POST("/api/v1/workflows/"+wfA+":deactivate", map[string]any{}).OK(t, nil)
	if rc, ln := readTrg(); rc != 1 || !ln {
		t.Fatalf("after one deactivate: want 1/true, got %d/%v", rc, ln)
	}
	if code := workflowC_rawPost(t, hookURL, `{"n":2}`, nil); code != 202 {
		t.Fatalf("webhook with one listener left must 202, got %d", code)
	}
	harness.Eventually(t, 30000, "only B runs after A deactivated", func() bool {
		return len(workflowC_runsOf(t, wc, wfB, "completed")) == 2
	})
	if n := len(workflowC_runsOf(t, wc, wfA, "")); n != 1 {
		t.Fatalf("deactivated A must not gain runs: %d", n)
	}

	// 1→0: listener stops; path 404s again. 1→0：listener 停、路径重回 404。
	wc.POST("/api/v1/workflows/"+wfB+":deactivate", map[string]any{}).OK(t, nil)
	if rc, ln := readTrg(); rc != 0 || ln {
		t.Fatalf("after all deactivated: want 0/false, got %d/%v", rc, ln)
	}
	if code := workflowC_rawPost(t, hookURL, `{"n":3}`, nil); code != 404 {
		t.Fatalf("webhook after all listeners gone must 404, got %d", code)
	}
}

// B-wf-13/B-trg-9 — 多入口 trigger 的挂载去重、重复激活幂等、全量解绑。
// Multi-trigger workflows must attach every distinct trigger ref exactly once; a duplicate
// trigger node must not inflate the listener refcount. Re-activating the same workflow is also
// idempotent, and deactivation must detach every entry so both webhook paths go cold.
//
// B-wf-13/B-trg-9 —— 多入口 trigger 的挂载去重、重复激活幂等、全量解绑：workflow 图里每个不同
// trigger ref 恰挂一次；同 ref 的重复 trigger 节点不得把 listener refcount 撑大；重复激活不重复计数；
// 停用必须摘掉全部入口，使两个 webhook 路径都回到 404。
func TestContractWorkflow_MultiTriggerAttachDetachAndDedup(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-multi-trigger")

	trgA := trgCreate(t, wc, "multi_a", "webhook", map[string]any{"path": "multi-a"})
	trgB := trgCreate(t, wc, "multi_b", "webhook", map[string]any{"path": "multi-b"})
	// The duplicate A node is intentional: entryTriggerRefsOf must dedupe entity refs while the
	// scheduler still resolves a firing to one concrete entry node.
	wfID := wfCreate(t, wc, "multi_entry_wf", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "entry_a1", "kind": "trigger", "ref": trgA}},
		{"op": "add_node", "node": map[string]any{"id": "entry_a2", "kind": "trigger", "ref": trgA}},
		{"op": "add_node", "node": map[string]any{"id": "entry_b", "kind": "trigger", "ref": trgB}},
	})

	readRefCount := func(triggerID string) (int, bool) {
		t.Helper()
		var got struct {
			RefCount  int  `json:"refCount"`
			Listening bool `json:"listening"`
		}
		wc.GET("/api/v1/triggers/"+triggerID).OK(t, &got)
		return got.RefCount, got.Listening
	}
	assertHot := func(triggerID string, wantCount int) {
		t.Helper()
		if rc, listening := readRefCount(triggerID); rc != wantCount || listening != (wantCount > 0) {
			t.Fatalf("trigger %s runtime projection: want %d/%v, got %d/%v", triggerID, wantCount, wantCount > 0, rc, listening)
		}
	}

	// Both distinct refs attach, but the duplicate A node contributes only one reference.
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)
	assertHot(trgA, 1)
	assertHot(trgB, 1)
	// The lifecycle endpoint is idempotent: no second workflow reference is created.
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)
	assertHot(trgA, 1)
	assertHot(trgB, 1)

	urlA := srv.BaseURL + "/api/v1/webhooks/" + trgA + "/multi-a"
	urlB := srv.BaseURL + "/api/v1/webhooks/" + trgB + "/multi-b"
	if code := workflowC_rawPost(t, urlA, `{"entry":"a"}`, nil); code != 202 {
		t.Fatalf("active multi-trigger A path must return 202, got %d", code)
	}
	harness.Eventually(t, 30000, "A entry creates the first run", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 1
	})
	if code := workflowC_rawPost(t, urlB, `{"entry":"b"}`, nil); code != 202 {
		t.Fatalf("active multi-trigger B path must return 202, got %d", code)
	}
	harness.Eventually(t, 30000, "B entry creates the second run", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 2
	})

	// Deactivation must detach every distinct entry, including the one that had a duplicate node.
	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, nil)
	assertHot(trgA, 0)
	assertHot(trgB, 0)
	if code := workflowC_rawPost(t, urlA, `{"entry":"a-off"}`, nil); code != 404 {
		t.Fatalf("deactivated A path must return 404, got %d", code)
	}
	if code := workflowC_rawPost(t, urlB, `{"entry":"b-off"}`, nil); code != 404 {
		t.Fatalf("deactivated B path must return 404, got %d", code)
	}
}

// B-wf-15/B-trg-11 — trigger 软删后的 active workflow 悬空引用可审计、可通过 edit rebind 修复。
// Deleting a source stops its listener but keeps the workflow row/history. Capability-check must
// expose the dangling ref; recreating the trigger with the same name is not an implicit rebind.
// Explicitly editing the workflow ref should reattach the live workflow to the new source.
//
// B-wf-15/B-trg-11 —— trigger 软删后 active workflow 的悬空 ref 可被审计、可经 edit rebind 修复：删源
// 必须停 listener 但保留 workflow 行/历史；capability-check 大声报 dangling；同名重建不暗中换绑，只有
// 显式 edit workflow ref 才重挂 active listener。
func TestContractWorkflow_DeletedTriggerRebindsActiveWorkflow(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-trigger-rebind")

	oldTrigger := trgCreate(t, wc, "rebind_source", "webhook", map[string]any{"path": "rebind-old"})
	wfID := workflowC_trgOnly(t, wc, "rebind_after_delete", oldTrigger)
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)
	oldURL := srv.BaseURL + "/api/v1/webhooks/" + oldTrigger + "/rebind-old"
	if code := workflowC_rawPost(t, oldURL, `{"generation":1}`, nil); code != 202 {
		t.Fatalf("baseline webhook must return 202, got %d", code)
	}
	harness.Eventually(t, 30000, "baseline run completes before source deletion", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 1
	})

	if r := wc.DELETE("/api/v1/triggers/" + oldTrigger); r.Status != 204 {
		t.Fatalf("soft-delete active trigger must 204, got %d %s", r.Status, r.Raw)
	}
	if code := workflowC_rawPost(t, oldURL, `{"generation":2}`, nil); code != 404 {
		t.Fatalf("deleted trigger path must stop immediately, got %d", code)
	}
	wc.Do("GET", "/api/v1/triggers/"+oldTrigger, nil).Fail(t, 404, "TRIGGER_NOT_FOUND")

	// The workflow remains a durable entity, but its capability report must not pretend the old
	// trigger ref still resolves. This is the repair hand-off, not a silent success state.
	var report struct {
		Resolved bool     `json:"resolved"`
		Problems []string `json:"problems"`
	}
	wc.POST("/api/v1/workflows/"+wfID+":capability-check", map[string]any{}).OK(t, &report)
	if len(report.Problems) == 0 {
		t.Fatalf("deleted trigger must remain auditable as a dangling workflow ref: %+v", report)
	}

	// Same-name recreation gets a fresh id and does not implicitly retarget the old graph.
	newTrigger := trgCreate(t, wc, "rebind_source", "webhook", map[string]any{"path": "rebind-new"})
	if newTrigger == oldTrigger {
		t.Fatalf("recreated trigger must get a fresh id after soft delete")
	}
	newURL := srv.BaseURL + "/api/v1/webhooks/" + newTrigger + "/rebind-new"
	if code := workflowC_rawPost(t, newURL, `{"generation":3}`, nil); code != 404 {
		t.Fatalf("recreated trigger must stay cold until workflow rebind, got %d", code)
	}

	wc.POST("/api/v1/workflows/"+wfID+":edit", map[string]any{"ops": []map[string]any{
		{"op": "update_node", "id": "start", "patch": map[string]any{"ref": newTrigger}},
	}}).OK(t, nil)
	var newRuntime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &newRuntime)
	if newRuntime.RefCount != 1 || !newRuntime.Listening {
		t.Fatalf("editing an active workflow onto the new trigger must rebind listener, got %+v", newRuntime)
	}
	var reboundReport struct {
		Resolved bool     `json:"resolved"`
		Problems []string `json:"problems"`
	}
	wc.POST("/api/v1/workflows/"+wfID+":capability-check", map[string]any{}).OK(t, &reboundReport)
	if !reboundReport.Resolved || len(reboundReport.Problems) != 0 {
		t.Fatalf("explicit rebind must repair capability report: %+v", reboundReport)
	}
	if code := workflowC_rawPost(t, newURL, `{"generation":4}`, nil); code != 202 {
		t.Fatalf("rebound trigger path must return 202, got %d", code)
	}
	harness.Eventually(t, 30000, "rebound source creates the second run", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 2
	})

	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, nil)
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &newRuntime)
	if newRuntime.RefCount != 0 || newRuntime.Listening {
		t.Fatalf("deactivate after rebind must detach the replacement trigger, got %+v", newRuntime)
	}
}

// B-wf-15/B-trg-11 (restart half) — a deleted trigger's dangling active workflow survives a hard
// restart as an explicit repair state: boot must not resurrect the old path or silently bind a
// same-name replacement. Only an explicit workflow edit may reattach the listener after restart.
//
// B-wf-15/B-trg-11（重启半边）——删 trigger 后 active workflow 的悬空状态跨硬重启保留；boot 不得复活旧
// path，也不得把同名新 trigger 暗中换绑。只有显式 edit workflow 才能在重启后重新挂 listener。
func TestContractWorkflow_DeletedTriggerRebindsAfterRestart(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-trigger-rebind-restart")
	wsID := wc.WorkspaceID()

	oldTrigger := trgCreate(t, wc, "rebind_restart_source", "webhook", map[string]any{"path": "rebind-restart-old"})
	wfID := workflowC_trgOnly(t, wc, "rebind_restart_workflow", oldTrigger)
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)
	oldURL := srv.BaseURL + "/api/v1/webhooks/" + oldTrigger + "/rebind-restart-old"
	if code := workflowC_rawPost(t, oldURL, `{"generation":1}`, nil); code != 202 {
		t.Fatalf("baseline webhook must return 202, got %d", code)
	}
	harness.Eventually(t, 30000, "baseline restart-rebind run completes", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 1
	})

	if r := wc.DELETE("/api/v1/triggers/" + oldTrigger); r.Status != 204 {
		t.Fatalf("delete source before restart must 204, got %d %s", r.Status, r.Raw)
	}
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)
	if code := workflowC_rawPost(t, oldURL, `{"generation":2}`, nil); code != 404 {
		t.Fatalf("old webhook path must stay cold after restart, got %d", code)
	}
	var wf struct {
		Active         bool   `json:"active"`
		LifecycleState string `json:"lifecycleState"`
	}
	wc.GET("/api/v1/workflows/"+wfID).OK(t, &wf)
	if !wf.Active || wf.LifecycleState != "active" {
		t.Fatalf("deleted-trigger workflow should remain an explicitly active repair state, got %+v", wf)
	}

	newTrigger := trgCreate(t, wc, "rebind_restart_source", "webhook", map[string]any{"path": "rebind-restart-new"})
	newURL := srv.BaseURL + "/api/v1/webhooks/" + newTrigger + "/rebind-restart-new"
	var runtime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &runtime)
	if runtime.RefCount != 0 || runtime.Listening {
		t.Fatalf("same-name replacement must stay cold after restart, got %+v", runtime)
	}
	wc.Do("POST", "/api/v1/workflows/"+wfID+":activate", map[string]any{}).Fail(t, 422, "WORKFLOW_NOT_RUNNABLE")
	if code := workflowC_rawPost(t, newURL, `{"generation":3}`, nil); code != 404 {
		t.Fatalf("replacement path must stay cold before explicit edit, got %d", code)
	}

	wc.POST("/api/v1/workflows/"+wfID+":edit", map[string]any{"ops": []map[string]any{
		{"op": "update_node", "id": "start", "patch": map[string]any{"ref": newTrigger}},
	}}).OK(t, nil)
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &runtime)
	if runtime.RefCount != 1 || !runtime.Listening {
		t.Fatalf("explicit post-restart rebind must attach replacement listener, got %+v", runtime)
	}
	var report struct {
		Resolved bool     `json:"resolved"`
		Problems []string `json:"problems"`
	}
	wc.POST("/api/v1/workflows/"+wfID+":capability-check", map[string]any{}).OK(t, &report)
	if !report.Resolved || len(report.Problems) != 0 {
		t.Fatalf("post-restart explicit rebind must repair capability report: %+v", report)
	}
	if code := workflowC_rawPost(t, newURL, `{"generation":4}`, nil); code != 202 {
		t.Fatalf("rebound replacement path must return 202, got %d", code)
	}
	harness.Eventually(t, 30000, "post-restart rebound run completes", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 2
	})
	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, nil)
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &runtime)
	if runtime.RefCount != 0 || runtime.Listening {
		t.Fatalf("post-restart deactivate must detach replacement listener, got %+v", runtime)
	}
}

// B-wf-20/B-trg-15 — deleting the source does not erase an event that was already accepted into
// the durable inbox. A pending firing remains a valid historical event: after the parked first run
// settles, the second run starts against the pinned graph even though trigger provenance is now
// unavailable (origin is omitted), and the deleted source path stays cold for future events.
//
// B-wf-20/B-trg-15 —— 删除 trigger 不抹掉已落入 durable inbox 的事件。pending firing 仍是合法历史：第一条
// parked run 结算后，第二条用已 pin 的图启动；但 trigger 已删，溯源 origin 诚实缺席。未来事件入口保持冷。
func TestContractWorkflow_DeletedTriggerKeepsAcceptedFiring(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-trigger-delete-accepted")

	trgID := trgCreate(t, wc, "accepted_trigger_hook", "webhook", map[string]any{"path": "accepted-trigger"})
	apfID := workflowC_apf(t, wc, "accepted_trigger_gate")
	wfID := workflowC_apfGraph(t, wc, "accepted_trigger_workflow", trgID, apfID,
		map[string]any{"op": "set_meta", "concurrency": "serial"})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	fireConcurrencyWebhook(t, srv, trgID, "accepted-trigger", `{"seq":1}`)
	var firstRunID string
	harness.Eventually(t, 20000, "first accepted run parks", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 {
			return false
		}
		firstRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, firstRunID)
		return strings.Contains(nodes, `"parked"`)
	})
	fireConcurrencyWebhook(t, srv, trgID, "accepted-trigger", `{"seq":2}`)
	harness.Eventually(t, 20000, "second accepted firing is pending", func() bool {
		rows := listConcurrencyFirings(t, wc, trgID)
		counts := countFiringStatuses(rows)
		return len(rows) == 2 && counts["started"] == 1 && counts["pending"] == 1
	})

	oldURL := srv.BaseURL + "/api/v1/webhooks/" + trgID + "/accepted-trigger"
	if r := wc.DELETE("/api/v1/triggers/" + trgID); r.Status != 204 {
		t.Fatalf("delete source with accepted firing must 204, got %d %s", r.Status, r.Raw)
	}
	wc.Do("GET", "/api/v1/triggers/"+trgID, nil).Fail(t, 404, "TRIGGER_NOT_FOUND")
	if code := workflowC_rawPost(t, oldURL, `{"seq":3}`, nil); code != 404 {
		t.Fatalf("deleted source path must reject future events, got %d", code)
	}

	// Resolve the first run through the public human decision path; the second pending firing should
	// then be released by the next scheduler drain despite its source entity being gone.
	wc.POST("/api/v1/flowruns/"+firstRunID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, firstRunID, "completed", 20000)
	var secondRunID string
	harness.Eventually(t, 30000, "accepted firing starts after trigger deletion", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 || runs[0].ID == firstRunID {
			return false
		}
		secondRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, secondRunID)
		return strings.Contains(nodes, `"parked"`)
	})
	var secondDetail struct {
		Flowrun struct {
			TriggerID string  `json:"triggerId"`
			Origin    *string `json:"origin"`
		} `json:"flowrun"`
	}
	wc.GET("/api/v1/flowruns/"+secondRunID).OK(t, &secondDetail)
	if secondDetail.Flowrun.TriggerID != trgID || secondDetail.Flowrun.Origin != nil {
		t.Fatalf("run from deleted trigger must retain trigger id but omit unavailable origin: %+v", secondDetail.Flowrun)
	}
	wc.POST("/api/v1/flowruns/"+secondRunID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, secondRunID, "completed", 20000)

	finalFirings := listFirings(t, wc, trgID, "limit=50")
	if len(finalFirings) != 2 {
		t.Fatalf("accepted firing audit must survive trigger deletion, got %+v", finalFirings)
	}
	for _, firing := range finalFirings {
		if firing.Status != "started" || firing.WorkflowID != wfID || firing.FlowrunID == "" {
			t.Fatalf("both accepted firings must remain started and linked after source delete, got %+v", finalFirings)
		}
	}
	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, nil)
}

// B-wf-21/B-trg-16 — the accepted-firing guarantee crosses a hard process restart. The source is
// deleted before boot, so replay leaves an active workflow in explicit dangling-repair state; the
// parked run and pending inbox row must nevertheless survive and drain exactly once afterwards.
//
// B-wf-21/B-trg-16 —— 已接受 firing 的保证跨硬重启仍成立。boot 前先删 source，重放后 workflow 保持
// 明确的 dangling-repair 状态；停泊 run 与 pending inbox 行仍须存活，并在之后恰好消费一次。
func TestContractWorkflow_DeletedTriggerAcceptedFiringSurvivesRestart(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-trigger-delete-accepted-restart")
	wsID := wc.WorkspaceID()

	trgID := trgCreate(t, wc, "accepted_restart_trigger", "webhook", map[string]any{"path": "accepted-restart"})
	apfID := workflowC_apf(t, wc, "accepted_restart_gate")
	wfID := workflowC_apfGraph(t, wc, "accepted_restart_workflow", trgID, apfID,
		map[string]any{"op": "set_meta", "concurrency": "serial"})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	fireConcurrencyWebhook(t, srv, trgID, "accepted-restart", `{"seq":1}`)
	var firstRunID string
	harness.Eventually(t, 20000, "first restart-accepted run parks", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 {
			return false
		}
		firstRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, firstRunID)
		return strings.Contains(nodes, `"parked"`)
	})
	fireConcurrencyWebhook(t, srv, trgID, "accepted-restart", `{"seq":2}`)
	harness.Eventually(t, 20000, "restart-accepted second firing is pending", func() bool {
		rows := listConcurrencyFirings(t, wc, trgID)
		counts := countFiringStatuses(rows)
		return len(rows) == 2 && counts["started"] == 1 && counts["pending"] == 1
	})

	if r := wc.DELETE("/api/v1/triggers/" + trgID); r.Status != 204 {
		t.Fatalf("delete source before accepted-firing restart must 204, got %d %s", r.Status, r.Raw)
	}
	srv.Kill9(t)
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)

	// Boot replay must preserve the active repair state but never resurrect a deleted source path.
	var wf struct {
		Active         bool   `json:"active"`
		LifecycleState string `json:"lifecycleState"`
	}
	wc.GET("/api/v1/workflows/"+wfID).OK(t, &wf)
	if !wf.Active || wf.LifecycleState != "active" {
		t.Fatalf("accepted-firing workflow must survive restart as active repair state, got %+v", wf)
	}
	if code := workflowC_rawPost(t, srv.BaseURL+"/api/v1/webhooks/"+trgID+"/accepted-restart", `{"seq":3}`, nil); code != 404 {
		t.Fatalf("deleted source path must stay cold after accepted-firing restart, got %d", code)
	}
	if rows := listFirings(t, wc, trgID, "limit=50"); len(rows) != 2 {
		t.Fatalf("restart must retain both accepted firing rows before drain, got %+v", rows)
	}
	wc.Do("POST", "/api/v1/workflows/"+wfID+":activate", map[string]any{}).Fail(t, 422, "WORKFLOW_NOT_RUNNABLE")

	// The parked run is durable across SIGKILL. Resolve it, then let the scheduler drain the old
	// pending firing once; the deleted trigger only affects optional provenance metadata.
	workflowC_waitParked(t, wc, firstRunID, 20000)
	wc.POST("/api/v1/flowruns/"+firstRunID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, firstRunID, "completed", 20000)
	var secondRunID string
	harness.Eventually(t, 30000, "restart-accepted firing drains after trigger deletion", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 || runs[0].ID == firstRunID {
			return false
		}
		secondRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, secondRunID)
		return strings.Contains(nodes, `"parked"`)
	})
	var secondDetail struct {
		Flowrun struct {
			TriggerID string  `json:"triggerId"`
			Origin    *string `json:"origin"`
		} `json:"flowrun"`
	}
	wc.GET("/api/v1/flowruns/"+secondRunID).OK(t, &secondDetail)
	if secondDetail.Flowrun.TriggerID != trgID || secondDetail.Flowrun.Origin != nil {
		t.Fatalf("post-restart run must retain deleted trigger id but omit unavailable origin: %+v", secondDetail.Flowrun)
	}
	wc.POST("/api/v1/flowruns/"+secondRunID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, secondRunID, "completed", 20000)

	finalFirings := listFirings(t, wc, trgID, "limit=50")
	if len(finalFirings) != 2 {
		t.Fatalf("restart must not duplicate or erase accepted firing audit, got %+v", finalFirings)
	}
	for _, firing := range finalFirings {
		if firing.Status != "started" || firing.WorkflowID != wfID || firing.FlowrunID == "" {
			t.Fatalf("both post-restart accepted firings must remain started and linked, got %+v", finalFirings)
		}
	}
	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, nil)
}

// B-wf-22/B-trg-17 — an accepted firing whose source is removed from the active graph must not
// spin forever in pending. Editing an active workflow hot-swaps the listener to a new trigger; the
// old parked run keeps its pin, while the older queued event has no legal entry in the new graph and
// must settle as neutral `shed` rather than retrying every drain tick.
//
// B-wf-22/B-trg-17 —— 已接受但其 source 已从 active 图移除的 firing 不得永久 pending 自旋。active workflow
// 编辑会把 listener 热换到新 trigger；旧停泊 run 保持自己的 pin，而旧排队事件在新图中没有合法入口，须中性
// 终结为 `shed`，不能每个 drain tick 重试。
func TestContractWorkflow_PendingFiringShedsAfterEntryRebind(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-trigger-rebind-pending")

	oldTrigger := trgCreate(t, wc, "pending_old_trigger", "webhook", map[string]any{"path": "pending-old"})
	newTrigger := trgCreate(t, wc, "pending_new_trigger", "webhook", map[string]any{"path": "pending-new"})
	apfID := workflowC_apf(t, wc, "pending_rebind_gate")
	wfID := workflowC_apfGraph(t, wc, "pending_rebind_workflow", oldTrigger, apfID,
		map[string]any{"op": "set_meta", "concurrency": "serial"})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	fireConcurrencyWebhook(t, srv, oldTrigger, "pending-old", `{"seq":1}`)
	var firstRunID string
	harness.Eventually(t, 20000, "rebind-pending first run parks", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 {
			return false
		}
		firstRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, firstRunID)
		return strings.Contains(nodes, `"parked"`)
	})
	fireConcurrencyWebhook(t, srv, oldTrigger, "pending-old", `{"seq":2}`)
	harness.Eventually(t, 20000, "rebind-pending second firing is pending", func() bool {
		rows := listConcurrencyFirings(t, wc, oldTrigger)
		counts := countFiringStatuses(rows)
		return len(rows) == 2 && counts["started"] == 1 && counts["pending"] == 1
	})

	wc.POST("/api/v1/workflows/"+wfID+":edit", map[string]any{"ops": []map[string]any{
		{"op": "update_node", "id": "start", "patch": map[string]any{"ref": newTrigger}},
	}}).OK(t, nil)
	var oldRuntime, newRuntime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+oldTrigger).OK(t, &oldRuntime)
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &newRuntime)
	if oldRuntime.RefCount != 0 || oldRuntime.Listening || newRuntime.RefCount != 1 || !newRuntime.Listening {
		t.Fatalf("active edit must move listener old→new before pending drain: old=%+v new=%+v", oldRuntime, newRuntime)
	}
	if code := workflowC_rawPost(t, srv.BaseURL+"/api/v1/webhooks/"+oldTrigger+"/pending-old", `{"seq":3}`, nil); code != 404 {
		t.Fatalf("old source path must be cold after entry rebind, got %d", code)
	}

	wc.POST("/api/v1/flowruns/"+firstRunID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, firstRunID, "completed", 20000)
	var finalFirings []firingRow
	harness.Eventually(t, 15000, "old pending firing settles after entry rebind", func() bool {
		finalFirings = listFirings(t, wc, oldTrigger, "limit=50")
		counts := map[string]int{}
		for _, firing := range finalFirings {
			counts[firing.Status]++
		}
		return len(finalFirings) == 2 && counts["started"] == 1 && counts["shed"] == 1
	})
	if rows := workflowC_runsOf(t, wc, wfID, ""); len(rows) != 1 || rows[0].ID != firstRunID {
		t.Fatalf("a firing with no entry in the fresh graph must not create a phantom run, got %+v", rows)
	}
	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, nil)
}

// B-wf-23/B-trg-18 — a queued firing follows the active graph pointer across an edit→revert
// round-trip and a hard restart. The parked first run keeps its original topology pin; the
// pending second firing is not consumed while the listener is temporarily rebound to the new
// trigger, then drains exactly once after the old entry is restored.
//
// B-wf-23/B-trg-18 —— 排队 firing 穿过 edit→revert 与硬重启仍跟随 active 图指针。第一条停泊 run
// 保持起跑时的拓扑 pin；监听临时换到新 trigger 期间，第二条 pending 不被错误消费；旧入口恢复后，
// 重启仍只消费一次并闭合两条 firing/run 审计。
func TestContractWorkflow_PendingFiringFollowsActiveRevertAcrossRestart(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "wfc-revert-pending"}).OK(t, nil).Field(t, "id")
	wc := c.WS(wsID)

	oldTrigger := trgCreate(t, wc, "revert_old_trigger", "webhook", map[string]any{"path": "revert-old"})
	newTrigger := trgCreate(t, wc, "revert_new_trigger", "webhook", map[string]any{"path": "revert-new"})
	apfID := workflowC_apf(t, wc, "revert_pending_gate")
	wfID := workflowC_apfGraph(t, wc, "revert_pending_workflow", oldTrigger, apfID,
		map[string]any{"op": "set_meta", "concurrency": "serial"})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	fireConcurrencyWebhook(t, srv, oldTrigger, "revert-old", `{"seq":1}`)
	var firstRunID string
	harness.Eventually(t, 20000, "revert-pending first run parks", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 {
			return false
		}
		firstRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, firstRunID)
		return strings.Contains(nodes, `"parked"`)
	})

	var firstHeader struct {
		Flowrun struct {
			VersionID string `json:"versionId"`
		} `json:"flowrun"`
	}
	wc.GET("/api/v1/flowruns/"+firstRunID).OK(t, &firstHeader)
	if firstHeader.Flowrun.VersionID == "" {
		t.Fatalf("parked run must expose its frozen workflow version: %+v", firstHeader.Flowrun)
	}
	firstVersionID := firstHeader.Flowrun.VersionID

	fireConcurrencyWebhook(t, srv, oldTrigger, "revert-old", `{"seq":2}`)
	harness.Eventually(t, 20000, "revert-pending second firing is pending", func() bool {
		rows := listConcurrencyFirings(t, wc, oldTrigger)
		counts := countFiringStatuses(rows)
		return len(rows) == 2 && counts["started"] == 1 && counts["pending"] == 1
	})

	// Edit the active graph to the new entry, then immediately revert to v1 before the parked
	// run is decided. Both operations must update the live listener projection, not only the row.
	// active 图先编辑到新入口，再在停泊 run 结算前回 v1；两次都必须同步真实 listener。
	wc.POST("/api/v1/workflows/"+wfID+":edit", map[string]any{"ops": []map[string]any{
		{"op": "update_node", "id": "start", "patch": map[string]any{"ref": newTrigger}},
	}}).OK(t, nil)
	state, active, version := workflowC_wfState(t, wc, wfID)
	if state != "active" || !active || version != 2 {
		t.Fatalf("active edit must move pointer to v2 without leaving active state: state=%q active=%v version=%d", state, active, version)
	}
	var oldRuntime, newRuntime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+oldTrigger).OK(t, &oldRuntime)
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &newRuntime)
	if oldRuntime.RefCount != 0 || oldRuntime.Listening || newRuntime.RefCount != 1 || !newRuntime.Listening {
		t.Fatalf("edit must move listener old→new: old=%+v new=%+v", oldRuntime, newRuntime)
	}

	var reverted struct {
		Version int `json:"version"`
	}
	wc.POST("/api/v1/workflows/"+wfID+":revert", map[string]any{"version": 1}).OK(t, &reverted)
	if reverted.Version != 1 {
		t.Fatalf(":revert must select v1, got %+v", reverted)
	}
	state, active, version = workflowC_wfState(t, wc, wfID)
	if state != "active" || !active || version != 1 {
		t.Fatalf(":revert must restore v1 while remaining active: state=%q active=%v version=%d", state, active, version)
	}
	oldRuntime, newRuntime = struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}{}, struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}{}
	wc.GET("/api/v1/triggers/"+oldTrigger).OK(t, &oldRuntime)
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &newRuntime)
	if oldRuntime.RefCount != 1 || !oldRuntime.Listening || newRuntime.RefCount != 0 || newRuntime.Listening {
		t.Fatalf("revert must move listener new→old: old=%+v new=%+v", oldRuntime, newRuntime)
	}
	rows := listConcurrencyFirings(t, wc, oldTrigger)
	counts := countFiringStatuses(rows)
	if len(rows) != 2 || counts["started"] != 1 || counts["pending"] != 1 {
		t.Fatalf("edit→revert must preserve the queued firing: %+v", rows)
	}

	// Boot must reattach the CURRENT (reverted) graph, preserve the parked/pending inbox, and not
	// create a duplicate run while rebuilding scheduler state.
	// 重启必须按当前（已回 v1）图恢复 listener，保留 parked/pending inbox，且不得重复铸造 run。
	srv.Kill9(t)
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)
	state, active, version = workflowC_wfState(t, wc, wfID)
	if state != "active" || !active || version != 1 {
		t.Fatalf("restart must preserve active reverted workflow: state=%q active=%v version=%d", state, active, version)
	}
	oldRuntime, newRuntime = struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}{}, struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}{}
	wc.GET("/api/v1/triggers/"+oldTrigger).OK(t, &oldRuntime)
	wc.GET("/api/v1/triggers/"+newTrigger).OK(t, &newRuntime)
	if oldRuntime.RefCount != 1 || !oldRuntime.Listening || newRuntime.RefCount != 0 || newRuntime.Listening {
		t.Fatalf("restart must reattach reverted listener only: old=%+v new=%+v", oldRuntime, newRuntime)
	}
	rows = listConcurrencyFirings(t, wc, oldTrigger)
	counts = countFiringStatuses(rows)
	if len(rows) != 2 || counts["started"] != 1 || counts["pending"] != 1 {
		t.Fatalf("restart must preserve exactly one pending firing: %+v", rows)
	}
	if len(workflowC_runsOf(t, wc, wfID, "")) != 1 {
		t.Fatalf("restart must not duplicate the parked run")
	}

	wc.POST("/api/v1/flowruns/"+firstRunID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, firstRunID, "completed", 20000)
	var secondRunID, secondVersionID string
	harness.Eventually(t, 25000, "reverted pending firing starts one run", func() bool {
		var runs []struct {
			ID        string `json:"id"`
			Status    string `json:"status"`
			VersionID string `json:"versionId"`
		}
		wc.GET("/api/v1/flowruns?workflowId="+wfID).OK(t, &runs)
		if len(runs) != 2 {
			return false
		}
		for _, run := range runs {
			if run.ID != firstRunID && run.Status == "running" {
				_, nodes := workflowC_run(t, wc, run.ID)
				if strings.Contains(nodes, `"parked"`) {
					secondRunID, secondVersionID = run.ID, run.VersionID
					return true
				}
			}
		}
		return false
	})
	if secondVersionID != firstVersionID {
		t.Fatalf("pending firing claimed after revert must pin active v1: first=%q second=%q", firstVersionID, secondVersionID)
	}
	wc.POST("/api/v1/flowruns/"+secondRunID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
	workflowC_waitRunStatus(t, wc, secondRunID, "completed", 20000)

	finalFirings := listFirings(t, wc, oldTrigger, "limit=50")
	if len(finalFirings) != 2 {
		t.Fatalf("edit→revert→restart must leave exactly two firing rows, got %+v", finalFirings)
	}
	for _, firing := range finalFirings {
		if firing.Status != "started" || firing.WorkflowID != wfID || firing.FlowrunID == "" {
			t.Fatalf("every accepted firing must finish started and link its workflow/run: %+v", finalFirings)
		}
	}
	if len(workflowC_runsOf(t, wc, wfID, "completed")) != 2 {
		t.Fatalf("both reverted serial runs must complete exactly once, got %+v", workflowC_runsOf(t, wc, wfID, ""))
	}
	wc.POST("/api/v1/workflows/"+wfID+":deactivate", map[string]any{}).OK(t, nil)
}

// B-wf-16/B-trg-12 — deleting an active workflow must detach its live trigger listeners without
// erasing the workflow's durable run/history log. Reusing the workflow name on the same trigger
// must not inherit a stale listener from the deleted workflow.
//
// B-wf-16/B-trg-12 —— 删除 active workflow 必须摘掉 live trigger listener，但不抹掉 durable run/历史账；
// 同 trigger 复用 workflow 名时不能继承已删 workflow 的悬空 listener。
func TestContractWorkflow_DeletedActiveWorkflowDetachesTriggerAndKeepsLogs(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-workflow-delete-runtime")

	trgID := trgCreate(t, wc, "delete_workflow_hook", "webhook", map[string]any{"path": "delete-workflow"})
	wfID := workflowC_trgOnly(t, wc, "delete_workflow", trgID)
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	aid := workflowC_fire(t, wc, trgID)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 1 {
		t.Fatalf("baseline trigger fire must fan out to one workflow, got %d", n)
	}
	harness.Eventually(t, 30000, "baseline workflow run completes", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 1
	})
	baselineRuns := workflowC_runsOf(t, wc, wfID, "")
	if len(baselineRuns) != 1 {
		t.Fatalf("baseline history must contain one run, got %+v", baselineRuns)
	}
	baselineRunID := baselineRuns[0].ID

	if r := wc.DELETE("/api/v1/workflows/" + wfID); r.Status != 204 {
		t.Fatalf("delete active workflow must 204, got %d %s", r.Status, r.Raw)
	}
	wc.Do("GET", "/api/v1/workflows/"+wfID, nil).Fail(t, 404, "WORKFLOW_NOT_FOUND")
	var deletedVersions []struct {
		ID      string `json:"id"`
		Version int    `json:"version"`
	}
	wc.GET("/api/v1/workflows/"+wfID+"/versions").OK(t, &deletedVersions)
	if len(deletedVersions) != 1 || deletedVersions[0].Version != 1 {
		t.Fatalf("soft-delete must retain immutable version history for audit, got %+v", deletedVersions)
	}

	var runtime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+trgID).OK(t, &runtime)
	if runtime.RefCount != 0 || runtime.Listening {
		t.Fatalf("deleting active workflow must detach its trigger listener, got %+v", runtime)
	}
	if code := workflowC_rawPost(t, srv.BaseURL+"/api/v1/webhooks/"+trgID+"/delete-workflow", `{"after":"delete"}`, nil); code != 404 {
		t.Fatalf("webhook must go cold after workflow deletion, got %d", code)
	}

	// The trigger entity remains usable as a source, but with no workflow listener its explicit fire
	// must produce an auditable zero-fanout activation and no phantom run for the deleted workflow.
	aid = workflowC_fire(t, wc, trgID)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 0 {
		t.Fatalf("fire after deleting its only workflow must fan out to zero, got %d", n)
	}
	if rows := workflowC_runsOf(t, wc, wfID, ""); len(rows) != 1 {
		t.Fatalf("deleted workflow must not gain a phantom run, got %+v", rows)
	}
	if r := wc.GET("/api/v1/flowruns/" + baselineRunID); r.Status != 200 {
		t.Fatalf("durable run history must survive workflow soft-delete, got %d %s", r.Status, r.Raw)
	}

	// Reusing the workflow name on the surviving trigger must start with exactly one fresh listener.
	newWorkflow := workflowC_trgOnly(t, wc, "delete_workflow", trgID)
	if newWorkflow == wfID {
		t.Fatalf("recreated workflow must get a fresh id")
	}
	wc.POST("/api/v1/workflows/"+newWorkflow+":activate", map[string]any{}).OK(t, nil)
	wc.GET("/api/v1/triggers/"+trgID).OK(t, &runtime)
	if runtime.RefCount != 1 || !runtime.Listening {
		t.Fatalf("recreated workflow must be the only live listener, got %+v", runtime)
	}
	aid = workflowC_fire(t, wc, trgID)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 1 {
		t.Fatalf("recreated workflow fire must fan out exactly once, got %d", n)
	}
	harness.Eventually(t, 30000, "recreated workflow run completes", func() bool {
		return len(workflowC_runsOf(t, wc, newWorkflow, "completed")) == 1
	})
	wc.POST("/api/v1/workflows/"+newWorkflow+":deactivate", map[string]any{}).OK(t, nil)
	wc.GET("/api/v1/triggers/"+trgID).OK(t, &runtime)
	if runtime.RefCount != 0 || runtime.Listening {
		t.Fatalf("deactivate after workflow recreation must fully detach trigger, got %+v", runtime)
	}
}

// B-wf-16/B-trg-12 (in-flight half) — deleting a workflow is a hard automation stop: a parked
// approval run is cancelled, its trigger is detached, and its activation/firing audit remains.
//
// B-wf-16/B-trg-12（在途半边）——删 workflow 是自动化硬停：停在 approval 的 run 变 cancelled，入口摘掉，
// activation/firing 审计仍保留。
func TestContractWorkflow_DeleteCancelsInFlightRunAndKeepsAudit(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-workflow-delete-inflight")

	trgID := trgCreate(t, wc, "delete_inflight_hook", "webhook", map[string]any{"path": "delete-inflight"})
	apfID := workflowC_apf(t, wc, "delete_inflight_gate")
	wfID := workflowC_apfGraph(t, wc, "delete_inflight", trgID, apfID)
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	aid := workflowC_fire(t, wc, trgID)
	if n := workflowC_activationFiringCount(t, wc, aid); n != 1 {
		t.Fatalf("in-flight trigger fire must fan out once, got %d", n)
	}
	harness.Eventually(t, 30000, "triggered run parks at approval", func() bool {
		rows := workflowC_runsOf(t, wc, wfID, "running")
		if len(rows) != 1 {
			return false
		}
		status, nodes := workflowC_run(t, wc, rows[0].ID)
		return status == "running" && strings.Contains(nodes, `"parked"`)
	})
	running := workflowC_runsOf(t, wc, wfID, "running")
	if len(running) != 1 {
		t.Fatalf("expected one parked run before delete, got %+v", running)
	}
	runID := running[0].ID

	if r := wc.DELETE("/api/v1/workflows/" + wfID); r.Status != 204 {
		t.Fatalf("delete workflow with parked run must 204, got %d %s", r.Status, r.Raw)
	}
	wc.Do("GET", "/api/v1/workflows/"+wfID, nil).Fail(t, 404, "WORKFLOW_NOT_FOUND")
	workflowC_waitRunStatus(t, wc, runID, "cancelled", 20000)

	var runtime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+trgID).OK(t, &runtime)
	if runtime.RefCount != 0 || runtime.Listening {
		t.Fatalf("deleting workflow with parked run must detach trigger, got %+v", runtime)
	}
	wc.GET("/api/v1/trigger-activations/"+aid).OK(t, &struct {
		ID          string `json:"id"`
		FiringCount int    `json:"firingCount"`
	}{})
	if rows := workflowC_runsOf(t, wc, wfID, ""); len(rows) != 1 || rows[0].Status != "cancelled" {
		t.Fatalf("cancelled run audit must remain queryable after delete, got %+v", rows)
	}
}

// B-wf-16/B-wf-17 — a soft-deleted workflow keeps immutable reads but every mutable/action face
// must reject the id. This closes the resurrection boundary around :activate/:stage/:edit/:revert,
// execution verbs, capability-check, PATCH, and :iterate (the latter must not spawn a phantom chat).
//
// B-wf-16/B-wf-17 —— workflow 软删后仍可读不可变历史，但所有可变/动作入口都必须拒绝该 id。
// 覆盖 activate/stage/edit/revert、执行动词、能力检查、PATCH 与 :iterate（不得生成幻影对话）。
func TestContractWorkflow_DeletedWorkflowRejectsMutationActions(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-workflow-delete-actions")

	trgID := trgCreate(t, wc, "delete_actions_hook", "webhook", map[string]any{"path": "delete-actions"})
	wfID := workflowC_trgOnly(t, wc, "delete_actions", trgID)
	// A second immutable version makes :revert exercise a real retained target rather than
	// failing early on malformed input or an absent version.
	wc.POST("/api/v1/workflows/"+wfID+":edit", map[string]any{"ops": []map[string]any{
		{"op": "update_node", "id": "start", "patch": map[string]any{"notes": "v2"}},
	}}).OK(t, nil)
	if r := wc.DELETE("/api/v1/workflows/" + wfID); r.Status != 204 {
		t.Fatalf("delete workflow must 204, got %d %s", r.Status, r.Raw)
	}

	// Version reads are deliberately retained for audit/replay; the mutation/action surface is not.
	var versions []struct {
		Version int `json:"version"`
	}
	wc.GET("/api/v1/workflows/"+wfID+"/versions").OK(t, &versions)
	if len(versions) != 2 {
		t.Fatalf("deleted workflow must retain two immutable versions, got %+v", versions)
	}
	var version struct {
		Version int `json:"version"`
	}
	wc.GET("/api/v1/workflows/"+wfID+"/versions/1").OK(t, &version)
	if version.Version != 1 {
		t.Fatalf("deleted workflow version read must remain available, got %+v", version)
	}

	checks := []struct {
		name   string
		method string
		path   string
		body   any
	}{
		{"patch", "PATCH", "/api/v1/workflows/" + wfID, map[string]any{"description": "must not mutate"}},
		{"edit", "POST", "/api/v1/workflows/" + wfID + ":edit", map[string]any{"ops": []map[string]any{{"op": "update_node", "id": "start", "patch": map[string]any{"notes": "no"}}}}},
		{"revert", "POST", "/api/v1/workflows/" + wfID + ":revert", map[string]any{"version": 1}},
		{"trigger", "POST", "/api/v1/workflows/" + wfID + ":trigger", map[string]any{"payload": map[string]any{"after": "delete"}}},
		{"stage", "POST", "/api/v1/workflows/" + wfID + ":stage", map[string]any{}},
		{"activate", "POST", "/api/v1/workflows/" + wfID + ":activate", map[string]any{}},
		{"deactivate", "POST", "/api/v1/workflows/" + wfID + ":deactivate", map[string]any{}},
		{"kill", "POST", "/api/v1/workflows/" + wfID + ":kill", map[string]any{}},
		{"capability-check", "POST", "/api/v1/workflows/" + wfID + ":capability-check", map[string]any{}},
		{"iterate", "POST", "/api/v1/workflows/" + wfID + ":iterate", map[string]any{"request": "must not spawn"}},
	}
	for _, tc := range checks {
		t.Run(tc.name, func(t *testing.T) {
			wc.Do(tc.method, tc.path, tc.body).Fail(t, 404, "WORKFLOW_NOT_FOUND")
		})
	}
	if r := wc.DELETE("/api/v1/workflows/" + wfID); r.Status != 404 || r.Code != "WORKFLOW_NOT_FOUND" {
		t.Fatalf("second delete must stay a not-found no-op, got %d/%s %s", r.Status, r.Code, r.Raw)
	}

	// The source entity survives, but the deleted workflow never comes back as a listener.
	var runtime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+trgID).OK(t, &runtime)
	if runtime.RefCount != 0 || runtime.Listening {
		t.Fatalf("action attempts must not resurrect deleted listener, got %+v", runtime)
	}
}

// B-wf-18/B-trg-13 — workflow and trigger ids, action verbs, version reads and flowrun lists are
// workspace-scoped even though ids are globally shaped. A second workspace can neither inspect nor
// mutate the first workspace's workflow, and sees an empty run projection rather than a foreign row.
//
// B-wf-18/B-trg-13 —— workflow/trigger id、动作、版本读取与 flowrun 列表均按 workspace 隔离；第二个
// workspace 既不能查看/修改第一个的 workflow，也不会在 run 投影里看到外部行。
func TestContractWorkflow_WorkspaceIsolationAcrossActionsAndHistory(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws1 := c.POST("/api/v1/workspaces", map[string]any{"name": "wfc-workflow-iso-one"}).Field(t, "id")
	ws2 := c.POST("/api/v1/workspaces", map[string]any{"name": "wfc-workflow-iso-two"}).Field(t, "id")
	wc1, wc2 := c.WS(ws1), c.WS(ws2)

	trgID := trgCreate(t, wc1, "iso_action_hook", "webhook", map[string]any{"path": "iso-actions"})
	wfID := workflowC_trgOnly(t, wc1, "iso_action_workflow", trgID)
	// Keep one run in the owning workspace so the cross-workspace flowrun list has a positive
	// control to distinguish from a legitimate empty projection.
	workflowC_startRun(t, wc1, wfID)

	wc2.Do("GET", "/api/v1/workflows/"+wfID, nil).Fail(t, 404, "WORKFLOW_NOT_FOUND")
	wc2.Do("GET", "/api/v1/triggers/"+trgID, nil).Fail(t, 404, "TRIGGER_NOT_FOUND")
	if r := wc2.GET("/api/v1/workflows/" + wfID + "/versions"); r.Status != 200 || string(r.Data) != "[]" {
		t.Fatalf("cross-workspace version history must be an empty projection, got %d %s", r.Status, r.Raw)
	}
	if rows := workflowC_runsOf(t, wc2, wfID, ""); len(rows) != 0 {
		t.Fatalf("cross-workspace flowrun list leaked foreign rows: %+v", rows)
	}

	for _, tc := range []struct {
		name   string
		method string
		path   string
		body   any
		code   string
	}{
		{"activate", "POST", "/api/v1/workflows/" + wfID + ":activate", map[string]any{}, "WORKFLOW_NOT_FOUND"},
		{"stage", "POST", "/api/v1/workflows/" + wfID + ":stage", map[string]any{}, "WORKFLOW_NOT_FOUND"},
		{"trigger", "POST", "/api/v1/workflows/" + wfID + ":trigger", map[string]any{}, "WORKFLOW_NOT_FOUND"},
		{"capability-check", "POST", "/api/v1/workflows/" + wfID + ":capability-check", map[string]any{}, "WORKFLOW_NOT_FOUND"},
		{"delete", "DELETE", "/api/v1/workflows/" + wfID, nil, "WORKFLOW_NOT_FOUND"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			wc2.Do(tc.method, tc.path, tc.body).Fail(t, 404, tc.code)
		})
	}

	// The owning workspace remains fully functional after all foreign attempts.
	state, active, version := workflowC_wfState(t, wc1, wfID)
	if state != "inactive" || active || version != 1 {
		t.Fatalf("foreign action attempts changed owning workflow: state=%q active=%v version=%d", state, active, version)
	}
	if rows := workflowC_runsOf(t, wc1, wfID, ""); len(rows) != 1 {
		t.Fatalf("foreign action attempts must not alter owning history, got %+v", rows)
	}
}

// B-wf-19/B-trg-14 — a queued firing that was accepted before deletion must not become a run after
// the workflow disappears. Serial overlap makes the pending state deterministic: the first webhook
// parks at approval, the second stays pending, DELETE cancels the first and the next drain sheds only
// the orphaned second firing while retaining both activation/firing audit rows.
//
// B-wf-19/B-trg-14 —— 删除前已接收但排队中的 firing 不得在 workflow 消失后变成 run。用 serial overlap
// 确定制造 pending：第一条 webhook 停在审批、第二条保持 pending；DELETE 取消第一条，下一次 drain 只把
// 孤儿第二条记为 shed，同时保留两条 activation/firing 审计。
func TestContractWorkflow_DeletedWorkflowShedsQueuedFiring(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wfc-workflow-delete-queued")

	trgID := trgCreate(t, wc, "delete_queued_hook", "webhook", map[string]any{"path": "delete-queued"})
	apfID := workflowC_apf(t, wc, "delete_queued_gate")
	wfID := workflowC_apfGraph(t, wc, "delete_queued", trgID, apfID,
		map[string]any{"op": "set_meta", "concurrency": "serial"})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	fireConcurrencyWebhook(t, srv, trgID, "delete-queued", `{"seq":1}`)
	var firstRunID string
	harness.Eventually(t, 20000, "first queued-delete run parks", func() bool {
		runs := workflowC_runsOf(t, wc, wfID, "running")
		if len(runs) != 1 {
			return false
		}
		firstRunID = runs[0].ID
		_, nodes := workflowC_run(t, wc, firstRunID)
		return strings.Contains(nodes, `"parked"`)
	})

	// A distinct body avoids webhook retry dedup and creates a second durable firing while serial
	// overlap deliberately leaves it pending behind the parked first run.
	fireConcurrencyWebhook(t, srv, trgID, "delete-queued", `{"seq":2}`)
	harness.Eventually(t, 20000, "second firing remains pending behind parked run", func() bool {
		rows := listConcurrencyFirings(t, wc, trgID)
		counts := countFiringStatuses(rows)
		return len(rows) == 2 && counts["started"] == 1 && counts["pending"] == 1
	})

	if r := wc.DELETE("/api/v1/workflows/" + wfID); r.Status != 204 {
		t.Fatalf("delete with queued firing must 204, got %d %s", r.Status, r.Raw)
	}
	wc.Do("GET", "/api/v1/workflows/"+wfID, nil).Fail(t, 404, "WORKFLOW_NOT_FOUND")
	workflowC_waitRunStatus(t, wc, firstRunID, "cancelled", 20000)

	var finalFirings []firingRow
	harness.Eventually(t, 20000, "queued firing is shed after workflow delete", func() bool {
		finalFirings = listFirings(t, wc, trgID, "limit=50")
		counts := map[string]int{}
		for _, firing := range finalFirings {
			counts[firing.Status]++
		}
		return len(finalFirings) == 2 && counts["started"] == 1 && counts["shed"] == 1
	})
	var shedCount int
	for _, firing := range finalFirings {
		if firing.Status == "shed" {
			shedCount++
			if firing.FlowrunID != "" || firing.WorkflowID != wfID {
				t.Fatalf("shed firing must retain workflow audit but no run link, got %+v", firing)
			}
		}
	}
	if shedCount != 1 {
		t.Fatalf("exactly one queued firing must be shed, got %+v", finalFirings)
	}
	if rows := workflowC_runsOf(t, wc, wfID, ""); len(rows) != 1 || rows[0].ID != firstRunID || rows[0].Status != "cancelled" {
		t.Fatalf("delete must not create a run for the queued firing, got %+v", rows)
	}
	var runtime struct {
		RefCount  int  `json:"refCount"`
		Listening bool `json:"listening"`
	}
	wc.GET("/api/v1/triggers/"+trgID).OK(t, &runtime)
	if runtime.RefCount != 0 || runtime.Listening {
		t.Fatalf("queued-delete workflow must leave no trigger listener, got %+v", runtime)
	}
}

// ---------------------------------------------------------------------------
// B-trg-8 — webhook 明文式两载体（X-Webhook-Secret 头 / ?token= 查询）+ signatureHeader 改头名
// ---------------------------------------------------------------------------

func TestContractWorkflow_TriggerWebhookSecretCarriers(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "trgc-secret")

	// --- plaintext secret: header OR query token ---
	plainTrg := trgCreate(t, wc, "plain_hook", "webhook", map[string]any{"path": "plain", "secret": "pw123"})
	wfPlain := workflowC_trgOnly(t, wc, "plain_wf", plainTrg)
	wc.POST("/api/v1/workflows/"+wfPlain+":activate", map[string]any{}).OK(t, nil)
	plainURL := srv.BaseURL + "/api/v1/webhooks/" + plainTrg + "/plain"

	if code := workflowC_rawPost(t, plainURL, `{"a":1}`, nil); code != 401 {
		t.Fatalf("missing secret must 401, got %d", code)
	}
	if code := workflowC_rawPost(t, plainURL, `{"a":2}`, map[string]string{"X-Webhook-Secret": "wrong"}); code != 401 {
		t.Fatalf("wrong secret must 401, got %d", code)
	}
	if code := workflowC_rawPost(t, plainURL, `{"a":3}`, map[string]string{"X-Webhook-Secret": "pw123"}); code != 202 {
		t.Fatalf("header-carried secret must 202, got %d", code)
	}
	if code := workflowC_rawPost(t, plainURL+"?token=pw123", `{"a":4}`, nil); code != 202 {
		t.Fatalf("query-carried secret must 202, got %d", code)
	}
	harness.Eventually(t, 30000, "both accepted plain posts run", func() bool {
		return len(workflowC_runsOf(t, wc, wfPlain, "completed")) == 2
	})

	// --- HMAC with a RENAMED signature header ---
	sigTrg := trgCreate(t, wc, "sig_hook", "webhook", map[string]any{
		"path": "sig", "secret": "hmacpw", "signatureAlgo": "hmac-sha256-hex", "signatureHeader": "X-Custom-Sig",
	})
	wfSig := workflowC_trgOnly(t, wc, "sig_wf", sigTrg)
	wc.POST("/api/v1/workflows/"+wfSig+":activate", map[string]any{}).OK(t, nil)
	sigURL := srv.BaseURL + "/api/v1/webhooks/" + sigTrg + "/sig"

	body := `{"event":"push"}`
	mac := hmac.New(sha256.New, []byte("hmacpw"))
	mac.Write([]byte(body))
	sig := "sha256=" + hex.EncodeToString(mac.Sum(nil))

	// valid signature in the RENAMED header → accepted. 正签在改名头 → 收。
	if code := workflowC_rawPost(t, sigURL, body, map[string]string{"X-Custom-Sig": sig}); code != 202 {
		t.Fatalf("signature in renamed header must 202, got %d", code)
	}
	// same valid signature in the DEFAULT header name → 401 (header was renamed).
	// 同一正签放默认头名 → 401（头名已改）。
	if code := workflowC_rawPost(t, sigURL, body, map[string]string{"X-Hub-Signature-256": sig}); code != 401 {
		t.Fatalf("default header after rename must 401, got %d", code)
	}
}

// ---------------------------------------------------------------------------
// B-trg-12 — Edit 热更：改 config.path 后旧路径 404（catch-all registry 派发）、新路径 202
// ---------------------------------------------------------------------------

func TestContractWorkflow_TriggerWebhookEditHotSwapsPath(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "trgc-hotswap")

	trgID := trgCreate(t, wc, "swap_hook", "webhook", map[string]any{"path": "before"})
	wfID := workflowC_trgOnly(t, wc, "swap_wf", trgID)
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	base := srv.BaseURL + "/api/v1/webhooks/" + trgID
	if code := workflowC_rawPost(t, base+"/before", `{"s":1}`, nil); code != 202 {
		t.Fatalf("original path must 202 while listening, got %d", code)
	}

	// PATCH = Edit,热更监听中的 listener(trigger.md §4)。
	var edited struct {
		Config map[string]any `json:"config"`
	}
	wc.PATCH("/api/v1/triggers/"+trgID, map[string]any{"config": map[string]any{"path": "after"}}).OK(t, &edited)
	if edited.Config["path"] != "after" {
		t.Fatalf("edit must land config.path=after: %+v", edited.Config)
	}

	if code := workflowC_rawPost(t, base+"/before", `{"s":2}`, nil); code != 404 {
		t.Fatalf("stale path after hot swap must 404, got %d", code)
	}
	if code := workflowC_rawPost(t, base+"/after", `{"s":3}`, nil); code != 202 {
		t.Fatalf("new path after hot swap must 202, got %d", code)
	}
	harness.Eventually(t, 30000, "runs from pre+post swap posts", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "completed")) == 2
	})
}
