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
// ~5 minutes wakes to find those ticks booked `missed` (never re-run), and a SECOND sweep books
// nothing new — the dedup key is the tick itself, so accounting is exactly-once by construction.
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
	downSince := time.Now().Add(-5 * time.Minute)
	backdateTrigger(t, db, tr.ID, downSince)

	n, err := s.SweepMisfires(ctx)
	if err != nil {
		t.Fatalf("SweepMisfires: %v", err)
	}
	if n < 4 || n > 6 {
		t.Fatalf("a ~5min downtime of an every-minute cron should book ~5 missed ticks, booked %d", n)
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
	downSince := time.Now().Add(-5 * time.Minute)
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
	// The older ticks are still honestly booked missed (catch up ONE, not all).
	// 更早的刻度仍诚实记 missed（补**一个**、非全部）。
	if rows := missedRows(t, st, ctx, tr.ID); len(rows) < 4 {
		t.Fatalf("the older missed ticks must remain booked, got %d", len(rows))
	}

	// Re-sweep (watermark already advanced): no second catch-up run.
	// 重复 sweep（水位已推进）：不会有第二次补跑。
	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("second sweep: %v", err)
	}
	if pend2, _ := st.ListPendingFirings(ctx, 50); len(pend2) != 1 {
		t.Fatalf("a re-sweep must not fire a second catch-up, got %d pending", len(pend2))
	}
	// Forcing the same window again is still exactly one: the catch-up dedup key is the tick's.
	// 再次强制同一个窗仍然只有一条：补跑的 dedup 键也是按刻度构的。
	backdateTrigger(t, db, tr.ID, downSince)
	if _, err := s.SweepMisfires(ctx); err != nil {
		t.Fatalf("forced re-sweep: %v", err)
	}
	if pend3, _ := st.ListPendingFirings(ctx, 50); len(pend3) != 1 {
		t.Fatalf("re-checking the same gap must not double-fire the catch-up, got %d pending", len(pend3))
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
