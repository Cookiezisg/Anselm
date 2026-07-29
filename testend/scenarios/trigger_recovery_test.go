package scenarios

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestTrigger_WebhookFiringSurvivesRestartBeforeDrain closes the external-trigger recovery seam:
// the webhook is accepted and its firing is durable, the process dies before/while the scheduler
// drains it, and boot produces exactly one started firing + one completed flowrun with linked audit.
//
// TestTrigger_WebhookFiringSurvivesRestartBeforeDrain 闭合外部 trigger 恢复缝：webhook 已接受且 firing
// 已耐久，scheduler drain 前/中进程死亡；boot 最终只产一条 started firing、一条 completed flowrun，审计互链。
func TestTrigger_WebhookFiringSurvivesRestartBeforeDrain(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "trigger-restart-recovery"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	secret := "restart-webhook-secret"
	trgID := trgCreate(t, wc, "restart_hook", "webhook", map[string]any{
		"path": "restart-inbound", "secret": secret,
	})
	wfID, fnID := wfWithTrigger(t, wc, "restart_hook_pipe", trgID)

	// The HTTP acknowledgement is the only pre-crash guarantee we need: the trigger report has
	// committed its firing, but no drain timing assumption is made before killing the process.
	// HTTP ack 是崩溃前唯一需要的保证：trigger report 已提交 firing，但不假设 drain 已经发生。
	url := srv.BaseURL + "/api/v1/webhooks/" + trgID + "/restart-inbound"
	if status := workflowC_rawPost(t, url, `{"event":"restart-proof"}`, map[string]string{"X-Webhook-Secret": secret}); status < 200 || status >= 300 {
		t.Fatalf("webhook must acknowledge before crash, got %d", status)
	}
	srv.Kill9(t)
	srv.Restart(t)
	wc2 := srv.Client(t).WS(wsID)

	var firing firingRow
	var run struct {
		ID        string `json:"id"`
		Status    string `json:"status"`
		Origin    string `json:"origin"`
		TriggerID string `json:"triggerId"`
		FiringID  string `json:"firingId"`
	}
	harness.Eventually(t, 30000, "webhook firing drains after restart", func() bool {
		rows := listFirings(t, wc2, trgID, "limit=50")
		if len(rows) != 1 || rows[0].Status != "started" || rows[0].FlowrunID == "" || rows[0].WorkflowID != wfID {
			return false
		}
		firing = rows[0]
		var runs []struct {
			ID        string `json:"id"`
			Status    string `json:"status"`
			Origin    string `json:"origin"`
			TriggerID string `json:"triggerId"`
			FiringID  string `json:"firingId"`
		}
		if r := wc2.GET("/api/v1/flowruns?workflowId=" + wfID); r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil || len(runs) != 1 {
			return false
		}
		run = runs[0]
		return run.Status == "completed" && run.Origin == "webhook" && run.TriggerID == trgID && run.FiringID == firing.ID && run.ID == firing.FlowrunID
	})
	if firing.ID == "" || run.ID == "" {
		t.Fatalf("restart must produce one linked firing/run: firing=%+v run=%+v", firing, run)
	}

	// The linked execution ledger closes the external-trigger → scheduler → callable chain.
	// execution 台账闭合 external trigger → scheduler → callable 链。
	var executions struct {
		Executions []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc2.GET("/api/v1/functions/"+fnID+"/executions?flowrunId="+run.ID).OK(t, &executions)
	if len(executions.Executions) != 1 || executions.Executions[0].Status != "ok" || executions.Executions[0].FlowrunID != run.ID || executions.Executions[0].FlowrunNodeID != "step" || executions.Executions[0].FlowrunIteration != 0 {
		t.Fatalf("recovered webhook execution provenance wrong: %+v", executions.Executions)
	}
	if rows := listFirings(t, wc2, trgID, "status=started&limit=50"); len(rows) != 1 || rows[0].FlowrunID != run.ID {
		t.Fatalf("started firing ledger must stay singular and linked: %+v", rows)
	}
}

// TestTrigger_WebhookDuplicateBodyDedupsWithinMinute proves the webhook retry contract that is
// easy to confuse with workflow overlap: two identical raw bodies in the same minute collapse to
// one durable firing/run, while a different body creates a second independent execution.
//
// TestTrigger_WebhookDuplicateBodyDedupsWithinMinute 证明 webhook 重试契约，避免与 workflow overlap
// 混淆：同一分钟两次相同 raw body 折成一条 durable firing/run；body 不同才产生第二次独立执行。
func TestTrigger_WebhookDuplicateBodyDedupsWithinMinute(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "webhook-dedup-retry"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))
	secret := "dedup-webhook-secret"
	trgID := trgCreate(t, wc, "dedup_hook", "webhook", map[string]any{
		"path": "dedup-inbound", "secret": secret,
	})
	wfID, _ := wfWithTrigger(t, wc, "dedup_hook_pipe", trgID)
	url := srv.BaseURL + "/api/v1/webhooks/" + trgID + "/dedup-inbound"
	hdr := map[string]string{"X-Webhook-Secret": secret}

	// Network retry: same raw body twice. Both HTTP calls are accepted, but the second must hit the
	// body-hash + minute-bucket unique key and not mint another workflow run.
	// 网络重试：相同 raw body 两次。两次 HTTP 都可接受，但第二次必须命中 body-hash+分钟桶唯一键，不得新建 run。
	body := `{"event":"retry-same"}`
	if st := workflowC_rawPost(t, url, body, hdr); st < 200 || st >= 300 {
		t.Fatalf("first webhook retry probe must be accepted, got %d", st)
	}
	if st := workflowC_rawPost(t, url, body, hdr); st < 200 || st >= 300 {
		t.Fatalf("duplicate webhook retry must be accepted idempotently, got %d", st)
	}
	harness.Eventually(t, 30000, "duplicate body collapses to one run", func() bool {
		rows := listFirings(t, wc, trgID, "limit=50")
		if len(rows) != 1 || rows[0].Status != "started" {
			return false
		}
		var runs []struct {
			Status    string `json:"status"`
			Origin    string `json:"origin"`
			TriggerID string `json:"triggerId"`
		}
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil || len(runs) != 1 {
			return false
		}
		return runs[0].Status == "completed" && runs[0].Origin == "webhook" && runs[0].TriggerID == trgID
	})

	// Different payloads are not retries of the same event and must produce a second firing/run.
	// body 不同不是同一事件的重试，必须产生第二条 firing/run。
	if st := workflowC_rawPost(t, url, `{"event":"retry-different"}`, hdr); st < 200 || st >= 300 {
		t.Fatalf("different webhook body must be accepted, got %d", st)
	}
	harness.Eventually(t, 30000, "different body produces a second run", func() bool {
		rows := listFirings(t, wc, trgID, "limit=50")
		if len(rows) != 2 {
			return false
		}
		seenFiringIDs := map[string]bool{}
		for _, row := range rows {
			if row.Status != "started" || seenFiringIDs[row.ID] {
				return false
			}
			seenFiringIDs[row.ID] = true
		}
		var runs []struct {
			Status string `json:"status"`
			Origin string `json:"origin"`
		}
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil || len(runs) != 2 {
			return false
		}
		for _, run := range runs {
			if run.Status != "completed" || run.Origin != "webhook" {
				return false
			}
		}
		return true
	})
}

