package trigger

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

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Index guards for the firing reads (scheduler 工单⑭). These EXPLAIN the SQL the store ACTUALLY
// runs — captured through a recording driver rather than re-typed into the test — because a guard
// over a hand-copied query is theatre: it keeps passing while the real one drifts to `julianday(
// created_at) >= ?`, loses its index, and takes the Overview down at 129,600 rows.
//
// Timings stay OUT of the gate (they flake on shared CI); the plan is the mechanical invariant.
// Measured on this shape at 129,600 firings (a per-minute cron over 90d): 23.9ms → 802µs (track),
// 15.8ms → 23µs (missed count, covering), 51.1ms → 236µs (per-trigger).
//
// firing 读的索引守卫（scheduler 工单⑭）。它们 EXPLAIN 的是 store **真正**跑的那条 SQL——经记录型
// driver 抓下来、而非在测试里重敲一遍——因为「守着一份手抄查询」的守卫是演戏：真查询漂移成
// `julianday(created_at) >= ?`、丢掉索引、在 129,600 行上把 Overview 拖垮时，它还在一路绿灯。
//
// 时间数字**不**进门禁（共享 CI 上会 flake）；查询计划才是机械不变式。本形状实测（129,600 条 firing，
// 每分钟 cron 跑 90 天）：23.9ms → 802µs（轨道）、15.8ms → 23µs（missed 计数、覆盖索引）、
// 51.1ms → 236µs（逐 trigger）。

// recDriver records every statement prepared against the wrapped driver. It forwards to whichever
// test's recorder is currently live (a driver name can only be registered once per process).
// recDriver 记录经被包 driver 准备的每一条语句。它转发给当前活着的那个测试的 recorder（一个 driver
// 名在一个进程里只能注册一次）。
type recDriver struct {
	inner driver.Driver
	rec   *recSwitch
}

type recorder struct {
	mu   sync.Mutex
	sqls []string
}

func (r *recorder) add(q string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sqls = append(r.sqls, q)
}

func (r *recorder) reset() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sqls = nil
}

