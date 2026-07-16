package trigger

// pause_test.go covers the runtime pause/resume switch (scheduler 工单⑦): pausing gates firing
// production AT THE SOURCE (listener unregistered + racing reports dropped + manual :fire
// refused), the switch is idempotent, it persists across a "restart" (a fresh Service over the
// same store), the read projection is honest (paused=true / listening=false / nextFireAt nil move
// together, off ONE truth — the persisted row), an Edit cannot clobber it, and a Resume whose
// Register fails rolls back to a retryable paused state instead of stranding a cold listener.
//
// pause_test.go 覆盖运行时暂停/恢复开关（scheduler 工单⑦）：暂停在**源头**闸住 firing 产生
// （listener 注销 + 竞态报告丢弃 + 手动 :fire 拒绝）、开关幂等、跨「重启」持久（同 store 上的全新
// Service）、读投影诚实（paused=true / listening=false / nextFireAt nil **三键同动**，同源于**一个**
// 真相——持久化的行）、Edit 覆写不掉它、Resume 的 Register 失败会回滚成**可重试**的暂停态而非搁下一个
// 冷 listener。

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"sync"
	"testing"
	"time"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
)

// failingListener is a fakeListener whose Register fails while `fail` is set — the shape of a real
// source refusing to come back up (a webhook path already taken, an fsnotify watch on a path that
// vanished, a cron expression the row acquired behind the API).
//
// failingListener 是 Register 在 `fail` 置位期间失败的 fakeListener——真实 source 拒绝重新起来的形状
// （webhook 路径已被占、fsnotify 监视的路径没了、行被绕过 API 改坏的 cron 表达式）。
type failingListener struct {
	fakeListener
	fail bool
}

func (f *failingListener) Register(id, ws string, config map[string]any) error {
	if f.fail {
		return fmt.Errorf("register refused")
	}
	return f.fakeListener.Register(id, ws, config)
}

// hookRepo delegates to the real store, running beforeWrite once, immediately before the Edit path's
// write. Edit reads the row ITSELF, so a :pause issued before the call is simply read and honoured —
// the bug needs a pause that lands INSIDE the read → validate → write window, and that interleave
// cannot be produced from outside the service. Hooking the write seam is how the test gets there.
//
// hookRepo 代理真 store，在 Edit 径写入之前**恰好跑一次** beforeWrite。Edit 是**自己**读行的，故调用之前
// 发出的 `:pause` 只会被读到并遵守——这个 bug 需要暂停落在「读→校验→写」窗口**之内**，而那个交错从
// service 外面造不出来。钩住写入缝就是测试进到那里的办法。
type hookRepo struct {
	triggerdomain.Repository
	once        sync.Once
	beforeWrite func()
}

func (h *hookRepo) fire() {
	if h.beforeWrite != nil {
		h.once.Do(h.beforeWrite)
	}
}

func (h *hookRepo) EditTrigger(ctx context.Context, t *triggerdomain.Trigger) error {
	h.fire()
	return h.Repository.EditTrigger(ctx, t)
}

func (h *hookRepo) SaveTrigger(ctx context.Context, t *triggerdomain.Trigger) error {
	h.fire()
	return h.Repository.SaveTrigger(ctx, t)
}

func TestPause_GatesFiringAtTheSource(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "daily")
	_ = s.Attach(ctx, tr.ID, "wf_1")
	_ = s.Attach(ctx, tr.ID, "wf_2")

	got, err := s.Pause(ctx, tr.ID)
	if err != nil {
		t.Fatalf("Pause: %v", err)
	}
	// The source listener is really unregistered — pausing stops the machinery, not just the fan-out.
	// 底层 listener 真被注销——暂停停的是机器本身、不只扇出。
	if fake.unregisters != 1 {
		t.Fatalf("pause must unregister the source listener, got %d", fake.unregisters)
	}
	// Honest read projection: paused, not listening, refs kept, nothing scheduled.
	// 读投影诚实：已暂停、不监听、引用保留、无排程。
	if !got.Paused || got.Listening || got.RefCount != 2 || got.NextFireAt != nil {
		t.Fatalf("paused projection wrong: paused=%v listening=%v refs=%d next=%v", got.Paused, got.Listening, got.RefCount, got.NextFireAt)
	}

	// A report racing in behind the unregister is dropped — no firing, no activation.
	// 抢在 unregister 之后进来的报告被丢——无 firing、无 activation。
	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: "k1"})
	if firings, err := st.ListPendingFirings(ctx, 0); err != nil || len(firings) != 0 {
		t.Fatalf("paused trigger must produce NO firings: n=%d err=%v", len(firings), err)
	}
	if acts, _, _ := st.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: tr.ID}); len(acts) != 0 {
		t.Fatalf("paused trigger must record NO activations: %d", len(acts))
	}

	// Manual :fire refuses loudly — an agent cannot bypass the user's pause.
	// 手动 :fire 大声拒——agent 绕不过用户的暂停。
	if _, err := s.FireManual(ctx, tr.ID); !errors.Is(err, triggerdomain.ErrPaused) {
		t.Fatalf("FireManual on paused must return ErrPaused, got %v", err)
	}
}

