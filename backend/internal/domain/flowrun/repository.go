package flowrun

import (
	"context"
	"time"
)

// ListFilter paginates a workspace's flowruns (newest-first). All filters compose with AND
// (scheduler 工单⑥): WorkflowID / TriggerID narrow provenance, Status and Origin are closed-set
// (an out-of-enum value is a loud 422, never a silent empty page — F168-M2), and each time window
// is half-open [After, Before) so adjacent windows tile without overlap (zero time = that bound
// unset). NULL-origin rows (pre-provenance) never match an Origin filter.
//
// TWO windows, on the two timestamps a run has, because they answer two different questions
// (scheduler 工单⑮): started_at asks "which runs BEGAN in this period", completed_at asks "which
// runs LANDED in it". For failures the second is the only honest one — a run that began 30h ago
// and failed an hour ago belongs to today's failures and to no window on started_at, and a run
// that began inside the window and is still going belongs to neither. That difference is the whole
// reason the Overview's 「24h 失败」 KPI card counts on completed_at (see Repository.RunStats'
// failedSince, whose predicate this one is byte-for-byte), and the reason the card could not be
// clicked until this window existed.
//
// CompletedAfter/Before select ONLY landed runs: completed_at is NULL while a run is running or
// parked, and `NULL >= ?` is never true, so either bound silently excludes the unfinished. That is
// the intent (a window on when runs LANDED cannot speak about runs that have not), and it is
// pinned by a test rather than left to be "fixed" by someone reading it as a bug.
//
// ListFilter 分页一个 workspace 的 flowrun（最新优先）。所有过滤 AND 组合（scheduler 工单⑥）：
// WorkflowID / TriggerID 收窄溯源，Status 与 Origin 是封闭集（枚举外值 422 大声拒、绝不静默空页——
// F168-M2），每个时间窗都是半开区间 [After, Before)——相邻窗口无缝拼接不重叠（零值时间 = 该端不设界）。
// origin 为 NULL 的旧行永不匹配 Origin 过滤。
//
// **两个窗，开在 run 仅有的两个时刻上**，因为它们回答两个不同的问题（scheduler 工单⑮）：started_at 问
// 「哪些 run 在这段时间**开始**」，completed_at 问「哪些 run 在这段时间**落定**」。对失败而言只有后者诚实
// ——30 小时前起跑、一小时前失败的那个属于「今天的失败」、却不属于 started_at 上的任何窗；而窗内起跑、还在
// 跑的那个两个窗都不属于。这个差别正是 Overview「24h 失败」牌按 completed_at 数的全部理由（见
// Repository.RunStats 的 failedSince——本窗的谓词与它**逐字节相同**），也正是这张牌在本窗存在之前点不开的理由。
//
// CompletedAfter/Before **只**选落定的 run：run 在跑或 parked 时 completed_at 为 NULL，而 `NULL >= ?`
// 永不为真，故任一界都会静默剔除未完成的。这是**本意**（一个问「何时落定」的窗，讲不了还没落定的 run），
// 且由测试钉死——而不是留给后来人读成 bug 去「修」。
type ListFilter struct {
	WorkflowID      string
	Status          string    // running | completed | failed | cancelled; "" = all. 空 = 全部。
	TriggerID       string    // entry trg_ equality; "" = all. 入口 trg_ 等值；空 = 全部。
	Origin          string    // RunOrigins member; "" = all. RunOrigins 之一；空 = 全部。
	StartedAfter    time.Time // inclusive lower bound on started_at. started_at 含下界。
	StartedBefore   time.Time // exclusive upper bound on started_at. started_at 不含上界。
	CompletedAfter  time.Time // inclusive lower bound on completed_at; excludes unlanded. completed_at 含下界；剔除未落定。
	CompletedBefore time.Time // exclusive upper bound on completed_at; excludes unlanded. completed_at 不含上界；剔除未落定。
	Cursor          string
	Limit           int
}

