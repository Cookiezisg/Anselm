package trigger

// misfire_test.go covers misfire detection + `missed` accounting (scheduler 工单⑨, 判决⑥):
// the sweep books ticks the app slept through, is idempotent (dedup key = the tick), NEVER books a
// tick that actually fired, treats a PAUSE as the user's intent (accounted, not missed), skips
// stretches nobody listened to, honours catchup_one exactly once, and stays out of non-cron kinds.
//
// misfire_test.go 覆盖 misfire 检测 + `missed` 记账（scheduler 工单⑨，判决⑥）：sweep 把 app 睡过去的
// 刻度记账、幂等（dedup 键 = 刻度）、**绝不**记真 fire 过的刻度、把**暂停**当用户意志（入账但不记 missed）、
// 跳过无人监听的时段、catchup_one 恰补一次、不碰非 cron kind。

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"testing"
	"time"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerstore "github.com/sunweilin/anselm/backend/internal/infra/store/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
	croninfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/cron"
)

// backdateTrigger rewinds a trigger's misfire watermark AND its creation to `at`, simulating an app
// that was down (or asleep) since then — the sweep then sees the ticks in (at, now] as unaccounted.
// created_at moves too because the sweep floors its window there: a trigger born a second ago could
// not have missed an hour of ticks. Raw SQL by necessity (no API ages a row), mirroring the store
// tests' own created_at rewinds.
//
// backdateTrigger 把 trigger 的 misfire 水位**与创建时间**一起回拨到 `at`，模拟 app 自那时起就停机（或睡着）
// ——sweep 随即把 (at, now] 内的刻度视作未入账。created_at 也要动，因为 sweep 以它为窗下限：一秒前出生的
// trigger 不可能错过一小时的刻度。必须用裸 SQL（没有 API 能把行做旧），照 store 测试自己回拨 created_at 的先例。
func backdateTrigger(t *testing.T, db *sql.DB, id string, at time.Time) {
	t.Helper()
	if _, err := db.Exec(`UPDATE triggers SET missed_checked_at = ?, created_at = ? WHERE id = ?`, at.UTC(), at.UTC(), id); err != nil {
		t.Fatalf("backdate %s: %v", id, err)
	}
}

// ageHotSince backdates when this process Registered the trigger's listener, turning a just-attached
// service into one that has been LISTENING all along — the live-process misfire (a laptop that slept
// for an hour and woke with the process alive), as opposed to a restart. It is the difference the
// sweep's grace hangs on: a restart's ticks are dead on arrival (the entry cannot deliver them), a
// live listener's youngest ticks may still fire late. In-memory by necessity — no API ages a
// registration, and that is exactly the state under test.
//
// ageHotSince 把本进程 Register 该 trigger listener 的时刻回拨，使一个刚挂载的 service 变成**一直在监听**的
// ——即**活进程** misfire（笔记本睡了一小时、醒来进程还活着），与重启相对。sweep 的宽限正挂在这个区别上：
// 重启的刻度一到就是死的（entry 送不出它们），而活 listener 最年轻的那些仍可能迟到开火。只能在内存里做
// （没有 API 能把一次注册做旧），而那正是被测的状态。
func ageHotSince(t *testing.T, s *Service, triggerID string, d time.Duration) {
	t.Helper()
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.listeners[triggerID]
	if !ok {
		t.Fatalf("ageHotSince: %s has no listen entry", triggerID)
	}
	e.hotSince = time.Now().Add(-d)
}

// missedRows returns a trigger's firing rows in the `missed` disposition.
//
// missedRows 返回某 trigger 处于 `missed` 处置态的 firing 行。
func missedRows(t *testing.T, st *triggerstore.Store, ctx context.Context, triggerID string) []*triggerdomain.Firing {
	t.Helper()
	rows, _, err := st.SearchFirings(ctx, triggerdomain.FiringFilter{TriggerID: triggerID, Status: triggerdomain.FiringMissed, Limit: 500})
	if err != nil {
		t.Fatalf("SearchFirings(missed): %v", err)
	}
	return rows
}

