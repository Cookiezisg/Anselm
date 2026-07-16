package flowrun

import (
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// newStatsStore is newStore + the raw handle, so tests can seed rows with EXACT timestamps
// (orm's ,created stamp always overwrites started_at on Create — history needs raw INSERTs).
func newStatsStore(t *testing.T) (*Store, *sql.DB) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB)), sqlDB
}

// seedStatsRun inserts one run row with exact timestamps. completedAt nil ⇒ still running-shaped
// (the status argument stays authoritative either way).
func seedStatsRun(t *testing.T, db *sql.DB, ws, id, wf, status string, startedAt time.Time, completedAt *time.Time) {
	t.Helper()
	var done any
	if completedAt != nil {
		done = *completedAt
	}
	if _, err := db.Exec(
		`INSERT INTO flowruns (id, workspace_id, workflow_id, version_id, status, started_at, completed_at, updated_at)
		 VALUES (?, ?, ?, 'wfv_1', ?, ?, ?, ?)`,
		id, ws, wf, status, startedAt, done, startedAt,
	); err != nil {
		t.Fatalf("seed run %s: %v", id, err)
	}
}

// seedParkedNode inserts one parked node row for a run.
func seedParkedNode(t *testing.T, db *sql.DB, ws, nodeRowID, flowrunID, nodeID string, at time.Time) {
	t.Helper()
	if _, err := db.Exec(
		`INSERT INTO flowrun_nodes (id, workspace_id, flowrun_id, node_id, kind, status, created_at, updated_at)
		 VALUES (?, ?, ?, ?, 'approval', 'parked', ?, ?)`,
		nodeRowID, ws, flowrunID, nodeID, at, at,
	); err != nil {
		t.Fatalf("seed parked node %s: %v", nodeRowID, err)
	}
}

func ptr(ts time.Time) *time.Time { return &ts }

// statsQuery is the fully-defaulted query the app layer would hand down.
func statsQuery(ids []string, since time.Time) flowrundomain.StatsQuery {
	return flowrundomain.StatsQuery{WorkflowIDs: ids, RecentN: 10, Since: since}
}

// TestRunStats_TotalsAndParkedSemantics — totals are workspace-wide (never limited to the
// requested ids), the since window keys on completed_at, and parkedNodes counts RUNS awaiting a
// human: a running run with TWO parked nodes counts once; a parked row orphaned on a failed run
// does not count; another workspace is invisible.
func TestRunStats_TotalsAndParkedSemantics(t *testing.T) {
	s, db := newStatsStore(t)
	now := time.Now().UTC()
	since := now.Add(-7 * 24 * time.Hour)

	// ws_1: 2 running, 1 completed in-window, 1 completed OUT of window, 1 failed in-window.
	seedStatsRun(t, db, "ws_1", "fr_run1", "wf_a", "running", now.Add(-time.Hour), nil)
	seedStatsRun(t, db, "ws_1", "fr_run2", "wf_b", "running", now.Add(-time.Minute), nil)
	seedStatsRun(t, db, "ws_1", "fr_ok", "wf_a", "completed", now.Add(-2*time.Hour), ptr(now.Add(-time.Hour)))
	seedStatsRun(t, db, "ws_1", "fr_old", "wf_a", "completed", now.Add(-9*24*time.Hour), ptr(now.Add(-8*24*time.Hour)))
	seedStatsRun(t, db, "ws_1", "fr_bad", "wf_b", "failed", now.Add(-3*time.Hour), ptr(now.Add(-2*time.Hour)))
	// parked: two nodes on the same running run → 1 awaiting run; one node on the failed run → 0.
	seedParkedNode(t, db, "ws_1", "frn_p1", "fr_run1", "gate1", now)
	seedParkedNode(t, db, "ws_1", "frn_p2", "fr_run1", "gate2", now)
	seedParkedNode(t, db, "ws_1", "frn_p3", "fr_bad", "gate1", now)
	// ws_2 noise must not leak.
	seedStatsRun(t, db, "ws_2", "fr_other", "wf_z", "running", now, nil)
	seedParkedNode(t, db, "ws_2", "frn_pz", "fr_other", "gate", now)

	// Totals ignore the requested ids (none here) — workspace-wide by design.
	got, err := s.RunStats(ctxWS("ws_1"), statsQuery(nil, since))
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	want := flowrundomain.StatsTotals{Running: 2, CompletedSince: 1, FailedSince: 1, ParkedRuns: 1}
	if got.Totals != want {
		t.Fatalf("totals = %+v, want %+v", got.Totals, want)
	}
	if len(got.ByWorkflow) != 0 {
		t.Fatalf("no ids requested → byWorkflow must be empty, got %d rows", len(got.ByWorkflow))
	}
}

