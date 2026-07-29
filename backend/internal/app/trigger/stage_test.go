package trigger

import (
	"context"
	"sync"
	"testing"
	"time"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
)

// blockingFiringRepo forces two fan-outs to overlap between listener snapshot and durable firing
// append. It makes a one-shot race deterministic instead of relying on scheduler timing.
type blockingFiringRepo struct {
	triggerdomain.Repository
	calls   chan struct{}
	release <-chan struct{}
}

func (r *blockingFiringRepo) AppendFiring(ctx context.Context, f *triggerdomain.Firing) (*triggerdomain.Firing, error) {
	r.calls <- struct{}{}
	<-r.release
	return r.Repository.AppendFiring(ctx, f)
}

// TestAttachOnce_AutoDisarmsAfterFire: a one-shot (staged) workflow fires exactly once, then is
// auto-detached — while a continuously-attached workflow on the same trigger keeps firing. After the
// first fire both run; after the second only the continuous one does.
func TestAttachOnce_AutoDisarmsAfterFire(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "t")

	if err := s.AttachOnce(ctx, tr.ID, "wf_once"); err != nil {
		t.Fatalf("AttachOnce: %v", err)
	}
	if err := s.Attach(ctx, tr.ID, "wf_cont"); err != nil {
		t.Fatalf("Attach: %v", err)
	}
	if fake.registers != 1 {
		t.Fatalf("two workflows share one listener, want 1 register, got %d", fake.registers)
	}

	// first fire → both wf_once and wf_cont get a firing; then wf_once auto-disarms.
	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: "k1"})
	if firings, _ := st.ListPendingFirings(ctx, 0); len(firings) != 2 {
		t.Fatalf("first fire: want 2 firings (both workflows), got %d", len(firings))
	}
	if fake.unregisters != 0 {
		t.Fatalf("listener must stay up for the continuous workflow, got %d unregisters", fake.unregisters)
	}

	// second fire → only wf_cont (wf_once is disarmed): one more firing, 3 total pending.
	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: "k2"})
	if firings, _ := st.ListPendingFirings(ctx, 0); len(firings) != 3 {
		t.Fatalf("second fire: want 3 total firings (wf_once disarmed), got %d", len(firings))
	}
}

// TestAttachOnce_SoleListenerStopsAfterFire: when the ONLY reference is a one-shot, its single fire
// disarms it and takes the listener 1→0 (it stops) — staging does not leak a hot listener.
func TestAttachOnce_SoleListenerStopsAfterFire(t *testing.T) {
	s, _ := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "t")

	if err := s.AttachOnce(ctx, tr.ID, "wf_once"); err != nil {
		t.Fatalf("AttachOnce: %v", err)
	}
	if fake.registers != 1 {
		t.Fatalf("want 1 register, got %d", fake.registers)
	}

	s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: "k1"})
	if fake.unregisters != 1 {
		t.Fatalf("a sole one-shot should stop the listener after its single fire, got %d unregisters", fake.unregisters)
	}
}

// TestAttachOnce_MultiTriggerWorkflowDisarmsEveryEntry: staging arms every trigger entry as one
// trial budget. The first source to report must remove the one-shot reference from the other
// source too, otherwise a multi-trigger workflow can run twice from one :stage action.
func TestAttachOnce_MultiTriggerWorkflowDisarmsEveryEntry(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	trA := mkCron(t, s, ctx, "multi_a")
	trB := mkCron(t, s, ctx, "multi_b")
	if err := s.AttachOnce(ctx, trA.ID, "wf_once"); err != nil {
		t.Fatalf("AttachOnce A: %v", err)
	}
	if err := s.AttachOnce(ctx, trB.ID, "wf_once"); err != nil {
		t.Fatalf("AttachOnce B: %v", err)
	}

	s.onReport(trA.ID, triggerinfra.Activity{Fired: true, DedupKey: "multi-k1"})
	if firings, _ := st.ListPendingFirings(ctx, 0); len(firings) != 1 {
		t.Fatalf("first source should create one firing, got %d", len(firings))
	}
	if fake.unregisters != 2 {
		t.Fatalf("first source must unregister both one-shot listeners, got %d", fake.unregisters)
	}
	s.mu.RLock()
	_, aListening := s.listeners[trA.ID]
	_, bListening := s.listeners[trB.ID]
	s.mu.RUnlock()
	if aListening || bListening {
		t.Fatalf("multi-trigger stage leaked listeners: A=%v B=%v", aListening, bListening)
	}

	// A late report from the other source is dropped because its entry was detached.
	s.onReport(trB.ID, triggerinfra.Activity{Fired: true, DedupKey: "multi-k2"})
	if firings, _ := st.ListPendingFirings(ctx, 0); len(firings) != 1 {
		t.Fatalf("late second source must not add a firing, got %d", len(firings))
	}
}

// TestAttachOnce_ConcurrentReportsConsumeSingleBudget: two reports that overlap before either
// durable append must still yield one firing. A stale listener snapshot cannot spend the trial
// budget twice.
func TestAttachOnce_ConcurrentReportsConsumeSingleBudget(t *testing.T) {
	s, st := newTestService(t)
	ctx := ctxWS("ws_1")
	fake := &fakeListener{}
	s.cron = fake
	tr := mkCron(t, s, ctx, "concurrent_stage")
	if err := s.AttachOnce(ctx, tr.ID, "wf_once"); err != nil {
		t.Fatalf("AttachOnce: %v", err)
	}

	release := make(chan struct{})
	s.repo = &blockingFiringRepo{
		Repository: st,
		calls:      make(chan struct{}, 2),
		release:    release,
	}
	var wg sync.WaitGroup
	for _, key := range []string{"concurrent-k1", "concurrent-k2"} {
		wg.Add(1)
		go func(dedupKey string) {
			defer wg.Done()
			s.onReport(tr.ID, triggerinfra.Activity{Fired: true, DedupKey: dedupKey})
		}(key)
	}
	select {
	case <-s.repo.(*blockingFiringRepo).calls:
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for the winning AppendFiring call")
	}
	// The first append is held open. A second call here would prove the stale snapshot spent the
	// one-shot budget twice; the fixed path has already claimed and removed the listener globally.
	select {
	case <-s.repo.(*blockingFiringRepo).calls:
		t.Fatal("concurrent staged reports reached two AppendFiring calls")
	case <-time.After(100 * time.Millisecond):
	}
	close(release)
	wg.Wait()

	firings, _ := st.ListPendingFirings(ctx, 0)
	if len(firings) != 1 {
		t.Fatalf("concurrent staged reports must create one firing, got %d", len(firings))
	}
}