func TestPauseResume_IdempotentAndRestoresFiring(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "daily")
	_ = s.Attach(ctx, tr.ID, "wf_1")

	if _, err := s.Pause(ctx, tr.ID); err != nil {
		t.Fatalf("pause: %v", err)
	}
	// Pausing a paused trigger is a harmless no-op (idempotent endpoint). 重复暂停无害 no-op。
	if _, err := s.Pause(ctx, tr.ID); err != nil {
		t.Fatalf("re-pause: %v", err)
	}
	if fake.unregisters != 1 {
		t.Fatalf("re-pause must not double-unregister, got %d", fake.unregisters)
	}

	got, err := s.Resume(ctx, tr.ID)
	if err != nil {
		t.Fatalf("resume: %v", err)
	}
	// registers: 1 from Attach + 1 from Resume. Resume 重注册（Attach 1 次 + Resume 1 次）。
	if fake.registers != 2 {
		t.Fatalf("resume must re-register the source listener, got %d", fake.registers)
	}
	if got.Paused || !got.Listening || got.NextFireAt == nil {
		t.Fatalf("resumed projection wrong: paused=%v listening=%v next=%v", got.Paused, got.Listening, got.NextFireAt)
	}
	// Resuming a resumed trigger is a no-op too. 重复恢复同样 no-op。
	if _, err := s.Resume(ctx, tr.ID); err != nil {
		t.Fatalf("re-resume: %v", err)
	}
	if fake.registers != 2 {
		t.Fatalf("re-resume must not double-register, got %d", fake.registers)
	}

	// Firing production is restored end-to-end. firing 产生端到端恢复。
	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: "k2"})
	if firings, err := st.ListPendingFirings(ctx, 0); err != nil || len(firings) != 1 {
		t.Fatalf("resumed trigger must fire again: n=%d err=%v", len(firings), err)
	}
	if _, err := s.FireManual(ctx, tr.ID); err != nil {
		t.Fatalf("FireManual after resume: %v", err)
	}
}

func TestPause_PersistsAcrossRestart(t *testing.T) {
	s1, st := newTestService(t)
	ctx := ctxWS("ws_1")
	fake1 := &fakeListener{}
	s1.cron = fake1
	tr := mkCron(t, s1, ctx, "daily")
	_ = s1.Attach(ctx, tr.ID, "wf_1")
	if _, err := s1.Pause(ctx, tr.ID); err != nil {
		t.Fatalf("pause: %v", err)
	}

	// "Restart": a fresh Service over the same store; boot replay (ReattachActive) re-attaches the
	// active workflow. The persisted switch must keep the listener cold.
	// 「重启」：同一 store 上的全新 Service；boot 重放（ReattachActive）重挂 active workflow。
	// 持久开关必须让 listener 保持冷。
	s2 := NewService(st, http.NewServeMux(), nopInvoker{}, zap.NewNop())
	fake2 := &fakeListener{}
	s2.cron = fake2
	if err := s2.Attach(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("boot attach: %v", err)
	}
	if fake2.registers != 0 {
		t.Fatalf("boot attach on a paused trigger must NOT register, got %d", fake2.registers)
	}
	got, err := s2.Get(ctx, tr.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if !got.Paused || got.Listening || got.RefCount != 1 || got.NextFireAt != nil {
		t.Fatalf("restarted projection wrong: paused=%v listening=%v refs=%d next=%v", got.Paused, got.Listening, got.RefCount, got.NextFireAt)
	}

	// Resume on the new process re-registers from the surviving reference set. 新进程 Resume 凭存活引用集重注册。
	if _, err := s2.Resume(ctx, tr.ID); err != nil {
		t.Fatalf("resume: %v", err)
	}
	if fake2.registers != 1 {
		t.Fatalf("resume after restart must register, got %d", fake2.registers)
	}
}

func TestEdit_WhilePaused_DefersConfigToResume(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "daily")
	_ = s.Attach(ctx, tr.ID, "wf_1")
	if _, err := s.Pause(ctx, tr.ID); err != nil {
		t.Fatalf("pause: %v", err)
	}

	// An Edit while paused must NOT resurrect the listener (restartIfListening skips paused entries).
	// 暂停期间 Edit 绝不复活 listener（restartIfListening 跳过暂停 entry）。
	if _, err := s.Edit(ctx, tr.ID, EditInput{Config: map[string]any{"expression": "0 9 * * *"}}); err != nil {
		t.Fatalf("edit: %v", err)
	}
	if fake.registers != 1 { // the original Attach only. 只有最初 Attach 那次。
		t.Fatalf("edit while paused must not re-register, got %d", fake.registers)
	}

	// Resume picks up the CURRENT (edited) config. Resume 用当前（已编辑）config。
	if _, err := s.Resume(ctx, tr.ID); err != nil {
		t.Fatalf("resume: %v", err)
	}
	if fake.registers != 2 || fake.lastConfig["expression"] != "0 9 * * *" {
		t.Fatalf("resume must register with the edited config: registers=%d cfg=%v", fake.registers, fake.lastConfig)
	}
}

