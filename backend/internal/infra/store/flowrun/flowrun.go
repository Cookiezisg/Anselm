// Package flowrun is the orm-backed flowrundomain.Repository: flowruns (header) +
// flowrun_nodes (the node-result memoization truth table). Both are Log tables — NO
// deleted_at (D1), so any Delete here is PHYSICAL, and exactly TWO are permitted (both
// legislated in database.md's flowrun section):
//
//  1. DeleteFailedNodes — clears a NON-RESULT so :replay's idempotent re-walk can retry it.
//     Erases nothing: the failed row was never a result.
//  2. PurgeTerminalRunsBefore (retention.go, scheduler 工单⑬) — the user's configured
//     retention line. This one DOES delete real history, and is legitimate only as explicit
//     capacity governance: see that file's carve-out note before touching it.
//
// Record-once lives on idx_frn_once = UNIQUE(flowrun_id, node_id, iteration) (D3):
// InsertNodeResult is first-wins (a duplicate is silently ignored), and an approval decision is
// a conditional update gated on status='parked' (first-wins again). Workspace isolation is
// automatic (orm ,ws tag); ListRunningRuns deliberately crosses it (boot recovery scans every
// workspace's in-flight runs).
//
// Package flowrun 是 flowrundomain.Repository 的 orm 实现：flowruns（header）+ flowrun_nodes
// （节点结果记忆化真相表）。两张都是 Log 表——无 deleted_at（D1），故这里的任何 Delete 都是**物理**的，
// 且恰恰允许**两个**（都立法在 database.md 的 flowrun 节）：
//
//  1. DeleteFailedNodes——清掉**非结果**，让 :replay 的幂等重走能重试它。什么都没抹：failed 行从来
//     就不是结果。
//  2. PurgeTerminalRunsBefore（retention.go，scheduler 工单⑬）——用户配置的保留线。这个**确实**删真实
//     历史，只因它是显式的容量治理才正当：动它之前先读该文件的例外注释。
//
// record-once 落在 idx_frn_once = UNIQUE(flowrun_id,node_id,iteration)（D3）：InsertNodeResult
// first-wins（重复静默忽略），approval 决策是 status='parked' 上的条件更新（同 first-wins）。workspace
// 隔离自动（orm ,ws）；ListRunningRuns 刻意跨 workspace（boot 恢复扫所有 workspace 的在途 run）。
package flowrun

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Table names, exported so the scheduler's firing-claim callback can bind a Repo on the
// trigger store's transaction (SeedRunOnTx) without re-deriving the strings.
//
// 表名导出，使 scheduler 的 firing-claim 回调能在 trigger store 的事务上绑 Repo（SeedRunOnTx），
// 不必重复字符串。
const (
	TableFlowRuns     = "flowruns"
	TableFlowRunNodes = "flowrun_nodes"
)