// TestRunStats_ByWorkflowRow — the per-workflow projection: running count, lastRunAt, recent
// beads newest→oldest capped at RecentN, windowed successRate (cancelled excluded) + avgElapsedMs
// (completed only), and a ZERO row (not an absence) for an id with no runs, in request order.
func TestRunStats_ByWorkflowRow(t *testing.T) {
	s, db := newStatsStore(t)
	now := time.Now().UTC()
	since := now.Add(-7 * 24 * time.Hour)

	// wf_a history (newest → oldest): running, completed(60s), failed, cancelled, completed(20s).
	seedStatsRun(t, db, "ws_1", "fr_5", "wf_a", "running", now.Add(-1*time.Minute), nil)
	seedStatsRun(t, db, "ws_1", "fr_4", "wf_a", "completed", now.Add(-10*time.Minute), ptr(now.Add(-9*time.Minute)))
	seedStatsRun(t, db, "ws_1", "fr_3", "wf_a", "failed", now.Add(-20*time.Minute), ptr(now.Add(-19*time.Minute)))
	seedStatsRun(t, db, "ws_1", "fr_2", "wf_a", "cancelled", now.Add(-30*time.Minute), ptr(now.Add(-29*time.Minute)))
	seedStatsRun(t, db, "ws_1", "fr_1", "wf_a", "completed", now.Add(-40*time.Minute), ptr(now.Add(-40*time.Minute).Add(20*time.Second)))
	// fr_4 elapsed 60s, fr_1 elapsed 20s → avg 40s.

	got, err := s.RunStats(ctxWS("ws_1"), statsQuery([]string{"wf_a", "wf_ghost"}, since))
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if len(got.ByWorkflow) != 2 || got.ByWorkflow[0].WorkflowID != "wf_a" || got.ByWorkflow[1].WorkflowID != "wf_ghost" {
		t.Fatalf("rows must follow request order: %+v", got.ByWorkflow)
	}
	a := got.ByWorkflow[0]
	if a.Running != 1 {
		t.Fatalf("wf_a running = %d, want 1", a.Running)
	}
	if a.LastRunAt == nil || now.Add(-1*time.Minute).Sub(*a.LastRunAt).Abs() > time.Second {
		t.Fatalf("wf_a lastRunAt = %v, want ~now-1m", a.LastRunAt)
	}
	wantBeads := []string{"running", "completed", "failed", "cancelled", "completed"}
	if len(a.Recent) != len(wantBeads) {
		t.Fatalf("wf_a recent = %v, want %v", a.Recent, wantBeads)
	}
	for i := range wantBeads {
		if a.Recent[i] != wantBeads[i] {
			t.Fatalf("wf_a recent[%d] = %q, want %q (full: %v)", i, a.Recent[i], wantBeads[i], a.Recent)
		}
	}
	// successRate = completed 2 / (completed 2 + failed 1) — cancelled is neutral.
	if a.SuccessRate == nil || (*a.SuccessRate-2.0/3.0) > 1e-9 || (2.0/3.0-*a.SuccessRate) > 1e-9 {
		t.Fatalf("wf_a successRate = %v, want 2/3", a.SuccessRate)
	}
	// avgElapsedMs over completed runs only: (60s+20s)/2 = 40s.
	if a.AvgElapsedMs == nil || *a.AvgElapsedMs < 39900 || *a.AvgElapsedMs > 40100 {
		t.Fatalf("wf_a avgElapsedMs = %v, want ~40000", a.AvgElapsedMs)
	}
	// the ghost id gets an honest zero row.
	g := got.ByWorkflow[1]
	if g.Running != 0 || g.ParkedRuns != 0 || g.LastRunAt != nil || len(g.Recent) != 0 || g.SuccessRate != nil || g.AvgElapsedMs != nil || g.ConsecutiveFailures != 0 {
		t.Fatalf("ghost id must be a zero row, got %+v", g)
	}
	if g.Recent == nil {
		t.Fatalf("zero row's recent must be [] (non-nil) so the wire never emits null")
	}
}