// TestEdit_CannotClobberTheRuntimeAxis — 工单⑦/⑨: Edit is a read → validate → write, and the two
// runtime columns move on their own clocks throughout. The product ships an `edit_trigger` tool, so
// "a chat agent is editing while the user hits ⏸" is ordinary — and a whole-row upsert answers it by
// writing the read-time copies back: the stop-the-bleeding switch flips itself on again (persisted,
// so it survives restarts) and the misfire watermark rewinds, re-opening a window already accounted.
//
// Edit's OWN columns must of course still land — a targeted write that quietly dropped the edit
// would be the opposite bug.
func TestEdit_CannotClobberTheRuntimeAxis(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCron(t, s, ctx, "daily")
	if err := s.Attach(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("Attach: %v", err)
	}

	// The interleave: the user's :pause and a cron fan-out's watermark advance land AFTER Edit read
	// the row and BEFORE it writes. Edit is then holding read-time copies of both runtime columns.
	// 交错：用户的 `:pause` 与一次 cron 扇出的水位推进，落在 Edit **读完行之后、写入之前**。此时 Edit 手上
	// 攥着两个运行时列的读时拷贝。
	mark := time.Now().Truncate(time.Second)
	real := s.repo
	s.repo = &hookRepo{Repository: real, beforeWrite: func() {
		if _, err := s.Pause(ctx, tr.ID); err != nil {
			t.Errorf("Pause mid-edit: %v", err)
		}
		if err := real.AdvanceMissedWatermark(ctx, tr.ID, mark); err != nil {
			t.Errorf("AdvanceMissedWatermark mid-edit: %v", err)
		}
	}}

	// The edit lands on top of that, as the agent's request would.
	// 编辑就落在这之上，一如 agent 的请求。
	name := "renamed"
	got, err := s.Edit(ctx, tr.ID, EditInput{Name: &name, Config: map[string]any{"expression": "0 9 * * *"}})
	if err != nil {
		t.Fatalf("Edit: %v", err)
	}

	// The pause survived — on the wire AND on disk (a pause that came back on after a restart is the
	// sharpest form of this bug). 暂停幸存——线缆上**与**盘上（重启后又自己弹回来的暂停是这个 bug 最锋利的形态）。
	if !got.Paused || got.Listening || got.NextFireAt != nil {
		t.Fatalf("Edit clobbered the pause switch on the wire: paused=%v listening=%v next=%v", got.Paused, got.Listening, got.NextFireAt)
	}
	fresh, err := st.GetTrigger(ctx, tr.ID)
	if err != nil {
		t.Fatalf("GetTrigger after edit: %v", err)
	}
	if !fresh.Paused {
		t.Fatal("Edit wrote paused=false back to disk — the user's pause is gone across restarts")
	}
	// The misfire watermark survived: rewinding it re-opens an accounted window (工单⑨).
	// misfire 水位幸存：把它回拨会重新打开一个已入账的窗（工单⑨）。
	if fresh.MissedCheckedAt == nil || fresh.MissedCheckedAt.Before(mark.Add(-time.Second)) {
		t.Fatalf("Edit rewound the misfire watermark to %v, want >= %v", fresh.MissedCheckedAt, mark)
	}
	// ...and the edit itself really landed. ……而编辑本身确实落地了。
	if fresh.Name != "renamed" || triggerdomain.CronExpression(fresh.Config) != "0 9 * * *" {
		t.Fatalf("the edit's own columns must land: name=%q expr=%q", fresh.Name, triggerdomain.CronExpression(fresh.Config))
	}
	// A rename onto a taken name is still a loud conflict, not a 500 — the targeted write must keep
	// mapping the UNIQUE violation the whole-row upsert used to map.
	// 改名撞车仍是大声的冲突、不是 500——定点写必须照样映射整行 upsert 过去映射的那个 UNIQUE 冲突。
	mkCron(t, s, ctx, "taken")
	dupe := "taken"
	if _, err := s.Edit(ctx, tr.ID, EditInput{Name: &dupe}); !errors.Is(err, triggerdomain.ErrDuplicateName) {
		t.Fatalf("Edit onto a taken name must be ErrDuplicateName, got %v", err)
	}
}

