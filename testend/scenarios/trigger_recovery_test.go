package scenarios

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

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
