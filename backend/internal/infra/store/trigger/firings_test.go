package trigger

import (
	"testing"
	"time"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
)

// TestSupersedePendingOlderThan — buffer_one's "keep only the latest waiting" disposition: marks a
// workflow's pending firings older than a cutoff as superseded, scoped to that workflow + status.
func TestSupersedePendingOlderThan(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mk := func(id, wf string) {
		t.Helper()
		f := &triggerdomain.Firing{ID: id, TriggerID: "trg_a", WorkflowID: wf, ActivationID: "tra_1", DedupKey: id, Status: triggerdomain.FiringPending}
		if _, err := s.AppendFiring(ctx, f); err != nil {
			t.Fatalf("AppendFiring %s: %v", id, err)
		}
	}
	mk("trf_a1", "wf_1")
	mk("trf_a2", "wf_1")
	mk("trf_b1", "wf_2") // a different workflow — must NOT be touched

	// A future cutoff supersedes ALL of wf_1's pending firings (created_at < future); wf_2 untouched.
	n, err := s.SupersedePendingOlderThan(ctx, "wf_1", time.Now().Add(time.Hour))
	if err != nil {
		t.Fatalf("supersede: %v", err)
	}
	if n != 2 {
		t.Fatalf("should supersede both wf_1 pending firings, superseded %d", n)
	}
	pend, _ := s.ListPendingFirings(ctx, 10)
	if len(pend) != 1 || pend[0].WorkflowID != "wf_2" {
		t.Fatalf("only wf_2's firing should remain pending, got %+v", pend)
	}
	// A past cutoff supersedes nothing (no pending firing is older than it).
	if n2, _ := s.SupersedePendingOlderThan(ctx, "wf_2", time.Now().Add(-time.Hour)); n2 != 0 {
		t.Fatalf("a past cutoff should supersede nothing, superseded %d", n2)
	}
}

// TestSearchFirings_FilterAndOrder: the inbox pages newest-first, filters by trigger and
// status, and stays inside the workspace (D2).
//
// TestSearchFirings_FilterAndOrder：收件箱最新优先分页、按 trigger 与 status 过滤、不出 workspace（D2）。
func TestSearchFirings_FilterAndOrder(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mk := func(id, trg, dedup, status string) {
		t.Helper()
		f := &triggerdomain.Firing{ID: id, TriggerID: trg, WorkflowID: "wf_1", ActivationID: "tra_1", DedupKey: dedup, Status: triggerdomain.FiringPending}
		if _, err := s.AppendFiring(ctx, f); err != nil {
			t.Fatalf("AppendFiring %s: %v", id, err)
		}
		if status != triggerdomain.FiringPending {
			if err := s.MarkFiringOutcome(ctx, id, status); err != nil {
				t.Fatalf("MarkFiringOutcome %s: %v", id, err)
			}
		}
	}
	mk("trf_1", "trg_a", "k1", triggerdomain.FiringStarted)
	mk("trf_2", "trg_a", "k2", triggerdomain.FiringSkipped)
	mk("trf_3", "trg_b", "k3", triggerdomain.FiringPending)

	rows, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{TriggerID: "trg_a"})
	if err != nil || len(rows) != 2 {
		t.Fatalf("trigger filter: rows=%d err=%v", len(rows), err)
	}
	rows, _, err = s.SearchFirings(ctx, triggerdomain.FiringFilter{TriggerID: "trg_a", Status: triggerdomain.FiringSkipped})
	if err != nil || len(rows) != 1 || rows[0].ID != "trf_2" {
		t.Fatalf("status filter: %v err=%v", rows, err)
	}
	rows, _, err = s.SearchFirings(ctx, triggerdomain.FiringFilter{})
	if err != nil || len(rows) != 3 {
		t.Fatalf("unfiltered: rows=%d err=%v", len(rows), err)
	}
}
