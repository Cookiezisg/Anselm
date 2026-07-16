package scenarios

// scheduler_p1_test.go — scheduler P1 工单黑盒:
// ⑥ GET /flowruns 过滤器(origin/triggerId/startedAfter/startedBefore,真 run 真过滤 + 非法值 422)
// ⑦ trigger :pause/:resume(暂停后 cron 到点不 fire、:fire 422、重启后仍暂停;resume 后真 fire)
//
// scheduler_p1_test.go — black-box for the two scheduler P1 work orders: ⑥ flowrun list filters
// over real runs (origin/triggerId/started window + loud 422s) and ⑦ the trigger pause/resume
// switch (a paused cron does NOT fire at the tick, :fire is refused, the switch survives a
// restart; resume fires again).

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

type frRow struct {
	ID        string `json:"id"`
	Status    string `json:"status"`
	Origin    string `json:"origin"`
	TriggerID string `json:"triggerId"`
}

func listRunRows(t *testing.T, wc *harness.Client, query string) []frRow {
	t.Helper()
	var rows []frRow
	wc.GET("/api/v1/flowruns"+query).OK(t, &rows)
	return rows
}

// TestFlowruns_ListFilters — 工单⑥: one webhook-fired run + one manual run in the same workflow,
// then every new filter axis proves itself against real rows.
func TestFlowruns_ListFilters(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fr-filters"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	trgID := trgCreate(t, wc, "filter_hook", "webhook", map[string]any{"path": "filterp"})
	wfID, _ := wfWithTrigger(t, wc, "filter_pipe", trgID)

	// One trigger-fired run (origin = the trigger's kind: webhook) + one manual run (origin=manual).
	// 一个触发起的 run（origin=trigger kind：webhook）+ 一个手动 run（origin=manual）。
	wc.POST("/api/v1/triggers/"+trgID+":fire", map[string]any{}).OK(t, nil)
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{}}).OK(t, nil)
	harness.Eventually(t, 30000, "both runs complete", func() bool {
		rows := listRunRows(t, wc, "?workflowId="+wfID)
		done := 0
		for _, r := range rows {
			if r.Status == "completed" {
				done++
			}
		}
		return done == 2
	})

	// origin filter: exactly one run per origin, and the two never bleed into each other.
	// origin 过滤：每个 origin 恰一条，互不串。
	hooked := listRunRows(t, wc, "?workflowId="+wfID+"&origin=webhook")
	if len(hooked) != 1 || hooked[0].Origin != "webhook" || hooked[0].TriggerID != trgID {
		t.Fatalf("origin=webhook must match exactly the fired run: %+v", hooked)
	}
	manual := listRunRows(t, wc, "?workflowId="+wfID+"&origin=manual")
	if len(manual) != 1 || manual[0].Origin != "manual" {
		t.Fatalf("origin=manual must match exactly the manual run: %+v", manual)
	}

	// triggerId filter: only the fired run carries the entry trg_. triggerId 过滤：只有触发起的 run 带入口 trg_。
	byTrg := listRunRows(t, wc, "?triggerId="+trgID)
	if len(byTrg) != 1 || byTrg[0].ID != hooked[0].ID {
		t.Fatalf("triggerId filter must match only the fired run: %+v", byTrg)
	}

	// started window: everything sits between the distant past and future bounds; an inverted
	// window is honestly empty. 时间窗：远过去/远未来界内全中；反向窗诚实为空。
	past, future := "2000-01-01T00:00:00Z", "2100-01-01T00:00:00Z"
	if rows := listRunRows(t, wc, "?workflowId="+wfID+"&startedAfter="+past+"&startedBefore="+future); len(rows) != 2 {
		t.Fatalf("wide window must match both runs, got %d", len(rows))
	}
	if rows := listRunRows(t, wc, "?workflowId="+wfID+"&startedBefore="+past); len(rows) != 0 {
		t.Fatalf("window ending in the past must be empty, got %d", len(rows))
	}
	// Filters compose with AND. 过滤 AND 组合。
	if rows := listRunRows(t, wc, "?workflowId="+wfID+"&origin=webhook&status=completed&startedAfter="+past); len(rows) != 1 {
		t.Fatalf("composed filters must still match the fired run, got %d", len(rows))
	}

	// Illegal values are loud 422s, never silent empty pages. 非法值 422 大声拒、绝不静默空页。
	wc.GET("/api/v1/flowruns?origin=gremlin").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?startedAfter=yesterday").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?startedBefore=24h").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?status=parked").Fail(t, 422, "FLOWRUN_INVALID_STATUS") // 既有轴不回归。
}