// TestSweep_BooksMissedTicksIdempotently — 判决⑥ core: an every-minute cron whose app was down for
// ~10 minutes wakes to find those ticks booked `missed` (never re-run), and a SECOND sweep books
// nothing new — the dedup key is the tick itself, so accounting is exactly-once by construction.
//
// This is the RESTART shape (AttachReplay re-Registers the listener now), so the whole gap books in
// one pass: a tick that came due before this process scheduled its cron entry can never be delivered
// by it. The grace that guards a still-firable tick is
// TestSweep_LeavesTheToleranceBandToALateFire's business.
func TestSweep_BooksMissedTicksIdempotently(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	// AttachReplay = the boot path: this workflow was listening before the "restart", so the gap is
	// honestly its own. AttachReplay = boot 径：该 workflow 在「重启」前就在监听，故缺口诚实属于它。
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	downSince := time.Now().Add(-10 * time.Minute)
	backdateTrigger(t, db, tr.ID, downSince)

	n, err := s.SweepMisfires(ctx)
	if err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	if n < 9 || n > 11 {
		t.Fatalf("a ~10min downtime of an every-minute cron should book ~10 missed ticks, booked %d", n)
	}
	rows := missedRows(t, st, ctx, tr.ID)
	if len(rows) != n {
		t.Fatalf("booked %d but the ledger holds %d missed rows", n, len(rows))
	}
	// Missed is NOT a run: nothing pending, nothing to drain — 判决⑥'s "do not catch up".
	// missed 不是 run：无 pending、无可 drain——判决⑥ 的「不补跑」。
	if pend, _ := st.ListPendingFirings(ctx, 10); len(pend) != 0 {
		t.Fatalf("missed ticks must NOT become runnable firings, got %d pending", len(pend))
	}
	// Each row is dated at the tick it stands for, not at the sweep instant.
	// 每行的日期是它代表的刻度、不是 sweep 时刻。
	for _, r := range rows {
		if r.CreatedAt.After(time.Now().Add(-time.Second)) {
			t.Fatalf("a missed row must be dated at its scheduled tick, got %v", r.CreatedAt)
		}
		if r.WorkflowID != "wf_1" {
			t.Fatalf("missed row must name the listening workflow, got %q", r.WorkflowID)
		}
	}

	// Re-sweep: the watermark advanced, and even if it had not, the dedup key already exists.
	// 重复 sweep：水位已推进；即便没推进，dedup 键也已存在。
	again, err := s.SweepMisfires(ctx)
	if err != nil {
		t.Fatalf("second SweepMisfires: %v", err)
	}
	if again != 0 {
		t.Fatalf("a second sweep must book nothing, booked %d", again)
	}
	if rows2 := missedRows(t, st, ctx, tr.ID); len(rows2) != len(rows) {
		t.Fatalf("re-sweep changed the ledger: %d → %d rows", len(rows), len(rows2))
	}

	// Force the idempotence path itself: rewind the watermark so the SAME ticks are re-checked.
	// Nothing may double-book — the dedup key (workflow, trigger, tick) is already taken.
	// 直接逼出幂等径本身：把水位回拨，让**同样**的刻度被重查。绝不能重复记账——dedup 键已被占。
	backdateTrigger(t, db, tr.ID, downSince)
	forced, err := s.SweepMisfires(ctx)
	if err != nil {
		t.Fatalf("forced re-sweep: %v", err)
	}
	if forced != 0 {
		t.Fatalf("re-checking the same ticks must book nothing (dedup key), booked %d", forced)
	}
	if rows3 := missedRows(t, st, ctx, tr.ID); len(rows3) != len(rows) {
		t.Fatalf("forced re-sweep duplicated rows: %d → %d", len(rows), len(rows3))
	}
}

// TestSweep_LeavesTheToleranceBandToALateFire — 工单⑨ boundary: the sweep must not book a tick that
// can STILL fire. The live listener honours a callback up to croninfra.MisfireTolerance behind its
// tick (snapTick), so booking one younger than that steals the tick's dedup key from under the fire
// about to arrive — and a stolen key is not a loud failure but a silent one: AppendFiring returns
// the missed row, no runnable firing exists, and the workflow never runs while the ledger swears the
// tick was missed.
//
// Nothing is swallowed either: the watermark stops at the window's end, not at now, so the band is
// booked by a later sweep once it really is past firing.
//
// The grace applies to a LIVE listener — one that has been hot since before the gap, i.e. the laptop
// that slept with the process alive. Its counterpart (a restart, whose entry cannot deliver those
// ticks at all, so they book at once) is TestSweep_BooksMissedTicksIdempotently; together they pin
// the window's end as max(hotSince, now-tolerance).
func TestSweep_LeavesTheToleranceBandToALateFire(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	backdateTrigger(t, db, tr.ID, time.Now().Add(-10*time.Minute))
	// The process has been LISTENING all along — it slept, it did not restart. Its cron entry could
	// still deliver the youngest ticks late. 进程**一直在监听**——它是睡着了、不是重启。它的 cron entry
	// 仍可能把最年轻的那些刻度迟到送达。
	ageHotSince(t, s, tr.ID, time.Hour)

	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	cutoff := time.Now().Add(-croninfra.MisfireTolerance)
	rows := missedRows(t, st, ctx, tr.ID)
	if len(rows) == 0 {
		t.Fatal("the gap outside the tolerance band must still be booked")
	}
	for _, r := range rows {
		// created_at is the scheduled tick this row stands for (AppendMissedFiring backdates it).
		if r.CreatedAt.After(cutoff) {
			t.Fatalf("booked a tick at %v that may still legally fire (band starts %v) — its dedup key would be stolen from the real fire", r.CreatedAt, cutoff)
		}
	}
	// The watermark must NOT have jumped past the band: it stops where the accounting stopped, so the
	// band is still owed and a later sweep books it. 水位绝不能跳过尾带：它停在记账停下的地方，故尾带
	// 仍欠着账，由稍后的 sweep 记下。
	var wm time.Time
	if err := db.QueryRow(`SELECT missed_checked_at FROM triggers WHERE id = ?`, tr.ID).Scan(&wm); err != nil {
		t.Fatalf("read watermark: %v", err)
	}
	if wm.After(cutoff.Add(time.Second)) {
		t.Fatalf("the watermark (%v) must not claim the still-firable band (starts %v) is accounted — those ticks would be swallowed forever", wm, cutoff)
	}
}

