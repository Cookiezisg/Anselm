package scenarios

import (
	"encoding/json"
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
