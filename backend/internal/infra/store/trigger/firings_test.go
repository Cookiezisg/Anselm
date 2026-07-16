package trigger

import (
	"context"
	"errors"
	"testing"
	"time"

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

// mkFiringAt books one firing dated at `at`, whatever its final status. It always goes through
// AppendMissedFiring — that is the ONLY write path that can set created_at (the orm stamps `now` on
// every insert), and it force-sets status=missed, so a non-missed row is marked to its real outcome
// afterwards. Roundabout, but it is how a row gets a created_at the test chose.
//
// mkFiringAt 写一条日期为 `at` 的 firing，无论其终态为何。它**总是**走 AppendMissedFiring——那是唯一
// 能设定 created_at 的写路径（orm 每次插入都盖 `now`），而它会强制 status=missed，故非 missed 的行随后
// 再标成它真正的处置。绕，但这就是让一行戴上测试选定的 created_at 的办法。
func mkFiringAt(t *testing.T, s *Store, ctx context.Context, id, trg, status string, at time.Time) {
	t.Helper()
	f := &triggerdomain.Firing{
		ID: id, TriggerID: trg, WorkflowID: "wf_1", ActivationID: "tra_1",
		DedupKey: id, Status: status, CreatedAt: at.UTC(),
	}
	if _, err := s.AppendMissedFiring(ctx, f); err != nil {
		t.Fatalf("book %s: %v", id, err)
	}
	if status != triggerdomain.FiringMissed {
		if err := s.MarkFiringOutcome(ctx, id, status); err != nil {
			t.Fatalf("outcome %s: %v", id, err)
		}
	}
}

// TestSearchFirings_HalfOpenWindow — the created_at window is [CreatedAfter, CreatedBefore), the
// flowrun ListFilter grammar VERBATIM (工单⑭). Half-open is not a detail: the Overview tiles
// adjacent windows, and a closed upper bound would render the tick on the seam twice.
//
// TestSearchFirings_HalfOpenWindow——created_at 窗口是 [CreatedAfter, CreatedBefore)，**逐字**是
// flowrun ListFilter 的文法（工单⑭）。半开不是细节：Overview 会把相邻窗口拼起来，闭上界会让缝上的
// 那个刻度**渲两次**。
func TestSearchFirings_HalfOpenWindow(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	mkFiringAt(t, s, ctx, "trf_at_lo", "trg_a", triggerdomain.FiringMissed, base)                  // exactly the lower bound
	mkFiringAt(t, s, ctx, "trf_mid", "trg_a", triggerdomain.FiringMissed, base.Add(time.Hour))     // inside
	mkFiringAt(t, s, ctx, "trf_at_hi", "trg_a", triggerdomain.FiringMissed, base.Add(2*time.Hour)) // exactly the upper bound

	rows, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{
		CreatedAfter: base, CreatedBefore: base.Add(2 * time.Hour),
	})
	if err != nil {
		t.Fatalf("window: %v", err)
	}
	got := map[string]bool{}
	for _, r := range rows {
		got[r.ID] = true
	}
	if !got["trf_at_lo"] {
		t.Fatalf("the lower bound is INCLUSIVE, trf_at_lo must be in the window: %v", got)
	}
	if !got["trf_mid"] {
		t.Fatalf("trf_mid is inside the window: %v", got)
	}
	if got["trf_at_hi"] {
		t.Fatalf("the upper bound is EXCLUSIVE — trf_at_hi belongs to the NEXT window, not this one: %v", got)
	}
	// Each bound is independently optional (zero = unset).
	if rows, _, _ := s.SearchFirings(ctx, triggerdomain.FiringFilter{CreatedAfter: base.Add(time.Hour)}); len(rows) != 2 {
		t.Fatalf("open-ended upper: want trf_mid + trf_at_hi, got %d", len(rows))
	}
	if rows, _, _ := s.SearchFirings(ctx, triggerdomain.FiringFilter{CreatedBefore: base.Add(time.Hour)}); len(rows) != 1 {
		t.Fatalf("open-ended lower: want trf_at_lo, got %d", len(rows))
	}
	if rows, _, _ := s.SearchFirings(ctx, triggerdomain.FiringFilter{}); len(rows) != 3 {
		t.Fatalf("no window: want all 3, got %d", len(rows))
	}
}

