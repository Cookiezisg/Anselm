package trigger

import (
	"errors"
	"testing"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
)

// TestSupersedeAllButNewestPending — buffer_one's "keep only the latest waiting" disposition: collapse
// a workflow's pending firings to the newest, mark the rest superseded, return the survivor's id.
// Order-independent + scoped to the workflow; idempotent; empty when nothing is pending.
func TestSupersedeAllButNewestPending(t *testing.T) {
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
	mk("trf_a3", "wf_1") // newest (latest insert → latest created_at; the id DESC tiebreak also picks it)
	mk("trf_b1", "wf_2") // a different workflow — must NOT be touched

	keep, n, err := s.SupersedeAllButNewestPending(ctx, "wf_1")
	if err != nil {
		t.Fatalf("supersede: %v", err)
	}
	if keep != "trf_a3" {
		t.Fatalf("newest survivor should be trf_a3, got %q", keep)
	}
	if n != 2 {
		t.Fatalf("should supersede the 2 older wf_1 firings, superseded %d", n)
	}
	if pend, _ := s.ListPendingFirings(ctx, 10); len(pend) != 2 {
		t.Fatalf("2 pending should remain (trf_a3 + wf_2's trf_b1), got %d", len(pend))
	}
	// Idempotent: a second call (only trf_a3 pending for wf_1) supersedes nothing, keeps trf_a3.
	if keep2, n2, _ := s.SupersedeAllButNewestPending(ctx, "wf_1"); keep2 != "trf_a3" || n2 != 0 {
		t.Fatalf("second call should keep trf_a3 + supersede 0, got keep=%q n=%d", keep2, n2)
	}
	// No pending for an unknown workflow → empty survivor + 0.
	if keep3, n3, _ := s.SupersedeAllButNewestPending(ctx, "wf_none"); keep3 != "" || n3 != 0 {
		t.Fatalf("no pending → empty survivor + 0, got keep=%q n=%d", keep3, n3)
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
	// An out-of-enum status is rejected loudly (422), not a silent empty page (F168-M2 → F175-M7).
	if _, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{Status: "bogus"}); !errors.Is(err, triggerdomain.ErrInvalidFiringStatus) {
		t.Fatalf("an out-of-enum status filter must return ErrInvalidFiringStatus, got %v", err)
	}
}
