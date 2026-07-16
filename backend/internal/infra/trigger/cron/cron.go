// Package cron is the cron source listener (wraps robfig/cron), keyed by triggerID: one
// cron entry per trigger. dedupKey is the scheduled tick (minute-truncated, ParseStandard's
// resolution) so a re-materialized fire of the same tick dedups against the live one.
//
// Package cron 是 cron source listener（封装 robfig/cron），按 triggerID 键：每 trigger 一个
// cron entry。dedupKey 是调度刻度（截断到分钟，ParseStandard 分辨率），同刻度重复材化时去重。
package cron

import (
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	robfigcron "github.com/robfig/cron/v3"
	"go.uber.org/zap"

	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
)

// Validate reports whether expr is a parseable standard (5-field) cron expression. The app
// calls it at create/edit time so a bad expression fails fast (mapped to ErrInvalidCron),
// not silently at Register.
//
// Validate 报告 expr 是否可解析的标准（5 字段）cron 表达式；app 在 create/edit 时调以快速失败。
func Validate(expr string) error {
	// robfig ParseStandard ALSO accepts @descriptors (@every/@daily/@hourly/...), but the listener's
	// dedupKey truncates to the minute (5-field resolution) — an @every fires at non-minute-aligned
	// instants it would mis-fold. Reject them here so the documented "5-field only; @every unsupported"
	// contract (TRIGGER_INVALID_CRON message + trigger.md) is TRUE, not a lie that silently schedules
	// an @every (F103).
	//
	// robfig ParseStandard 还接受 @descriptors（@every/@daily/...），但 listener 的 dedupKey 截断到分钟
	// （5 字段分辨率）——@every 在非分钟对齐时刻 fire、会被误折。在此拒绝它们，使文档化的「仅 5 字段、@every
	// 不支持」契约（TRIGGER_INVALID_CRON 消息 + trigger.md）为真，而非谎称不支持却静默调度（F103）。
	if strings.HasPrefix(strings.TrimSpace(expr), "@") {
		return fmt.Errorf("cron: @descriptors are not supported — use a 5-field expression")
	}
	if _, err := robfigcron.ParseStandard(expr); err != nil {
		return err
	}
	return nil
}

// NextAfter returns the first scheduled fire strictly after `after` for a 5-field cron expression
// (same ParseStandard semantics the listener schedules on). The app projects it as the read-time
// NextFireAt so the UI can show "next fire in N" without re-deriving the schedule; an invalid expr
// errors (create-time Validate already rejects those).
//
// NextAfter 返回 5 字段 cron 表达式在 `after` 之后的首次调度触发（与 listener 调度同 ParseStandard 语义）。
// app 把它作读时 NextFireAt 投影，使 UI 不必重算 schedule 即可显示「N 后触发」；非法 expr 报错（create 时 Validate 已拒）。
func NextAfter(expr string, after time.Time) (time.Time, error) {
	sched, err := robfigcron.ParseStandard(expr)
	if err != nil {
		return time.Time{}, err
	}
	return sched.Next(after), nil
}

// TicksWithin returns the scheduled ticks strictly after `after` and at/before `until`,
// earliest-first, parsing the expression once. cap>0 bounds the slice; more=true reports the
// window held further ticks beyond the cap (the caller's honest-truncation signal). Consumers:
// the schedule timeline (工单⑧) and the misfire sweep (工单⑨). A zero Next (robfig's
// "no tick within 5 years" dead-end) terminates the walk.
//
// TicksWithin 返回严格在 `after` 之后、`until`（含）之前的调度刻度，最早在前，表达式只解析一次。
// cap>0 封顶；more=true 表示窗内还有超出 cap 的刻度（调用方的诚实截断信号）。消费方：调度时间线
// （工单⑧）与 misfire sweep（工单⑨）。robfig 的零值 Next（5 年内无刻度的死端）终止遍历。
func TicksWithin(expr string, after, until time.Time, cap int) ([]time.Time, bool, error) {
	sched, err := robfigcron.ParseStandard(expr)
	if err != nil {
		return nil, false, err
	}
	var out []time.Time
	for t := sched.Next(after); !t.IsZero() && !t.After(until); t = sched.Next(t) {
		if cap > 0 && len(out) >= cap {
			return out, true, nil
		}
		out = append(out, t)
	}
	return out, false, nil
}

// DedupKey is the cron firing dedup key for one scheduled tick (minute-truncated, ParseStandard's
// resolution). Exported so the misfire sweep (工单⑨) mints the SAME key for a missed tick that the
// live listener mints for a fired one — idx_trf_dedup then guarantees a tick is booked exactly once
// (fired XOR missed), which is the whole idempotence story of missed accounting.
//
// DedupKey 是单个调度刻度的 cron firing 去重键（截断到分钟，ParseStandard 分辨率）。导出以使 misfire
// sweep（工单⑨）为错过刻度铸出与活 listener 为已 fire 刻度**完全相同**的键——idx_trf_dedup 由此保证
// 一个刻度恰入账一次（fired 与 missed 互斥），这就是 missed 记账幂等性的全部。
func DedupKey(triggerID string, tick time.Time) string {
	return triggerID + "|cron|" + strconv.FormatInt(tick.Truncate(time.Minute).Unix(), 10)
}

