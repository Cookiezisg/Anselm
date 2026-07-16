// stats_bench_test.go measures RunStats at the run volume the SHIPPED config reaches without any
// help from the user: a cron@1m workflow under the 90d default retention line = 129,600 rows. It
// exists because "six queries, ≤50 ids, bounded output" was mistaken for a cost bound, and the
// streak's per-row EXISTS grew quadratic in the streak length underneath it — invisible to every
// test, because it is fast on healthy data and only explodes while a workflow is FAILING, which is
// the exact moment the user opens the scheduler to look at it.
//
// Run: go test ./internal/infra/store/flowrun -bench=RunStats -benchtime=1x -run=XXX
// Not part of `make verify` (a 129,600-row seed is minutes of wall clock, and a timing assertion on
// a shared CI box is a flake, not a guard). The guard that IS mechanical is
// TestRunStats_StreakUsesTheStatusIndex below.
//
// stats_bench_test.go 在**出厂配置**不用用户帮忙就能长到的 run 量上测 RunStats：cron@1m 的 workflow 在
// 90d 默认保留线下 = 129,600 行。它之所以存在，是因为「六条查询、≤50 个 id、输出有界」被误当成了成本上界，
// 而连败的逐行 EXISTS 在它底下长成了连败长度的平方——所有测试都看不见它，因为它在健康数据上很快、只在
// workflow **正在失败**时爆炸，而那恰恰是用户打开 scheduler 去看它的那一刻。
//
// 跑法：go test ./internal/infra/store/flowrun -bench=RunStats -benchtime=1x -run=XXX
// 不进 `make verify`（129,600 行的播种要几分钟墙钟，且在共享 CI 机器上做时间断言是 flake、不是守卫）。
// 真正机械的守卫是下方的 TestRunStats_StreakUsesTheStatusIndex。
package flowrun

import (
	"database/sql"
	"fmt"
	"strings"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// benchRunVolume is cron@1m × the 90d default retention line — the number the shipped config
// produces on its own, not a stress figure.
// benchRunVolume = cron@1m × 90d 默认保留线——出厂配置自己产出的数，不是压测捏的。
const benchRunVolume = 129_600

// seedRunHistory writes `total` runs for wf_a, oldest→newest one minute apart, the newest `streak`
// of them failed and the rest completed. One transaction + one prepared statement: seeding is not
// what is under measurement.
func seedRunHistory(tb testing.TB, db *sql.DB, total, streak int) {
	tb.Helper()
	tx, err := db.Begin()
	if err != nil {
		tb.Fatalf("begin: %v", err)
	}
	stmt, err := tx.Prepare(`INSERT INTO flowruns
		(id, workspace_id, workflow_id, version_id, status, started_at, completed_at, updated_at)
		VALUES (?, 'ws_1', 'wf_a', 'wfv_1', ?, ?, ?, ?)`)
	if err != nil {
		tb.Fatalf("prepare: %v", err)
	}
	base := time.Now().UTC().Add(-time.Duration(total) * time.Minute)
	for i := 0; i < total; i++ {
		at := base.Add(time.Duration(i) * time.Minute)
		status := flowrundomain.StatusCompleted
		if i >= total-streak {
			status = flowrundomain.StatusFailed
		}
		if _, err := stmt.Exec(fmt.Sprintf("fr_%08d", i), status, at, at.Add(30*time.Second), at); err != nil {
			tb.Fatalf("seed run %d: %v", i, err)
		}
	}
	if err := stmt.Close(); err != nil {
		tb.Fatalf("close stmt: %v", err)
	}
	if err := tx.Commit(); err != nil {
		tb.Fatalf("commit: %v", err)
	}
}

// schemaWithoutStreakIndex is Schema minus idx_fr_ws_wf_status — the "before" arm, so the benchmark
// measures the index's contribution instead of taking its word for it.
// schemaWithoutStreakIndex = Schema 减去 idx_fr_ws_wf_status——「之前」那一臂，使基准**测**出索引的贡献、
// 而不是信它的一面之词。
func schemaWithoutStreakIndex() []string {
	out := make([]string, 0, len(Schema))
	for _, stmt := range Schema {
		if strings.Contains(stmt, "idx_fr_ws_wf_status") {
			continue
		}
		out = append(out, stmt)
	}
	return out
}

func benchStats(b *testing.B, schema []string, streak int) {
	s, db := newStatsStoreWith(b, schema)
	seedRunHistory(b, db, benchRunVolume, streak)
	q := flowrundomain.StatsQuery{
		WorkflowIDs: []string{"wf_a"},
		RecentN:     flowrundomain.StatsDefaultRecentN,
		Since:       time.Now().UTC().Add(-flowrundomain.StatsDefaultWindow),
	}
	ctx := ctxWS("ws_1")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := s.RunStats(ctx, q); err != nil {
			b.Fatalf("RunStats: %v", err)
		}
	}
}

