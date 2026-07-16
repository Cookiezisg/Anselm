package trigger

// pause_test.go covers the runtime pause/resume switch (scheduler 工单⑦): pausing gates firing
// production AT THE SOURCE (listener unregistered + racing reports dropped + manual :fire
// refused), the switch is idempotent, it persists across a "restart" (a fresh Service over the
// same store), and the read projection is honest (paused=true / listening=false / nextFireAt nil).
//
// pause_test.go 覆盖运行时暂停/恢复开关（scheduler 工单⑦）：暂停在**源头**闸住 firing 产生
// （listener 注销 + 竞态报告丢弃 + 手动 :fire 拒绝）、开关幂等、跨「重启」持久（同 store 上的全新
// Service）、读投影诚实（paused=true / listening=false / nextFireAt nil）。

import (
	"errors"
	"net/http"
	"testing"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
)

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
