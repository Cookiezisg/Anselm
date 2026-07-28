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