// BenchmarkRunStats_WithStreakIndex / _WithoutStreakIndex — the same query, the same 129,600 rows,
// the same streaks; the only difference is idx_fr_ws_wf_status. The healthy arm is the control: it
// is fast either way, which is precisely why the regression hid.
func BenchmarkRunStats_WithStreakIndex(b *testing.B) {
	for _, k := range []int{0, 1000, 4000} {
		b.Run(fmt.Sprintf("streak=%d", k), func(b *testing.B) { benchStats(b, Schema, k) })
	}
}

func BenchmarkRunStats_WithoutStreakIndex(b *testing.B) {
	for _, k := range []int{0, 1000, 4000} {
		b.Run(fmt.Sprintf("streak=%d", k), func(b *testing.B) { benchStats(b, schemaWithoutStreakIndex(), k) })
	}
}

// TestRunStats_StreakUsesTheStatusIndex is the mechanical half of the benchmark: timings cannot live
// in `make verify`, but the PLAN can. If the streak's EXISTS ever stops riding idx_fr_ws_wf_status —
// someone wraps started_at in julianday() (which is what the rest of this file does against the
// caller's `since`, so it is a live temptation), reorders the index, or rewrites the correlated
// subquery — this fails immediately, on a table small enough to run in milliseconds.
//
// TestRunStats_StreakUsesTheStatusIndex 是基准的**机械**那半：时间数字不能进 `make verify`，但**执行计划**
// 可以。若连败的 EXISTS 哪天不再走 idx_fr_ws_wf_status——有人给 started_at 套上 julianday()（本文件对调用方
// 的 `since` 正是这么做的，故这诱惑活生生存在）、调换索引列序、或重写那条相关子查询——本测试立刻失败，且跑在
// 一张毫秒级的小表上。
func TestRunStats_StreakUsesTheStatusIndex(t *testing.T) {
	_, db := newStatsStore(t)
	now := time.Now().UTC()
	seedStatsRun(t, db, "ws_1", "fr_1", "wf_a", flowrundomain.StatusFailed, now.Add(-time.Minute), ptr(now))

	// The streak query verbatim (one workflow id), asked for its plan.
	rows, err := db.Query(`EXPLAIN QUERY PLAN
		SELECT f.workflow_id, COUNT(*)
		FROM flowruns f
		WHERE f.workspace_id = ? AND f.workflow_id IN (?) AND f.status = 'failed'
			AND NOT EXISTS (
				SELECT 1 FROM flowruns g
				WHERE g.workspace_id = f.workspace_id AND g.workflow_id = f.workflow_id
					AND g.status = 'completed'
					AND (g.started_at, g.id) > (f.started_at, f.id)
			)
		GROUP BY f.workflow_id`, "ws_1", "wf_a")
	if err != nil {
		t.Fatalf("explain: %v", err)
	}
	defer rows.Close()
	var plan strings.Builder
	for rows.Next() {
		var id, parent, notUsed int
		var detail string
		if err := rows.Scan(&id, &parent, &notUsed, &detail); err != nil {
			t.Fatalf("scan plan: %v", err)
		}
		plan.WriteString(detail)
		plan.WriteString("\n")
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("plan rows: %v", err)
	}
	got := plan.String()
	if !strings.Contains(got, "idx_fr_ws_wf_status") {
		t.Fatalf("the streak must ride idx_fr_ws_wf_status — without it the EXISTS scans every newer\n"+
			"run of the workflow per failed row (O(K²): 12.7s at 129,600 rows / K=4000).\nplan:\n%s", got)
	}
	// A full table SCAN of flowruns means the index was dropped from the plan entirely.
	if strings.Contains(got, "SCAN flowruns") && !strings.Contains(got, "USING INDEX") {
		t.Fatalf("the streak fell back to a full scan:\n%s", got)
	}
}