// TestTrigger_FsnotifyEventReachesWorkflow proves the real filesystem source, not only the
// listener unit vocabulary: a filtered create event becomes a durable fsnotify firing, its
// canonical eventKind/path payload reaches the workflow CEL wiring, and the callable audit joins.
//
// TestTrigger_FsnotifyEventReachesWorkflow 走真实文件系统 source，而非只测 listener 单元词汇：满足过滤的
// create 事件成为 durable fsnotify firing，canonical eventKind/path 经 workflow CEL 接线到终点，审计闭合。
func TestTrigger_FsnotifyEventReachesWorkflow(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fsnotify-workflow"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	watchDir := t.TempDir()
	fnID := fnCreate(t, wc, "fsnotify_payload_sink", "def f(event: str, path: str) -> dict:\n    return {'event': event, 'path': path}\n")
	trgID := trgCreate(t, wc, "file_watch", "fsnotify", map[string]any{
		"path": watchDir, "pattern": "*.txt", "events": []string{"create"},
	})
	wfID := wfCreate(t, wc, "fsnotify_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{
			"id": "sink", "kind": "action", "ref": fnID,
			"input": map[string]any{"event": "start.eventKind", "path": "start.path"},
		}},
		{"op": "add_edge", "edge": map[string]any{"id": "e-start-sink", "from": "start", "to": "sink"}},
	})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	path := filepath.Join(watchDir, "created.txt")
	if err := os.WriteFile(path, []byte("fsnotify-proof"), 0o644); err != nil {
		t.Fatalf("create watched file: %v", err)
	}

	var run struct {
		ID        string `json:"id"`
		Status    string `json:"status"`
		Origin    string `json:"origin"`
		TriggerID string `json:"triggerId"`
		FiringID  string `json:"firingId"`
	}
	harness.Eventually(t, 30000, "fsnotify event reaches a completed workflow", func() bool {
		var runs []struct {
			ID        string `json:"id"`
			Status    string `json:"status"`
			Origin    string `json:"origin"`
			TriggerID string `json:"triggerId"`
			FiringID  string `json:"firingId"`
		}
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil || len(runs) != 1 {
			return false
		}
		run = runs[0]
		return run.Status == "completed" && run.Origin == "fsnotify" && run.TriggerID == trgID && run.FiringID != ""
	})
	if run.ID == "" {
		t.Fatalf("fsnotify must create one linked flowrun: %+v", run)
	}

	var detail struct {
		Nodes []struct {
			NodeID string         `json:"nodeId"`
			Status string         `json:"status"`
			Result map[string]any `json:"result"`
		} `json:"nodes"`
	}
	wc.GET("/api/v1/flowruns/"+run.ID).OK(t, &detail)
	if len(detail.Nodes) != 2 {
		t.Fatalf("fsnotify graph must persist start+sink completed rows: %+v", detail.Nodes)
	}
	var sink map[string]any
	for _, node := range detail.Nodes {
		if node.Status != "completed" {
			t.Fatalf("fsnotify graph node must complete: %+v", detail.Nodes)
		}
		if node.NodeID == "sink" {
			sink = node.Result
		}
	}
	if sink["event"] != "create" || sink["path"] != path {
		t.Fatalf("fsnotify canonical payload did not reach sink: got=%+v want event=create path=%q", sink, path)
	}

	firings := listFirings(t, wc, trgID, "limit=50")
	if len(firings) != 1 || firings[0].Status != "started" || firings[0].FlowrunID != run.ID || firings[0].ID != run.FiringID {
		t.Fatalf("fsnotify firing/run provenance wrong: firings=%+v run=%+v", firings, run)
	}
	var executions struct {
		Executions []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions?flowrunId="+run.ID).OK(t, &executions)
	if len(executions.Executions) != 1 || executions.Executions[0].Status != "ok" || executions.Executions[0].FlowrunID != run.ID || executions.Executions[0].FlowrunNodeID != "sink" || executions.Executions[0].FlowrunIteration != 0 {
		t.Fatalf("fsnotify sink execution provenance wrong: %+v", executions.Executions)
	}
}