// selects returns the recorded SELECTs (the store's reads; schema DDL and inserts are noise here).
func (r *recorder) selects() []string {
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

func (d recDriver) Open(name string) (driver.Conn, error) {
	c, err := d.inner.Open(name)
	if err != nil {
		return nil, err
	}
	return recConn{Conn: c, rec: d.rec}, nil
}

// recConn deliberately implements ONLY Prepare/PrepareContext over the embedded Conn: database/sql
// then routes every query through Prepare, so nothing escapes the recorder via the Queryer fast path.
//
// recConn 刻意只在被嵌 Conn 之上实现 Prepare/PrepareContext：database/sql 于是把每条查询都经 Prepare
// 走，故没有任何查询能从 Queryer 快径上溜过记录器。
type recConn struct {
	driver.Conn
	rec *recSwitch
}

func (c recConn) Prepare(q string) (driver.Stmt, error) {
	c.rec.add(q)
	return c.Conn.Prepare(q)
}

func (c recConn) PrepareContext(ctx context.Context, q string) (driver.Stmt, error) {
	c.rec.add(q)
	if p, ok := c.Conn.(driver.ConnPrepareContext); ok {
		return p.PrepareContext(ctx, q)
	}
	return c.Conn.Prepare(q)
}

var regOnce sync.Once

// newRecordingStore opens an in-memory store whose SQL is recorded, seeded with enough rows that
// SQLite's planner has something to choose between.
func newRecordingStore(t *testing.T) (*Store, *sql.DB, *recorder) {
	t.Helper()
	rec := &recorder{}
	// One global registration; the recorder is swapped in per test via the closure below.
	regOnce.Do(func() { sql.Register("sqlite-rec", recDriver{inner: &sqlite.Driver{}, rec: activeRec}) })
	activeRec.swap(rec)
	t.Cleanup(func() { activeRec.swap(nil) })

	db, err := sql.Open("sqlite-rec", ":memory:")
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
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	base := time.Now().UTC().Add(-30 * 24 * time.Hour)
	for i := 0; i < 400; i++ {
		status := triggerdomain.FiringStarted
		if i%50 == 0 {
			status = triggerdomain.FiringMissed
		}
		mkFiringAt(t, s, ctx, fmt.Sprintf("trf_%04d", i), fmt.Sprintf("trg_%d", i%3), status, base.Add(time.Duration(i)*time.Hour))
	}
	if _, err := db.Exec("ANALYZE"); err != nil {
		t.Fatalf("analyze: %v", err)
	}
	rec.reset()
	return s, db, rec
}

// activeRec lets the single registered driver forward to whichever test's recorder is live.
type recSwitch struct {
	mu  sync.Mutex
	cur *recorder
}

func (s *recSwitch) swap(r *recorder) { s.mu.Lock(); s.cur = r; s.mu.Unlock() }
func (s *recSwitch) add(q string) {
	s.mu.Lock()
	r := s.cur
	s.mu.Unlock()
	if r != nil {
		r.add(q)
	}
}

var activeRec = &recSwitch{}

// plan EXPLAINs the SQL and returns the plan lines joined.
func plan(t *testing.T, db *sql.DB, query string, args []any) string {
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

// TestFiringReads_UseTheirIndexes — every firing read the product makes must be an index SEARCH with
// no temp b-tree sort. Before 工单⑭ no index carried workspace_id at all, while the orm prepends
// `workspace_id = ?` to every query — so each of these was a full scan + a sort of the whole table.
//
// TestFiringReads_UseTheirIndexes——产品发出的每一条 firing 读都必须是走索引的 SEARCH、且无临时 b-tree
// 排序。工单⑭ 之前**没有任何**索引带 workspace_id，而 orm 给每条查询前置 `workspace_id = ?`——故下面
// 每一条当时都是全表扫 + 全表排序。
func TestFiringReads_UseTheirIndexes(t *testing.T) {
	s, db, rec := newRecordingStore(t)
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	now := time.Now().UTC()

	cases := []struct {
		name    string
		run     func()
		wantIdx string
		// wantPred is the FULL predicate SQLite reports resolving through the index. Asserting the
		// index name alone is not enough: wrap one bound in julianday() and the plan still names the
		// index (the OTHER bound keeps it), while the query quietly walks the whole workspace to
		// filter the wrapped one. The predicate signature is what pins every bound as sargable.
		//
		// wantPred 是 SQLite 报告的、经索引解析的**完整**谓词。只断言索引名不够：把其中一个界包进
		// julianday()，计划**照样**会点到那个索引（另一个界撑着它），而查询已经在悄悄走遍整个 workspace
		// 去过滤被包住的那个界。谓词签名才是把**每一个**界都钉成可索引的东西。
		wantPred string
		// wantCovering: the count never touches the table, only the index.
		wantCovering bool
	}{
		{
			// The Overview's 24h schedule track: every trigger's firings in a window.
			name: "track: ws + created_at window, all statuses",
			run: func() {
				if _, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{
					CreatedAfter: now.Add(-24 * time.Hour), CreatedBefore: now, Limit: 200,
				}); err != nil {
					t.Fatalf("track: %v", err)
				}
			},
			wantIdx:  "idx_trf_ws_created",
			wantPred: "(workspace_id=? AND created_at>? AND created_at<?)",
		},
		{
			// The "错过 N" KPI card.
			name: "count: ws + status=missed + since",
			run: func() {
				if _, err := s.CountFirings(ctx, triggerdomain.FiringFilter{
					Status: triggerdomain.FiringMissed, CreatedAfter: now.Add(-24 * time.Hour),
				}); err != nil {
					t.Fatalf("count: %v", err)
				}
			},
			wantIdx:      "idx_trf_ws_status",
			wantPred:     "(workspace_id=? AND status=? AND created_at>?)",
			wantCovering: true,
		},
		{
			// The card's deep-link. Decisive on a HEALTHY workspace: `missed` matches nothing, and
			// any other index has to walk the whole workspace to prove it.
			name: "deep-link: ws + status=missed page",
			run: func() {
				if _, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{
					Status: triggerdomain.FiringMissed, Limit: 50,
				}); err != nil {
					t.Fatalf("deep-link: %v", err)
				}
			},
			wantIdx:  "idx_trf_ws_status",
			wantPred: "(workspace_id=? AND status=?)",
		},
		{
			// The trigger detail page's firing strip. Without its own index SQLite walks
			// idx_trf_ws_created and a rarely-firing trigger's page costs MORE than the full scan
			// it replaced — which is why adding ws_created without ws_trigger would be a regression.
			name: "per-trigger: ws + triggerId page",
			run: func() {
				if _, _, err := s.SearchFirings(ctx, triggerdomain.FiringFilter{
					TriggerID: "trg_1", Limit: 50,
				}); err != nil {
					t.Fatalf("per-trigger: %v", err)
				}
			},
			wantIdx:  "idx_trf_ws_trigger",
			wantPred: "(workspace_id=? AND trigger_id=?)",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec.reset()
			tc.run()
			sqls := rec.selects()
			if len(sqls) != 1 {
				t.Fatalf("expected exactly one SELECT recorded, got %d: %v", len(sqls), sqls)
			}
			// Re-bind the same args by running EXPLAIN over the captured text. The orm binds args
			// positionally; EXPLAIN QUERY PLAN does not need real values to pick an index, so NULLs
			// are fine — the plan depends on the predicate SHAPE.
			nArgs := strings.Count(sqls[0], "?")
			args := make([]any, nArgs)
			got := plan(t, db, sqls[0], args)

			if !strings.Contains(got, tc.wantIdx) {
				t.Fatalf("must use %s\n  sql  : %s\n  plan : %s", tc.wantIdx, sqls[0], got)
			}
			if !strings.Contains(got, tc.wantPred) {
				t.Fatalf("every bound must resolve THROUGH the index — want predicate %s\n  sql  : %s\n  plan : %s", tc.wantPred, sqls[0], got)
			}
			if strings.Contains(got, "SCAN") {
				t.Fatalf("must not full-scan trigger_firings\n  sql  : %s\n  plan : %s", sqls[0], got)
			}
			if strings.Contains(got, "TEMP B-TREE") {
				t.Fatalf("the index must supply the order — no temp b-tree sort\n  sql  : %s\n  plan : %s", sqls[0], got)
			}
			if tc.wantCovering && !strings.Contains(got, "COVERING INDEX") {
				t.Fatalf("the count must be answered from the index alone (covering)\n  sql  : %s\n  plan : %s", sqls[0], got)
			}
		})
	}
}