// TestSweep_ARestartDoesNotWaitOutTheGraceForDeadTicks — the other half of the window's end, and the
// everyday one: a desktop app restarts, and the ticks it slept through are dead the moment the new
// process schedules its cron entry (an entry's first activation is computed from that instant, and
// the old process's entries died with it). Making those wait out the grace would leave a restart's
// own missed ticks invisible on the ledger for two minutes after boot — the exact window a user opens
// the panel and asks "did I miss anything?".
func TestSweep_ARestartDoesNotWaitOutTheGraceForDeadTicks(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil { // boot replay: Register happens NOW
		t.Fatalf("AttachReplay: %v", err)
	}
	// Down for just over one tick — the shape of an ordinary restart, and the whole gap sits inside
	// the tolerance band. 只停了刚过一个刻度——普通重启的形状，且整个缺口都落在容差带里。
	backdateTrigger(t, db, tr.ID, time.Now().Add(-90*time.Second))

	n, err := s.SweepMisfires(ctx)
	if err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	if n == 0 {
		t.Fatal("a restart's missed tick is dead on arrival (this process's entry can never deliver it) — it must book at once, not two minutes later")
	}
	if rows := missedRows(t, st, ctx, tr.ID); len(rows) != n {
		t.Fatalf("booked %d but the ledger holds %d missed rows", n, len(rows))
	}
	// Still 判决⑥: accounted, never run. 仍是判决⑥：入账、绝不补跑。
	if pend, _ := st.ListPendingFirings(ctx, 10); len(pend) != 0 {
		t.Fatalf("a restart must not wake into a catch-up, got %d runnable firings", len(pend))
	}
}

// TestFanOut_AFireOnATickBookedMissedRequeuesItIntoTheRun — 工单⑨, the honesty half of the same
// boundary: if a fire ever DOES land on a tick the sweep called missed (a clock step, a tolerance
// that drifts), the dedup hit must not swallow the run. AppendFiring returning the existing row with
// a nil error means "the key is accounted for", never "your fire produced a run" — so the row is
// requeued and the firingCount counts a real, runnable firing.
func TestFanOut_AFireOnATickBookedMissedRequeuesItIntoTheRun(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	backdateTrigger(t, db, tr.ID, time.Now().Add(-10*time.Minute))
	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	booked := missedRows(t, st, ctx, tr.ID)
	if len(booked) == 0 {
		t.Fatal("precondition: the sweep must have booked some missed ticks")
	}
	victim := booked[0] // its dedup key is a tick the ledger currently calls `missed`

	// The real fire for that very tick arrives after all.
	// 那个刻度的真 fire 终究还是来了。
	s.onReport(tr.ID, triggerinfra.Activity{
		Fired:    true,
		Payload:  map[string]any{"firedAt": victim.CreatedAt},
		DedupKey: victim.DedupKey,
	})

	// The row became the run — not a second row, and not a silently-dropped fire.
	// 那一行**变成了**这次 run——没有第二行，也没有被静默丢掉的 fire。
	pend, _ := st.ListPendingFirings(ctx, 50)
	if len(pend) != 1 || pend[0].ID != victim.ID {
		t.Fatalf("the fire must requeue the booked row into the run, got %d pending (want just %s)", len(pend), victim.ID)
	}
	for _, r := range missedRows(t, st, ctx, tr.ID) {
		if r.ID == victim.ID {
			t.Fatal("a tick that fired must not stay booked `missed` — the ledger would contradict the run")
		}
	}
	// The activation counts the firing it really produced.
	// activation 记的是它**真正**产生的那条 firing。
	acts, _, err := st.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: tr.ID, Limit: 10})
	if err != nil || len(acts) != 1 {
		t.Fatalf("SearchActivations: %d rows, err %v", len(acts), err)
	}
	if !acts[0].Fired || acts[0].FiringCount != 1 {
		t.Fatalf("the activation must report the 1 runnable firing it produced, got fired=%v firingCount=%d", acts[0].Fired, acts[0].FiringCount)
	}
	// ...and the firing points BACK at it. The sweep books a missed row with no activation (booking
	// is not an action), so a requeue that left activation_id empty would leave the activation
	// claiming a firing that references nothing — an audit trail that dead-ends.
	// ……而那条 firing **反指**它。sweep 记 missed 行时不带 activation（记账不是一次动作），故若 requeue 不盖
	// activation_id，就会剩下一个 activation 报着一条谁也不指的 firing——审计链断头。
	if pend[0].ActivationID != acts[0].ID {
		t.Fatalf("the requeued firing must reference the activation that ran it: firing.activationId=%q, activation=%q", pend[0].ActivationID, acts[0].ID)
	}
}

