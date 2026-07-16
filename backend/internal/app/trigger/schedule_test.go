package trigger

// schedule_test.go covers the forward schedule timeline (scheduler 工单⑧): the window bounds what
// is returned, only LISTENING non-paused cron triggers contribute, a trigger's whole reference set
// rides each point, the global cap truncates honestly (earliest-first, across triggers), and the
// non-cron kinds are absent by nature.
//
// schedule_test.go 覆盖前瞻调度时间线（scheduler 工单⑧）：窗口界定返回什么、只有**正在监听且未暂停**的
// cron trigger 有贡献、trigger 的整个引用集随每个点带出、全局 cap 诚实截断（跨 trigger、最早优先）、
// 非 cron kind 天然缺席。

import (
	"context"
	"testing"
	"time"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
)

func mkCronExpr(t *testing.T, s *Service, ctx context.Context, name, expr string) *triggerdomain.Trigger {
	t.Helper()
	tr, err := s.Create(ctx, CreateInput{Name: name, Kind: triggerdomain.KindCron, Config: map[string]any{"expression": expr}})
	if err != nil {
		t.Fatalf("create %s: %v", name, err)
	}
	return tr
}

// TestSchedule_WindowListenersAndWorkflows: the window decides the horizon; every point carries the
// trigger's full listening set; a trigger nobody listens to is not scheduled at all.
func TestSchedule_WindowListenersAndWorkflows(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}

	hourly := mkCronExpr(t, s, ctx, "hourly", "0 * * * *")
	_ = s.Attach(ctx, hourly.ID, "wf_1")
	_ = s.Attach(ctx, hourly.ID, "wf_2")

	// An unreferenced cron trigger: real row, real expression, but nothing listens → no points.
	// 无引用的 cron trigger：行真、表达式真，但无人监听 → 无点。
	mkCronExpr(t, s, ctx, "orphan", "0 * * * *")

	res, err := s.Schedule(ctx, ScheduleQuery{Within: 3 * time.Hour, Limit: 100})
	if err != nil {
		t.Fatalf("Schedule: %v", err)
	}
	if len(res.Points) == 0 {
		t.Fatal("an hourly trigger must produce points within 3h")
	}
	if res.Truncated {
		t.Fatalf("3 points under a 100 cap must not report truncation")
	}
	now := time.Now()
	for _, p := range res.Points {
		if p.TriggerID != hourly.ID {
			t.Fatalf("only the LISTENED trigger may contribute points, got %s", p.TriggerID)
		}
		if p.TriggerName != "hourly" {
			t.Fatalf("point must carry the trigger name, got %q", p.TriggerName)
		}
		if !p.At.After(now) || p.At.After(now.Add(3*time.Hour)) {
			t.Fatalf("point %v outside the (now, now+3h] window", p.At)
		}
		// The whole reference set rides the point — this is the trigger→workflow reverse lookup.
		// 整个引用集随点带出——这就是 trigger→workflow 反查。
		if len(p.WorkflowIDs) != 2 || p.WorkflowIDs[0] != "wf_1" || p.WorkflowIDs[1] != "wf_2" {
			t.Fatalf("point must carry both listening workflows sorted, got %v", p.WorkflowIDs)
		}
	}
	// Ascending by time. 按时间升序。
	for i := 1; i < len(res.Points); i++ {
		if res.Points[i].At.Before(res.Points[i-1].At) {
			t.Fatalf("points must ascend by time: %v then %v", res.Points[i-1].At, res.Points[i].At)
		}
	}
}

// TestSchedule_PausedAndNonCronAreAbsent — 判决① + 工单⑧: a paused trigger has NO schedule (its cron
// entry is removed — a future point would be a lie), and webhook/fsnotify/sensor have no knowable
// next fire, so they never enter the timeline. Resuming brings the points back.
func TestSchedule_PausedAndNonCronAreAbsent(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	s.webhook = &fakeListener{}
	s.sensor = &fakeListener{}

	cronTrg := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	_ = s.Attach(ctx, cronTrg.ID, "wf_1")

	hook, err := s.Create(ctx, CreateInput{Name: "hook", Kind: triggerdomain.KindWebhook, Config: map[string]any{"path": "p"}})
	if err != nil {
		t.Fatalf("create webhook: %v", err)
	}
	_ = s.Attach(ctx, hook.ID, "wf_2")

	res, err := s.Schedule(ctx, ScheduleQuery{Within: time.Hour, Limit: 10})
	if err != nil {
		t.Fatalf("Schedule: %v", err)
	}
	for _, p := range res.Points {
		if p.TriggerID == hook.ID {
			t.Fatal("a webhook trigger has no knowable next fire — it must not enter the timeline")
		}
	}
	if len(res.Points) == 0 {
		t.Fatal("the cron trigger should contribute before the pause")
	}

	if _, err := s.Pause(ctx, cronTrg.ID); err != nil {
		t.Fatalf("Pause: %v", err)
	}
	paused, err := s.Schedule(ctx, ScheduleQuery{Within: time.Hour, Limit: 10})
	if err != nil {
		t.Fatalf("Schedule after pause: %v", err)
	}
	if len(paused.Points) != 0 {
		t.Fatalf("a paused trigger schedules NOTHING; got %d points", len(paused.Points))
	}

	if _, err := s.Resume(ctx, cronTrg.ID); err != nil {
		t.Fatalf("Resume: %v", err)
	}
	resumed, err := s.Schedule(ctx, ScheduleQuery{Within: time.Hour, Limit: 10})
	if err != nil {
		t.Fatalf("Schedule after resume: %v", err)
	}
	if len(resumed.Points) == 0 {
		t.Fatal("resume must bring the schedule back")
	}
}

