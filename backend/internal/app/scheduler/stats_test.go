package scheduler

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerstore "github.com/sunweilin/anselm/backend/internal/infra/store/trigger"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// statsSvc builds the thinnest Service the stats read path needs: s.runs for the flowrun totals +
// health rows, and s.inbox for Totals.Missed (工单⑭ — RunStats counts trigger_firings through the
// FiringInbox port). newStore already loads the trigger schema into the same handle.
//
// statsSvc 建 stats 读路径所需的最薄 Service：s.runs 供 flowrun 聚合 + 健康行，s.inbox 供
// Totals.Missed（工单⑭——RunStats 经 FiringInbox 端口数 trigger_firings）。newStore 已把 trigger
// schema 装进同一个 handle。
func statsSvc(t *testing.T) *Service {
	t.Helper()
	store, sqlDB := newStore(t)
	return &Service{runs: store, inbox: triggerstore.New(ormpkg.Open(sqlDB))}
}

// missedSvc returns statsSvc plus the trigger store, for booking `missed` firings directly.
// missedSvc 返 statsSvc + trigger store，供直接记 `missed` firing。
func missedSvc(t *testing.T) (*Service, *triggerstore.Store) {
	t.Helper()
	store, sqlDB := newStore(t)
	trg := triggerstore.New(ormpkg.Open(sqlDB))
	return &Service{runs: store, inbox: trg}, trg
}

// bookMissed writes one `missed` firing dated AT the tick it stands for — exactly what the misfire
// sweep does (AppendMissedFiring backdates created_at, 工单⑨). The dating is the whole point of the
// window: a missed row wears its scheduled instant, not the moment it was booked.
//
// bookMissed 写一条 `missed` firing、**日期取它代表的刻度**——与 misfire sweep 所做的完全一致
// （AppendMissedFiring 回拨 created_at，工单⑨）。这个盖戳正是窗口的全部意义：missed 行戴的是它的
// 调度时刻、不是它被记账的那一刻。
func bookMissed(t *testing.T, trg *triggerstore.Store, ctx context.Context, id string, tick time.Time) {
	t.Helper()
	if _, err := trg.AppendMissedFiring(ctx, &triggerdomain.Firing{
		ID: id, TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: id,
		Status: triggerdomain.FiringMissed, CreatedAt: tick.UTC(),
	}); err != nil {
		t.Fatalf("bookMissed %s: %v", id, err)
	}
}

// TestRunStats_MissedIsWindowedOnTheSameSince — the "错过 N" card (工单⑭). Three properties, one
// test, because they are one promise: the count is windowed, it shares completedSince/failedSince's
// window physically (not by documentation), and it is dated on the TICK — so a night-long outage
// lands in the night's window, not in the window of the second the machine woke up.
//
// TestRunStats_MissedIsWindowedOnTheSameSince——「错过 N」牌（工单⑭）。三条性质、一个测试，因为它们
// 是同一个承诺：计数带窗、与 completedSince/failedSince **物理上**同窗（而非「文档说同」）、且按**刻度**
// 盖戳——故整夜停机落在**那一夜**的窗口里，而不是落在机器醒来那一秒的窗口里。
func TestRunStats_MissedIsWindowedOnTheSameSince(t *testing.T) {
	svc, trg := missedSvc(t)
	ctx := ctxWS("ws_1")
	now := time.Now().UTC()

	bookMissed(t, trg, ctx, "trf_m1", now.Add(-2*time.Hour))   // inside 24h
	bookMissed(t, trg, ctx, "trf_m2", now.Add(-20*time.Hour))  // inside 24h
	bookMissed(t, trg, ctx, "trf_m3", now.Add(-100*time.Hour)) // outside 24h, inside 7d

	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{Since: now.Add(-24 * time.Hour)})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if got.Totals.Missed != 2 {
		t.Fatalf("24h window must count the 2 ticks missed inside it, got %d", got.Totals.Missed)
	}
	// A wider window sees more — proving the number tracks the window rather than being all-time.
	// 更宽的窗看见更多——证明这个数字跟着窗口走、而非 all-time。
	wide, err := svc.RunStats(ctx, flowrundomain.StatsQuery{Since: now.Add(-7 * 24 * time.Hour)})
	if err != nil {
		t.Fatalf("RunStats wide: %v", err)
	}
	if wide.Totals.Missed != 3 {
		t.Fatalf("7d window must count all 3, got %d", wide.Totals.Missed)
	}
	// The default window is the SAME default completedSince/failedSince use (7d) — one Since, one
	// place. 默认窗口就是 completedSince/failedSince 用的那个默认（7d）——一个 Since、一处默认。
	def, err := svc.RunStats(ctx, flowrundomain.StatsQuery{})
	if err != nil {
		t.Fatalf("RunStats default: %v", err)
	}
	if def.Totals.Missed != 3 {
		t.Fatalf("default 7d window must count all 3, got %d", def.Totals.Missed)
	}
}