// TestFanOut_ARefireOfADispositionedTickCountsNoFiring — the other half of reading AppendFiring's
// return: a tick that already reached a disposition (here: claimed by the drain) produces NO run on
// a re-materialized fire, so firingCount must say 0. Counting it would let a `firingCount: 1`
// activation stand for a run that does not exist.
func TestFanOut_ARefireOfADispositionedTickCountsNoFiring(t *testing.T) {
	s, st, _ := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	if err := s.Attach(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("Attach: %v", err)
	}
	tick := time.Now().Truncate(time.Minute)
	fire := func() {
		s.onReport(tr.ID, triggerinfra.Activity{
			Fired: true, Payload: map[string]any{"firedAt": tick}, DedupKey: croninfra.DedupKey(tr.ID, tick),
		})
	}
	fire()
	pend, _ := st.ListPendingFirings(ctx, 10)
	if len(pend) != 1 {
		t.Fatalf("precondition: the first fire must queue a firing, got %d", len(pend))
	}
	// The drain claims it — the tick now has a disposition and is no longer runnable.
	// drain 认领了它——该刻度已有处置、不再可跑。
	if err := st.MarkFiringOutcome(ctx, pend[0].ID, triggerdomain.FiringStarted); err != nil {
		t.Fatalf("MarkFiringOutcome: %v", err)
	}

	fire() // the same tick re-materializes (a retry, a duplicate delivery)
	acts, _, err := st.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: tr.ID, Limit: 10})
	if err != nil || len(acts) != 2 {
		t.Fatalf("SearchActivations: %d rows, err %v; want 2", len(acts), err)
	}
	// Newest-first: the re-fire produced no runnable firing at all.
	if acts[0].FiringCount != 0 {
		t.Fatalf("a re-fire of an already-dispositioned tick mints no run, so it must count 0 firings, got %d", acts[0].FiringCount)
	}
	if pend2, _ := st.ListPendingFirings(ctx, 10); len(pend2) != 0 {
		t.Fatalf("the re-fire must not resurrect a started tick, got %d pending", len(pend2))
	}
}

// TestSweep_OldInstallBackfillIsBoundedButExact — the upgrade-first-boot shape (工单⑨): an install
// predating the watermark column has missed_checked_at NULL, so the window floors at created_at —
// however old the trigger is — and the boot sweep runs on the SYNCHRONOUS boot path, before the
// server serves. Expanding `* * * * *` across a year there is half a million robfig Next() calls.
//
// Three schedules pin the two halves of the bound, and the trade-off between them:
//   - SPARSE (weekly): the probe settles the whole year in ~52 Next() calls, so it is booked EXACTLY.
//     The walk bound must never truncate a schedule the cap was not going to truncate anyway.
//   - MID (daily): overflows the cap, and its 200 most recent ticks span 200 DAYS — past the floor.
//     This is where the floor's cost is real and deliberate: 30 days of "your 03:00 job did not run"
//     is the signal; the older rows are the noise the cap already exists to drop.
//   - DENSE (minutely): overflows the cap, but its 200 most recent ticks span 200 MINUTES — far
//     inside the floor, so the booked rows are identical to walking the whole year. Only the cost
//     differs, which is the entire point.
func TestSweep_OldInstallBackfillIsBoundedButExact(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}

	weekly := mkCronExpr(t, s, ctx, "weekly", "0 3 * * 1")     // ~52 ticks/yr — under the cap
	daily := mkCronExpr(t, s, ctx, "daily", "0 3 * * *")       // ~365 ticks/yr — over the cap, 24h cadence
	minutely := mkCronExpr(t, s, ctx, "minutely", "* * * * *") // ~525k ticks/yr — the boot-cost case
	for _, id := range []string{weekly.ID, daily.ID, minutely.ID} {
		if err := s.AttachReplay(ctx, id, "wf_1"); err != nil {
			t.Fatalf("AttachReplay: %v", err)
		}
		// created_at a year back, watermark NULL — exactly what an upgrading install looks like.
		// created_at 一年前、水位 NULL——升级中的安装就长这样。
		if _, err := db.Exec(`UPDATE triggers SET created_at = ?, missed_checked_at = NULL WHERE id = ?`,
			time.Now().Add(-365*24*time.Hour).UTC(), id); err != nil {
			t.Fatalf("age %s: %v", id, err)
		}
	}

	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	oldestOf := func(rows []*triggerdomain.Firing) time.Duration {
		t.Helper()
		if len(rows) == 0 {
			t.Fatal("no rows booked")
		}
		oldest := time.Now()
		for _, r := range rows {
			if r.CreatedAt.Before(oldest) {
				oldest = r.CreatedAt
			}
		}
		return time.Since(oldest)
	}

	// Sparse: booked whole, right back to the start of the outage. Truncating this to the last 30
	// days would under-report a real outage for no gain at all (~52 Next() calls).
	// 稀疏：整个记下，一直回到停机之初。把它砍到最近 30 天，是白白少报一次真实停机、且一分钱都没省（约 52 次 Next()）。
	weeklyRows := missedRows(t, st, ctx, weekly.ID)
	if len(weeklyRows) < 45 || len(weeklyRows) > maxMissedPerTrigger {
		t.Fatalf("a weekly cron down for a year must be booked exactly (~52 ticks), got %d — the walk bound must not truncate a sparse schedule", len(weeklyRows))
	}
	if age := oldestOf(weeklyRows); age < 300*24*time.Hour {
		t.Fatalf("the weekly cron's oldest booked tick is only %v old — the year-long gap was truncated", age)
	}

	// Mid: the floor bites, and it is meant to. Without it this books 200 rows reaching 200 days
	// back; with it, the last 30 days. 中等：地板咬住了，而且是有意的。没有它这里会记 200 行、回溯 200 天；
	// 有它则是最近 30 天。
	dailyRows := missedRows(t, st, ctx, daily.ID)
	floor := time.Now().Add(-maxMisfireLookback)
	for _, r := range dailyRows {
		if r.CreatedAt.Before(floor) {
			t.Fatalf("booked a daily tick at %v, older than the walk floor %v — the sweep expanded the whole year", r.CreatedAt, floor)
		}
	}
	if len(dailyRows) < 25 || len(dailyRows) > 35 {
		t.Fatalf("a daily cron backfilled under the %v floor should book ~30 ticks, got %d", maxMisfireLookback, len(dailyRows))
	}

	// Dense: the cap's worth, all recent — identical to an unbounded walk, minus the half-million
	// Next() calls. 密集：记满 cap、全是近期的——与无界遍历逐条相同，只是少了那五十万次 Next()。
	dense := missedRows(t, st, ctx, minutely.ID)
	if len(dense) != maxMissedPerTrigger {
		t.Fatalf("an every-minute cron down for a year must book exactly the cap, got %d", len(dense))
	}
	if age := oldestOf(dense); age > maxMisfireLookback {
		t.Fatalf("the every-minute cron's oldest booked tick is %v old, past the floor — the sweep expanded the whole year", age)
	}

	// Accounted exactly once: the watermark jumped to the window's end, so the pre-floor gap is
	// never re-walked. 恰入账一次：水位已跳到窗口末端，故地板之前的缺口绝不重走。
	if n, err := s.SweepMisfires(ctx); err != nil || n != 0 {
		t.Fatalf("the backfilled gap must be accounted exactly once: n=%d err=%v", n, err)
	}
}