// TestRunStats_ByWorkflowParkedRuns — the row-level twin of the totals' parked semantics: per
// workflow, distinct STILL-RUNNING runs holding ≥1 parked node. Two parked nodes on the same run
// count once; a parked row orphaned on a failed run counts zero; an id with no parked runs (and a
// ghost id) reads 0.
func TestRunStats_ByWorkflowParkedRuns(t *testing.T) {
	s, db := newStatsStore(t)
	now := time.Now().UTC()
	since := now.Add(-7 * 24 * time.Hour)

	// wf_a: one running run parked on TWO approvals (counts 1) + one plain running run.
	seedStatsRun(t, db, "ws_1", "fr_a1", "wf_a", "running", now.Add(-2*time.Minute), nil)
	seedStatsRun(t, db, "ws_1", "fr_a2", "wf_a", "running", now.Add(-1*time.Minute), nil)
	seedParkedNode(t, db, "ws_1", "frn_a1", "fr_a1", "gate1", now)
	seedParkedNode(t, db, "ws_1", "frn_a2", "fr_a1", "gate2", now)
	// wf_b: a parked row orphaned on a FAILED run — not actionable, counts 0.
	seedStatsRun(t, db, "ws_1", "fr_b1", "wf_b", "failed", now.Add(-3*time.Minute), ptr(now.Add(-2*time.Minute)))
	seedParkedNode(t, db, "ws_1", "frn_b1", "fr_b1", "gate1", now)
	// wf_c: two running runs, each parked once — counts 2.
	seedStatsRun(t, db, "ws_1", "fr_c1", "wf_c", "running", now.Add(-2*time.Minute), nil)
	seedStatsRun(t, db, "ws_1", "fr_c2", "wf_c", "running", now.Add(-1*time.Minute), nil)
	seedParkedNode(t, db, "ws_1", "frn_c1", "fr_c1", "gate", now)
	seedParkedNode(t, db, "ws_1", "frn_c2", "fr_c2", "gate", now)

	got, err := s.RunStats(ctxWS("ws_1"), statsQuery([]string{"wf_a", "wf_b", "wf_c", "wf_ghost"}, since))
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	want := []int{1, 0, 2, 0}
	for i, row := range got.ByWorkflow {
		if row.ParkedRuns != want[i] {
			t.Fatalf("%s parkedRuns = %d, want %d", row.WorkflowID, row.ParkedRuns, want[i])
		}
	}
	// rows sum to the workspace bucket here (all parked hosts were requested).
	if got.Totals.ParkedRuns != 3 {
		t.Fatalf("totals parked = %d, want 3", got.Totals.ParkedRuns)
	}
}

// TestRunStats_RecentNCapsBeads — RecentN bounds the bead strip, newest first.
func TestRunStats_RecentNCapsBeads(t *testing.T) {
	s, db := newStatsStore(t)
	now := time.Now().UTC()
	for i := 0; i < 5; i++ {
		st := now.Add(-time.Duration(i+1) * time.Minute)
		seedStatsRun(t, db, "ws_1", "fr_"+string(rune('a'+i)), "wf_a", "completed", st, ptr(st.Add(time.Second)))
	}
	q := flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}, RecentN: 3, Since: now.Add(-time.Hour)}
	got, err := s.RunStats(ctxWS("ws_1"), q)
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if n := len(got.ByWorkflow[0].Recent); n != 3 {
		t.Fatalf("recent capped at RecentN=3, got %d beads", n)
	}
}

