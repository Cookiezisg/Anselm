package scenarios

// scheduler_p2_test.go — scheduler P2 工单黑盒:
// ⑧ GET /trigger-schedule(真 cron 真未来点 + workflowIds 反查 + 暂停消失 + 非法参数 422)
// ⑨ misfire=跳过+missed 记账(真停机跨过刻度 → 醒来 firing 台账有 missed 行、且一个都没补跑)
//
// scheduler_p2_test.go — black-box for the two scheduler P2 work orders: ⑧ the forward schedule
// timeline over a real listening cron (points, reverse-resolved workflowIds, pause removes them,
// loud 422s) and ⑨ misfire accounting — a REAL shutdown across a tick boundary, after which the
// ledger carries `missed` rows and NOTHING was caught up (判决⑥).

import (
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

type schedulePoint struct {
	At          string   `json:"at"`
	TriggerID   string   `json:"triggerId"`
	TriggerName string   `json:"triggerName"`
	WorkflowIDs []string `json:"workflowIds"`
}

type scheduleRes struct {
	Points    []schedulePoint `json:"points"`
	Truncated bool            `json:"truncated"`
}

func getSchedule(t *testing.T, wc *harness.Client, query string) scheduleRes {
	t.Helper()
	var res scheduleRes
	wc.GET("/api/v1/trigger-schedule" + query).OK(t, &res)
	return res
}

type firingRow struct {
	ID         string `json:"id"`
	Status     string `json:"status"`
	WorkflowID string `json:"workflowId"`
	FlowrunID  string `json:"flowrunId"`
	CreatedAt  string `json:"createdAt"`
}

func listFirings(t *testing.T, wc *harness.Client, trgID, query string) []firingRow {
	t.Helper()
	var rows []firingRow
	wc.GET("/api/v1/triggers/" + trgID + "/firings" + query).OK(t, &rows)
	return rows
}

// TestTriggerSchedule_Timeline — 工单⑧: an hourly cron with an active workflow yields ascending
// future points that name the trigger and reverse-resolve the workflows that would really run;
// pausing empties the timeline (nothing IS scheduled); garbage params are loud 422s.
func TestTriggerSchedule_Timeline(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "trg-schedule"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	trgID := trgCreate(t, wc, "hourly_tick", "cron", map[string]any{"expression": "0 * * * *"})
	wfID, _ := wfWithTrigger(t, wc, "sched_pipe", trgID)

	res := getSchedule(t, wc, "?within=6h&limit=50")
	if len(res.Points) == 0 {
		t.Fatal("an hourly cron with an active workflow must have future points within 6h")
	}
	if res.Truncated {
		t.Fatalf("6 hourly points under a cap of 50 must not truncate: %+v", res)
	}
	var prev time.Time
	for i, p := range res.Points {
		at, err := time.Parse(time.RFC3339, p.At)
		if err != nil {
			t.Fatalf("point %d: at must be RFC3339, got %q", i, p.At)
		}
		if !at.After(time.Now().Add(-time.Minute)) {
			t.Fatalf("point %d is not in the future: %v", i, at)
		}
		if i > 0 && at.Before(prev) {
			t.Fatalf("points must ascend by time: %v then %v", prev, at)
		}
		prev = at
		if p.TriggerID != trgID || p.TriggerName != "hourly_tick" {
			t.Fatalf("point must name its trigger, got %+v", p)
		}
		// The reverse lookup: the point carries the workflow that would actually run.
		// 反查：点带出真会跑的 workflow。
		if len(p.WorkflowIDs) != 1 || p.WorkflowIDs[0] != wfID {
			t.Fatalf("point must reverse-resolve to the listening workflow %s, got %v", wfID, p.WorkflowIDs)
		}
	}

	// A shorter window really bounds the horizon. 更短的窗真的收紧地平线。
	if short := getSchedule(t, wc, "?within=90m&limit=50"); len(short.Points) > 2 {
		t.Fatalf("a 90m window of an hourly cron holds at most 2 points, got %d", len(short.Points))
	}

	// Paused → nothing is scheduled (判决①: a future point would lie). 暂停 → 无排程（给未来点即撒谎）。
	wc.POST("/api/v1/triggers/"+trgID+":pause", map[string]any{}).OK(t, nil)
	if paused := getSchedule(t, wc, "?within=6h&limit=50"); len(paused.Points) != 0 {
		t.Fatalf("a paused trigger schedules NOTHING, got %d points", len(paused.Points))
	}
	wc.POST("/api/v1/triggers/"+trgID+":resume", map[string]any{}).OK(t, nil)
	if resumed := getSchedule(t, wc, "?within=6h&limit=50"); len(resumed.Points) == 0 {
		t.Fatal("resume must bring the schedule back")
	}

	// Illegal query values are loud 422s, never a silent default. 非法值 422 大声拒、绝不静默用默认。
	wc.GET("/api/v1/trigger-schedule?within=soon").Fail(t, 422, "TRIGGER_SCHEDULE_INVALID_QUERY")
	wc.GET("/api/v1/trigger-schedule?within=-3h").Fail(t, 422, "TRIGGER_SCHEDULE_INVALID_QUERY")
	wc.GET("/api/v1/trigger-schedule?limit=0").Fail(t, 422, "TRIGGER_SCHEDULE_INVALID_QUERY")
	wc.GET("/api/v1/trigger-schedule?limit=lots").Fail(t, 422, "TRIGGER_SCHEDULE_INVALID_QUERY")
}

// TestTriggerSchedule_TruncatesHonestly — 工单⑧: an every-minute cron over a week vastly overruns
// the cap; the response must say so rather than pass a capped page off as the whole window.
func TestTriggerSchedule_TruncatesHonestly(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "trg-trunc"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	trgID := trgCreate(t, wc, "minutely", "cron", map[string]any{"expression": "* * * * *"})
	wfWithTrigger(t, wc, "trunc_pipe", trgID)

	res := getSchedule(t, wc, "?within=168h&limit=10")
	if len(res.Points) != 10 {
		t.Fatalf("limit=10 must cap the timeline, got %d points", len(res.Points))
	}
	if !res.Truncated {
		t.Fatal("a week of minutely ticks under a cap of 10 MUST report truncated=true")
	}
}

// TestTrigger_MisfireMissedAccounting — 工单⑨ / 判决⑥, the real thing: an every-minute cron is
// listening, the sidecar is HARD-KILLED, a tick boundary passes while it is down, and the restarted
// app must (a) book the missed tick(s) on the firing ledger as `missed`, readable through the
// firings endpoint, and (b) run NONE of them — the default policy is skip, because a local app that
// wakes into a catch-up storm is the hazard the verdict exists to prevent.
func TestTrigger_MisfireMissedAccounting(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "trg-misfire"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	trgID := trgCreate(t, wc, "misfire_tick", "cron", map[string]any{"expression": "* * * * *"})
	wfID, _ := wfWithTrigger(t, wc, "misfire_pipe", trgID)

	// Kill the sidecar and stay down ACROSS a minute boundary — those ticks fall on the floor.
	// 杀掉 sidecar 并**跨过**一个整分钟边界——那些刻度掉在地上。
	srv.Kill9(t)
	boundary := time.Now().Truncate(time.Minute).Add(time.Minute + 5*time.Second)
	time.Sleep(time.Until(boundary))

	// Boot: replay the listeners, then account the gap.
	// 启动：重放监听，再把缺口入账。
	srv.Restart(t)
	wc = srv.Client(t).WS(wsID)

	var missed []firingRow
	harness.Eventually(t, 30000, "the downtime tick is booked missed", func() bool {
		missed = listFirings(t, wc, trgID, "?status=missed&limit=100")
		return len(missed) > 0
	})
	for _, m := range missed {
		if m.Status != "missed" {
			t.Fatalf("status filter leaked a non-missed row: %+v", m)
		}
		if m.WorkflowID != wfID {
			t.Fatalf("a missed row must name the listening workflow, got %+v", m)
		}
		// A missed tick is NOT a run: it never claims a flowrun. missed 不是 run：它绝无 flowrun。
		if m.FlowrunID != "" {
			t.Fatalf("a missed tick must never carry a flowrun — it was not run: %+v", m)
		}
		// It is dated at the tick it stands for (during the downtime), not at wake-up.
		// 它的日期是它所代表的刻度（停机期间）、不是睡醒时刻。
		at, err := time.Parse(time.RFC3339, m.CreatedAt)
		if err != nil {
			t.Fatalf("createdAt must be RFC3339: %q", m.CreatedAt)
		}
		if at.After(time.Now().Add(-2 * time.Second)) {
			t.Fatalf("a missed row must be dated at its scheduled tick, not the sweep instant: %v", at)
		}
	}

	// 判决⑥ "do not catch up": the missed ticks produced NO runs. Any run that exists could only
	// come from a post-restart live tick, which is a legitimately fresh fire — so assert the strong
	// invariant instead: no run's firing is a missed one (checked above via flowrunId), and the
	// missed rows never turn runnable.
	// 判决⑥「不补跑」：错过的刻度**没**产出 run。restart 之后的活刻度产生的 run 是合法的新 fire——
	// 故断言更强的不变式：没有 run 出自 missed（上方经 flowrunId 已查），且 missed 行永不变成可跑。
	stillMissed := listFirings(t, wc, trgID, "?status=missed&limit=100")
	if len(stillMissed) < len(missed) {
		t.Fatalf("missed rows must stay missed (nothing may reclaim them): %d → %d", len(missed), len(stillMissed))
	}

	// The ledger's other dispositions are untouched by the new word — the enum stayed closed and
	// the old filters still work (no silent empty page).
	// 台账其余处置不受新词影响——枚举仍封闭、旧过滤照常（不出静默空页）。
	wc.GET("/api/v1/triggers/" + trgID + "/firings?status=started").OK(t, nil)
	wc.GET("/api/v1/triggers/"+trgID+"/firings?status=gremlin").Fail(t, 422, "TRIGGER_FIRING_INVALID_STATUS")
}

// TestTrigger_MisfirePolicyVocabulary — 工单⑨: the per-trigger catchup policy is a closed
// vocabulary gated at create AND edit; a typo must not silently behave as the default.
func TestTrigger_MisfirePolicyVocabulary(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "trg-policy"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	// Both legal policies are accepted and persist on the config.
	// 两个合法策略都被接受且落在 config 上。
	for _, policy := range []string{"skip", "catchup_one"} {
		id := trgCreate(t, wc, "pol_"+policy, "cron", map[string]any{"expression": "*/5 * * * *", "misfirePolicy": policy})
		var got struct {
			Config map[string]any `json:"config"`
		}
		wc.GET("/api/v1/triggers/" + id).OK(t, &got)
		if got.Config["misfirePolicy"] != policy {
			t.Fatalf("misfirePolicy must round-trip, got %v", got.Config["misfirePolicy"])
		}
	}

	// A typo is a loud 422 at create... 写错 → create 时 422 大声拒……
	wc.POST("/api/v1/triggers", map[string]any{
		"name": "bad_policy", "kind": "cron",
		"config": map[string]any{"expression": "*/5 * * * *", "misfirePolicy": "catchup"},
	}).Fail(t, 422, "TRIGGER_INVALID_MISFIRE_POLICY")

	// ...and at edit. ……edit 时同样。
	id := trgCreate(t, wc, "editable_policy", "cron", map[string]any{"expression": "*/5 * * * *"})
	wc.PATCH("/api/v1/triggers/"+id, map[string]any{
		"config": map[string]any{"expression": "*/5 * * * *", "misfirePolicy": "ALL"},
	}).Fail(t, 422, "TRIGGER_INVALID_MISFIRE_POLICY")
}