// TestSweep_NeverBooksATickThatFired — the fired/missed exclusion: a tick that really fired holds
// the dedup key, so the sweep can never re-book it as missed (the row would contradict the run).
func TestSweep_NeverBooksATickThatFired(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	downSince := time.Now().Add(-3 * time.Minute)
	backdateTrigger(t, db, tr.ID, downSince)

	// The listener really delivered ONE of the ticks in the gap (its dedup key is that tick).
	// listener 真的送达了缺口里的**一个**刻度（其 dedup 键就是该刻度）。
	fired := time.Now().Add(-2 * time.Minute).Truncate(time.Minute)
	s.onReport(tr.ID, triggerinfra.Activity{
		Fired:    true,
		Payload:  map[string]any{"firedAt": fired},
		DedupKey: croninfra.DedupKey(tr.ID, fired),
	})
	// onReport advanced the watermark to now — rewind again so the sweep re-examines the gap that
	// still contains the fired tick. onReport 把水位推到了 now——再回拨，让 sweep 重查仍含该已 fire
	// 刻度的缺口。
	backdateTrigger(t, db, tr.ID, downSince)

	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	for _, r := range missedRows(t, st, ctx, tr.ID) {
		if r.DedupKey == croninfra.DedupKey(tr.ID, fired) {
			t.Fatal("a tick that FIRED must never also be booked missed — the ledger would contradict the run")
		}
	}
	// The fired tick is still a live pending firing, untouched by the sweep.
	// 已 fire 的刻度仍是活的 pending firing，sweep 没碰它。
	pend, _ := st.ListPendingFirings(ctx, 10)
	if len(pend) != 1 || pend[0].DedupKey != croninfra.DedupKey(tr.ID, fired) {
		t.Fatalf("the fired tick must remain a pending firing, got %d rows", len(pend))
	}
}