// TestTrigger_FsnotifyFiltersCreateEvents proves the source-side filter vocabulary is enforced
// before durable reporting: a non-matching extension and a modify event produce no run, while one
// matching create produces exactly one activation/firing/run.
//
// TestTrigger_FsnotifyFiltersCreateEvents 证明 source 侧过滤词汇在 durable report 之前生效：不匹配扩展名
// 与 modify 事件都不产生 run；一个匹配的 create 恰产生一条 activation/firing/run。
func TestTrigger_FsnotifyFiltersCreateEvents(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fsnotify-filtering"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	watchDir := t.TempDir()
	trgID := trgCreate(t, wc, "filtered_file_watch", "fsnotify", map[string]any{
		"path": watchDir, "pattern": "*.txt", "events": []string{"create"},
	})
	wfID, _ := wfWithTrigger(t, wc, "filtered_file_pipe", trgID)

	if err := os.WriteFile(filepath.Join(watchDir, "ignored.log"), []byte("wrong suffix"), 0o644); err != nil {
		t.Fatalf("create ignored file: %v", err)
	}
	time.Sleep(700 * time.Millisecond)
	if rows := listRunRows(t, wc, "?workflowId="+wfID); len(rows) != 0 {
		t.Fatalf("pattern-mismatched file must not start a run: %+v", rows)
	}

	acceptedPath := filepath.Join(watchDir, "accepted.txt")
	if err := os.WriteFile(acceptedPath, []byte("create"), 0o644); err != nil {
		t.Fatalf("create accepted file: %v", err)
	}
	// This is a modify event, not another create. The trigger's events filter must discard it.
	// 这是 modify 而非另一个 create，trigger 的 events 过滤必须丢弃它。
	if err := os.WriteFile(acceptedPath, []byte("modify"), 0o644); err != nil {
		t.Fatalf("modify accepted file: %v", err)
	}

	harness.Eventually(t, 30000, "one filtered create reaches the workflow", func() bool {
		rows := listRunRows(t, wc, "?workflowId="+wfID)
		if len(rows) != 1 {
			return false
		}
		return rows[0].Status == "completed" && rows[0].Origin == "fsnotify"
	})
	time.Sleep(1200 * time.Millisecond)
	if rows := listRunRows(t, wc, "?workflowId="+wfID); len(rows) != 1 {
		t.Fatalf("filtered modify/mismatch events must not create a second run: %+v", rows)
	}
	var acts []struct {
		Fired       bool           `json:"fired"`
		Payload     map[string]any `json:"payload"`
		FiringCount int            `json:"firingCount"`
	}
	wc.GET("/api/v1/triggers/"+trgID+"/activations").OK(t, &acts)
	if len(acts) != 1 || !acts[0].Fired || acts[0].FiringCount != 1 || acts[0].Payload["eventKind"] != "create" || acts[0].Payload["path"] != acceptedPath {
		t.Fatalf("filtered fsnotify activation must describe only the accepted create: %+v", acts)
	}
	if firings := listFirings(t, wc, trgID, "limit=50"); len(firings) != 1 || firings[0].Status != "started" {
		t.Fatalf("filtered fsnotify must leave one started firing: %+v", firings)
	}
}