// TestRunStats_MissedCountsOnlyMissedAndStaysInWorkspace — the card counts the `missed` disposition
// alone (a skipped/shed tick is a DIFFERENT sentence — the machine was awake and decided), and D2
// isolation holds: another workspace's outage is never this workspace's number.
//
// TestRunStats_MissedCountsOnlyMissedAndStaysInWorkspace——这张牌只数 `missed` 处置（skipped/shed
// 是**另一句话**——机器当时醒着、并且做了决定），且 D2 隔离成立：别的 workspace 的停机永远不是本
// workspace 的数字。
func TestRunStats_MissedCountsOnlyMissedAndStaysInWorkspace(t *testing.T) {
	svc, trg := missedSvc(t)
	ctx := ctxWS("ws_1")
	now := time.Now().UTC()

	bookMissed(t, trg, ctx, "trf_m1", now.Add(-1*time.Hour))
	// Sibling neutral dispositions must NOT be counted: they are not misfires.
	for _, s := range []string{triggerdomain.FiringSkipped, triggerdomain.FiringSuperseded, triggerdomain.FiringShed, triggerdomain.FiringStarted} {
		if _, err := trg.AppendFiring(ctx, &triggerdomain.Firing{
			ID: "trf_" + s, TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: "k_" + s, Status: s,
		}); err != nil {
			t.Fatalf("append %s: %v", s, err)
		}
	}
	// Another workspace's missed tick (D2).
	bookMissed(t, trg, ctxWS("ws_2"), "trf_other", now.Add(-1*time.Hour))

	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{Since: now.Add(-24 * time.Hour)})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if got.Totals.Missed != 1 {
		t.Fatalf("only ws_1's single `missed` counts (not its skipped/superseded/shed/started siblings, not ws_2's), got %d", got.Totals.Missed)
	}
}

// TestRunStats_NoInboxMeansNoFirings — a deployment with no firing store has no firings at all, so 0
// is the truth rather than a shrug. Pinned because the alternative (panicking on a nil port) would
// take the whole stats batch down on a manual-only deployment.
//
// TestRunStats_NoInboxMeansNoFirings——没有 firing 存储的部署根本没有 firing，故 0 是**真相**、而非
// 搪塞。钉死它是因为另一种写法（nil 端口上 panic）会让纯手动部署的整个统计批查垮掉。
func TestRunStats_NoInboxMeansNoFirings(t *testing.T) {
	store, _ := newStore(t)
	svc := &Service{runs: store} // no inbox wired
	got, err := svc.RunStats(ctxWS("ws_1"), flowrundomain.StatsQuery{})
	if err != nil {
		t.Fatalf("a nil inbox must not fail the batch: %v", err)
	}
	if got.Totals.Missed != 0 {
		t.Fatalf("no firing store → 0 missed, got %d", got.Totals.Missed)
	}
}

// TestRunStats_TooManyIDsLoudReject — the >50 guard fires AFTER dedup (the bound caps query cost,
// which depends on unique ids) and carries the allowed cap in Details.
func TestRunStats_TooManyIDsLoudReject(t *testing.T) {
	svc := statsSvc(t)
	ctx := ctxWS("ws_1")

	ids := make([]string, 0, flowrundomain.StatsMaxWorkflowIDs+1)
	for i := 0; i <= flowrundomain.StatsMaxWorkflowIDs; i++ {
		ids = append(ids, fmt.Sprintf("wf_%d", i))
	}
	if _, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: ids}); !errors.Is(err, flowrundomain.ErrStatsTooManyIDs) {
		t.Fatalf("51 unique ids must reject with ErrStatsTooManyIDs, got %v", err)
	}

	// 60 raw ids that dedup to 2 pass — and blanks are dropped, duplicates collapse to one row.
	noisy := make([]string, 0, 60)
	for i := 0; i < 58; i++ {
		noisy = append(noisy, "wf_dup")
	}
	noisy = append(noisy, "", "wf_other")
	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: noisy})
	if err != nil {
		t.Fatalf("deduped-under-cap must pass: %v", err)
	}
	if len(got.ByWorkflow) != 2 || got.ByWorkflow[0].WorkflowID != "wf_dup" || got.ByWorkflow[1].WorkflowID != "wf_other" {
		t.Fatalf("dedup must keep first-occurrence order and drop blanks: %+v", got.ByWorkflow)
	}
}