// TestSearchFirings_CrossTriggerWorkspaceLevel — an empty TriggerID spans the workspace (工单⑭):
// the Overview's 24h track asks "every firing", and D2 still holds at that scope.
//
// TestSearchFirings_CrossTriggerWorkspaceLevel——TriggerID 为空即跨整个 workspace（工单⑭）：
// Overview 的 24h 轨道问的是「所有 firing」，而 D2 在这个尺度上依然成立。
func TestSearchFirings_CrossTriggerWorkspaceLevel(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	mkFiringAt(t, s, ctx, "trf_a", "trg_a", triggerdomain.FiringMissed, base)
	mkFiringAt(t, s, ctx, "trf_b", "trg_b", triggerdomain.FiringStarted, base.Add(time.Minute))
	mkFiringAt(t, s, ctx, "trf_c", "trg_c", triggerdomain.FiringSkipped, base.Add(2*time.Minute))
	mkFiringAt(t, s, ctxWS("ws_2"), "trf_other", "trg_z", triggerdomain.FiringMissed, base)

	rows, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{})
	if err != nil || len(rows) != 3 {
		t.Fatalf("no TriggerID spans every trigger in the workspace: rows=%d err=%v", len(rows), err)
	}
	// Newest-first, across triggers.
	if rows[0].ID != "trf_c" || rows[2].ID != "trf_a" {
		t.Fatalf("cross-trigger page must stay newest-first: %s..%s", rows[0].ID, rows[2].ID)
	}
	for _, r := range rows {
		if r.ID == "trf_other" {
			t.Fatalf("D2: ws_2's firing must never appear in ws_1's page")
		}
	}
	// Cross-trigger + window + status compose.
	rows, _, err = s.SearchFirings(ctx, triggerdomain.FiringFilter{
		Status: triggerdomain.FiringMissed, CreatedAfter: base, CreatedBefore: base.Add(time.Hour),
	})
	if err != nil || len(rows) != 1 || rows[0].ID != "trf_a" {
		t.Fatalf("status + window compose across triggers: %v err=%v", rows, err)
	}
}

// TestCountFirings_SameFilterAsTheList — the count and the page it deep-links to are the same
// predicates (工单⑭). This is the property that keeps the "错过 N" card from saying 3 while the list
// it opens shows 4; it is asserted by construction — count == len(page) for the same filter.
//
// TestCountFirings_SameFilterAsTheList——计数与它深链过去的那一页是**同一组谓词**（工单⑭）。正是这条
// 性质让「错过 N」牌不会写着 3 而点开的列表显示 4；此处按构造断言——同一个 filter 下 count == len(page)。
func TestCountFirings_SameFilterAsTheList(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	mkFiringAt(t, s, ctx, "trf_m1", "trg_a", triggerdomain.FiringMissed, base)
	mkFiringAt(t, s, ctx, "trf_m2", "trg_a", triggerdomain.FiringMissed, base.Add(time.Hour))
	mkFiringAt(t, s, ctx, "trf_m3", "trg_b", triggerdomain.FiringMissed, base.Add(48*time.Hour)) // outside
	mkFiringAt(t, s, ctx, "trf_s1", "trg_a", triggerdomain.FiringSkipped, base)                  // wrong status
	mkFiringAt(t, s, ctxWS("ws_2"), "trf_x", "trg_z", triggerdomain.FiringMissed, base)          // wrong workspace

	for _, f := range []triggerdomain.FiringFilter{
		{Status: triggerdomain.FiringMissed, CreatedAfter: base, CreatedBefore: base.Add(24 * time.Hour)},
		{Status: triggerdomain.FiringMissed},
		{TriggerID: "trg_a"},
		{CreatedAfter: base.Add(72 * time.Hour)}, // matches nothing
		{},
	} {
		n, err := s.CountFirings(ctx, f)
		if err != nil {
			t.Fatalf("count %+v: %v", f, err)
		}
		rows, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{
			TriggerID: f.TriggerID, Status: f.Status,
			CreatedAfter: f.CreatedAfter, CreatedBefore: f.CreatedBefore, Limit: 500,
		})
		if err != nil {
			t.Fatalf("page %+v: %v", f, err)
		}
		if n != len(rows) {
			t.Fatalf("count(%d) must equal the page it deep-links to (%d) for filter %+v", n, len(rows), f)
		}
	}
	// The card's actual query.
	if n, _ := s.CountFirings(ctx, triggerdomain.FiringFilter{Status: triggerdomain.FiringMissed, CreatedAfter: base}); n != 3 {
		t.Fatalf("ws_1 missed since base = 3 (ws_2's is not ours), got %d", n)
	}
	// Cursor/Limit are the page's alone — a count is not a page.
	if n, _ := s.CountFirings(ctx, triggerdomain.FiringFilter{Status: triggerdomain.FiringMissed, Limit: 1}); n != 3 {
		t.Fatalf("Limit must not truncate a count, got %d", n)
	}
	// An out-of-enum status is rejected loudly here too — the count shares the list's validation.
	if _, err := s.CountFirings(ctx, triggerdomain.FiringFilter{Status: "bogus"}); !errors.Is(err, triggerdomain.ErrInvalidFiringStatus) {
		t.Fatalf("count must reject an out-of-enum status like the list does, got %v", err)
	}
}
