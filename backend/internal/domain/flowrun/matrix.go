// Run matrix (scheduler 工单⑩) — a PURE READ PROJECTION over the two existing flowrun tables
// (no new table, no new column) shaped for the scheduler ocean's node×run grid (AnRunMatrix on the
// operations home). ONE bounded batch answers the whole grid for an EXPLICIT set of runs: two
// queries total (the requested run headers, then every node row of those runs in a single
// flowrun_id IN (…)), never a per-run detail fetch (N+1). The client owns which runs are on
// screen — it pages GET /flowruns with the time-range grammar and batch-fetches the grid per page
// of ids, so this endpoint carries no window/recency parameters of its own.
//
// run 矩阵（scheduler 工单⑩）——flowrun 两张既有表上的**纯读投影**（零新表零新列），形状对准 scheduler
// 运营主页的 节点×run 格阵（AnRunMatrix）。一次有界批查按**显式 run id 集**答完整个格阵：总共两条查询
// （请求的 run 头，再一条 flowrun_id IN (…) 取这批 run 的全部节点行），绝不逐 run 拉详情（N+1）。哪些
// run 在屏上由客户端做主——它按时间窗文法翻 GET /flowruns、逐页拿 id 批取格阵，故本端点自身不带任何
// 窗口/近期参数。
package flowrun

