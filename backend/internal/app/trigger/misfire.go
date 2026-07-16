package trigger

// misfire.go — misfire detection + `missed` accounting (scheduler 工单⑨, 判决⑥). A desktop app
// sleeps and gets shut down; cron ticks fall on the floor. The verdict: DO NOT catch up (a wake-up
// run-storm is the local-app hazard), but never silently swallow either — every missed tick becomes
// a `missed` firing row, a neutral "did not execute" ledger entry the UI can show as a grey ✕.
//
// Per-trigger watermark `missed_checked_at` = "every tick at or before this instant is accounted".
// The sweep books ticks in (watermark, now]. The watermark also advances on each delivered cron
// fan-out (report.go), on a live 0→1 attach and on :resume (lifecycle.go) — the two places where a
// stretch of NOT listening must be closed WITHOUT booking it, since a pause / an inactive workflow
// is the user's intent, not an accident.
//
// misfire.go — misfire 检测 + `missed` 记账（scheduler 工单⑨，判决⑥）。桌面 app 会睡、会被关；cron
// 刻度掉在地上。判决：**不补跑**（睡醒补跑风暴是本地 app 的危险），但也绝不静默吞掉——每个错过的刻度
// 落一条 `missed` firing 行，中性的「未执行」台账，UI 可渲成灰 ✕。
//
// 逐 trigger 水位 `missed_checked_at` =「此刻及之前的每个刻度都已入账」。sweep 记账 (水位, now] 内的刻度。
// 水位还在每次已送达的 cron 扇出（report.go）、实时 0→1 挂载与 :resume（lifecycle.go）时推进——后两处正是
// 必须**闭合但不记账**一段未监听时间的地方：暂停 / workflow 未激活是用户意志、不是事故。