// TestSweep_PauseIsIntentNotMisfire — 判决⑥ + 工单⑦: ticks skipped while PAUSED are the user's own
// choice. Resuming must close the window silently (accounted, zero missed rows) — crying "you
// missed 40 runs" about a switch the user deliberately held down would be a false alarm.
func TestSweep_PauseIsIntentNotMisfire(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	if _, err := s.Pause(ctx, tr.ID); err != nil {
		t.Fatalf("Pause: %v", err)
	}
	// A long pause: rewind the watermark to simulate ticks passing while paused.
	// 长时间暂停：回拨水位，模拟暂停期间流过的刻度。
	backdateTrigger(t, db, tr.ID, time.Now().Add(-40*time.Minute))

	// A paused trigger is skipped outright by the sweep. 暂停的 trigger 被 sweep 整个跳过。
	if n, err := s.SweepMisfires(ctx); err != nil || n != 0 {
		t.Fatalf("a paused trigger must book no missed rows: n=%d err=%v", n, err)
	}
	if rows := missedRows(t, st, ctx, tr.ID); len(rows) != 0 {
		t.Fatalf("pause is intent, not misfire: got %d missed rows", len(rows))
	}

	// Resume CLOSES the pause window (watermark → now) instead of booking it. 恢复**闭合**暂停窗（水位 → now），而非记账。
	if _, err := s.Resume(ctx, tr.ID); err != nil {
		t.Fatalf("Resume: %v", err)
	}
	if n, err := s.SweepMisfires(ctx); err != nil || n != 0 {
		t.Fatalf("the pause stretch must be accounted, not booked: n=%d err=%v", n, err)
	}
	if rows := missedRows(t, st, ctx, tr.ID); len(rows) != 0 {
		t.Fatalf("resume must not resurrect the paused ticks as missed: got %d rows", len(rows))
	}
}

// TestSweep_NotListeningIsNotMisfire — a stretch during which the trigger had NO listener (no
// workflow active) is not a misfire either: nothing was owed. A live 0→1 attach closes that window,
// so activating a workflow today never books last week's ticks against it.
func TestSweep_NotListeningIsNotMisfire(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	// Nobody listens yet; a long stretch passes. 尚无人监听；流过很长一段。
	backdateTrigger(t, db, tr.ID, time.Now().Add(-30*time.Minute))

	if n, err := s.SweepMisfires(ctx); err != nil || n != 0 {
		t.Fatalf("an unlistened trigger owes nothing: n=%d err=%v", n, err)
	}

	// A LIVE attach (activate now) closes the not-listening window at this instant.
	// **实时** attach（此刻激活）在此刻闭合未监听窗。
	if err := s.Attach(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("Attach: %v", err)
	}
	if n, err := s.SweepMisfires(ctx); err != nil || n != 0 {
		t.Fatalf("activating today must not book yesterday's ticks: n=%d err=%v", n, err)
	}
	if rows := missedRows(t, st, ctx, tr.ID); len(rows) != 0 {
		t.Fatalf("no one was listening — nothing was missed; got %d rows", len(rows))
	}
}