type trgRow struct {
	Paused     bool   `json:"paused"`
	Listening  bool   `json:"listening"`
	NextFireAt string `json:"nextFireAt"`
}

func getTrg(t *testing.T, wc *harness.Client, id string) trgRow {
	t.Helper()
	var tr trgRow
	wc.GET("/api/v1/triggers/"+id).OK(t, &tr)
	return tr
}

// TestTrigger_PauseResume_CronGate — 工单⑦: pause a listening every-minute cron, restart the
// process (the switch is persisted), prove the tick passes WITHOUT firing, then resume and see it
// fire for real.
func TestTrigger_PauseResume_CronGate(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "trg-pause"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	trgID := trgCreate(t, wc, "tick_gate", "cron", map[string]any{"expression": "* * * * *"})
	wfID, _ := wfWithTrigger(t, wc, "pause_pipe", trgID)

	// Listening (workflow active) — now hit the switch before any tick lands.
	// 已在监听（workflow active）——在任何刻度落地前按下开关。
	var paused trgRow
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, &paused)
	if !paused.Paused || paused.Listening || paused.NextFireAt != "" {
		t.Fatalf("paused trigger must read paused=true, listening=false, no nextFireAt: %+v", paused)
	}
	// Idempotent repeat. 重复暂停幂等。
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, nil)
	// Manual fire refuses loudly. 手动催大声拒。
	wc.POST("/api/v1/triggers/"+trgID+":fire", map[string]any{}).Fail(t, 422, "TRIGGER_PAUSED")

	// The switch survives a hard restart (persisted column + boot re-attach skips Register).
	// 开关活过硬重启（持久列 + boot 重挂跳过 Register）。
	srv.Kill9(t)
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)
	if tr := getTrg(t, wc, trgID); !tr.Paused || tr.Listening || tr.NextFireAt != "" {
		t.Fatalf("pause must survive a restart: %+v", tr)
	}

	// Let at least one full minute boundary pass — the tick must NOT fire. Baselines are taken
	// AFTER the pause: in the sliver between activate and :pause a boundary tick may already have
	// fired, which is legitimate pre-pause history, not a gate leak.
	// 让至少一个整分钟边界过去——刻度必须不 fire。基线在 pause **之后**取：activate 与 :pause 的间隙
	// 可能恰逢边界已 fire 一次，那是暂停前的合法历史、不是闸漏。
	baseRuns := len(listRunRows(t, wc, "?workflowId="+wfID))
	baseFired := strings.Count(string(wc.GET("/api/v1/triggers/"+trgID+"/activations").Data), `"fired":true`)
	boundary := time.Now().Truncate(time.Minute).Add(time.Minute + 10*time.Second)
	time.Sleep(time.Until(boundary))
	if rows := listRunRows(t, wc, "?workflowId="+wfID); len(rows) != baseRuns {
		t.Fatalf("paused cron must not start runs at the tick: %d → %d", baseRuns, len(rows))
	}
	if fired := strings.Count(string(wc.GET("/api/v1/triggers/"+trgID+"/activations").Data), `"fired":true`); fired != baseFired {
		t.Fatalf("paused cron must not record fired activations: %d → %d", baseFired, fired)
	}

	// Resume flips it back: projection restored, then the next tick really fires a NEW run
	// (strictly beyond the pre-pause baseline).
	// 恢复翻回：投影复原,下一刻度真触发**新** run（严格超出暂停前基线）。
	var resumed trgRow
	wc.POST("/api/v1/triggers/"+trgID+":resume", map[string]any{}).OK(t, &resumed)
	if resumed.Paused || !resumed.Listening || resumed.NextFireAt == "" {
		t.Fatalf("resumed trigger must read paused=false, listening=true, nextFireAt set: %+v", resumed)
	}
	harness.Eventually(t, 75000, "a fresh run completes after resume", func() bool {
		rows := listRunRows(t, wc, "?workflowId="+wfID+"&status=completed")
		return len(rows) > baseRuns
	})

	// The fired run carries the cron provenance stamp — closing the loop with 工单⑥'s filter.
	// 触发的 run 带 cron 溯源章——与工单⑥ 的过滤闭环。
	if rows := listRunRows(t, wc, fmt.Sprintf("?workflowId=%s&origin=cron", wfID)); len(rows) == 0 {
		t.Fatalf("the post-resume run must stamp origin=cron")
	}
}