// TestRunStats_ConsecutiveFailures — the streak walks newest→oldest on (started_at, id):
// running runs are SKIPPED (a streak must not blink off while a retry is in flight), the first
// completed/cancelled stops it, and the count is NOT bounded by RecentN or the since window.
func TestRunStats_ConsecutiveFailures(t *testing.T) {
	now := time.Now().UTC()
	since := now.Add(-7 * 24 * time.Hour)
	at := func(minAgo int) time.Time { return now.Add(-time.Duration(minAgo) * time.Minute) }

	t.Run("completed stops the walk", func(t *testing.T) {
		s, db := newStatsStore(t)
		seedStatsRun(t, db, "ws_1", "fr_1", "wf_a", "failed", at(1), ptr(at(1)))
		seedStatsRun(t, db, "ws_1", "fr_2", "wf_a", "failed", at(2), ptr(at(2)))
		seedStatsRun(t, db, "ws_1", "fr_3", "wf_a", "completed", at(3), ptr(at(3)))
		seedStatsRun(t, db, "ws_1", "fr_4", "wf_a", "failed", at(4), ptr(at(4))) // pre-heal failure must not count
		got, err := s.RunStats(ctxWS("ws_1"), statsQuery([]string{"wf_a"}, since))
		if err != nil {
			t.Fatalf("RunStats: %v", err)
		}
		if got.ByWorkflow[0].ConsecutiveFailures != 2 {
			t.Fatalf("streak = %d, want 2 (stopped by completed)", got.ByWorkflow[0].ConsecutiveFailures)
		}
	})

	t.Run("running is skipped, not a streak breaker", func(t *testing.T) {
		s, db := newStatsStore(t)
		seedStatsRun(t, db, "ws_1", "fr_new", "wf_a", "running", at(1), nil) // retry in flight
		seedStatsRun(t, db, "ws_1", "fr_1", "wf_a", "failed", at(2), ptr(at(2)))
		seedStatsRun(t, db, "ws_1", "fr_2", "wf_a", "failed", at(3), ptr(at(3)))
		got, err := s.RunStats(ctxWS("ws_1"), statsQuery([]string{"wf_a"}, since))
		if err != nil {
			t.Fatalf("RunStats: %v", err)
		}
		if got.ByWorkflow[0].ConsecutiveFailures != 2 {
			t.Fatalf("streak = %d, want 2 (running skipped)", got.ByWorkflow[0].ConsecutiveFailures)
		}
	})

	t.Run("cancelled stops the walk", func(t *testing.T) {
		s, db := newStatsStore(t)
		seedStatsRun(t, db, "ws_1", "fr_1", "wf_a", "failed", at(1), ptr(at(1)))
		seedStatsRun(t, db, "ws_1", "fr_2", "wf_a", "cancelled", at(2), ptr(at(2)))
		seedStatsRun(t, db, "ws_1", "fr_3", "wf_a", "failed", at(3), ptr(at(3)))
		got, err := s.RunStats(ctxWS("ws_1"), statsQuery([]string{"wf_a"}, since))
		if err != nil {
			t.Fatalf("RunStats: %v", err)
		}
		if got.ByWorkflow[0].ConsecutiveFailures != 1 {
			t.Fatalf("streak = %d, want 1 (stopped by cancelled)", got.ByWorkflow[0].ConsecutiveFailures)
		}
	})

	t.Run("streak outruns RecentN and the since window", func(t *testing.T) {
		s, db := newStatsStore(t)
		// 4 failures, the oldest two OUTSIDE the 7d window — the streak still counts all 4.
		seedStatsRun(t, db, "ws_1", "fr_1", "wf_a", "failed", at(1), ptr(at(1)))
		seedStatsRun(t, db, "ws_1", "fr_2", "wf_a", "failed", at(2), ptr(at(2)))
		old1 := now.Add(-9 * 24 * time.Hour)
		old2 := now.Add(-10 * 24 * time.Hour)
		seedStatsRun(t, db, "ws_1", "fr_3", "wf_a", "failed", old1, ptr(old1))
		seedStatsRun(t, db, "ws_1", "fr_4", "wf_a", "failed", old2, ptr(old2))
		q := flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}, RecentN: 2, Since: since}
		got, err := s.RunStats(ctxWS("ws_1"), q)
		if err != nil {
			t.Fatalf("RunStats: %v", err)
		}
		if got.ByWorkflow[0].ConsecutiveFailures != 4 {
			t.Fatalf("streak = %d, want 4 (unbounded by RecentN/window)", got.ByWorkflow[0].ConsecutiveFailures)
		}
		// while the windowed rate only sees the two in-window failures.
		if r := got.ByWorkflow[0].SuccessRate; r == nil || *r != 0 {
			t.Fatalf("successRate = %v, want 0 (in-window failures only)", r)
		}
	})
}

// TestRunStats_WindowBoundary — a terminal run whose completed_at predates since is invisible to
// the windowed numbers (counts/rate/avg) but still present in recent beads and lastRunAt.
func TestRunStats_WindowBoundary(t *testing.T) {
	s, db := newStatsStore(t)
	now := time.Now().UTC()
	old := now.Add(-8 * 24 * time.Hour)
	seedStatsRun(t, db, "ws_1", "fr_old", "wf_a", "completed", old, ptr(old.Add(time.Minute)))

	got, err := s.RunStats(ctxWS("ws_1"), statsQuery([]string{"wf_a"}, now.Add(-7*24*time.Hour)))
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	a := got.ByWorkflow[0]
	if got.Totals.CompletedSince != 0 || a.SuccessRate != nil || a.AvgElapsedMs != nil {
		t.Fatalf("out-of-window run leaked into windowed stats: totals=%+v row=%+v", got.Totals, a)
	}
	if len(a.Recent) != 1 || a.Recent[0] != "completed" || a.LastRunAt == nil {
		t.Fatalf("out-of-window run must still show in recent/lastRunAt: %+v", a)
	}
}
