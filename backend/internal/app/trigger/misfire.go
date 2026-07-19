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

// maxMisfireLookback floors how far back one sweep WALKS when the window overflows the ledger cap
// above. It bounds the WALK, not the truth: `missed_checked_at` is NULL until the first sweep ever
// runs, so `from` falls back to created_at — on an install upgrading into 工单⑨ that is however old
// the trigger is, and expanding a `* * * * *` cron across a year is half a million robfig Next()
// calls ON THE SYNCHRONOUS BOOT PATH (the boot sweep runs before the server serves).
//
// It can only bite a window that ALREADY holds more than the cap — a probe settles that in cap+1
// Next() calls — i.e. one whose older ticks the cap was going to drop anyway. So a SPARSE schedule
// is booked exactly, however old the gap (a weekly cron down for half a year = ~26 ticks, all of
// them), and at hourly-or-denser the kept tail (200 ticks = 200 hours or less) lives well inside the
// floor, so the booked rows are identical to walking the whole gap. The watermark still jumps to the
// window's end, so whatever the floor cut is accounted exactly once and never re-walked.
//
// maxMisfireLookback 界定单次 sweep 在窗口撑爆上面那个台账 cap 时最多**往回走**多远。它界的是**遍历**、
// 不是真相：首次 sweep 跑之前 `missed_checked_at` 恒为 NULL，故 `from` 回落 created_at——对升级进工单⑨
// 的安装来说，那是 trigger 有多老就多老，而把 `* * * * *` 展开一年 = 五十万次 robfig Next()，且跑在
// **同步 boot 径**上（boot sweep 在开始服务之前跑）。
//
// 它只可能咬到**本就**装了超过 cap 个刻度的窗——一次探针用 cap+1 次 Next() 就能判定——也就是那些老刻度
// 本来就要被 cap 丢掉的窗。故**稀疏**调度无论缺口多老都记得**分毫不差**（每周一次的 cron 停机半年 =
// 约 26 个刻度、一个不少），而每小时或更密时，留下的尾巴（200 个刻度 = 至多 200 小时）远在地板之内，
// 故记下的行与走完整段缺口逐条相同。水位照样跳到窗口末端，故被地板切掉的部分恰入账一次、绝不重走。
const maxMisfireLookback = 30 * 24 * time.Hour

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
		// Shutdown reaches the sweep (bootstrap threads the loop's ctx through forEachWorkspace):
		// stop at a trigger boundary — every booked row is already committed — rather than grinding
		// the rest of the list through a cancelled ctx and logging a failure for each.
		// 关停能抵达 sweep（bootstrap 经 forEachWorkspace 把循环的 ctx 串了进来）：在 trigger 边界停——
		// 已记的行都已提交——而不是拖着一个已取消的 ctx 把剩下的列表磨完、还逐个记一条失败。
		if err := ctx.Err(); err != nil {
			return booked, err
		}
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
	// The window ends where the tick becomes UNFIREABLE — it is NOT (watermark, now].
	//
	// The live listener still honours a callback up to croninfra.MisfireTolerance behind its tick
	// (snapTick), so a tick inside that trailing band may yet fire FOR REAL. Booking it `missed`
	// takes the tick's dedup key, and the fire arriving a moment later finds the key taken:
	// AppendFiring returns the missed row, no runnable firing exists, and the workflow silently never
	// runs while the ledger swears the tick was missed. Only a tick that can no longer legally fire
	// is accountable.
	//
	// But the grace is bounded BELOW by hotSince, and that is not a detail — it is the common case.
	// A cron entry computes its first activation from the instant it is scheduled, so a tick at or
	// before this process Registered the listener is already dead: the previous process's entries
	// went with it, and this one will never deliver them. Waiting the grace out for those would leave
	// a restart's own missed ticks — the everyday shape of this on a desktop app — invisible on the
	// ledger for two minutes after boot. Nothing is swallowed either way: the watermark stops at the
	// same instant, so a tick still inside the grace is booked by a later sweep, once it IS dead.
	//
	// 窗口止于**刻度再也开不出火**之处——**不是** (水位, now]。
	//
	// 活 listener 仍认可迟于其刻度至多 croninfra.MisfireTolerance 的回调（snapTick），故落在这条尾带里的刻度
	// **仍可能真开火**。此时记 `missed` 会占掉该刻度的 dedup 键，而随后到来的 fire 发现键已被占：AppendFiring
	// 返回那条 missed 行、没有任何可跑的 firing 存在，于是 workflow 悄无声息地不跑，台账却赌咒说它错过了。
	// **只有再也不可能合法开火的刻度才可入账**。
	//
	// 但宽限**下界是 hotSince**，而这不是细节、正是常态：cron entry 的首次触发从它被排入的那一刻算起，故
	// 本进程 Register listener 之时及之前的刻度**已经死了**——上个进程的 entry 随进程而去，这个 entry 也永远
	// 不会送达它们。为它们干等宽限，会让**一次重启自己错过的刻度**（桌面 app 上这事最日常的形状）在 boot 后
	// 两分钟内于台账上不可见。两种情况都不会吞：水位停在同一时刻，故仍在宽限内的刻度由稍后的 sweep 记下、
	// 那时它才真死。
	until := now.Add(-croninfra.MisfireTolerance)
	if hot := s.hotSince(t.ID); hot.After(until) {
		until = hot
	}

	// Watermark floor: never before the trigger existed — a trigger created yesterday cannot have
	// missed last year's ticks (a NULL watermark is a trigger that never fired nor swept).
	// 水位下限：绝不早于 trigger 存在之时——昨天建的 trigger 不可能错过去年的刻度（NULL 水位 = 从未
	// fire 也从未 sweep 过的 trigger）。
	from := t.CreatedAt
	if t.MissedCheckedAt != nil && t.MissedCheckedAt.After(from) {
		from = *t.MissedCheckedAt
	}
	if !from.Before(until) {
		return 0, nil // nothing accountable yet. 尚无可入账的。
	}

	ticks, err := s.accountableTicks(t, from, until)
	if err != nil {
		return 0, err
	}

	booked := 0
	// lastBooked = the most recent tick this sweep REALLY put on the ledger (ticks ascend, so the
	// last assignment wins). It, not len(ticks), is what catchup_one may fire — see below.
	// lastBooked = 本次 sweep **真正**落进台账的最近一个刻度（ticks 升序，故最后一次赋值胜出）。
	// catchup_one 可以补的是**它**、不是 len(ticks)——见下。
	var lastBooked time.Time
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
				lastBooked = tick
			}
		}
	}

	// Account the whole window regardless of the cap: the gap is now checked up to the window's END
	// (`until`, not now — the trailing tolerance band is deliberately still open, see above), so the
	// next sweep starts from here and an old shutdown is never re-walked.
	// 无论是否封顶，整个窗都已入账：缺口已查到窗口**末端**（`until`、非 now——尾部容差带刻意仍开着，
	// 见上），下次 sweep 从此处起，老关机绝不重走。
	if err := s.repo.AdvanceMissedWatermark(ctx, t.ID, until); err != nil {
		return booked, err
	}

	// catchup_one (判决⑥, opt-in per trigger): after accounting, fire ONCE for the most recent
	// missed tick — through the normal fan-out, so the run is indistinguishable from a real cron
	// run (origin stays cron, overlap policy applies). Older ticks stay `missed`: "catch up ONE"
	// means one, which is the whole point of not storming.
	//
	// The gate is what this sweep actually BOOKED, never what the window merely held. A tick already
	// accounted (dedup hit — it fired, or a previous sweep booked it) must not be caught up again,
	// and re-checking a window that books nothing is not hypothetical: it is exactly the crash
	// window this sweep is written to survive (fan-out committed, AdvanceMissedWatermark did not, the
	// process died in between). Firing off `len(ticks) > 0` there runs the same tick a SECOND time.
	//
	// catchup_one（判决⑥，逐 trigger 自选）：记账之后，对**最近一个**错过刻度补一次 fire——照正常扇出径，
	// 使该 run 与真 cron run 无从分辨（origin 仍 cron、并发策略照常）。更早的刻度仍是 `missed`：「补一个」
	// 就是一个，这正是不搞风暴的全部要义。
	//
	// 闸门是本次 sweep **真正落账**的东西、绝不是窗口里**装着**什么。已入账的刻度（dedup 命中——它 fire 过、
	// 或上次 sweep 已记）不许再补，而「重查一个什么都记不下的窗」并非假想：那正是本 sweep 写出来就为了扛住的
	// 崩溃窗（扇出已提交、AdvanceMissedWatermark 没有、进程死在两者之间）。在那里按 `len(ticks) > 0` 开火，
	// 就是把同一个刻度跑**第二遍**。
	if !lastBooked.IsZero() && triggerdomain.MisfirePolicy(t.Config) == triggerdomain.MisfireCatchupOne {
		s.catchupOne(ctx, t, lastBooked)
	}
	return booked, nil
}

