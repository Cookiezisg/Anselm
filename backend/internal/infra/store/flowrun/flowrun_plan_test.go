package flowrun

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	sqlite "github.com/glebarez/go-sqlite"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Index guard for the 「24h 失败」 card's deep-link (scheduler 工单⑮: ?status=failed&completedAfter=).
// It EXPLAINs the SQL ListRuns ACTUALLY runs — captured through a recording driver, not re-typed —
// because a guard over a hand-copied query is theatre: it keeps passing while the real one drifts to
// `julianday(completed_at) >= ?` (the wrapper 工单⑮ removed, whose return would blind the index AND
// re-open 「牌上写 3、点开列表显示 4」), loses idx_fr_ws_status_completed, and walks the whole
// workspace at 129,600 rows — 50ms, and worst precisely when the workspace is HEALTHY (few failures
// ⇒ LIMIT 51 never fills ⇒ full walk to prove there is no more). Mirrors firings_plan_test.go on the
// trigger side; the two card indexes (idx_trf_ws_status / idx_fr_ws_status_completed) are the same
// shape because they answer the same product question.
//
// The recording machinery is package-private here (there is no shared testutil), so it is duplicated
// from firings_plan_test.go with a DISTINCT driver name — `sql.Register` panics on a duplicate name,
// once per process.
//
// 「24h 失败」牌深链的索引守卫（scheduler 工单⑮：?status=failed&completedAfter=）。它 EXPLAIN 的是 ListRuns
// **真正**跑的那条 SQL——经记录型 driver 抓下、非重敲——因为守着手抄查询是演戏：真查询漂移回
// `julianday(completed_at) >= ?`（工单⑮ 拆掉的那个包装，它的回归会既弄瞎索引又重开「牌上写 3、点开列表显示
// 4」）、丢掉 idx_fr_ws_status_completed、在 129,600 行上走遍整个 workspace 时——50ms，且**恰在 workspace
// 健康时**最糟（失败少 ⇒ LIMIT 51 填不满 ⇒ 走遍全表以证明没有更多）。与 trigger 侧 firings_plan_test.go
// 同形；两张牌索引（idx_trf_ws_status / idx_fr_ws_status_completed）形状相同，因为它们答同一个产品问题。
//
// 记录机制在本包私有（无共享 testutil），故从 firings_plan_test.go 复制、用**不同的** driver 名——
// `sql.Register` 对重复名 panic、每进程一次。

type frRecDriver struct {
	inner driver.Driver
	rec   *frRecSwitch
}

type frRecorder struct {
	mu   sync.Mutex
	sqls []string
}

func (r *frRecorder) add(q string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sqls = append(r.sqls, q)
}

func (r *frRecorder) reset() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sqls = nil
}

// selects returns the recorded SELECTs (the store's reads; schema DDL and inserts are noise here).
func (r *frRecorder) selects() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []string
	for _, q := range r.sqls {
		if strings.HasPrefix(strings.ToUpper(strings.TrimSpace(q)), "SELECT") {
			out = append(out, q)
		}
	}
	return out
}

func (d frRecDriver) Open(name string) (driver.Conn, error) {
	c, err := d.inner.Open(name)
	if err != nil {
		return nil, err
	}
	return frRecConn{Conn: c, rec: d.rec}, nil
}

// frRecConn implements ONLY Prepare/PrepareContext over the embedded Conn: database/sql then routes
// every query through Prepare, so nothing escapes the recorder via the Queryer fast path.
type frRecConn struct {
	driver.Conn
	rec *frRecSwitch
}

func (c frRecConn) Prepare(q string) (driver.Stmt, error) {
	c.rec.add(q)
	return c.Conn.Prepare(q)
}

func (c frRecConn) PrepareContext(ctx context.Context, q string) (driver.Stmt, error) {
	c.rec.add(q)
	if p, ok := c.Conn.(driver.ConnPrepareContext); ok {
		return p.PrepareContext(ctx, q)
	}
	return c.Conn.Prepare(q)
}