// TestSweep_LiveAttachEpochBoundsItsOwnMissedTicks — the per-workflow epoch: when a gap IS real (a
// replayed workflow missed it), a workflow that only started listening midway must not be charged
// with the ticks that predate its attach.
func TestSweep_LiveAttachEpochBoundsItsOwnMissedTicks(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	// wf_old was listening before the restart (boot replay); wf_new attaches live, right now.
	// wf_old 在重启前就在监听（boot 重放）；wf_new 此刻实时挂载。
	if err := s.AttachReplay(ctx, tr.ID, "wf_old"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	if err := s.Attach(ctx, tr.ID, "wf_new"); err != nil {
		t.Fatalf("Attach: %v", err)
	}
	backdateTrigger(t, db, tr.ID, time.Now().Add(-5*time.Minute))

	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	rows := missedRows(t, st, ctx, tr.ID)
	if len(rows) == 0 {
		t.Fatal("the replayed workflow really missed the gap — it must be booked")
	}
	for _, r := range rows {
		if r.WorkflowID != "wf_old" {
			t.Fatalf("only the workflow that was listening during the gap may be booked, got %q", r.WorkflowID)
		}
	}
}

// TestSweep_CatchupOne_FiresExactlyOnce — 判决⑥ opt-in: catchup_one fires ONCE for the most recent
// missed tick (through the normal fan-out, so it is a real run), while the older ticks stay booked
// `missed`. Re-sweeping must not fire again — one means one.
func TestSweep_CatchupOne_FiresExactlyOnce(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr, err := s.Create(ctx, CreateInput{Name: "catcher", Kind: triggerdomain.KindCron, Config: map[string]any{
		"expression": "* * * * *", "misfirePolicy": triggerdomain.MisfireCatchupOne,
	}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	downSince := time.Now().Add(-10 * time.Minute)
	backdateTrigger(t, db, tr.ID, downSince)

	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	// Exactly ONE runnable firing — the catch-up — no matter how many ticks were missed.
	// 恰好**一条**可跑的 firing——补跑的那条——无论错过了多少刻度。
	pend, _ := st.ListPendingFirings(ctx, 50)
	if len(pend) != 1 {
		t.Fatalf("catchup_one must produce exactly ONE runnable firing, got %d", len(pend))
	}
	// The catch-up IS the most recent missed tick's own row, requeued — one tick, one ledger row,
	// one disposition. The ledger must never assert both "this tick was missed" and "this tick ran".
	// 补跑**就是**最近那个错过刻度自己的行被救回队列——一个刻度、一行台账、一个处置。台账绝不能同时断言
	// 「该刻度错过了」和「该刻度跑了」。
	missed := missedRows(t, st, ctx, tr.ID)
	for _, r := range missed {
		if r.DedupKey == pend[0].DedupKey {
			t.Fatal("the caught-up tick must not ALSO remain booked missed — the ledger would contradict the run")
		}
	}
	// The older ticks are still honestly booked missed (catch up ONE, not all): ~8 accountable ticks
	// in the 10min gap minus the tolerance band, one of which became the run.
	// 更早的刻度仍诚实记 missed（补**一个**、非全部）：10 分钟缺口去掉容差带 ≈ 8 个可入账刻度，其中一个变成了 run。
	if len(missed) < 6 {
		t.Fatalf("the older missed ticks must remain booked, got %d", len(missed))
	}

	// Re-sweep (watermark already advanced): no second catch-up run.
	// 重复 sweep（水位已推进）：不会有第二次补跑。
	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("second sweep: %v", err)
	}
	if pend2, _ := st.ListPendingFirings(ctx, 50); len(pend2) != 1 {
		t.Fatalf("a re-sweep must not fire a second catch-up, got %d pending", len(pend2))
	}
}

// TestSweep_CatchupOne_GatesOnWhatWasBooked_NotOnWhatTheWindowHeld — 判决⑥ + 工单⑨: re-checking a
// window whose ticks are ALREADY accounted must not catch anything up. That window is not
// hypothetical — it is the exact crash this sweep is written to survive (the fan-out committed, the
// watermark write did not, the process died in between), and it also happens whenever a sweep runs
// twice over the same gap.
//
// The proof is the ACTIVATION log, not the pending count: every fan-out writes an Activation
// unconditionally, so gating on `len(ticks) > 0` (what the window held) fires catchupOne again and
// leaves a second Activation behind — while its firing dedups quietly enough that a pending-count
// assertion never notices. Gating on what was really BOOKED means the re-sweep touches nothing.
func TestSweep_CatchupOne_GatesOnWhatWasBooked_NotOnWhatTheWindowHeld(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr, err := s.Create(ctx, CreateInput{Name: "catcher", Kind: triggerdomain.KindCron, Config: map[string]any{
		"expression": "* * * * *", "misfirePolicy": triggerdomain.MisfireCatchupOne,
	}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	downSince := time.Now().Add(-10 * time.Minute)
	backdateTrigger(t, db, tr.ID, downSince)

	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	acts := func() int {
		t.Helper()
		rows, _, err := st.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: tr.ID, Limit: 500})
		if err != nil {
			t.Fatalf("SearchActivations: %v", err)
		}
		return len(rows)
	}
	before := acts()
	if before != 1 {
		t.Fatalf("the first sweep must catch up exactly once (1 activation), got %d", before)
	}

	// The crash window: rewind the watermark so the SAME already-booked ticks are re-checked, as a
	// process that died between the fan-out's commit and AdvanceMissedWatermark would leave them.
	// 崩溃窗：把水位回拨，让**同样的、已记账的**刻度被重查——正是进程死在扇出提交与 AdvanceMissedWatermark
	// 之间会留下的样子。
	backdateTrigger(t, db, tr.ID, downSince)
	n, err := s.SweepMisfires(ctx)
	if err != nil {
		t.Fatalf("forced re-sweep: %v", err)
	}
	if n != 0 {
		t.Fatalf("re-checking accounted ticks must book nothing, booked %d", n)
	}
	if after := acts(); after != before {
		t.Fatalf("a sweep that booked NOTHING must not fire a catch-up: activations %d → %d", before, after)
	}
	if pend, _ := st.ListPendingFirings(ctx, 50); len(pend) != 1 {
		t.Fatalf("re-checking the same gap must not double-fire the catch-up, got %d pending", len(pend))
	}
}

// TestSweep_DefaultPolicyIsSkip — 判决⑥ default: without an explicit policy nothing runs at wake.
// A local app must never wake into a run-storm.
func TestSweep_DefaultPolicyIsSkip(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCronExpr(t, s, ctx, "ticker", "* * * * *")
	if err := s.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	backdateTrigger(t, db, tr.ID, time.Now().Add(-10*time.Minute))

	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	if pend, _ := st.ListPendingFirings(ctx, 50); len(pend) != 0 {
		t.Fatalf("the default policy is skip — waking must run NOTHING, got %d runnable firings", len(pend))
	}
	if rows := missedRows(t, st, ctx, tr.ID); len(rows) == 0 {
		t.Fatal("skip still ACCOUNTS: the missed ticks must be on the ledger")
	}
}

// TestMisfirePolicy_Vocabulary — 工单⑨ validation: the policy is a closed vocabulary checked at
// create/edit. A typo must fail loudly (422) instead of silently behaving as skip; absent = skip.
func TestMisfirePolicy_Vocabulary(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}

	for _, ok := range []string{triggerdomain.MisfireSkip, triggerdomain.MisfireCatchupOne} {
		if _, err := s.Create(ctx, CreateInput{Name: "p_" + ok, Kind: triggerdomain.KindCron, Config: map[string]any{
			"expression": "* * * * *", "misfirePolicy": ok,
		}}); err != nil {
			t.Fatalf("misfirePolicy=%q must be accepted: %v", ok, err)
		}
	}
	// A typo'd / wrong-typed policy is a loud 422 — never a silent fallback to skip.
	// 写错的 / 类型不对的策略 → 422 大声拒——绝不静默回落 skip。
	for _, bad := range []any{"catchup", "CATCHUP_ONE", "all", 1, true} {
		_, err := s.Create(ctx, CreateInput{Name: "bad", Kind: triggerdomain.KindCron, Config: map[string]any{
			"expression": "* * * * *", "misfirePolicy": bad,
		}})
		if !errors.Is(err, triggerdomain.ErrInvalidMisfirePolicy) {
			t.Fatalf("misfirePolicy=%v must be rejected with ErrInvalidMisfirePolicy, got %v", bad, err)
		}
	}
	// Edit is gated by the same vocabulary. Edit 走同一词表。
	tr := mkCronExpr(t, s, ctx, "editable", "* * * * *")
	if _, err := s.Edit(ctx, tr.ID, EditInput{Config: map[string]any{"expression": "* * * * *", "misfirePolicy": "nonsense"}}); !errors.Is(err, triggerdomain.ErrInvalidMisfirePolicy) {
		t.Fatalf("Edit must gate the policy too, got %v", err)
	}
	// Absent → skip (the default), read through the domain accessor.
	// 缺席 → skip（默认），经 domain 存取器读。
	if p := triggerdomain.MisfirePolicy(map[string]any{"expression": "* * * * *"}); p != triggerdomain.MisfireSkip {
		t.Fatalf("an absent policy must read as skip, got %q", p)
	}
}

// TestSweep_IgnoresNonCronKinds — webhook/fsnotify/sensor have no schedule, so "missed" is
// meaningless for them; the sweep must not invent ledger rows.
func TestSweep_IgnoresNonCronKinds(t *testing.T) {
	s, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s.webhook = &fakeListener{}
	hook, err := s.Create(ctx, CreateInput{Name: "hook", Kind: triggerdomain.KindWebhook, Config: map[string]any{"path": "p"}})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := s.AttachReplay(ctx, hook.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	backdateTrigger(t, db, hook.ID, time.Now().Add(-time.Hour))

	if n, err := s.SweepMisfires(ctx); err != nil || n != 0 {
		t.Fatalf("a webhook trigger has no schedule to miss: n=%d err=%v", n, err)
	}
	if rows := missedRows(t, st, ctx, hook.ID); len(rows) != 0 {
		t.Fatalf("no missed rows for a non-cron kind, got %d", len(rows))
	}
}

// TestSweep_SurvivesRestartWithoutDoubleBooking — the real shape of 判决⑥: process dies, ticks pass,
// a FRESH service boots over the same store, replays the reference, sweeps. The gap is booked once;
// a second boot sweep adds nothing.
func TestSweep_SurvivesRestartWithoutDoubleBooking(t *testing.T) {
	s1, st, db := newTestServiceDB(t)
	ctx := ctxWS("ws_1")
	s1.cron = &fakeListener{}
	tr := mkCronExpr(t, s1, ctx, "ticker", "* * * * *")
	if err := s1.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("AttachReplay: %v", err)
	}
	backdateTrigger(t, db, tr.ID, time.Now().Add(-4*time.Minute))

	// "Restart": a fresh Service over the same store, boot-replaying the active reference.
	// 「重启」：同一 store 上全新 Service，boot 重放 active 引用。
	s2 := NewService(st, http.NewServeMux(), nopInvoker{}, zap.NewNop())
	s2.cron = &fakeListener{}
	if err := s2.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("boot AttachReplay: %v", err)
	}
	n, err := s2.SweepMisfires(ctx)
	if err != nil {
		t.Fatalf("boot sweep: %v", err)
	}
	if n == 0 {
		t.Fatal("the downtime gap must be accounted at boot")
	}
	before := len(missedRows(t, st, ctx, tr.ID))

	// A third boot (yet another Service): the watermark says the gap is accounted.
	// 第三次 boot（又一个 Service）：水位表明缺口已入账。
	s3 := NewService(st, http.NewServeMux(), nopInvoker{}, zap.NewNop())
	s3.cron = &fakeListener{}
	if err := s3.AttachReplay(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("third AttachReplay: %v", err)
	}
	if again, err := s3.SweepMisfires(ctx); err != nil || again != 0 {
		t.Fatalf("a later boot must not re-book the same gap: n=%d err=%v", again, err)
	}
	if after := len(missedRows(t, st, ctx, tr.ID)); after != before {
		t.Fatalf("restart double-booked the ledger: %d → %d rows", before, after)
	}
}