// TestAttachRuntime_PausedKeysMoveTogetherOffOneTruth — 工单⑦, the wire contract the frontend reads
// as law: paused=true ⟹ listening=false ∧ nextFireAt absent. Listening used to derive from the
// registry's in-memory pause mirror while nextFireAt derived from the row, so the instant the two
// disagreed the wire contradicted itself about a single fact. This forces that disagreement and
// pins that the projection stays self-consistent: `paused` has one truth, the persisted row.
func TestAttachRuntime_PausedKeysMoveTogetherOffOneTruth(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	s.cron = &fakeListener{}
	tr := mkCron(t, s, ctx, "daily")
	if err := s.Attach(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("Attach: %v", err)
	}

	// Force the divergence the two sources used to allow: the row says paused, the registry mirror
	// still says live. 逼出两个来源过去允许的分歧：行说已暂停、监听表镜像还说活着。
	if err := s.repo.SetTriggerPaused(ctx, tr.ID, true); err != nil {
		t.Fatalf("SetTriggerPaused: %v", err)
	}
	got, err := s.Get(ctx, tr.ID)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if !got.Paused || got.Listening || got.NextFireAt != nil {
		t.Fatalf("paused=true must carry listening=false + nextFireAt absent, got listening=%v next=%v", got.Listening, got.NextFireAt)
	}
	// And the reverse: live means all three agree the other way. 反向：活着时三键同样一致。
	if err := s.repo.SetTriggerPaused(ctx, tr.ID, false); err != nil {
		t.Fatalf("SetTriggerPaused: %v", err)
	}
	live, err := s.Get(ctx, tr.ID)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if live.Paused || !live.Listening || live.NextFireAt == nil {
		t.Fatalf("paused=false + refs must carry listening=true + nextFireAt present, got listening=%v next=%v", live.Listening, live.NextFireAt)
	}
}

// TestResume_RegisterFailureRollsBackAndStaysRetryable — 工单⑦: if the source refuses to come back
// up, Resume must not leave the switch off with a cold listener. The old note claimed "the next
// boot/activation retries the register" — it does not: attach only Registers on a 0→1 reference and
// a second :resume no-ops the moment the entry believes it is un-paused, so that state is escapable
// only by a restart, while the row swears the trigger is running. Staying paused is the honest and
// RETRYABLE outcome.
func TestResume_RegisterFailureRollsBackAndStaysRetryable(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &failingListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "daily")
	if err := s.Attach(ctx, tr.ID, "wf_1"); err != nil {
		t.Fatalf("Attach: %v", err)
	}
	if _, err := s.Pause(ctx, tr.ID); err != nil {
		t.Fatalf("Pause: %v", err)
	}

	fake.fail = true
	if _, err := s.Resume(ctx, tr.ID); err == nil {
		t.Fatal("Resume must surface a failed register, not pretend the listener is hot")
	}
	// Persisted state rolled back: the row must not claim a trigger is running while its source is cold.
	// 持久状态已回滚：行绝不能在 source 冷着的时候还自称在跑。
	fresh, err := st.GetTrigger(ctx, tr.ID)
	if err != nil {
		t.Fatalf("GetTrigger: %v", err)
	}
	if !fresh.Paused {
		t.Fatal("a failed Resume must leave the trigger paused — paused=false with a cold listener is a state only a restart escapes")
	}
	// A racing report is still dropped: the registry entry stayed paused too, so the machinery is off.
	// 竞态报告仍被丢弃：监听表 entry 也保持暂停，故机器是关着的。
	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: "k1"})
	if firings, _ := st.ListPendingFirings(ctx, 0); len(firings) != 0 {
		t.Fatalf("a failed Resume must not open the fan-out, got %d firings", len(firings))
	}

	// The whole point of rolling back: the user can just try again once the source is healthy.
	// 回滚的全部意义：source 一好，用户再试一次就行。
	fake.fail = false
	got, err := s.Resume(ctx, tr.ID)
	if err != nil {
		t.Fatalf("a retried Resume must work — otherwise only a restart clears the state: %v", err)
	}
	if got.Paused || !got.Listening {
		t.Fatalf("the retried resume must be live: paused=%v listening=%v", got.Paused, got.Listening)
	}
	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: "k2"})
	if firings, _ := st.ListPendingFirings(ctx, 0); len(firings) != 1 {
		t.Fatalf("the resumed trigger must fire again, got %d firings", len(firings))
	}
}