type frRecSwitch struct {
	mu  sync.Mutex
	cur *frRecorder
}

func (s *frRecSwitch) swap(r *frRecorder) { s.mu.Lock(); s.cur = r; s.mu.Unlock() }
func (s *frRecSwitch) add(q string) {
	s.mu.Lock()
	r := s.cur
	s.mu.Unlock()
	if r != nil {
		r.add(q)
	}
}

var frActiveRec = &frRecSwitch{}
var frRegOnce sync.Once

// newRecordingRunStore opens an in-memory store whose SQL is recorded, seeded with enough rows
// (across two workspaces and both statuses) that SQLite's planner has something to choose between.
func newRecordingRunStore(t *testing.T) (*Store, *sql.DB, *frRecorder) {
	t.Helper()
	rec := &frRecorder{}
	frRegOnce.Do(func() { sql.Register("sqlite-rec-flowrun", frRecDriver{inner: &sqlite.Driver{}, rec: frActiveRec}) })
	frActiveRec.swap(rec)
	t.Cleanup(func() { frActiveRec.swap(nil) })

	db, err := sql.Open("sqlite-rec-flowrun", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = db.Close() })
	for _, stmt := range Schema {
		if _, err := db.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	s := New(ormpkg.Open(db))
	// The healthy-workspace shape the card actually faces: a long run history ending at ~now (one run
	// every 2h back ~33 days), mostly completed, with only a HANDFUL of failures inside the last 24h.
	// The window (?completedAfter=now-24h) must therefore be selective — a seed whose rows all sit
	// weeks in the past leaves it matching zero rows, and the planner, unable to see that, picks
	// idx_fr_ws_created (this test's first draft did exactly that: the 工单⑭ lesson, that an index's
	// use is a claim to MEASURE, not assert — reproduced against my own guard).
	// 牌真正面对的健康档形状：一条长 run 史结束在 ~now（每 2h 一个、回溯 ~33 天）、大多 completed、只有
	// **少数几个**失败落在最近 24h 内。故窗口（?completedAfter=now-24h）必须有选择性——一个所有行都在几周前
	// 的种子会让它匹配 0 行、而规划器看不出这点、于是选了 idx_fr_ws_created（本测试初稿正是如此：工单⑭ 的教训
	// ——索引的采用是要**测**的主张、非声称——在我自己的守卫上重演了）。
	now := time.Now().UTC()
	for i := 0; i < 400; i++ {
		at := now.Add(-time.Duration(i) * 2 * time.Hour) // i=0 newest, i=399 ~33d ago
		status := "completed"
		// A few failures in the last 24h (the card's window) + sprinkled failures long ago, so status
		// alone is not selective — the completed_at window is what makes the seek win.
		if (i < 12 && i%3 == 0) || i%37 == 0 {
			status = "failed"
		}
		done := at.Add(30 * time.Second)
		seedStatsRun(t, db, "ws_1", fmt.Sprintf("fr_%04d", i), fmt.Sprintf("wf_%d", i%3), status, at, &done)
	}
	// A second workspace, so workspace_id is not a no-op predicate.
	for i := 0; i < 50; i++ {
		at := now.Add(-time.Duration(i) * 2 * time.Hour)
		seedStatsRun(t, db, "ws_2", fmt.Sprintf("fr_o%04d", i), "wf_o", "failed", at, ptr(at))
	}
	if _, err := db.Exec("ANALYZE"); err != nil {
		t.Fatalf("analyze: %v", err)
	}
	rec.reset()
	return s, db, rec
}

// frPlan EXPLAINs the SQL and returns the plan lines joined.
func frPlan(t *testing.T, db *sql.DB, query string, args []any) string {
	t.Helper()
	rows, err := db.Query("EXPLAIN QUERY PLAN "+query, args...)
	if err != nil {
		t.Fatalf("explain %q: %v", query, err)
	}
	defer rows.Close()
	var lines []string
	for rows.Next() {
		var a, b, c int
		var detail string
		if err := rows.Scan(&a, &b, &c, &detail); err != nil {
			t.Fatalf("scan plan: %v", err)
		}
		lines = append(lines, detail)
	}
	return strings.Join(lines, " | ")
}