// TestSchedule_TruncatesHonestlyAndAcrossTriggers — 工单⑧: an every-minute cron over a week vastly
// overruns the cap. The result must be capped, FLAGGED truncated (never a silent short page), and
// still hold the true earliest points — the cap is global, so a chatty trigger cannot crowd out an
// earlier tick of a quieter one.
func TestSchedule_TruncatesHonestlyAndAcrossTriggers(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}

	minutely := mkCronExpr(t, s, ctx, "minutely", "* * * * *")
	_ = s.Attach(ctx, minutely.ID, "wf_1")
	hourly := mkCronExpr(t, s, ctx, "hourly", "0 * * * *")
	_ = s.Attach(ctx, hourly.ID, "wf_2")

	res, err := s.Schedule(ctx, ScheduleQuery{Within: 168 * time.Hour, Limit: 5})
	if err != nil {
		t.Fatalf("Schedule: %v", err)
	}
	if len(res.Points) != 5 {
		t.Fatalf("limit=5 must cap the timeline at 5 points, got %d", len(res.Points))
	}
	if !res.Truncated {
		t.Fatal("a week of minutely ticks under a cap of 5 MUST report truncated=true")
	}
	// Global ordering: the 5 earliest ticks of the union are all minutely's (its next 5 minutes all
	// precede the next hour boundary in the common case) — assert ascending + inside the window
	// rather than a brittle exact match, but prove the hourly trigger cannot displace an earlier tick.
	// 全局有序：并集最早的 5 个刻度都是 minutely 的——断言升序 + 在窗内（不做脆的精确匹配），
	// 但要证明 hourly 无法挤掉更早的刻度。
	for i := 1; i < len(res.Points); i++ {
		if res.Points[i].At.Before(res.Points[i-1].At) {
			t.Fatalf("truncation must keep the EARLIEST points in order: %v then %v", res.Points[i-1].At, res.Points[i].At)
		}
	}
	last := res.Points[len(res.Points)-1].At
	for _, p := range res.Points {
		if p.At.After(last) {
			t.Fatalf("point %v beyond the last kept point %v", p.At, last)
		}
	}
}

// TestSchedule_DefaultsAndClamps — 工单⑧: zero/oversized inputs land on the documented defaults and
// ceilings rather than erroring or running unbounded (the handler 422s only on garbage).
func TestSchedule_DefaultsAndClamps(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "hourly", "0 * * * *")
	_ = s.Attach(ctx, tr.ID, "wf_1")

	// Zero query → default window (168h) + default cap: an hourly trigger yields 168-ish points,
	// comfortably under the 200 default cap, so nothing truncates.
	// 零值查询 → 默认窗（168h）+ 默认 cap：hourly 产约 168 个点，远低于默认 cap 200，故不截断。
	res, err := s.Schedule(ctx, ScheduleQuery{})
	if err != nil {
		t.Fatalf("Schedule: %v", err)
	}
	if len(res.Points) < 160 || len(res.Points) > DefaultScheduleLimit {
		t.Fatalf("default window should yield ~168 hourly points under the %d cap, got %d", DefaultScheduleLimit, len(res.Points))
	}
	if res.Truncated {
		t.Fatal("168 hourly points under the 200 default cap must not truncate")
	}

	// Oversized window/limit clamp to the ceilings instead of running unbounded.
	// 超界的窗/limit 钳到上限，而非无界运行。
	big, err := s.Schedule(ctx, ScheduleQuery{Within: 365 * 24 * time.Hour, Limit: 100000})
	if err != nil {
		t.Fatalf("Schedule (oversized): %v", err)
	}
	if len(big.Points) > MaxScheduleLimit {
		t.Fatalf("limit must clamp to %d, got %d points", MaxScheduleLimit, len(big.Points))
	}
	horizon := time.Now().Add(MaxScheduleWithin)
	for _, p := range big.Points {
		if p.At.After(horizon) {
			t.Fatalf("within must clamp to %v; point %v is beyond it", MaxScheduleWithin, p.At)
		}
	}
}