// TestTrigger_SensorFalseProbeThenFiresAfterEdit proves both halves of a polling sensor through
// product HTTP: a false condition is still an activation with ReturnValue and zero firings; after
// the target function is edited, the next probe fires a sensor-origin workflow with the output.
//
// TestTrigger_SensorFalseProbeThenFiresAfterEdit 经产品 HTTP 覆盖轮询 sensor 两半：false 条件仍记
// activation+ReturnValue 且零 firing；目标 function 编辑后下一轮 probe 变 true，触发 sensor-origin workflow。
func TestTrigger_SensorFalseProbeThenFiresAfterEdit(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "sensor-transition"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	probeFn := fnCreate(t, wc, "sensor_transition_probe", "def f() -> dict:\n    return {'level': 1}\n")
	trgID := trgCreate(t, wc, "transition_sensor", "sensor", map[string]any{
		"targetKind": "function", "targetId": probeFn, "intervalSec": 5,
		"condition": "payload.level > 10", "output": "{'level': payload.level}",
	})
	wfID, _ := wfWithTrigger(t, wc, "transition_sensor_pipe", trgID)

	type activation struct {
		Fired       bool           `json:"fired"`
		ReturnValue map[string]any `json:"returnValue"`
		Payload     map[string]any `json:"payload"`
		Detail      string         `json:"detail"`
		FiringCount int            `json:"firingCount"`
	}
	var acts []activation
	harness.Eventually(t, 15000, "sensor records a false probe", func() bool {
		r := wc.GET("/api/v1/triggers/" + trgID + "/activations")
		if r.Status != 200 || json.Unmarshal(r.Data, &acts) != nil {
			return false
		}
		for _, act := range acts {
			if !act.Fired && act.FiringCount == 0 && act.ReturnValue["level"] == float64(1) && act.Detail == "condition evaluated false" {
				return true
			}
		}
		return false
	})
	if rows := listFirings(t, wc, trgID, "limit=50"); len(rows) != 0 {
		t.Fatalf("false sensor probe must not create a firing: %+v", rows)
	}

	// Edit the target; sensor invokes the active version on its next interval, so this is a real
	// state transition rather than a second trigger or a synthetic activation.
	// 编辑目标；sensor 下一间隔调用 active 版本，这是实际状态转移，不是第二个 trigger 或捏造 activation。
	wc.POST("/api/v1/functions/"+probeFn+":edit", map[string]any{
		"ops": []map[string]any{{"op": "set_code", "code": "def f() -> dict:\n    return {'level': 42}\n"}},
	}).OK(t, nil)

	var run struct {
		ID     string `json:"id"`
		Status string `json:"status"`
		Origin string `json:"origin"`
	}
	harness.Eventually(t, 25000, "sensor turns true and starts a workflow", func() bool {
		r := wc.GET("/api/v1/triggers/" + trgID + "/activations")
		if r.Status != 200 || json.Unmarshal(r.Data, &acts) != nil {
			return false
		}
		trueProbe := false
		for _, act := range acts {
			if act.Fired && act.FiringCount > 0 && act.ReturnValue["level"] == float64(42) && act.Payload["level"] == float64(42) {
				trueProbe = true
				break
			}
		}
		if !trueProbe {
			return false
		}
		var runs []struct {
			ID     string `json:"id"`
			Status string `json:"status"`
			Origin string `json:"origin"`
		}
		r = wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil {
			return false
		}
		for _, candidate := range runs {
			if candidate.Status == "completed" && candidate.Origin == "sensor" {
				run = candidate
				return true
			}
		}
		return false
	})
	if run.ID == "" {
		t.Fatalf("sensor true transition must create a completed sensor-origin run: %+v", run)
	}
	// Stop the five-second poll after the first true transition so later assertions describe one
	// deliberate event, not an unbounded stream of equivalent probes.
	wc.POST("/api/v1/triggers/"+trgID+":pause", nil).OK(t, nil)

	firings := listFirings(t, wc, trgID, "limit=50")
	if len(firings) == 0 {
		t.Fatal("true sensor transition must create a firing")
	}
	for _, firing := range firings {
		if firing.Status != "started" || firing.FlowrunID == "" {
			t.Fatalf("sensor firing must be started and linked: %+v", firings)
		}
	}
}