// accountableTicks returns the ticks in (from, until] this sweep should book: the window's contents,
// most-recent-capped at maxMissedPerTrigger.
//
// The walk is bounded BEFORE it starts. The probe costs at most cap+1 robfig Next() calls and answers
// the only question that decides the cost: does the window even hold more than the cap? Almost always
// no — a sparse schedule down for months (a weekly cron over half a year ≈ 26 ticks) is booked whole,
// exactly, at ~26 Next() calls. Only an overflowing window is re-anchored to maxMisfireLookback, and
// there the cap was going to keep just the tail anyway (see both consts).
//
// accountableTicks 返回本次 sweep 该记的 (from, until] 内刻度：窗口内容，按 maxMissedPerTrigger 保留最近的。
//
// 遍历在**开始之前**就被界定。探针至多花 cap+1 次 robfig Next()，回答唯一决定成本的问题：这个窗到底装没装
// 下超过 cap 个刻度？答案几乎总是「没有」——停机数月的稀疏调度（每周一次的 cron 跨半年 ≈ 26 个刻度）以约
// 26 次 Next() 被**分毫不差**地整个记下。只有撑爆的窗才重新锚到 maxMisfireLookback，而在那里 cap 本来也
// 只留尾巴（见两个常量）。
func (s *Service) accountableTicks(t *triggerdomain.Trigger, from, until time.Time) ([]time.Time, error) {
	expr := triggerdomain.CronExpression(t.Config)
	ticks, more, err := croninfra.TicksWithin(expr, from, until, maxMissedPerTrigger+1)
	if err != nil || !more {
		return ticks, err
	}
	if head := until.Add(-maxMisfireLookback); head.After(from) {
		from = head
	}
	ticks, _, err = croninfra.TicksWithin(expr, from, until, 0)
	if err != nil {
		return nil, err
	}
	if len(ticks) > maxMissedPerTrigger {
		s.log.Info("triggerapp: misfire gap exceeds the per-sweep cap; booking the most recent ticks only",
			zapTrigger(t.ID), zap.Int("ticks", len(ticks)), zap.Int("booked", maxMissedPerTrigger))
		ticks = ticks[len(ticks)-maxMissedPerTrigger:]
	}
	return ticks, nil
}