// Schema is the 2-table DDL (idempotent). flowruns is the run header; flowrun_nodes is the
// memoization truth table. Neither has deleted_at (Log, D1). idx_frn_once is the record-once
// key (D3). idx_fr_running supports cross-ws boot recovery; idx_frn_parked supports the approval
// inbox.
//
// Schema 是 2 表 DDL（幂等）。flowruns 是 run 头；flowrun_nodes 是记忆化真相表。都无 deleted_at
// （Log，D1）。idx_frn_once 是 record-once 键（D3）。idx_fr_running 支撑跨 ws boot 恢复；
// idx_frn_parked 支撑审批收件箱。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS flowruns (
		id            TEXT PRIMARY KEY,
		workspace_id  TEXT NOT NULL,
		workflow_id   TEXT NOT NULL,
		version_id    TEXT NOT NULL,
		pinned_refs   TEXT NOT NULL DEFAULT '{}',
		trigger_id    TEXT NOT NULL DEFAULT '',
		firing_id     TEXT NOT NULL DEFAULT '',
		status        TEXT NOT NULL CHECK (status IN ('running','completed','failed','cancelled')),
		replay_count  INTEGER NOT NULL DEFAULT 0,
		error         TEXT NOT NULL DEFAULT '',
		started_at    DATETIME NOT NULL,
		completed_at  DATETIME,
		updated_at    DATETIME NOT NULL
	)`,
	`CREATE INDEX IF NOT EXISTS idx_fr_ws_created ON flowruns(workspace_id, started_at DESC, id DESC)`,
	`CREATE INDEX IF NOT EXISTS idx_fr_ws_workflow ON flowruns(workspace_id, workflow_id, started_at DESC, id DESC)`,
	`CREATE INDEX IF NOT EXISTS idx_fr_running ON flowruns(status) WHERE status = 'running'`,

	// idx_fr_ws_wf_status exists for ONE query: the consecutive-failure streak (stats.go ④), whose
	// "is there a completed run newer than this failed one" test is a per-row EXISTS. idx_fr_ws_workflow
	// cannot serve it — status is not in that index, so each probe scans every newer row of the workflow
	// and finds nothing precisely WHEN A WORKFLOW IS FAILING, making the walk quadratic in the streak
	// length K. With status as the third column the probe becomes a seek instead: (ws, wf, 'completed')
	// is a range whose FIRST entry (started_at DESC) is the newest completed run, so EXISTS answers in
	// one index hit.
	//
	// Measured (stats_bench_test.go, M1 Pro, 129,600 runs = cron@1m × the 90d default retention line —
	// a volume the shipped config reaches on its own), whole-endpoint ns/op:
	//
	//	  K        without        with
	//	  0        0.443s         0.394s     ← healthy: indistinguishable, which is why this hid
	//	  1000     0.671s         0.393s
	//	  4000     4.27s          0.397s     ← 10.8× faster, and FLAT: K left the runtime entirely
	//
	// The cruelty was the shape, not the constant: it exploded exactly when a workflow was failing —
	// the moment the user opens the scheduler to look at it — and no test on healthy data could see it.
	// A plain additive CREATE INDEX (no table rebuild, outcome-idempotent); the cost is one more index
	// maintained on flowruns writes, which are per-run-header, not per-node. The ~0.39s floor that
	// remains is NOT this index's to give back: it is query ①'s GROUP BY, which scans every run of the
	// requested workflows and evaluates julianday() per row. That floor is linear and predictable rather
	// than explosive, and is recorded rather than fixed here — see stats.go's header.
	//
	// idx_fr_ws_wf_status 只为**一条**查询存在：连败游走（stats.go ④），它的「有没有比这条 failed 更新的
	// completed」是逐行 EXISTS。idx_fr_ws_workflow 服务不了它——status 不在那个索引里，故每次探测都要扫遍该
	// workflow 所有更新的行、且**恰恰在 workflow 正在失败时**扫空，使游走在连败长度 K 上呈平方。把 status
	// 放进第三列后探测变成 seek：(ws, wf, 'completed') 是一段区间、其**首条**（started_at DESC）即最新的
	// completed run，故 EXISTS 一次命中即答完。
	//
	// 实测（stats_bench_test.go，M1 Pro，129,600 run = cron@1m × 90d 默认保留线——出厂配置自己就能长到的量），
	// 整端点 ns/op：
	//
	//	  K        无索引         有索引
	//	  0        0.443s        0.394s     ← 健康时无从分辨，这正是它藏住的原因
	//	  1000     0.671s        0.393s
	//	  4000     4.27s         0.397s     ← 快 10.8 倍，且**平**：K 彻底离开了运行时
	//
	// 恶毒的是形状、不是常数：它**恰好在 workflow 正在失败时**爆炸——也就是用户打开 scheduler 去看它的那一刻
	// ——而健康数据上的任何测试都看不见。纯增量 CREATE INDEX（无需重建表、结果幂等）；代价是 flowruns 写入多
	// 维护一个索引，而 flowruns 是**逐 run 头**写、非逐节点。剩下的 ~0.39s 地板**不归这个索引还**：那是查询
	// ① 的 GROUP BY——它扫请求 workflow 的每一个 run、并逐行求 julianday()。那个地板是线性可预测的、不是爆炸
	// 式的，故在此**记档而非顺手修**——见 stats.go 的头注释。
	`CREATE INDEX IF NOT EXISTS idx_fr_ws_wf_status ON flowruns(workspace_id, workflow_id, status, started_at DESC, id DESC)`,

	// Column evolution — run provenance (scheduler 工单①). ADD COLUMN (not baked into the CREATE)
	// so an existing install's flowruns table gains the columns on next boot; SQLite has no
	// ADD COLUMN IF NOT EXISTS, so re-runs rely on db.Migrate treating "duplicate column name" on an
	// ALTER … ADD COLUMN as already-applied. Both columns are NULLable: pre-provenance rows stay NULL
	// (CHECK passes on NULL) and the wire omits them.
	//
	// 列演化——run 溯源（scheduler 工单①）。用 ADD COLUMN（不并进 CREATE）使已有安装的 flowruns 表在下次
	// 启动补列；SQLite 无 ADD COLUMN IF NOT EXISTS，重复执行靠 db.Migrate 把 ALTER … ADD COLUMN 的
	// "duplicate column name" 视作已应用。两列可空：溯源之前的旧行保持 NULL（CHECK 对 NULL 放行）、线缆不发。
	`ALTER TABLE flowruns ADD COLUMN origin TEXT CHECK (origin IN ('manual','chat','cron','webhook','fsnotify','sensor'))`,
	`ALTER TABLE flowruns ADD COLUMN conversation_id TEXT`,

	`CREATE TABLE IF NOT EXISTS flowrun_nodes (
		id            TEXT PRIMARY KEY,
		workspace_id  TEXT NOT NULL,
		flowrun_id    TEXT NOT NULL,
		node_id       TEXT NOT NULL,
		iteration     INTEGER NOT NULL DEFAULT 0,
		kind          TEXT NOT NULL,
		ref           TEXT NOT NULL DEFAULT '',
		status        TEXT NOT NULL CHECK (status IN ('completed','failed','parked','cancelled')),
		result        TEXT NOT NULL DEFAULT '{}',
		error         TEXT NOT NULL DEFAULT '',
		created_at    DATETIME NOT NULL,
		completed_at  DATETIME,
		updated_at    DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_frn_once ON flowrun_nodes(flowrun_id, node_id, iteration)`,
	`CREATE INDEX IF NOT EXISTS idx_frn_run ON flowrun_nodes(flowrun_id)`,
	`CREATE INDEX IF NOT EXISTS idx_frn_parked ON flowrun_nodes(workspace_id, status) WHERE status = 'parked'`,

	// Column evolution — node queue stamps (scheduler 工单⑫), same outcome-idempotent ADD COLUMN
	// precedent as flowruns' origin. Both NULLable: pre-⑫ rows and seed trigger rows (never
	// scheduled) stay NULL; the stamps are captured in memory during a drive and ride the row's
	// single record-once INSERT — record-once itself is untouched.
	//
	// 列演化——节点排队戳（scheduler 工单⑫），与 flowruns origin 同一结果幂等 ADD COLUMN 先例。两列可空：
	// ⑫ 前旧行与 seed trigger 行（从不排队）保持 NULL；戳在驱动期间内存暂存、随该行唯一一次 record-once
	// INSERT 落盘——record-once 本身不动。
	`ALTER TABLE flowrun_nodes ADD COLUMN ready_at DATETIME`,
	`ALTER TABLE flowrun_nodes ADD COLUMN started_at DATETIME`,
}

// NodesCancelledMarker / NodesCheckRebuild: the node status CHECK gained 'cancelled' (the swept
// approval of a hand-stopped run records its real disposition instead of impersonating a failure —
// see CancelParkedNodes), and SQLite cannot ALTER a CHECK, so an existing install must REBUILD the
// table. Same mechanism and contract as trigger_firings' 'missed' (工单⑨): bootstrap runs this via
// db.MigrateRebuild, idempotent BY OUTCOME — it rebuilds only while the live sqlite_master DDL lacks
// the marker, so a fresh install (the CREATE above already carries the word) and every post-rebuild
// boot are no-ops.
//
// Two things this table has that trigger_firings did not, both load-bearing:
//   - ready_at / started_at (工单⑫) exist only as ALTER … ADD COLUMN above, never in the CREATE. The
//     rebuild declares all 15 columns INLINE and copies them explicitly — safe because MigrateRebuild
//     runs after Migrate, so the ALTERs have already landed on any install that reaches here.
//   - Three indexes drop with the old table and are recreated, one UNIQUE (idx_frn_once — the D3
//     record-once key; the copy preserves it because the source already satisfies it) and one PARTIAL
//     (idx_frn_parked, the inbox's covering index).
//
// NodesCancelledMarker / NodesCheckRebuild：节点 status CHECK 加词 'cancelled'（被手动停掉的 run 所收割
// 的审批记它**真实的处置**、不再假扮失败——见 CancelParkedNodes），而 SQLite 无法 ALTER CHECK，故已有安装
// 必须**重建**该表。机制与契约同 trigger_firings 的 'missed'（工单⑨）：bootstrap 经 db.MigrateRebuild 跑，
// **结果幂等**——仅当 sqlite_master 现行 DDL 缺该标记词才重建，故全新安装（上方 CREATE 已含该词）与重建后
// 的每次启动都是 no-op。
//
// 本表比 trigger_firings 多两处、皆承重：
//   - ready_at / started_at（工单⑫）只以上方的 ALTER … ADD COLUMN 存在、从不在 CREATE 里。重建把 15 列
//     全部**内联**声明并逐列拷贝——安全，因为 MigrateRebuild 在 Migrate **之后**跑，任何走到这里的安装都
//     已经补过那两列。
//   - 三个索引随旧表落、逐个重建，其中一个 UNIQUE（idx_frn_once——D3 record-once 键；源表本就满足它，故
//     拷贝不会撞）、一个**偏**索引（idx_frn_parked，收件箱的覆盖索引）。
var (
	NodesCancelledMarker = "'cancelled'"

	NodesCheckRebuild = []string{
		`CREATE TABLE flowrun_nodes_rebuild (
			id            TEXT PRIMARY KEY,
			workspace_id  TEXT NOT NULL,
			flowrun_id    TEXT NOT NULL,
			node_id       TEXT NOT NULL,
			iteration     INTEGER NOT NULL DEFAULT 0,
			kind          TEXT NOT NULL,
			ref           TEXT NOT NULL DEFAULT '',
			status        TEXT NOT NULL CHECK (status IN ('completed','failed','parked','cancelled')),
			result        TEXT NOT NULL DEFAULT '{}',
			error         TEXT NOT NULL DEFAULT '',
			created_at    DATETIME NOT NULL,
			completed_at  DATETIME,
			updated_at    DATETIME NOT NULL,
			ready_at      DATETIME,
			started_at    DATETIME
		)`,
		`INSERT INTO flowrun_nodes_rebuild
			SELECT id, workspace_id, flowrun_id, node_id, iteration, kind, ref, status, result, error,
				created_at, completed_at, updated_at, ready_at, started_at
			FROM flowrun_nodes`,
		`DROP TABLE flowrun_nodes`,
		`ALTER TABLE flowrun_nodes_rebuild RENAME TO flowrun_nodes`,
		`CREATE UNIQUE INDEX idx_frn_once ON flowrun_nodes(flowrun_id, node_id, iteration)`,
		`CREATE INDEX idx_frn_run ON flowrun_nodes(flowrun_id)`,
		`CREATE INDEX idx_frn_parked ON flowrun_nodes(workspace_id, status) WHERE status = 'parked'`,
	}
)

// Store implements flowrundomain.Repository over pkg/orm, plus the concrete run-creation
// methods (SeedRunOnTx / CreateRunWithTrigger) that span both tables in one transaction.
//
// Store 在 pkg/orm 上实现 flowrundomain.Repository，外加跨两表单事务的具体建-run 方法
// （SeedRunOnTx / CreateRunWithTrigger）。
type Store struct {
	db    *ormpkg.DB
	runs  *ormpkg.Repo[flowrundomain.FlowRun]
	nodes *ormpkg.Repo[flowrundomain.FlowRunNode]
}

// New constructs a Store bound to the two flowrun tables.
//
// New 构造绑定两张 flowrun 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{
		db:    db,
		runs:  ormpkg.For[flowrundomain.FlowRun](db, TableFlowRuns),
		nodes: ormpkg.For[flowrundomain.FlowRunNode](db, TableFlowRunNodes),
	}
}

var _ flowrundomain.Repository = (*Store)(nil)

// --- run creation (store-concrete, NOT in Repository: spans both tables atomically) -------

// SeedRunOnTx creates the run header + seeds its trigger node row on the GIVEN transaction —
// so the firing path can do it inside triggerstore.ClaimFiring's single tx (claim + run in one
// atom). Mints ids when empty. The trigger node IS the entry payload (its result), so
// a run never exists without its seed (no "ran nothing" ghost).
//
// SeedRunOnTx 在给定事务上建 run 头 + seed 它的 trigger 节点行——使 firing 路径能在
// triggerstore.ClaimFiring 的单事务内做（claim+建 run 一个原子）。id 空则铸。trigger
// 节点即入口 payload（它的 result），故 run 绝不无 seed 而存在（无「跑了个寂寞」幽灵）。
func (s *Store) SeedRunOnTx(ctx context.Context, tx *ormpkg.DB, run *flowrundomain.FlowRun, triggerNode *flowrundomain.FlowRunNode) error {
	if run.ID == "" {
		run.ID = idgenpkg.New("fr")
	}
	if run.Status == "" {
		run.Status = flowrundomain.StatusRunning
	}
	triggerNode.FlowRunID = run.ID
	if triggerNode.ID == "" {
		triggerNode.ID = idgenpkg.New("frn")
	}
	if triggerNode.Status == "" {
		triggerNode.Status = flowrundomain.NodeCompleted
	}
	if err := ormpkg.For[flowrundomain.FlowRun](tx, TableFlowRuns).Create(ctx, run); err != nil {
		return fmt.Errorf("flowrunstore.SeedRunOnTx run: %w", err)
	}
	if err := ormpkg.For[flowrundomain.FlowRunNode](tx, TableFlowRunNodes).Create(ctx, triggerNode); err != nil {
		return fmt.Errorf("flowrunstore.SeedRunOnTx trigger node: %w", err)
	}
	return nil
}

// CreateRunWithTrigger is the manual-trigger path: SeedRunOnTx in its own transaction (no firing
// to claim). Returns the run id.
//
// CreateRunWithTrigger 是手动 trigger 路径：在自有事务里 SeedRunOnTx（无 firing 可 claim）。返 run id。
func (s *Store) CreateRunWithTrigger(ctx context.Context, run *flowrundomain.FlowRun, triggerNode *flowrundomain.FlowRunNode) (string, error) {
	err := s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		return s.SeedRunOnTx(ctx, tx, run, triggerNode)
	})
	if err != nil {
		return "", fmt.Errorf("flowrunstore.CreateRunWithTrigger: %w", err)
	}
	return run.ID, nil
}

// --- flowruns --------------------------------------------------------------

func (s *Store) GetRun(ctx context.Context, id string) (*flowrundomain.FlowRun, error) {
	r, err := s.runs.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, flowrundomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.GetRun: %w", err)
	}
	return r, nil
}

// GetRunsByIDs batch-loads run headers in ONE WhereIn query (workspace-scoped) — the inbox's
// bounded join to workflow context (工单④). Missing ids are simply absent; output follows the
// requested order for the ids that hit (mirrors workflowstore.GetWorkflowsByIDs).
//
// GetRunsByIDs 单条 WhereIn 查询批读 run 头（workspace 隔离）——收件箱到 workflow 上下文的有界
// join（工单④）。缺席 id 直接不出现；命中的按请求顺序返回（照 workflowstore.GetWorkflowsByIDs）。
func (s *Store) GetRunsByIDs(ctx context.Context, ids []string) ([]*flowrundomain.FlowRun, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	vals := make([]any, len(ids))
	for i, id := range ids {
		vals[i] = id
	}
	rows, err := s.runs.WhereIn("id", vals...).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.GetRunsByIDs: %w", err)
	}
	byID := make(map[string]*flowrundomain.FlowRun, len(rows))
	for _, r := range rows {
		byID[r.ID] = r
	}
	out := make([]*flowrundomain.FlowRun, 0, len(ids))
	for _, id := range ids {
		if r, ok := byID[id]; ok {
			out = append(out, r)
		}
	}
	return out, nil
}

func (s *Store) ListRuns(ctx context.Context, filter flowrundomain.ListFilter) ([]*flowrundomain.FlowRun, string, error) {
	q := s.runs.Query()
	if filter.WorkflowID != "" {
		q = q.WhereEq("workflow_id", filter.WorkflowID)
	}
	if filter.Status != "" {
		// Reject an out-of-enum status loudly (422) instead of silently matching zero rows, which
		// reads to the caller as "no such runs exist" (F168-M2).
		// 非枚举状态大声拒（422），而非静默匹配 0 行——那会被读作「无此类 run」（F168-M2）。
		if !slices.Contains(flowrundomain.RunStatuses, filter.Status) {
			return nil, "", flowrundomain.ErrInvalidStatus.WithDetails(map[string]any{"allowed": flowrundomain.RunStatuses, "got": filter.Status})
		}
		q = q.WhereEq("status", filter.Status)
	}
	if filter.TriggerID != "" {
		q = q.WhereEq("trigger_id", filter.TriggerID)
	}
	if filter.Origin != "" {
		// Same loud-422 stance as status (F168-M2): an out-of-enum origin matches zero rows forever
		// (the column is CHECK-constrained), which would read as "no such runs" (scheduler 工单⑥).
		// 与 status 同一 422 大声拒立场（F168-M2）：枚举外 origin 永远 0 行（列有 CHECK），会被读作
		// 「无此类 run」（scheduler 工单⑥）。
		if !slices.Contains(flowrundomain.RunOrigins, filter.Origin) {
			return nil, "", flowrundomain.ErrInvalidListFilter.WithDetails(map[string]any{"param": "origin", "allowed": flowrundomain.RunOrigins, "got": filter.Origin})
		}
		q = q.WhereEq("origin", filter.Origin)
	}
	// Half-open window [StartedAfter, StartedBefore) on started_at (scheduler 工单⑥). Plain column
	// comparisons (no julianday wrapping): bound values and stored values go through the same driver
	// serialization (UTC — the handler normalizes), and a bare started_at predicate stays sargable on
	// idx_fr_ws_created / idx_fr_ws_workflow (workspace equality + started_at range).
	// started_at 上的半开窗 [StartedAfter, StartedBefore)（scheduler 工单⑥）。裸列比较（不包 julianday）：
	// 绑定值与存储值走同一 driver 序列化（UTC——handler 归一），裸 started_at 谓词在 idx_fr_ws_created /
	// idx_fr_ws_workflow 上可走索引（workspace 等值 + started_at 范围）。
	if !filter.StartedAfter.IsZero() {
		q = q.Where("started_at >= ?", filter.StartedAfter)
	}
	if !filter.StartedBefore.IsZero() {
		q = q.Where("started_at < ?", filter.StartedBefore)
	}
	rows, next, err := q.Page(ctx, filter.Cursor, filter.Limit)
	if err != nil {
		return nil, "", fmt.Errorf("flowrunstore.ListRuns: %w", err)
	}
	return rows, next, nil
}

// ListRunningRuns crosses workspaces on purpose: boot recovery runs before any request ctx and
// must re-walk every in-flight run regardless of workspace (the scheduler then advances each in
// a ctx scoped to that run's WorkspaceID).
//
// ListRunningRuns 刻意跨 workspace：boot 恢复在任何请求 ctx 之前跑，须重走每个在途 run（不论
// workspace；scheduler 再在各 run 自己 WorkspaceID 的 ctx 里 advance）。
func (s *Store) ListRunningRuns(ctx context.Context) ([]*flowrundomain.FlowRun, error) {
	rows, err := s.runs.CrossWorkspace().WhereEq("status", flowrundomain.StatusRunning).Order("started_at ASC, id ASC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.ListRunningRuns: %w", err)
	}
	return rows, nil
}

// CountRunningByWorkflow counts a workflow's running runs in the current workspace (overlap input).
//
// CountRunningByWorkflow 数当前 workspace 内某 workflow 的 running run（overlap 输入）。
func (s *Store) CountRunningByWorkflow(ctx context.Context, workflowID string) (int, error) {
	n, err := s.runs.WhereEq("workflow_id", workflowID).WhereEq("status", flowrundomain.StatusRunning).Count(ctx)
	if err != nil {
		return 0, fmt.Errorf("flowrunstore.CountRunningByWorkflow: %w", err)
	}
	return int(n), nil
}

// ListRunningByWorkflow returns one workflow's running runs in the current workspace — the kill set.
//
// ListRunningByWorkflow 返当前 workspace 内某 workflow 的 running run——kill 集。
func (s *Store) ListRunningByWorkflow(ctx context.Context, workflowID string) ([]*flowrundomain.FlowRun, error) {
	rows, err := s.runs.WhereEq("workflow_id", workflowID).WhereEq("status", flowrundomain.StatusRunning).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.ListRunningByWorkflow: %w", err)
	}
	return rows, nil
}

// MarkRunTerminal flips a run to a terminal status — GUARDED on it still being running (first-wins).
// :cancel, kill, finalize (completed), and failRun can race on the same run; whoever updates first
// wins, the loser's UPDATE matches 0 rows and is a no-op (a completed run is never clobbered to
// cancelled, etc.). The affected-row count IS the race verdict, returned as won so callers stay
// honest: only the winner emits run_terminal / reconciles, and :cancel turns a loss into 422.
//
// MarkRunTerminal 把 run 翻成终态——守卫在它仍 running（first-wins）。:cancel、kill、finalize
// （completed）、failRun 可能撞同一 run；先 UPDATE 者赢，输家匹配 0 行 no-op（completed run 绝不被
// 刷成 cancelled 等）。影响行数即竞态判决，作为 won 返回让调用方诚实：只有赢家发 run_terminal /
// 结算，:cancel 把输局转成 422。
func (s *Store) MarkRunTerminal(ctx context.Context, id, status, errMsg string) (bool, error) {
	n, err := s.runs.WhereEq("id", id).WhereEq("status", flowrundomain.StatusRunning).Updates(ctx, map[string]any{
		"status":       status,
		"error":        errMsg,
		"completed_at": time.Now().UTC(),
	})
	if err != nil {
		return false, fmt.Errorf("flowrunstore.MarkRunTerminal: %w", err)
	}
	return n > 0, nil
}

// ReopenForReplay flips a failed run back to running (:replay's header half) — GUARDED on it still
// being failed, the same first-wins discipline MarkRunTerminal applies to the terminal writes. This
// is the ONLY write that reverses a terminal, so it is the only place the guard could be missed, and
// an unguarded read-check-write here is not academic: two :replay calls both read `failed`, both pass
// the check, and the loser's UPDATE lands after the winner already drove the run to a new terminal —
// resurrecting a completed/failed run to running, wiping the completed_at and error it just earned,
// and writing a replay_count computed from a stale read. The guard collapses all of it: the loser
// matches 0 rows and gets ErrNotReplayable (422 — honest, the run is no longer failed), and because
// only a winner can move a run out of `failed`, the stale ReplayCount+1 it carries is exactly right.
// Retention's purge guards the same boundary from the other side (it re-asserts terminal on delete so
// a concurrent :replay wins).
//
// ReopenForReplay 把 failed run 翻回 running（:replay 的头那半）——守卫在它**仍是 failed**，与
// MarkRunTerminal 施于终态写的 first-wins 纪律同款。这是**唯一**逆转终态的写，故也是唯一可能漏掉守卫的
// 地方，而这里的无守卫「读-判-写」并非学术问题：两个 :replay 都读到 `failed`、都通过判断，输家的 UPDATE
// 落在赢家已把 run 驱到新终态之后——把 completed/failed 的 run **复活**成 running、抹掉它刚挣到的
// completed_at 与 error、并写入一个据陈旧读算出的 replay_count。守卫让这一切归零：输家匹配 0 行、得
// ErrNotReplayable（422——诚实，该 run 已不是 failed），且因为只有赢家能把 run 移出 `failed`，它带的
// 那个陈旧 ReplayCount+1 恰好正确。保留清理从另一侧守同一条边界（删头时重申终态守卫，使并发 :replay 赢）。
func (s *Store) ReopenForReplay(ctx context.Context, id string) error {
	run, err := s.GetRun(ctx, id) // ErrNotFound (ws-scoped) if missing
	if err != nil {
		return err
	}
	if run.Status != flowrundomain.StatusFailed {
		return flowrundomain.ErrNotReplayable
	}
	n, err := s.runs.WhereEq("id", id).WhereEq("status", flowrundomain.StatusFailed).Updates(ctx, map[string]any{
		"status":       flowrundomain.StatusRunning,
		"replay_count": run.ReplayCount + 1,
		"error":        "",
		"completed_at": nil,
	})
	if err != nil {
		return fmt.Errorf("flowrunstore.ReopenForReplay: %w", err)
	}
	if n == 0 {
		return flowrundomain.ErrNotReplayable // lost to a racing replay/terminal — the standing status wins
	}
	return nil
}

// --- flowrun_nodes ---------------------------------------------------------

func (s *Store) InsertNodeResult(ctx context.Context, n *flowrundomain.FlowRunNode) (bool, error) {
	if n.ID == "" {
		n.ID = idgenpkg.New("frn")
	}
	if err := s.nodes.Create(ctx, n); err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			return false, nil // record-once: the (run,node,iteration) row already exists — first writer won
		}
		return false, fmt.Errorf("flowrunstore.InsertNodeResult: %w", err)
	}
	return true, nil
}

func (s *Store) GetNodes(ctx context.Context, flowrunID string) ([]*flowrundomain.FlowRunNode, error) {
	rows, err := s.nodes.WhereEq("flowrun_id", flowrunID).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.GetNodes: %w", err)
	}
	return rows, nil
}

// ListNodes pages a run's node rows newest-first via the (created_at, id) keyset (N4) — the bounded
// REST counterpart to GetNodes' full dump.
//
// ListNodes 经 (created_at, id) keyset 最新在前分页一个 run 的节点行（N4）——GetNodes 全量倾倒的有界 REST 对应物。
func (s *Store) ListNodes(ctx context.Context, flowrunID, cursor string, limit int) ([]*flowrundomain.FlowRunNode, string, error) {
	rows, next, err := s.nodes.WhereEq("flowrun_id", flowrunID).Page(ctx, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("flowrunstore.ListNodes: %w", err)
	}
	return rows, next, nil
}

func (s *Store) ResolveParkedNode(ctx context.Context, flowrunID, nodeID, status string, result map[string]any) (bool, error) {
	raw, err := json.Marshal(result)
	if err != nil {
		return false, fmt.Errorf("flowrunstore.ResolveParkedNode marshal: %w", err)
	}
	n, err := s.nodes.
		WhereEq("flowrun_id", flowrunID).
		WhereEq("node_id", nodeID).
		WhereEq("status", flowrundomain.NodeParked).
		Updates(ctx, map[string]any{
			"status":       status,
			"result":       string(raw),
			"completed_at": time.Now().UTC(),
		})
	if err != nil {
		return false, fmt.Errorf("flowrunstore.ResolveParkedNode: %w", err)
	}
	return n > 0, nil
}

func (s *Store) GetParkedNode(ctx context.Context, flowrunID, nodeID string) (*flowrundomain.FlowRunNode, error) {
	n, err := s.nodes.
		WhereEq("flowrun_id", flowrunID).
		WhereEq("node_id", nodeID).
		WhereEq("status", flowrundomain.NodeParked).
		First(ctx)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, flowrundomain.ErrNodeNotParked
	}
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.GetParkedNode: %w", err)
	}
	return n, nil
}

func (s *Store) ListParkedNodes(ctx context.Context) ([]*flowrundomain.FlowRunNode, error) {
	rows, err := s.nodes.WhereEq("status", flowrundomain.NodeParked).Order("created_at ASC, id ASC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("flowrunstore.ListParkedNodes: %w", err)
	}
	return rows, nil
}

// CancelParkedNodes resolves a run's still-parked nodes to NodeCancelled when the run itself is
// being cancelled (:cancel / kill / replace while it was parked on an approval). Without this, the
// parked approval row outlives its cancelled run and lingers in the inbox (ListParkedNodes) as a
// dead, undecidable entry. Returns how many parked nodes were resolved.
//
// The row records CANCELLED, not failed: the approval never failed — nobody ever answered it, and
// the run was stopped by hand. `failed` here would make the node contradict its own header — a grey
// cancelled run whose node row is red, which the matrix renders as a red cell and the ledger
// auto-expands as a failure row carrying no error text (there is no error to show). Reaching for
// `failed` because it is the familiar non-completed terminal is the trap: cancelled is a disposition,
// not a fault. See NodeCancelled's invariant in the domain.
//
// CALLERS MUST GATE THIS ON WINNING THE HEADER GUARD (MarkRunTerminal's won). That is not politeness
// — it is what makes the word free. Only a winner's run is cancelled, so a cancelled row can only
// ever sit on a cancelled run, which is terminal-final and never re-walked. A loser's run reached its
// NATURAL terminal instead: if that terminal is `failed` the run is still replayable, and sweeping
// its parked row to cancelled would leave :replay unable to clear it (DeleteFailedNodes takes only
// failed rows) — the approval would be permanently stuck, silently skipped by every re-walk. A
// loser must leave the parked row alone: on a failed run that row is still live, because :replay can
// resurrect the run and a human can still decide it (exactly why the failRun path never sweeps).
//
// CancelParkedNodes 在 run 本身被取消时（parked 在审批上却遭 :cancel/kill/replace）把其仍 parked 的
// 节点收成 NodeCancelled。否则该 parked 审批行会比被取消的 run 活得久、留在收件箱（ListParkedNodes）
// 成死的不可决策项。返被收的 parked 节点数。
//
// 行记 **cancelled、不是 failed**：这个审批**没有失败**——根本没人回答它，是 run 被手动停了。在这里写
// `failed` 会让节点与自己的头**自相矛盾**——一个灰色 cancelled run，其节点行却是红的：矩阵把它渲成红格，
// 台账把它当失败行**自动展开**、却拿不出任何错误文字（根本没有错误）。「顺手抓 `failed`，因为它是那个眼熟
// 的非 completed 终态」正是这里的陷阱：cancelled 是**处置**、不是**故障**。不变式见 domain 的 NodeCancelled。
//
// **调用方必须把它闸在「赢了头守卫」（MarkRunTerminal 的 won）上**。这不是客气——这正是这个词免费的
// 原因。只有赢家的 run 才是 cancelled，故 cancelled 行只可能落在 cancelled run 上，而那是终局终态、
// 永不被重走。输家的 run 走到的是它**自然的**终态：若那是 `failed`，run 仍可 replay，而把它的 parked
// 行收成 cancelled 会让 :replay 清不掉它（DeleteFailedNodes 只收 failed 行）——该审批就永久卡死、被
// 之后每次重走静默跳过。输家必须**别碰** parked 行：在 failed run 上那行仍然活着，因为 :replay 能把
// run 救回来、人仍可决策它（这正是 failRun 路径从不收割的原因）。
func (s *Store) CancelParkedNodes(ctx context.Context, flowrunID string) (int64, error) {
	n, err := s.nodes.WhereEq("flowrun_id", flowrunID).WhereEq("status", flowrundomain.NodeParked).
		Updates(ctx, map[string]any{
			"status": flowrundomain.NodeCancelled,
			// The sweep is the row's completion: it is terminal now, and a NULL completed_at would
			// read as "still open" to every consumer that distinguishes parked-vs-decided by it.
			// 收割即该行的落定：它现在是终态，而 NULL 的 completed_at 会让所有靠它区分「park 中 vs
			// 已决」的消费者读成「还开着」。
			"completed_at": time.Now().UTC(),
		})
	if err != nil {
		return 0, fmt.Errorf("flowrunstore.CancelParkedNodes: %w", err)
	}
	return n, nil
}

// DeleteFailedNodes hard-deletes a run's failed rows (flowrun_nodes has no deleted column → the
// query Delete is a physical DELETE). The FIRST of the two permitted deletes on these Log tables
// (the other is the retention purge): a failed row is a non-result, removing it to retry is not
// erasing history.
//
// DeleteFailedNodes 物理删一个 run 的 failed 行（flowrun_nodes 无 deleted 列 → 查询 Delete 即物理
// DELETE）。这两张 Log 表上允许的两个删中的**第一个**（另一个是保留清理）：failed 行是非结果，删它重试
// 不是抹历史。
func (s *Store) DeleteFailedNodes(ctx context.Context, flowrunID string) (int, error) {
	n, err := s.nodes.WhereEq("flowrun_id", flowrunID).WhereEq("status", flowrundomain.NodeFailed).Delete(ctx)
	if err != nil {
		return 0, fmt.Errorf("flowrunstore.DeleteFailedNodes: %w", err)
	}
	return int(n), nil
}