// TestTrigger_FsnotifyPauseRestartResume proves that a filesystem source is actually removed
// while paused, stays removed across a hard restart, and is reattached with the same workflow
// references on resume. Files created during the pause must not be replayed as synthetic events;
// only a new post-resume create may mint one firing/run.
//
// TestTrigger_FsnotifyPauseRestartResume 证明文件系统 source 在暂停时确实摘除、硬重启后仍摘除，恢复时
// 用原 workflow 引用重挂。暂停期间创建的文件不得被捏造成补发事件；只有恢复后的新 create 才能铸一条 firing/run。
func TestTrigger_FsnotifyPauseRestartResume(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fsnotify-pause-restart"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	watchDir := t.TempDir()
	trgID := trgCreate(t, wc, "paused_file_watch", "fsnotify", map[string]any{
		"path": watchDir, "pattern": "*.txt", "events": []string{"create"},
	})
	wfID, fnID := wfWithTrigger(t, wc, "paused_file_pipe", trgID)

	var paused trgRow
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, &paused)
	if !paused.Paused || paused.Listening || paused.NextFireAt != "" {
		t.Fatalf("fsnotify pause projection wrong: %+v", paused)
	}
	baseRuns := len(listRunRows(t, wc, "?workflowId="+wfID))
	baseFirings := len(listFirings(t, wc, trgID, "limit=50"))

	// This create happens after the source was paused. It must not be buffered as a later run.
	// 这个 create 发生在 source 已暂停之后，不得被缓冲成之后的 run。
	if err := os.WriteFile(filepath.Join(watchDir, "paused-before-restart.txt"), []byte("paused"), 0o644); err != nil {
		t.Fatalf("create paused file: %v", err)
	}
	time.Sleep(1200 * time.Millisecond)
	if got := len(listRunRows(t, wc, "?workflowId="+wfID)); got != baseRuns {
		t.Fatalf("paused fsnotify must not start a run before restart: %d → %d", baseRuns, got)
	}
	if got := len(listFirings(t, wc, trgID, "limit=50")); got != baseFirings {
		t.Fatalf("paused fsnotify must not mint a firing before restart: %d → %d", baseFirings, got)
	}

	srv.Kill9(t)
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)
	if tr := getTrg(t, wc, trgID); !tr.Paused || tr.Listening || tr.NextFireAt != "" {
		t.Fatalf("fsnotify pause must survive restart with source detached: %+v", tr)
	}

	// A second create while the restarted process is still paused is another negative control.
	// 重启后的进程仍暂停，再造一个文件作为第二个负控。
	if err := os.WriteFile(filepath.Join(watchDir, "paused-after-restart.txt"), []byte("still-paused"), 0o644); err != nil {
		t.Fatalf("create paused-after-restart file: %v", err)
	}
	time.Sleep(1200 * time.Millisecond)
	if got := len(listRunRows(t, wc, "?workflowId="+wfID)); got != baseRuns {
		t.Fatalf("paused fsnotify must not start a run after restart: %d → %d", baseRuns, got)
	}
	if got := len(listFirings(t, wc, trgID, "limit=50")); got != baseFirings {
		t.Fatalf("paused fsnotify must not mint a firing after restart: %d → %d", baseFirings, got)
	}

	var resumed trgRow
	wc.POST("/api/v1/triggers/"+trgID+":resume", map[string]any{}).OK(t, &resumed)
	if resumed.Paused || !resumed.Listening {
		t.Fatalf("fsnotify resume projection wrong: %+v", resumed)
	}
	resumedPath := filepath.Join(watchDir, "resumed.txt")
	if err := os.WriteFile(resumedPath, []byte("resumed"), 0o644); err != nil {
		t.Fatalf("create resumed file: %v", err)
	}

	var run struct {
		ID        string `json:"id"`
		Status    string `json:"status"`
		Origin    string `json:"origin"`
		TriggerID string `json:"triggerId"`
		FiringID  string `json:"firingId"`
	}
	harness.Eventually(t, 30000, "resumed fsnotify event reaches a run", func() bool {
		var runs []struct {
			ID        string `json:"id"`
			Status    string `json:"status"`
			Origin    string `json:"origin"`
			TriggerID string `json:"triggerId"`
			FiringID  string `json:"firingId"`
		}
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil || len(runs) != baseRuns+1 {
			return false
		}
		for _, candidate := range runs {
			if candidate.Status == "completed" && candidate.Origin == "fsnotify" && candidate.TriggerID == trgID && candidate.FiringID != "" {
				run = candidate
				return true
			}
		}
		return false
	})
	if run.ID == "" {
		t.Fatalf("resumed fsnotify must create one linked run: %+v", run)
	}

	var detail struct {
		Nodes []struct {
			NodeID string         `json:"nodeId"`
			Status string         `json:"status"`
			Result map[string]any `json:"result"`
		} `json:"nodes"`
	}
	wc.GET("/api/v1/flowruns/"+run.ID).OK(t, &detail)
	if len(detail.Nodes) != 2 {
		t.Fatalf("resumed fsnotify graph must persist two nodes: %+v", detail.Nodes)
	}
	for _, node := range detail.Nodes {
		if node.Status != "completed" {
			t.Fatalf("resumed fsnotify graph node must complete: %+v", detail.Nodes)
		}
	}
	firings := listFirings(t, wc, trgID, "limit=50")
	if len(firings) != baseFirings+1 || firings[len(firings)-1].Status != "started" || firings[len(firings)-1].FlowrunID != run.ID {
		t.Fatalf("resumed fsnotify firing ledger wrong: %+v", firings)
	}
	var executions struct {
		Executions []struct {
			Status           string `json:"status"`
			FlowrunID        string `json:"flowrunId"`
			FlowrunNodeID    string `json:"flowrunNodeId"`
			FlowrunIteration int    `json:"flowrunIteration"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions?flowrunId="+run.ID).OK(t, &executions)
	if len(executions.Executions) != 1 || executions.Executions[0].Status != "ok" || executions.Executions[0].FlowrunID != run.ID || executions.Executions[0].FlowrunNodeID != "step" || executions.Executions[0].FlowrunIteration != 0 {
		t.Fatalf("resumed fsnotify execution provenance wrong: %+v", executions.Executions)
	}
}

// TestTrigger_SensorPauseRestartResume proves that a polling source's pause is durable and stops
// the probe goroutine, including after a hard restart. Editing the target while paused must not
// fire early; resume must re-register the current config and immediately observe the new version.
//
// TestTrigger_SensorPauseRestartResume 证明轮询 source 的暂停是耐久的，并在硬重启后仍停止 probe goroutine。
// 暂停期间编辑目标不得提前触发；resume 必须用当前配置重挂并立即观察新版本。
func TestTrigger_SensorPauseRestartResume(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "sensor-pause-restart"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	probeFn := fnCreate(t, wc, "paused_sensor_probe", "def f() -> dict:\n    return {'level': 1}\n")
	trgID := trgCreate(t, wc, "paused_sensor", "sensor", map[string]any{
		"targetKind": "function", "targetId": probeFn, "intervalSec": 5,
		"condition": "payload.level > 10", "output": "{'level': payload.level}",
	})
	wfID, _ := wfWithTrigger(t, wc, "paused_sensor_pipe", trgID)

	type activation struct {
		Fired       bool           `json:"fired"`
		ReturnValue map[string]any `json:"returnValue"`
		Payload     map[string]any `json:"payload"`
		FiringCount int            `json:"firingCount"`
	}
	var acts []activation
	harness.Eventually(t, 15000, "sensor records its initial false probe", func() bool {
		r := wc.GET("/api/v1/triggers/" + trgID + "/activations")
		return r.Status == 200 && json.Unmarshal(r.Data, &acts) == nil && len(acts) > 0 && !acts[0].Fired && acts[0].ReturnValue["level"] == float64(1)
	})
	baseActivations := len(acts)
	baseFirings := len(listFirings(t, wc, trgID, "limit=50"))

	var paused trgRow
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, &paused)
	if !paused.Paused || paused.Listening || paused.NextFireAt != "" {
		t.Fatalf("sensor pause projection wrong: %+v", paused)
	}

	srv.Kill9(t)
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)
	if tr := getTrg(t, wc, trgID); !tr.Paused || tr.Listening || tr.NextFireAt != "" {
		t.Fatalf("sensor pause must survive restart with polling stopped: %+v", tr)
	}

	// Change the active target while the source is stopped. The edit is intentionally before resume:
	// the first post-resume probe must see level=42, while the pause window must stay quiet.
	// source 停止时改 active target，刻意早于 resume：恢复后的第一轮 probe 必须看到 level=42，暂停窗必须安静。
	wc.POST("/api/v1/functions/"+probeFn+":edit", map[string]any{
		"ops": []map[string]any{{"op": "set_code", "code": "def f() -> dict:\n    return {'level': 42}\n"}},
	}).OK(t, nil)
	time.Sleep(6500 * time.Millisecond)
	var pausedActs []activation
	wc.GET("/api/v1/triggers/"+trgID+"/activations").OK(t, &pausedActs)
	if len(pausedActs) != baseActivations {
		t.Fatalf("paused sensor must not probe after restart/edit: %d → %d", baseActivations, len(pausedActs))
	}
	if got := len(listFirings(t, wc, trgID, "limit=50")); got != baseFirings {
		t.Fatalf("paused sensor must not mint a firing after restart/edit: %d → %d", baseFirings, got)
	}
	if rows := listRunRows(t, wc, "?workflowId="+wfID); len(rows) != 0 {
		t.Fatalf("false sensor must not have started a workflow before resume: %+v", rows)
	}

	var resumed trgRow
	wc.POST("/api/v1/triggers/"+trgID+":resume", map[string]any{}).OK(t, &resumed)
	if resumed.Paused || !resumed.Listening {
		t.Fatalf("sensor resume projection wrong: %+v", resumed)
	}

	var run struct {
		ID     string `json:"id"`
		Status string `json:"status"`
		Origin string `json:"origin"`
	}
	harness.Eventually(t, 30000, "resumed sensor observes edited target", func() bool {
		var current []activation
		r := wc.GET("/api/v1/triggers/" + trgID + "/activations")
		if r.Status != 200 || json.Unmarshal(r.Data, &current) != nil {
			return false
		}
		seenNew := false
		for _, act := range current {
			if act.Fired && act.ReturnValue["level"] == float64(42) && act.Payload["level"] == float64(42) && act.FiringCount > 0 {
				seenNew = true
				break
			}
		}
		if !seenNew {
			return false
		}
		var runs []struct {
			ID     string `json:"id"`
			Status string `json:"status"`
			Origin string `json:"origin"`
		}
		r = wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil {
			return false
		}
		for _, candidate := range runs {
			if candidate.Status == "completed" && candidate.Origin == "sensor" {
				run = candidate
				return true
			}
		}
		return false
	})
	if run.ID == "" {
		t.Fatalf("resumed sensor must create a completed sensor-origin run: %+v", run)
	}
	// Stop the five-second poll once the transition is observed so the assertions remain about one
	// deliberate edge, not an unbounded stream of equal true probes.
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, nil)
	firings := listFirings(t, wc, trgID, "limit=50")
	if len(firings) != baseFirings+1 || firings[len(firings)-1].Status != "started" || firings[len(firings)-1].FlowrunID != run.ID {
		t.Fatalf("resumed sensor firing ledger wrong: %+v", firings)
	}
}

// TestTrigger_SensorHandlerTargetAndInvokeFailure covers the resident-handler sensor adapter,
// not only the function adapter. Its first probe deliberately raises; the activation must retain
// the invoke failure, while the next cadence returns a valid payload and drives a real workflow.
//
// TestTrigger_SensorHandlerTargetAndInvokeFailure 覆盖驻留 handler sensor adapter，而不只 function
// adapter。第一次 probe 刻意抛错，activation 必须保留 invoke failure；下一 cadence 返回有效 payload
// 并驱动真实 workflow。
func TestTrigger_SensorHandlerTargetAndInvokeFailure(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "sensor-handler-target"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "sensor_handler_probe", map[string]any{
		"initBody": "self.calls = 0",
		"methods": []map[string]any{{
			"name": "probe", "inputs": []any{},
			"body": "self.calls += 1\nif self.calls == 1:\n    raise Exception('sensor probe boom')\nreturn {'level': 42, 'calls': self.calls}",
		}},
	})
	trgID := trgCreate(t, wc, "handler_sensor", "sensor", map[string]any{
		"targetKind": "handler", "targetId": hdID, "method": "probe", "intervalSec": 5,
		"condition": "payload.level > 10", "output": "{'level': payload.level, 'sourceCalls': payload.calls}",
	})
	wfID, _ := wfWithTrigger(t, wc, "handler_sensor_pipe", trgID)

	type activation struct {
		Fired       bool           `json:"fired"`
		ReturnValue map[string]any `json:"returnValue"`
		Payload     map[string]any `json:"payload"`
		Error       string         `json:"error"`
		Detail      string         `json:"detail"`
		FiringCount int            `json:"firingCount"`
	}
	var acts []activation
	harness.Eventually(t, 15000, "handler sensor records invoke failure", func() bool {
		r := wc.GET("/api/v1/triggers/" + trgID + "/activations")
		if r.Status != 200 || json.Unmarshal(r.Data, &acts) != nil {
			return false
		}
		for _, act := range acts {
			if !act.Fired && act.Detail == "invoke failed" && strings.Contains(act.Error, "sensor probe boom") && act.FiringCount == 0 {
				return true
			}
		}
		return false
	})

	var run struct {
		ID     string `json:"id"`
		Status string `json:"status"`
		Origin string `json:"origin"`
	}
	harness.Eventually(t, 30000, "handler sensor succeeds on the next probe", func() bool {
		r := wc.GET("/api/v1/triggers/" + trgID + "/activations")
		if r.Status != 200 || json.Unmarshal(r.Data, &acts) != nil {
			return false
		}
		seenSuccess := false
		for _, act := range acts {
			if act.Fired && act.FiringCount > 0 && act.ReturnValue["level"] == float64(42) && act.Payload["level"] == float64(42) && act.Payload["sourceCalls"] == float64(2) {
				seenSuccess = true
				break
			}
		}
		if !seenSuccess {
			return false
		}
		var runs []struct {
			ID     string `json:"id"`
			Status string `json:"status"`
			Origin string `json:"origin"`
		}
		r = wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 || json.Unmarshal(r.Data, &runs) != nil {
			return false
		}
		for _, candidate := range runs {
			if candidate.Status == "completed" && candidate.Origin == "sensor" {
				run = candidate
				return true
			}
		}
		return false
	})
	if run.ID == "" {
		t.Fatalf("handler sensor success must create a completed sensor-origin run: %+v", run)
	}

	var calls struct {
		Calls []struct {
			Status string `json:"status"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls").OK(t, &calls)
	if len(calls.Calls) < 2 {
		t.Fatalf("handler sensor must leave both failed and successful call rows: %+v", calls.Calls)
	}
	hasOK := false
	hasFailed := false
	for _, call := range calls.Calls {
		if call.Status == "ok" {
			hasOK = true
		}
		if call.Status == "failed" {
			hasFailed = true
		}
	}
	if !hasOK || !hasFailed {
		t.Fatalf("handler sensor call ledger must retain failed+ok attempts: %+v", calls.Calls)
	}
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, nil)
}
