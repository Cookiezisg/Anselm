// retention_wiring_test.go proves the ONE seam nothing else covers: that the assembled App's
// retention wiring actually DELETES (scheduler 工单⑬). The pieces are each unit-tested elsewhere
// (app/settings owns the line, app/scheduler owns the batch loop, infra/store/flowrun owns the
// transaction and the boundary), but only here does the chain run for real:
//
//	settings.json → Boot's primed kick → retentionLoop → sweepRetention (line→cutoff) →
//	forEachWorkspace (Detached ctx per workspace, D2) → SweepRunRetention → the physical delete.
//
// A backdated run is the only way to test it, and only a white-box test can make one (the black
// box cannot age a row — see testend/scenarios/flowrun_matrix_test.go's coverage-split note).
// The misfire loop's backdateTrigger helper is the same precedent: raw SQL to age rows no API can.
//
// retention_wiring_test.go 证明**唯一**没有别处覆盖的缝：装配好的 App 的保留清理接线**真的会删**
// （scheduler 工单⑬）。各零件在别处各有单测（app/settings 拥有线、app/scheduler 拥有批循环、
// infra/store/flowrun 拥有事务与边界），但只有这里让整条链**真跑**：
//
//	settings.json → Boot 预置的 kick → retentionLoop → sweepRetention（线→cutoff）→
//	forEachWorkspace（逐 workspace 的 Detached ctx，D2）→ SweepRunRetention → 物理删。
//
// 倒签日期的 run 是唯一的测法，而只有白盒造得出（黑盒没法给行加年龄——见 testend 那份覆盖切分说明）。
// misfire 循环的 backdateTrigger helper 是同一先例：用裸 SQL 给行加年龄，因为没有 API 能。
package bootstrap

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	workspaceapp "github.com/sunweilin/anselm/backend/internal/app/workspace"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// TestRetentionWiring_BootSweepPurgesPastTheLine: a 30d line + a run that finished 100 days ago →
// Boot's primed kick sweeps it, while a fresh run and a 900-day-old STILL-RUNNING run both survive.
//
// TestRetentionWiring_BootSweepPurgesPastTheLine：30d 的线 + 一个 100 天前落定的 run → Boot 预置的
// kick 清掉它，而一个新鲜 run 与一个 900 天前起跑、**仍在跑**的 run 都活着。
func TestRetentionWiring_BootSweepPurgesPastTheLine(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	// The line must be on disk BEFORE Build: settings.json loads at assembly, before any service.
	// 线必须在 Build **之前**落盘：settings.json 在装配期、任何 service 之前加载。
	if err := os.WriteFile(filepath.Join(dir, "settings.json"), []byte(`{"retention":{"runRetentionDays":30}}`), 0o644); err != nil {
		t.Fatalf("write settings: %v", err)
	}
	app, err := Build(Config{DataDir: dir})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	if got := app.svc.settings.Retention().RunRetentionDays; got != 30 {
		t.Fatalf("the line did not load: got %d want 30", got)
	}

	ws, err := app.svc.workspace.Create(context.Background(), workspaceapp.CreateInput{Name: "retention-wiring"})
	if err != nil {
		t.Fatalf("create workspace: %v", err)
	}
	now := time.Now().UTC()
	seed := func(id, status string, startedAt time.Time, completedAt *time.Time) {
		t.Helper()
		var done any
		if completedAt != nil {
			done = *completedAt
		}
		if _, err := app.db.Exec(context.Background(),
			`INSERT INTO flowruns (id, workspace_id, workflow_id, version_id, status, started_at, completed_at, updated_at)
			 VALUES (?, ?, 'wf_1', 'wfv_1', ?, ?, ?, ?)`,
			id, ws.ID, status, startedAt, done, startedAt); err != nil {
			t.Fatalf("seed %s: %v", id, err)
		}
	}
	old := now.AddDate(0, 0, -100)
	seed("fr_old", flowrundomain.StatusCompleted, old, &old)
	fresh := now.AddDate(0, 0, -1)
	seed("fr_fresh", flowrundomain.StatusCompleted, fresh, &fresh)
	ancient := now.AddDate(0, 0, -900)
	seed("fr_running", flowrundomain.StatusRunning, ancient, nil)

	app.Boot(context.Background())
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		app.Shutdown(ctx)
	})

	// The sweep runs on the loop's goroutine (Boot deliberately does NOT do it inline), so poll.
	// 清理跑在循环的 goroutine 上（Boot 刻意**不**内联跑），故轮询。
	count := func(id string) int {
		t.Helper()
		var n int
		if err := app.db.QueryRow(context.Background(), `SELECT COUNT(*) FROM flowruns WHERE id = ?`, id).Scan(&n); err != nil {
			t.Fatalf("count %s: %v", id, err)
		}
		return n
	}
	deadline := time.Now().Add(5 * time.Second)
	for count("fr_old") > 0 && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if count("fr_old") != 0 {
		t.Fatal("boot's primed kick never swept the run past the line — the retention wiring is dead")
	}
	if count("fr_fresh") != 1 {
		t.Error("a run inside the line was swept")
	}
	if count("fr_running") != 1 {
		t.Error("a 900-day-old STILL-RUNNING run was swept — running runs are not history")
	}
}

// TestRetentionWiring_ForeverNeverSweeps: the 0 line ("keep forever") must leave a 900-day-old
// finished run alone — the physical guarantee behind the setting, checked BEFORE the DB is touched.
//
// TestRetentionWiring_ForeverNeverSweeps：0 的线（「永久保留」）必须放过一个 900 天前落定的 run——
// 该设置背后的物理保证，在**碰 DB 之前**就查。
func TestRetentionWiring_ForeverNeverSweeps(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "settings.json"), []byte(`{"retention":{"runRetentionDays":0}}`), 0o644); err != nil {
		t.Fatalf("write settings: %v", err)
	}
	app, err := Build(Config{DataDir: dir})
	if err != nil {
		t.Fatalf("Build: %v", err)
	}
	ws, err := app.svc.workspace.Create(context.Background(), workspaceapp.CreateInput{Name: "retention-forever"})
	if err != nil {
		t.Fatalf("create workspace: %v", err)
	}
	ancient := time.Now().UTC().AddDate(0, 0, -900)
	if _, err := app.db.Exec(context.Background(),
		`INSERT INTO flowruns (id, workspace_id, workflow_id, version_id, status, started_at, completed_at, updated_at)
		 VALUES ('fr_ancient', ?, 'wf_1', 'wfv_1', 'completed', ?, ?, ?)`,
		ws.ID, ancient, ancient, ancient); err != nil {
		t.Fatalf("seed: %v", err)
	}

	app.Boot(context.Background())
	// Count BEFORE Shutdown — it closes the DB last, so a post-shutdown read is "database is closed".
	// 在 Shutdown **之前**数——它最后会关 DB，关停后再读就是 "database is closed"。
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		app.Shutdown(ctx)
	})
	// Give the primed kick a real chance to do damage before asserting it did none.
	// 在断言它什么都没干之前，给预置的 kick 一个真正搞破坏的机会。
	time.Sleep(300 * time.Millisecond)

	var n int
	if err := app.db.QueryRow(context.Background(), `SELECT COUNT(*) FROM flowruns WHERE id = 'fr_ancient'`).Scan(&n); err != nil {
		t.Fatalf("count: %v", err)
	}
	if n != 1 {
		t.Fatal("the forever line (0) deleted a 900-day-old run — 'keep forever' must never sweep")
	}
}
