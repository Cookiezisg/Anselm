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

// ---------------------------------------------------------------------------
// B-wf-7 — 手动 :trigger 绕过并发策略：replace 下两手动 run 同途、互不取消
// ---------------------------------------------------------------------------

func TestContractWorkflow_ManualTriggerBypassesReplace(t *testing.T) {
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

// ---------------------------------------------------------------------------
// B-trg-8 — webhook 明文式两载体（X-Webhook-Secret 头 / ?token= 查询）+ signatureHeader 改头名
// ---------------------------------------------------------------------------

func TestContractWorkflow_TriggerWebhookSecretCarriers(t *testing.T) {
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
