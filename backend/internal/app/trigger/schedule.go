package trigger

// schedule.go — the forward-looking schedule timeline (scheduler 工单⑧): every cron tick due in
// the next `within`, resolved to the workflows that would actually run. Only cron has future
// points; webhook/fsnotify/sensor are absent by nature (their next fire is unknowable), and a
// paused or unreferenced trigger contributes nothing — nothing IS scheduled for it.
//
// schedule.go — 前瞻调度时间线（scheduler 工单⑧）：未来 `within` 内每个 cron 刻度，解析到真会跑的
// workflow。只有 cron 有未来点；webhook/fsnotify/sensor 天然缺席（下次 fire 不可知）；暂停或无引用的
// trigger 什么都不贡献——它根本没有排程。

import (
	"context"
	"sort"
	"time"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	croninfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/cron"
)

// Schedule bounds (工单⑧). The window is generous (a week) but finite, and the point count is
// capped so a `* * * * *` trigger cannot mint 10k points — the response says so honestly via
// Truncated rather than silently short-changing the caller (N4: bounded → cursor-free).
//
// Schedule 边界（工单⑧）。窗口宽松（一周）但有限，点数封顶使 `* * * * *` 不会铸出 1 万个点——
// 响应经 Truncated 诚实说明，而非静默少给（N4：有界 → 免游标）。
const (
	DefaultScheduleWithin = 168 * time.Hour // 7d
	MaxScheduleWithin     = 30 * 24 * time.Hour
	DefaultScheduleLimit  = 200
	MaxScheduleLimit      = 1000
)

// SchedulePoint is one future cron tick: when it fires, whose tick it is, and which workflows would
// run. WorkflowIDs comes from the LIVE listen registry (the same reference set RefCount projects),
// so a point never promises a run that would not happen.
//
// SchedulePoint 是一个未来 cron 刻度：何时触发、属于谁、会跑哪些 workflow。WorkflowIDs 取自**活的**
// 监听表（与 RefCount 同一引用集），故一个点绝不承诺不会发生的运行。
type SchedulePoint struct {
	At          time.Time `json:"at"`
	TriggerID   string    `json:"triggerId"`
	TriggerName string    `json:"triggerName"`
	WorkflowIDs []string  `json:"workflowIds"`
}

// ScheduleQuery is the parsed GET /trigger-schedule query.
//
// ScheduleQuery 是解析后的 GET /trigger-schedule 查询。
type ScheduleQuery struct {
	Within time.Duration
	Limit  int
}

// ScheduleResult is the timeline plus its honest truncation signal: Truncated=true means the window
// really held more points than Limit, and the caller is seeing the earliest ones (never a silent lie).
//
// ScheduleResult 是时间线 + 诚实的截断信号：Truncated=true 表示窗内确实多于 Limit 个点、调用方看到的是
// 最早的那些（绝不静默撒谎）。
type ScheduleResult struct {
	Points    []SchedulePoint `json:"points"`
	Truncated bool            `json:"truncated"`
}

// Schedule returns every cron tick due within q.Within, ascending by time, capped at q.Limit.
//
// The cap is applied ACROSS triggers, not per trigger: each trigger is expanded up to the cap
// (a single `* * * * *` could fill it alone), the union is sorted by time, and only then is the
// global cap applied — so the earliest N points are the true earliest N, never one trigger's
// points crowding out an earlier tick of another. Truncated reports the union really overflowed.
//
// A trigger contributes points only while it is LISTENING and NOT paused: workflowIds is read from
// the in-memory listen registry (the reference set behind RefCount — the authority on "who would
// actually run"), so an unreferenced cron trigger (nothing listens) and a paused one contribute
// nothing at all. An unparseable expression is skipped (create-time Validate rejects those; a row
// mutated behind the API must not break the whole timeline).
//
// Schedule 返回 q.Within 内每个 cron 刻度，按时间升序，q.Limit 封顶。
//
// 封顶是**跨 trigger** 的、非逐 trigger：每个 trigger 各展开到 cap（单个 `* * * * *` 可能独自填满），
// 并集按时间排序，**然后**才应用全局 cap——故最早的 N 个点是真正最早的 N 个，绝不会让某个 trigger 的点
// 挤掉另一个更早的刻度。Truncated 报告并集确实溢出。
//
// trigger 仅在**正在监听且未暂停**时贡献点：workflowIds 读自内存监听表（RefCount 背后的引用集——
// 「谁真会跑」的权威），故无引用的 cron trigger（无人监听）与已暂停的一个点都不贡献。不可解析的表达式
// 跳过（create 时 Validate 已拒；被绕过 API 改坏的行不该弄坏整条时间线）。
func (s *Service) Schedule(ctx context.Context, q ScheduleQuery) (ScheduleResult, error) {
	if q.Within <= 0 {
		q.Within = DefaultScheduleWithin
	}
	if q.Within > MaxScheduleWithin {
		q.Within = MaxScheduleWithin
	}
	if q.Limit <= 0 {
		q.Limit = DefaultScheduleLimit
	}
	if q.Limit > MaxScheduleLimit {
		q.Limit = MaxScheduleLimit
	}

	triggers, err := s.repo.ListAllTriggers(ctx)
	if err != nil {
		return ScheduleResult{}, err
	}
	now := time.Now()
	until := now.Add(q.Within)

	points := make([]SchedulePoint, 0, q.Limit)
	overflow := false
	for _, t := range triggers {
		if t.Kind != triggerdomain.KindCron || t.Paused {
			continue
		}
		listeners := s.listeningSince(t.ID)
		if len(listeners) == 0 {
			continue // nothing listens → nothing is scheduled. 无人监听 → 无排程。
		}
		workflowIDs := make([]string, 0, len(listeners))
		for wf := range listeners {
			workflowIDs = append(workflowIDs, wf)
		}
		sort.Strings(workflowIDs) // deterministic wire order. 线缆顺序确定。

		// cap+1 per trigger: enough to know THIS trigger overflows the global cap on its own,
		// without walking a year of minutes.
		// 每 trigger 取 cap+1：足以判定它自己就撑爆全局 cap，而不必遍历一年的分钟。
		ticks, more, err := croninfra.TicksWithin(triggerdomain.CronExpression(t.Config), now, until, q.Limit+1)
		if err != nil {
			s.log.Warn("triggerapp.Schedule: skip unparseable cron expression", zapTrigger(t.ID), zapErr(err))
			continue
		}
		if more {
			overflow = true
		}
		for _, at := range ticks {
			points = append(points, SchedulePoint{At: at, TriggerID: t.ID, TriggerName: t.Name, WorkflowIDs: workflowIDs})
		}
	}

	sort.Slice(points, func(i, j int) bool {
		if points[i].At.Equal(points[j].At) {
			return points[i].TriggerID < points[j].TriggerID // stable same-instant tiebreak. 同刻确定 tiebreak。
		}
		return points[i].At.Before(points[j].At)
	})
	if len(points) > q.Limit {
		points = points[:q.Limit]
		overflow = true
	}
	return ScheduleResult{Points: points, Truncated: overflow}, nil
}