// Repository persists the two flowrun tables. Both are Log tables (D1: never deleted).
// The single-tx firing claim (pending→claimed + flowrun INSERT) is NOT here — it lives on the
// trigger store (it spans trigger_firings) and is handed the flowrun INSERT as a create callback;
// see triggerstore.ClaimFiring. The scheduler writes the claimed run's header + seed trigger node
// through that callback, then uses this Repository for everything after.
//
// Repository 持久化 flowrun 两表。两张都是 Log 表（D1：绝不删）。单事务 firing claim
// （pending→claimed + 建 flowrun）不在此——它住在 trigger store（跨 trigger_firings），以 create 回调
// 接住 flowrun 的 INSERT，见 triggerstore.ClaimFiring。scheduler 经该回调写 claim 后 run 的头 + seed
// trigger 节点，之后一切用本 Repository。
type Repository interface {
	// --- flowruns ---

	// GetRun loads a run header by id; ErrNotFound on miss.
	// GetRun 按 id 取 run 头；未命中 ErrNotFound。
	GetRun(ctx context.Context, id string) (*FlowRun, error)

	// ListRuns pages a workspace's runs newest-first (optionally one workflow's).
	// ListRuns 分页一个 workspace 的 run（最新优先，可限定单 workflow）。
	ListRuns(ctx context.Context, filter ListFilter) ([]*FlowRun, string, error)

	// GetRunsByIDs batch-loads run headers by id (ONE query, workspace-scoped) — the inbox's
	// bounded join to workflow context (工单④); missing ids are simply absent, never an error.
	// GetRunsByIDs 按 id 批读 run 头（单查询、workspace 隔离）——收件箱到 workflow 上下文的有界
	// join（工单④）；缺席 id 直接不出现、绝不报错。
	GetRunsByIDs(ctx context.Context, ids []string) ([]*FlowRun, error)

	// ListRunningRuns returns every run still in StatusRunning — the boot-recovery candidate set
	// (re-walk each; memoized rows skip, parked rows stay).
	// ListRunningRuns 返所有仍 StatusRunning 的 run——boot 恢复候选集（逐个重走；记忆化行跳过、parked 留）。
	ListRunningRuns(ctx context.Context) ([]*FlowRun, error)

	// RunStats computes the operational statistics batch (scheduler 工单③): workspace-wide totals
	// + one health row per requested workflow id (zero row when it has no runs). A pure read
	// projection over the two flowrun tables; q's defaults are the caller's job (app service).
	// RunStats 计算运营统计批查（scheduler 工单③）：全 workspace 聚合 + 每个请求 workflow id 一条
	// 健康行（无 run 即零值行）。flowrun 两表上的纯读投影；q 的默认值由调用方（app service）负责。
	RunStats(ctx context.Context, q StatsQuery) (*RunStats, error)

	// RunMatrix computes the node×run status grid (scheduler 工单⑩): one workflow's last RecentN
	// runs as columns, the union of their node ids as rows, and a sparse cell per (run, node). A
	// pure read projection over the two flowrun tables in TWO bounded queries (never a per-run
	// detail fetch); q's defaults are the caller's job (app service).
	// RunMatrix 计算节点×run 状态格阵（scheduler 工单⑩）：一个 workflow 近 RecentN 个 run 为列、
	// 它们 node id 的并集为行、每 (run, 节点) 一个稀疏格。flowrun 两表上的纯读投影、**两条**有界
	// 查询（绝不逐 run 拉详情）；q 的默认值由调用方（app service）负责。
	RunMatrix(ctx context.Context, q MatrixQuery) (*Matrix, error)

	// PurgeTerminalRunsBefore physically deletes up to `batch` finished runs that reached their
	// terminal before cutoff — the header, its node rows and the audit rows that run produced, all
	// in ONE transaction — and returns how many run headers went. running/parked runs are never
	// touched, however old. THE SECOND D1 CARVE-OUT (scheduler 工单⑬): unlike DeleteFailedNodes
	// (which clears a non-result), this deletes real history — legitimate only as the user's
	// configured capacity governance, legislated in database.md. The caller (app service) owns the
	// batch loop and the retention line → cutoff translation.
	// PurgeTerminalRunsBefore 物理删至多 `batch` 个在 cutoff 前落定的终态 run——头、它的节点行、
	// 以及该 run 产生的审计行，全在**一个**事务里——返回删掉多少个 run 头。running/parked 的 run
	// 永不被碰，不管多老。**D1 的第二个例外**（scheduler 工单⑬）：与 DeleteFailedNodes（清非结果）
	// 不同，这里删的是真实历史——只因它是用户配置的容量治理才正当，立法在 database.md。批循环与
	// 「保留线 → cutoff」的翻译归调用方（app service）。
	PurgeTerminalRunsBefore(ctx context.Context, cutoff time.Time, batch int) (int, error)

	// ListActivity returns ONE keyset page of a run's execution-log activity (scheduler 工单⑤):
	// the four audit tables UNIONed by flowrun_id, joined to flowrun_nodes for the queue stamp
	// (工单⑫), in the gantt's natural (started_at, exec id) ASCENDING order. A pure read projection
	// — it lives here (not behind four DIP ports) because a cross-table keyset page cannot be merged
	// from four independent cursors in memory. Run existence (404) is the caller's job; an unknown
	// run id simply yields an empty page. next == "" at the end.
	// ListActivity 返一个 run 执行日志活动的一页 keyset（scheduler 工单⑤）：四张审计表按 flowrun_id
	// UNION、join flowrun_nodes 取排队戳（工单⑫），按甘特天然序 (started_at, exec id) **升序**。纯读
	// 投影——放这里（而非四个 DIP 端口）因为跨表 keyset 分页无法在内存里合并四个独立游标。run 存在性
	// （404）归调用方；未知 run id 只得空页。到底 next == ""。
	ListActivity(ctx context.Context, flowrunID, cursor string, limit int) ([]*ActivityRow, string, error)

	// CountRunningByWorkflow counts a workflow's currently-running runs (overlap-policy input: serial
	// defers / Skip drops a new firing when this is > 0). Workspace-scoped.
	// CountRunningByWorkflow 数一个 workflow 当前 running 的 run（overlap 策略输入：>0 时 serial 推迟 /
	// Skip 丢弃新 firing）。按 workspace 隔离。
	CountRunningByWorkflow(ctx context.Context, workflowID string) (int, error)

	// ListRunningByWorkflow returns a workflow's currently-running runs — the kill set (kill_workflow
	// cancels each, interrupting any in-flight advance via ctx then marking it cancelled). Workspace-scoped.
	// ListRunningByWorkflow 返一个 workflow 当前 running 的 run——kill 集（kill_workflow 逐个取消：经 ctx
	// 打断在途 advance、再标 cancelled）。按 workspace 隔离。
	ListRunningByWorkflow(ctx context.Context, workflowID string) ([]*FlowRun, error)

	// MarkRunTerminal sets a run's terminal status (completed/failed/cancelled) + error +
	// completed_at, GUARDED on it still being running (first-wins). won=false means another
	// writer's terminal already stands — the loser must NOT emit run_terminal / reconcile /
	// notify for a terminal it did not write (:cancel surfaces it as ErrNotCancellable).
	// MarkRunTerminal 置 run 终态（completed/failed/cancelled）+ error + completed_at，守卫在
	// 它仍 running（first-wins）。won=false 表示另一写者的终态已立——输家绝不为不属于自己的
	// 终态发 run_terminal / 结算 / 通知（:cancel 把它上呈为 ErrNotCancellable）。
	MarkRunTerminal(ctx context.Context, id, status, errMsg string) (won bool, err error)

	// ReopenForReplay flips a failed run back to running + increments replay_count + clears error
	// (the :replay header half; clearing failed node rows is DeleteFailedNodes). Returns ErrNotReplayable
	// if the run is not currently failed.
	// ReopenForReplay 把 failed run 翻回 running + replay_count++ + 清 error（:replay 的头那半；清 failed
	// 节点行是 DeleteFailedNodes）。run 非 failed 时返 ErrNotReplayable。
	ReopenForReplay(ctx context.Context, id string) error

	// --- flowrun_nodes (record-once truth table) ---

	// InsertNodeResult writes a terminal/parked node row with first-wins semantics: a duplicate on
	// UNIQUE(flowrun_id,node_id,iteration) is silently ignored (inserted=false), never an error.
	// This is the record-once / replay-skip / approval-park-once mechanism.
	// InsertNodeResult 以 first-wins 写一条终态/parked 节点行：UNIQUE(flowrun_id,node_id,iteration) 上的
	// 重复被静默忽略（inserted=false），绝不报错。这是 record-once / 重放跳过 / approval park-once 机制。
	InsertNodeResult(ctx context.Context, n *FlowRunNode) (inserted bool, err error)

	// GetNodes returns all node rows of a run (the full memoization the interpreter re-derives state
	// from). Order is unspecified; the scheduler indexes by (node_id, iteration) in memory.
	// GetNodes 返一个 run 的全部节点行（解释器据以重推状态的全部记忆化）。顺序不定；scheduler 内存按
	// (node_id, iteration) 索引。
	GetNodes(ctx context.Context, flowrunID string) ([]*FlowRunNode, error)

	// ListNodes returns ONE keyset page of a run's node rows, newest-first, for the REST run-detail
	// view (N4 — a long loop run has thousands of rows; GetNodes' unbounded dump is the interpreter's,
	// not the wire's). next == "" at the end. The scheduler never uses this — it needs the whole set.
	// ListNodes 返一个 run 节点行的一页 keyset（最新在前），供 REST run 详情视图（N4——长 loop run 有数千行；
	// GetNodes 的无界倾倒是给解释器的、非线缆的）。到底 next == ""。scheduler 从不用它——它要全集。
	ListNodes(ctx context.Context, flowrunID, cursor string, limit int) (nodes []*FlowRunNode, next string, err error)

	// ResolveParkedNode flips a parked approval row to a terminal status + result, conditionally on
	// it still being parked — won=false means another writer (human vs timeout) already resolved it
	// (approval first-wins). The race loser is a no-op, not an error.
	// ResolveParkedNode 把一条 parked approval 行翻成终态 + result，条件是它仍 parked——won=false 表示
	// 另一写者（人 vs 超时）已抢先落定（approval first-wins）。竞争输家是 no-op、非错误。
	ResolveParkedNode(ctx context.Context, flowrunID, nodeID, status string, result map[string]any) (won bool, err error)

	// GetParkedNode loads the currently-parked row of (run, node) for the decide path; ErrNodeNotParked
	// if none is awaiting a decision.
	// GetParkedNode 取 (run,node) 当前 parked 行供决策路径；无在等的返 ErrNodeNotParked。
	GetParkedNode(ctx context.Context, flowrunID, nodeID string) (*FlowRunNode, error)

	// ListParkedNodes returns every parked node row in the workspace — the approval inbox (no separate
	// projection table; parked rows ARE the inbox).
	// ListParkedNodes 返 workspace 内所有 parked 节点行——审批收件箱（无独立投影表；parked 行即收件箱）。
	ListParkedNodes(ctx context.Context) ([]*FlowRunNode, error)

	// CancelParkedNodes resolves a run's still-parked nodes to NodeCancelled when the run is being
	// cancelled (:cancel/kill/replace while parked) — so a dead approval row does not linger in the
	// inbox. CALLERS MUST GATE THIS ON WINNING THE HEADER GUARD (MarkRunTerminal's won): the rows it
	// writes are only safe on a run whose header is cancelled, and a first-wins loser's run reached
	// its own terminal — if that is failed, its parked row is still live for :replay. The
	// implementation's note carries the full invariant.
	// CancelParkedNodes 在 run 被取消时（parked 时遭 :cancel/kill/replace）把其仍 parked 的节点收成
	// NodeCancelled——免死审批行滞留收件箱。**调用方必须把它闸在「赢了头守卫」（MarkRunTerminal 的 won）
	// 上**：它写的行只在头为 cancelled 的 run 上才安全，而 first-wins 输家的 run 走到的是它自己的终态
	// ——若那是 failed，它的 parked 行仍然活着、等着 :replay。完整不变式见实现处的注释。
	CancelParkedNodes(ctx context.Context, flowrunID string) (int64, error)

	// DeleteFailedNodes hard-deletes a run's failed node rows (the :replay node half — clears the
	// failures so a re-walk re-runs them; completed rows stay memoized). Returns rows removed. THE
	// FIRST of the two permitted physical deletes on these Log tables (the other is
	// PurgeTerminalRunsBefore's retention purge): a failed row is a non-result (the activity did not
	// durably complete), so removing it to retry is not erasing history. Deliberately failed-ONLY —
	// D1 permits no third carve-out, and none is needed: parked rows stay decidable across a replay,
	// and cancelled rows exist only on cancelled runs, which are never replayed.
	// DeleteFailedNodes 物理删一个 run 的 failed 节点行（:replay 的节点那半——清掉失败让重走重跑；
	// completed 行留作记忆化）。返删除行数。这是两张 Log 表上允许的两个物理删中的**第一个**（另一个是
	// PurgeTerminalRunsBefore 的保留清理）：failed 行是非结果（activity 没 durable 完成），删它重试不是
	// 抹历史。**刻意只收 failed**——D1 不容第三个例外，也不需要：parked 行跨 replay 仍可决策，而
	// cancelled 行只存在于 cancelled run 上、那种 run 永不被 replay。
	DeleteFailedNodes(ctx context.Context, flowrunID string) (int, error)
}
