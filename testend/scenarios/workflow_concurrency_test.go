package scenarios

import (
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

type concurrencyFiringRow struct {
	ID        string `json:"id"`
	Status    string `json:"status"`
	FlowrunID string `json:"flowrunId"`
}

func listConcurrencyFirings(t *testing.T, wc *harness.Client, triggerID string) []concurrencyFiringRow {
	t.Helper()
	var rows []concurrencyFiringRow
	wc.GET("/api/v1/triggers/"+triggerID+"/firings?limit=20").OK(t, &rows)
	return rows
}

func fireConcurrencyWebhook(t *testing.T, srv *harness.Server, triggerID, path, body string) {
	t.Helper()
	status := workflowC_rawPost(t, srv.BaseURL+"/api/v1/webhooks/"+triggerID+"/"+path, body, nil)
	if status != 202 {
		t.Fatalf("webhook fire must 202 for %s, got %d", triggerID, status)
	}
}

func countFiringStatuses(rows []concurrencyFiringRow) map[string]int {
	counts := make(map[string]int)
	for _, row := range rows {
		counts[row.Status]++
	}
	return counts
}

func waitConcurrencyDisposition(t *testing.T, wc *harness.Client, triggerID, wfID, policy string, want func(map[string]int, int, int) bool) []concurrencyFiringRow {
	t.Helper()
	deadline := time.Now().Add(20000 * time.Millisecond)
	for time.Now().Before(deadline) {
		firings := listConcurrencyFirings(t, wc, triggerID)
		running := len(workflowC_runsOf(t, wc, wfID, "running"))
		cancelled := len(workflowC_runsOf(t, wc, wfID, "cancelled"))
		if len(firings) == 2 && want(countFiringStatuses(firings), running, cancelled) {
			return firings
		}
		time.Sleep(100 * time.Millisecond)
	}
	firings := listConcurrencyFirings(t, wc, triggerID)
	t.Fatalf("%s overlap disposition timeout: firings=%+v runs=%+v", policy, firings, workflowC_runsOf(t, wc, wfID, ""))
	return nil
}

// settleConcurrencyApprovals resolves every parked approval run, including the second run
// released by serial/buffer_one after the first run completes. It intentionally uses the public
// flowrun approval route so cleanup exercises the same durable wake-up path as a real user.
func settleConcurrencyApprovals(t *testing.T, wc *harness.Client, wfID, triggerID string) {
	t.Helper()
	for pass := 0; pass < 3; pass++ {
		running := workflowC_runsOf(t, wc, wfID, "running")
		if len(running) == 0 {
			// A serial/buffer_one run can be pending for one scheduler tick after the prior
			// approval settles. Wait for that hand-off instead of letting cleanup hide it.
			harness.Eventually(t, 20000, "queued overlap firing drains", func() bool {
				if len(workflowC_runsOf(t, wc, wfID, "running")) > 0 {
					return true
				}
				for _, firing := range listConcurrencyFirings(t, wc, triggerID) {
					if firing.Status == "pending" {
						return false
					}
				}
				return true
			})
			if len(workflowC_runsOf(t, wc, wfID, "running")) == 0 {
				return
			}
			running = workflowC_runsOf(t, wc, wfID, "running")
		}
		ids := make([]string, 0, len(running))
		for _, run := range running {
			ids = append(ids, run.ID)
			wc.POST("/api/v1/flowruns/"+run.ID+"/approvals/hold:decide", map[string]any{"decision": "yes"}).OK(t, nil)
		}
		harness.Eventually(t, 20000, "approval runs settle", func() bool {
			for _, id := range ids {
				status, _ := workflowC_run(t, wc, id)
				if status == "running" {
					return false
				}
			}
			return true
		})
	}
	harness.Eventually(t, 20000, "all concurrency runs settle", func() bool {
		return len(workflowC_runsOf(t, wc, wfID, "running")) == 0
	})
}

// TestWorkflow_RealTriggerConcurrencyPolicies is the black-box counterpart to the scheduler
// overlap unit tests (D-conc-5). Each policy receives two real webhook fires while the first run
// is parked at an approval. The assertions cover both durable firing disposition and flowrun
// state, then resolve the approvals through the public route to leave no in-flight test state.
func TestWorkflow_RealTriggerConcurrencyPolicies(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	wc := workflowC_ws(t, srv, "wf-concurrency-live")

	policies := []struct {
		name string
		want func(firing map[string]int, running, cancelled int) bool
	}{
		{name: "serial", want: func(f map[string]int, running, cancelled int) bool {
			return f["started"] == 1 && f["pending"] == 1 && running == 1
		}},
		{name: "skip", want: func(f map[string]int, running, cancelled int) bool {
			return f["started"] == 1 && f["skipped"] == 1 && running == 1
		}},
		{name: "buffer_one", want: func(f map[string]int, running, cancelled int) bool {
			return f["started"] == 1 && f["pending"] == 1 && running == 1
		}},
		{name: "replace", want: func(f map[string]int, running, cancelled int) bool {
			return f["started"] == 2 && running == 1 && cancelled == 1
		}},
		{name: "allow_all", want: func(f map[string]int, running, cancelled int) bool {
			return f["started"] == 2 && running == 2
		}},
	}

	for _, policy := range policies {
		policy := policy
		t.Run(policy.name, func(t *testing.T) {
			path := "overlap-" + policy.name
			trgID := trgCreate(t, wc, path+"_hook", "webhook", map[string]any{"path": path})
			apfID := workflowC_apf(t, wc, path+"_gate")
			wfID := workflowC_apfGraph(t, wc, path+"_wf", trgID, apfID,
				map[string]any{"op": "set_meta", "concurrency": policy.name})
			wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

			fireConcurrencyWebhook(t, srv, trgID, path, `{"seq":1}`)
			harness.Eventually(t, 20000, policy.name+" first fire parks", func() bool {
				runs := workflowC_runsOf(t, wc, wfID, "running")
				if len(runs) != 1 {
					return false
				}
				_, nodes := workflowC_run(t, wc, runs[0].ID)
				return strings.Contains(nodes, `"parked"`)
			})

			// The second request is a real inbound webhook, not :fire or manual :trigger. The first
			// run remains parked so the overlap decision cannot be mistaken for a fast-run race.
			fireConcurrencyWebhook(t, srv, trgID, path, `{"seq":2}`)
			waitConcurrencyDisposition(t, wc, trgID, wfID, policy.name, policy.want)

			firings := listConcurrencyFirings(t, wc, trgID)
			if len(firings) != 2 {
				t.Fatalf("%s must leave two firing ledger rows, got %+v", policy.name, firings)
			}
			if !policy.want(countFiringStatuses(firings), len(workflowC_runsOf(t, wc, wfID, "running")), len(workflowC_runsOf(t, wc, wfID, "cancelled"))) {
				t.Fatalf("%s real overlap contract not met: firings=%+v runs=%+v", policy.name, firings, workflowC_runsOf(t, wc, wfID, ""))
			}

			settleConcurrencyApprovals(t, wc, wfID, trgID)
		})
	}
}