// TestListRuns_CardDeepLinkUsesItsIndex — the ?status=failed&completedAfter= read must SEARCH
// idx_fr_ws_status_completed with EVERY bound resolving through it, never a full scan. Asserting the
// index NAME alone is not enough: wrap completed_at in julianday() and the plan still names the index
// (workspace_id + status hold it) while the query walks the whole workspace to filter the wrapped
// bound. The predicate signature is what pins the completed_at bound as sargable.
func TestListRuns_CardDeepLinkUsesItsIndex(t *testing.T) {
	s, db, rec := newRecordingRunStore(t)
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	since := time.Now().UTC().Add(-24 * time.Hour)

	rec.reset()
	if _, _, err := s.ListRuns(ctx, flowrundomain.ListFilter{
		Status: "failed", CompletedAfter: since, Limit: 50,
	}); err != nil {
		t.Fatalf("deep-link: %v", err)
	}
	sqls := rec.selects()
	if len(sqls) != 1 {
		t.Fatalf("expected exactly one SELECT recorded, got %d: %v", len(sqls), sqls)
	}
	// EXPLAIN the captured text with the REAL bounds, not NULLs. This DIVERGES from
	// firings_plan_test.go, on purpose: that index (idx_trf_ws_created) wins on SHAPE alone — its
	// window column IS its sort column, so it beats a temp b-tree regardless of how many rows the
	// window holds, and NULL args suffice. This one wins on SELECTIVITY — it seeks (ws, status,
	// completed_at>) then sorts the few survivors by started_at (a different column), so it only beats
	// the ordered scan of idx_fr_ws_created when the planner can SEE the window is narrow. Bind
	// `completed_at >= NULL` and the planner cannot see that, falls back to idx_fr_ws_created, and the
	// guard fails on a query that is fast in production — a false alarm. The real bound is what makes
	// the plan the plan the product runs. Positional args mirror the recorded SQL: the orm prepends
	// workspace_id, then status, then the completed_at window (asserted by the one-SELECT + predicate
	// checks below).
	// 用**真实**边界（非 NULL）EXPLAIN 捕获的文本。这**刻意背离** firings_plan_test.go：那个索引
	// （idx_trf_ws_created）**靠形状**就赢——窗口列即排序列、不管窗内多少行都胜过临时 b-tree，NULL 参数够用。
	// 而本索引**靠选择性**赢——它 seek (ws, status, completed_at>) 再把少数幸存者按 started_at（另一列）排序，
	// 故只有规划器**看得见**窗口窄时才胜过 idx_fr_ws_created 的有序扫描。绑 `completed_at >= NULL` 规划器就看
	// 不见、回落 idx_fr_ws_created、守卫在一条生产上很快的查询上误报。真实边界才让计划成为产品真跑的计划。
	// 位置参数镜像记录的 SQL：orm 先前置 workspace_id、再 status、再 completed_at 窗（由下面的单 SELECT +
	// 谓词检查佐证）。
	if n := strings.Count(sqls[0], "?"); n != 3 {
		t.Fatalf("expected 3 bound params (ws, status, completedAfter), got %d: %s", n, sqls[0])
	}
	got := frPlan(t, db, sqls[0], []any{"ws_1", "failed", since})

	const wantIdx = "idx_fr_ws_status_completed"
	const wantPred = "(workspace_id=? AND status=? AND completed_at>?)"
	if !strings.Contains(got, wantIdx) {
		t.Fatalf("must use %s\n  sql  : %s\n  plan : %s", wantIdx, sqls[0], got)
	}
	if !strings.Contains(got, wantPred) {
		t.Fatalf("every bound must resolve THROUGH the index — want predicate %s\n  sql  : %s\n  plan : %s", wantPred, sqls[0], got)
	}
	if strings.Contains(got, "SCAN") {
		t.Fatalf("must not full-scan flowruns\n  sql  : %s\n  plan : %s", sqls[0], got)
	}
}