import (
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// MatrixMaxFlowrunIDs caps one batch, VERBATIM the flowrun-stats ids discipline: over the cap
// (after dedup) rejects loudly with the cap in Details — silently truncating requested ids would
// lie, because the client zips its on-screen page against the answer and would read a short one
// as complete.
//
// MatrixMaxFlowrunIDs 封顶一次批查，**逐字**沿用 flowrun-stats 的 ids 纪律：（去重后）越上限带上限
// 大声拒——静默截断请求 id 会撒谎：客户端拿屏上那页与答案对拉，会把短答案读成完整。
const MatrixMaxFlowrunIDs = 50

// MatrixQuery is the batch request: the grid for exactly these runs. FlowrunIDs is required and
// non-empty (no runs, no grid — the app rejects an empty set as a 400 rather than minting a
// meaningless empty answer); dedup/cap guards are applied by the app service, not the store.
// Unknown or foreign-workspace ids are silently absent from the answer (cols carry explicit
// flowrunId keys, so absence is discoverable — unlike stats' 1:1 zero-row zip).
//
// MatrixQuery 是批查请求：恰为这些 run 的格阵。FlowrunIDs 必填且非空（无 run 即无格阵——app 对空集
// 400、而非铸一个无意义的空答案）；去重/封顶守卫由 app service 应用、非 store。未知/异 workspace 的
// id 在答案中静默缺席（cols 自带 flowrunId 键、缺席可发现——不同于 stats 的 1:1 零值行对拉）。
type MatrixQuery struct {
	FlowrunIDs []string
}

// ErrMatrixTooManyIDs: the batch asked for more than MatrixMaxFlowrunIDs runs (after dedup) —
// rejected loudly with the allowed cap in Details, never silently truncated.
// ErrMatrixTooManyIDs：批查（去重后）超过 MatrixMaxFlowrunIDs 个 run——带 allowed 上限大声拒，
// 绝不静默截断。
var ErrMatrixTooManyIDs = errorspkg.New(errorspkg.KindUnprocessable, "FLOWRUN_MATRIX_TOO_MANY_IDS", "flowrun-matrix accepts at most 50 flowrunIds per request")

// MatrixCol is one run = one grid column, newest→oldest in the canonical (started_at, id) DESC
// order every run list renders — REGARDLESS of the request's id order (an arbitrary client order
// must not change the row axis, whose first-appearance scan walks these columns). ElapsedMs is the
// RUN's wall time (completed_at−started_at), feeding the column-top duration micro-bar; a
// still-running run has no completed_at, so the key is absent (never a zero that reads as
// "instant").
//
// MatrixCol 是一个 run = 一列，按所有 run 列表同款的正典 (started_at, id) DESC 新→旧——**与请求里的
// id 顺序无关**（客户端随手打乱的顺序不许改变行轴：首次出现扫描走的正是这些列）。ElapsedMs 是 **run**
// 的墙钟时长（completed_at−started_at），喂列顶时长微条；仍在跑的 run 无 completed_at，故键缺席
// （绝不发会被读成「瞬时」的 0）。
type MatrixCol struct {
	FlowRunID string    `json:"flowrunId"`
	StartedAt time.Time `json:"startedAt"`
	Status    string    `json:"status"`
	ElapsedMs *int64    `json:"elapsedMs,omitempty"`
}

// MatrixRow is one node = one grid row. The row set is the UNION of node ids that appear in this
// batch of runs, ordered by FIRST APPEARANCE scanning the columns newest→oldest and, within a run,
// by that node's own execution order (COALESCE(started_at, ready_at, created_at) ASC, id ASC).
//
// Why first-appearance and not "the graph's topological order": each run pins its OWN version_id
// (a frozen topology), so a batch spanning versions has NO single graph to be topological about —
// resolving one would force a winner and lie about the others. First-appearance needs no graph and
// is topological anyway WHERE IT MATTERS: a run's execution order IS a topological order of that
// run's frozen graph (restricted to the nodes that ran), so the rows read as the NEWEST run's
// topology, with nodes only older runs ever had (since renamed/removed) appended below.
//
// Kind is the node kind from the row's NEWEST occurrence (same scan) — across versions a node id
// may drift kind; the newest run is the current truth. This endpoint is the only honest source for
// the row axis's kinds: no single version graph covers a multi-version batch.
//
// MatrixRow 是一个节点 = 一行。行集 = 这批 run 里出现过的 node id **并集**，按**首次出现序**排——扫列
// 新→旧、每个 run 内按该节点自身的执行序（COALESCE(started_at, ready_at, created_at) ASC, id ASC）。
//
// 为何是首次出现序而非「图的拓扑序」：每个 run 钉死**自己**的 version_id（冻结拓扑），故跨版本的一批
// **没有**单一的图可供拓扑——硬解一个就是强立赢家、对其余撒谎。首次出现序不需要图，且在**要紧处**天然
// 就是拓扑序：一个 run 的执行顺序**就是**该 run 冻结图的一个拓扑序（限于跑过的节点），故行读起来 =
// **最新** run 的拓扑，只有更老 run 才有的节点（后来改名/删除）追加在下方。
//
// Kind 取该行**最新一次出现**的节点 kind（同一次扫描）——跨版本同一 node id 可能漂移 kind，最新 run 是
// 当前真相。本端点是行轴 kind 的唯一诚实来源：跨版本的一批没有任何单一版本图覆盖得了。
type MatrixRow struct {
	NodeID string `json:"nodeId"`
	Kind   string `json:"kind"`
}

// MatrixCell is one (run, node) grid cell. SPARSE: a node a run never reached has NO cell (the
// client renders "未及" — untouched), which is why the grid is emitted as a cell list and not a
// dense rows×cols array.
//
// A node can hold MANY rows in one run (a loop's iterations). The grid has ONE cell per (run,
// node), so the iterations are aggregated:
//
//   - Status = the WORST disposition across the node's iterations (failed > parked > completed).
//     Not "the last iteration": a loop whose 3rd turn failed IS a node that failed in this run, and
//     a later green turn must not erase that (the run header is failed too — the cell agrees with
//     it). Ties within a rank go to the LATEST iteration.
//   - Iteration = the iteration of the row that WON the rank above (which turn the cell is showing).
//   - Iterations = how many rows this (run, node) has = the loop's recorded turns (≥1). The client
//     renders "×N" only when > 1, same as the run ledger's fold.
//
// No per-cell elapsedMs, deliberately: flowrun_nodes has no ended_at, so any per-node duration
// derived here would be invented. The execution segment's truth is the audit rows —
// GET /flowruns/{id}/activity (工单⑤) — and the grid's visual only needs the column-top run
// duration (MatrixCol.ElapsedMs).
//
// MatrixCell 是一个 (run, 节点) 格。**稀疏**：某 run 没跑到的节点**无格**（客户端渲「未及」）——正因如此
// 格阵以格列表下发、而非 rows×cols 稠密阵。
//
// 一个节点在一个 run 里可有**多行**（loop 的迭代）。格阵每 (run, 节点) 只有**一格**，故迭代要聚合：
//
//   - Status = 该节点各迭代中**最坏**的处置（failed > parked > completed）。**不是**「最后一轮」：第 3 轮
//     失败的 loop **就是**一个在这次 run 里失败过的节点，后来的绿轮不能抹掉它（run 头也是 failed——格与
//     它一致）。同档相持取**最新**迭代。
//   - Iteration = 上述胜出行的迭代号（这格在展示哪一轮）。
//   - Iterations = 该 (run, 节点) 有多少行 = loop 记录在案的轮数（≥1）。客户端仅在 >1 时渲「×N」，与 run
//     台账的折叠同律。
//
// **刻意无逐格 elapsedMs**：flowrun_nodes 无 ended_at，此处派生的任何单节点时长都是编的。执行段的真相在
// 审计行——GET /flowruns/{id}/activity（工单⑤）——而格阵的视觉只需列顶的 run 时长（MatrixCol.ElapsedMs）。
type MatrixCell struct {
	FlowRunID  string `json:"flowrunId"`
	NodeID     string `json:"nodeId"`
	Status     string `json:"status"`
	Iteration  int    `json:"iteration"`
	Iterations int    `json:"iterations"`
}

// Matrix is the endpoint's data payload: {cols, rows, cells}. All three are non-nil (a batch of
// entirely unknown ids returns three empty lists, never null) — the endpoint is a pure flowruns
// projection and does not check run existence, same stance as flowrun-stats toward workflow ids
// (orphan runs are first-class in the scheduler ocean).
//
// Matrix 是端点的 data 载荷：{cols, rows, cells}。三者恒非 nil（一批全未知的 id 返三个空列表、绝不
// null）——端点是纯 flowruns 投影、不校验 run 存在性，与 flowrun-stats 对 workflow id 的立场相同
// （孤儿 run 在 scheduler 海洋是一等公民）。
type Matrix struct {
	Cols  []*MatrixCol  `json:"cols"`
	Rows  []*MatrixRow  `json:"rows"`
	Cells []*MatrixCell `json:"cells"`
}