// catchupOne fires the most recent missed tick once through the normal fan-out path.
//
// It fires under the TICK'S OWN dedup key, so the fan-out lands on the `missed` row this sweep just
// booked and requeues that row into the run (RequeueMissedFiring). One tick, one ledger row, one
// disposition — and idx_trf_dedup governs the catch-up like every other fire. A parallel
// `<tick>|catchup` key would instead leave the ledger asserting BOTH that the tick was missed and
// that it ran (the sweep's own contract says older ticks stay missed — implying the caught-up one
// does not), and would be the single firing path the dedup index does not cover: the one place a
// double-run could still be minted. Exactly-once is not the key's job anyway — the caller only
// reaches here for a tick it just booked, and a tick books at most once.
//
// catchupOne 对最近一个错过刻度经正常扇出径补一次 fire。
//
// 它用**刻度自己的** dedup 键开火，故扇出落在本次 sweep 刚记的那条 `missed` 行上、把该行**救进**这次 run
// （RequeueMissedFiring）。一个刻度、一行台账、一个处置——且 idx_trf_dedup 像管别的 fire 一样管住补跑。
// 若另起一个 `<刻度>|catchup` 键，台账就会**同时**断言该刻度既错过了、又跑了（sweep 自己的契约写着「更早的
// 刻度仍是 missed」——言下之意被补的那个不是），且那会是 dedup 索引唯一管不到的开火径：唯一还能铸出双跑的
// 地方。何况「恰一次」本就不归键管——调用方只为**刚落账**的刻度走到这里，而一个刻度至多落账一次。
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
		DedupKey: croninfra.DedupKey(t.ID, tick),
	})
}