// misfireTolerance bounds how late a delivered cron callback may run behind its scheduled tick and
// still count as that tick. Beyond it the fire is a wall-clock-jump artifact (system sleep/suspend:
// Go timers pause or expire late, then robfig delivers ONE stale fire at wake) and is suppressed —
// under 判决⑥ a missed tick is recorded by the misfire sweep, never implicitly re-run (工单⑨).
//
// misfireTolerance 界定 cron 回调最多可迟于其调度刻度多少仍算该刻度。超过即墙钟跳变的伪 fire
// （系统睡眠/挂起：Go 计时器暂停或迟爆，醒来 robfig 会补送**一次**过期 fire），一律压制——
// 判决⑥ 下错过的刻度由 misfire sweep 记账，绝不被隐式补跑（工单⑨）。
const misfireTolerance = 2 * time.Minute

// snapTick resolves the scheduled tick a callback firing at `now` belongs to: the latest tick at or
// before now, within misfireTolerance. ok=false = no such tick — an off-schedule wake artifact.
//
// snapTick 求 `now` 触发的回调所属的调度刻度：now 及之前、misfireTolerance 内最近的刻度。
// ok=false = 无此刻度——睡醒的离谱伪 fire。
func snapTick(sched robfigcron.Schedule, now time.Time) (time.Time, bool) {
	var last time.Time
	for t := sched.Next(now.Add(-misfireTolerance - time.Second)); !t.IsZero() && !t.After(now); t = sched.Next(t) {
		last = t
	}
	return last, !last.IsZero()
}

// Listener wraps robfig/cron with one entry per triggerID.
//
// Listener 包 robfig/cron，每 triggerID 一个 entry。
type Listener struct {
	mu      sync.Mutex
	cron    *robfigcron.Cron
	entries map[string]robfigcron.EntryID
	report  triggerinfra.ReportFunc
	log     *zap.Logger
}

// New constructs a Listener bound to time.Local; caller calls Start to begin scheduling.
//
// New 构造 Listener（时区锁 time.Local）；调用方调 Start 才开始调度。
func New(log *zap.Logger, report triggerinfra.ReportFunc) *Listener {
	return &Listener{
		cron:    robfigcron.New(robfigcron.WithLocation(time.Local)),
		entries: make(map[string]robfigcron.EntryID),
		report:  report,
		log:     log.Named("trigger.cron"),
	}
}

// Register adds or replaces the cron entry for triggerID.
//
// Register 增加或替换 triggerID 的 cron entry。
func (l *Listener) Register(triggerID string, _ string, config map[string]any) error {
	expr, _ := config["expression"].(string)
	if expr == "" {
		return fmt.Errorf("cron.Register %s: empty expression", triggerID)
	}
	// Parse once and keep the schedule: the callback needs it to snap the fire to its scheduled
	// tick (and to suppress wake artifacts, see snapTick).
	// 只解析一次并持有 schedule：回调用它把 fire 吸附到调度刻度（并压制睡醒伪 fire，见 snapTick）。
	sched, err := robfigcron.ParseStandard(expr)
	if err != nil {
		return fmt.Errorf("cron.Register %s: %w", triggerID, err)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if existing, ok := l.entries[triggerID]; ok {
		l.cron.Remove(existing)
		delete(l.entries, triggerID)
	}
	id := l.cron.Schedule(sched, robfigcron.FuncJob(func() {
		now := time.Now()
		// Recover so an onFire panic doesn't crash the shared scheduler.
		// recover 防回调 panic 把共享 scheduler 拉崩。
		defer func() {
			if r := recover(); r != nil {
				l.log.Error("cron report panic", zap.String("triggerID", triggerID), zap.Any("recover", r))
			}
		}()
		// A callback more than misfireTolerance behind any scheduled tick is a wall-clock-jump
		// artifact (system slept through the tick; the timer fired late at wake) — drop it: the
		// misfire sweep accounts the gap as `missed` (工单⑨), and an implicit late run would
		// betray 判决⑥'s "never re-run". Snapping the dedup key to the TICK (not the fire minute)
		// also lets a legitimately-late fire dedup against that tick's missed row and vice versa.
		// 迟于任何调度刻度超过 misfireTolerance 的回调是墙钟跳变伪 fire（系统睡过该刻度、醒来计时器
		// 迟爆）——丢弃：misfire sweep 会把缺口记成 `missed`（工单⑨），隐式迟跑会背叛判决⑥的
		// 「绝不补跑」。dedup 键吸附到**刻度**（而非 fire 所在分钟），也让合法迟到的 fire 与该刻度的
		// missed 行互相去重。
		tick, ok := snapTick(sched, now)
		if !ok {
			l.log.Warn("cron: off-schedule fire suppressed (wall clock jumped; the misfire sweep accounts the gap)",
				zap.String("triggerID", triggerID), zap.Time("firedAt", now))
			return
		}
		l.report(triggerID, triggerinfra.Activity{
			Fired:    true,
			Payload:  map[string]any{"firedAt": now},
			DedupKey: DedupKey(triggerID, tick),
		})
	}))
	l.entries[triggerID] = id
	return nil
}

// Unregister removes triggerID's cron entry; no-op when absent.
//
// Unregister 删 triggerID 的 cron entry；不存在则 no-op。
func (l *Listener) Unregister(triggerID string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if id, ok := l.entries[triggerID]; ok {
		l.cron.Remove(id)
		delete(l.entries, triggerID)
	}
}

func (l *Listener) Start() { l.cron.Start() }

// Stop halts the scheduler and waits for in-flight fires to finish.
//
// Stop 停 scheduler 并等 in-flight fire 跑完。
func (l *Listener) Stop() {
	ctx := l.cron.Stop()
	<-ctx.Done()
}

var _ triggerinfra.Listener = (*Listener)(nil)