// TestRunStats_DefaultsAndClamp — RecentN ≤0 → 10, >20 → 20; a zero Since → the 7d window;
// empty ids → totals only with an empty (non-nil) byWorkflow.
func TestRunStats_DefaultsAndClamp(t *testing.T) {
	svc := statsSvc(t)
	ctx := ctxWS("ws_1")

	// 22 completed runs, newest first by orm's create stamp (each Create gets its own now).
	for i := 0; i < 22; i++ {
		id := fmt.Sprintf("fr_%02d", i)
		mustSeedTerminal(t, svc, ctx, id, "wf_a", flowrundomain.StatusCompleted)
	}

	// default RecentN = 10.
	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if n := len(got.ByWorkflow[0].Recent); n != flowrundomain.StatsDefaultRecentN {
		t.Fatalf("default RecentN: got %d beads, want %d", n, flowrundomain.StatsDefaultRecentN)
	}
	// oversized RecentN clamps to 20.
	got, err = svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}, RecentN: 99})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if n := len(got.ByWorkflow[0].Recent); n != flowrundomain.StatsMaxRecentN {
		t.Fatalf("RecentN clamp: got %d beads, want %d", n, flowrundomain.StatsMaxRecentN)
	}
	// zero Since defaults to the 7d window: everything just seeded lands inside it.
	if got.Totals.CompletedSince != 22 {
		t.Fatalf("default 7d window must cover fresh runs: completedSince = %d", got.Totals.CompletedSince)
	}
	// empty ids: totals only, byWorkflow [] not nil (the wire must emit [], never null).
	got, err = svc.RunStats(ctx, flowrundomain.StatsQuery{})
	if err != nil {
		t.Fatalf("RunStats empty ids: %v", err)
	}
	if got.ByWorkflow == nil || len(got.ByWorkflow) != 0 {
		t.Fatalf("empty ids → byWorkflow must be [] (non-nil), got %#v", got.ByWorkflow)
	}
	if got.Totals.Running != 0 || got.Totals.CompletedSince != 22 {
		t.Fatalf("totals must still aggregate the workspace: %+v", got.Totals)
	}
}

// TestRunStats_ExplicitSinceWindow — a caller-supplied Since bounds the windowed counts without
// touching the streak (store-level windowing is pinned in the store tests; this pins that the
// app passes an explicit Since through untouched).
func TestRunStats_ExplicitSinceWindow(t *testing.T) {
	svc := statsSvc(t)
	ctx := ctxWS("ws_1")
	mustSeedTerminal(t, svc, ctx, "fr_1", "wf_a", flowrundomain.StatusFailed)

	// a window starting in the future sees nothing…
	got, err := svc.RunStats(ctx, flowrundomain.StatsQuery{WorkflowIDs: []string{"wf_a"}, Since: time.Now().UTC().Add(time.Hour)})
	if err != nil {
		t.Fatalf("RunStats: %v", err)
	}
	if got.Totals.FailedSince != 0 || got.ByWorkflow[0].SuccessRate != nil {
		t.Fatalf("future window must be empty: %+v %+v", got.Totals, got.ByWorkflow[0])
	}
	// …the streak is window-independent.
	if got.ByWorkflow[0].ConsecutiveFailures != 1 {
		t.Fatalf("streak must ignore the window: %d", got.ByWorkflow[0].ConsecutiveFailures)
	}
}

// mustSeedTerminal creates a run via the store path and settles it to a terminal status.
func mustSeedTerminal(t *testing.T, svc *Service, ctx context.Context, id, wf, status string) {
	t.Helper()
	run := &flowrundomain.FlowRun{ID: id, WorkflowID: wf, VersionID: "wfv_1"}
	trig := &flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger"}
	if _, err := svc.runs.CreateRunWithTrigger(ctx, run, trig); err != nil {
		t.Fatalf("seed %s: %v", id, err)
	}
	if status != flowrundomain.StatusRunning {
		if _, err := svc.runs.MarkRunTerminal(ctx, id, status, ""); err != nil {
			t.Fatalf("terminal %s: %v", id, err)
		}
	}
}