import (
	"context"
	"time"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
	croninfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/cron"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

// maxMissedPerTrigger bounds one sweep's accounting per trigger. A `* * * * *` cron across a
// week-long shutdown is 10k ticks — booking every one would flood the ledger and the boot path for
// no added truth (the UI says "missed", the count past a point is noise). The MOST RECENT ticks are
// kept (the tail of the window), because those are the ones a user asks about; the watermark still
// jumps to now, so an old gap is accounted exactly once and never re-walked.
//
// maxMissedPerTrigger 界定单次 sweep 每 trigger 的记账量。`* * * * *` 跨一周关机 = 1 万个刻度——全记会淹掉
// 台账与 boot 径且不增真相（UI 只说「错过」，超过一定数量的计数是噪声）。保留**最近**的刻度（窗口尾部），
// 因为那才是用户会问的；水位照样跳到 now，故老缺口恰入账一次、绝不重走。
const maxMissedPerTrigger = 200

// SweepMisfires accounts every cron tick that came due while nobody could serve it, for every
// LISTENING, non-paused cron trigger in the ctx's workspace. Called at boot (after the listen
// registry is replayed) and on a periodic ticker — a laptop that sleeps for an hour and wakes with
// the process alive misfires exactly like a shutdown, and only a running sweep notices.
//
// Idempotence is the dedup key, not a flag: a missed tick is booked with croninfra.DedupKey(trigger,
// tick) — byte-identical to the key the live listener mints for that same tick — so idx_trf_dedup
// (workflow_id, trigger_id, dedup_key) makes a tick land EXACTLY ONCE per workflow, whether it
// fired or was missed, however many times the sweep runs. AppendFiring returns the existing row on
// conflict, so a re-sweep is a silent no-op rather than an error.
//
// Returns the number of missed rows actually booked (test/telemetry). Per-trigger failures are
// logged and skipped — one bad trigger must not stall the sweep for the rest.
//
// SweepMisfires 为 ctx 所在 workspace 里每个**正在监听、未暂停**的 cron trigger，把无人能服务时到期的
// 每个刻度入账。boot（监听表重放**之后**）与周期 ticker 调用——笔记本睡一小时醒来、进程还活着，其 misfire
// 与关机一模一样，而只有正在跑的 sweep 会发现。
//
// 幂等靠的是 dedup 键、不是标志位：错过的刻度以 croninfra.DedupKey(trigger, tick) 记账——与活 listener 为
// **同一刻度**铸的键逐字节相同——故 idx_trf_dedup (workflow_id, trigger_id, dedup_key) 使一个刻度对每个
// workflow **恰落一次**，无论它是 fire 了还是被错过、无论 sweep 跑多少次。AppendFiring 冲突时返已存在行，
// 故重复 sweep 是静默 no-op 而非报错。
//
// 返回真正记账的 missed 行数（测试/遥测）。逐 trigger 失败记日志跳过——一个坏 trigger 不该卡住其余。
func (s *Service) SweepMisfires(ctx context.Context) (int, error) {
	triggers, err := s.repo.ListAllTriggers(ctx)
	if err != nil {
		return 0, err
	}
	now := time.Now()
	booked := 0
	for _, t := range triggers {
		if t.Kind != triggerdomain.KindCron || t.Paused {
			continue
		}
		listeners := s.listeningSince(t.ID)
		if len(listeners) == 0 {
			continue // not listening → nothing was owed. 未监听 → 本就不欠。
		}
		n, err := s.sweepTrigger(ctx, t, listeners, now)
		if err != nil {
			s.log.Warn("triggerapp.SweepMisfires: skip trigger", zapTrigger(t.ID), zapErr(err))
			continue
		}
		booked += n
	}
	return booked, nil
}

// sweepTrigger books one trigger's missed ticks and advances its watermark.
//
// sweepTrigger 记一个 trigger 的错过刻度并推进其水位。
func (s *Service) sweepTrigger(ctx context.Context, t *triggerdomain.Trigger, listeners map[string]time.Time, now time.Time) (int, error) {
	// Watermark floor: never before the trigger existed — a trigger created yesterday cannot have
	// missed last year's ticks (a NULL watermark is a trigger that never fired nor swept).
	// 水位下限：绝不早于 trigger 存在之时——昨天建的 trigger 不可能错过去年的刻度（NULL 水位 = 从未
	// fire 也从未 sweep 过的 trigger）。
	from := t.CreatedAt
	if t.MissedCheckedAt != nil && t.MissedCheckedAt.After(from) {
		from = *t.MissedCheckedAt
	}
	if !from.Before(now) {
		return 0, nil // nothing to check. 无可查。
	}

	ticks, _, err := croninfra.TicksWithin(triggerdomain.CronExpression(t.Config), from, now, 0)
	if err != nil {
		return 0, err
	}
	// Keep only the most recent maxMissedPerTrigger — see the const. 只留最近的 N 个，见常量注释。
	if len(ticks) > maxMissedPerTrigger {
		s.log.Info("triggerapp: misfire gap exceeds the per-sweep cap; booking the most recent ticks only",
			zapTrigger(t.ID), zap.Int("ticks", len(ticks)), zap.Int("booked", maxMissedPerTrigger))
		ticks = ticks[len(ticks)-maxMissedPerTrigger:]
	}

	booked := 0
	for _, tick := range ticks {
		for wf, since := range listeners {
			// A workflow only misses ticks that came due AFTER it started listening. A zero epoch =
			// attached by the boot replay = it was listening before this process, so the whole
			// downtime gap is honestly its own.
			// workflow 只会错过它开始监听**之后**到期的刻度。零值纪元 = boot 重放挂上的 = 本进程之前
			// 就在监听，故整个停机缺口诚实地属于它。
			if !since.IsZero() && tick.Before(since) {
				continue
			}
			// Pre-mint the id so the return value tells new-row from dedup-hit: AppendFiring returns
			// the EXISTING row (a different id) when the key is taken — the tick already fired, or a
			// previous sweep booked it. Idempotence, not an error.
			// 预铸 id 使返回值能区分新行与去重命中：键被占时 AppendFiring 返**已存在**行（id 不同）——
			// 该刻度或真 fire 过、或上次 sweep 已记。这是幂等、不是错误。
			id := idgenpkg.New("trf")
			f, err := s.repo.AppendMissedFiring(ctx, &triggerdomain.Firing{
				ID:         id,
				TriggerID:  t.ID,
				WorkflowID: wf,
				Payload:    map[string]any{"firedAt": tick},
				DedupKey:   croninfra.DedupKey(t.ID, tick),
				Status:     triggerdomain.FiringMissed,
				// CreatedAt is the SCHEDULED tick, not the sweep instant: the ledger row answers
				// "what was due at 03:00 and didn't run", so wearing the wake-up time would make
				// every missed row of a night-long outage claim to be from the same second.
				// CreatedAt 取**调度刻度**、非 sweep 时刻：台账行回答的是「03:00 该跑什么、没跑」，
				// 若戴上睡醒时间，整夜停机的每条 missed 行都会自称同一秒发生。
				CreatedAt: tick.UTC(),
			})
			if err != nil {
				return booked, err
			}
			if f.ID == id {
				booked++
			}
		}
	}

	// Account the whole window regardless of the cap: the gap is now checked up to `now`, so the
	// next sweep starts from here and an old shutdown is never re-walked.
	// 无论是否封顶，整个窗都已入账：缺口已查到 `now`，下次 sweep 从此处起，老关机绝不重走。
	if err := s.repo.AdvanceMissedWatermark(ctx, t.ID, now); err != nil {
		return booked, err
	}

	// catchup_one (判决⑥, opt-in per trigger): after accounting, fire ONCE for the most recent
	// missed tick — through the normal fan-out, so the run is indistinguishable from a real cron
	// run (origin stays cron, overlap policy applies). Older ticks stay `missed`: "catch up ONE"
	// means one, which is the whole point of not storming. The catch-up fire carries its own dedup
	// key (the tick's key is taken by the missed row we just booked), keyed on the tick so a second
	// sweep cannot double-fire it.
	//
	// catchup_one（判决⑥，逐 trigger 自选）：记账之后，对**最近一个**错过刻度补一次 fire——照正常扇出径，
	// 使该 run 与真 cron run 无从分辨（origin 仍 cron、并发策略照常）。更早的刻度仍是 `missed`：「补一个」
	// 就是一个，这正是不搞风暴的全部要义。补跑的 fire 用自己的 dedup 键（刻度键已被刚记的 missed 行占了），
	// 仍按刻度构键，故第二次 sweep 无法重复补跑。
	if len(ticks) > 0 && triggerdomain.MisfirePolicy(t.Config) == triggerdomain.MisfireCatchupOne {
		last := ticks[len(ticks)-1]
		s.catchupOne(ctx, t, last)
	}
	return booked, nil
}

// catchupOne fires the most recent missed tick once through the normal fan-out path.
//
// catchupOne 对最近一个错过刻度经正常扇出径补一次 fire。
func (s *Service) catchupOne(ctx context.Context, t *triggerdomain.Trigger, tick time.Time) {
	listeners := s.listeningSince(t.ID)
	workflows := make([]string, 0, len(listeners))
	for wf, since := range listeners {
		if !since.IsZero() && tick.Before(since) {
			continue
		}
		workflows = append(workflows, wf)
	}
	if len(workflows) == 0 {
		return
	}
	s.log.Info("triggerapp: misfire catchup_one — firing the most recent missed tick",
		zapTrigger(t.ID), zap.Time("tick", tick))
	s.fanOut(ctx, t.ID, t.Kind, workflows, triggerinfra.Activity{
		Fired: true,
		// The payload keeps the SCHEDULED tick as firedAt (the canonical cron output field): the
		// workflow is running for that tick, and telling it the wake-up time would misdate the work.
		// payload 的 firedAt 保持**调度刻度**（cron 的规范输出字段）：workflow 正是为该刻度而跑，
		// 告诉它睡醒时间会让这次工作的日期错位。
		Payload:  map[string]any{"firedAt": tick},
		DedupKey: croninfra.DedupKey(t.ID, tick) + "|catchup",
	})
}
