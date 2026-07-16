// Run matrix (scheduler 工单⑩) — a PURE READ PROJECTION over the two existing flowrun tables
// (no new table, no new column) shaped for the scheduler ocean's node×run grid (S5 AnRunMatrix).
// ONE bounded batch answers the whole grid: two queries total (the recent runs, then every node
// row of those runs in a single flowrun_id IN (…)), never a per-run detail fetch (N+1).
//
// run 矩阵（scheduler 工单⑩）——flowrun 两张既有表上的**纯读投影**（零新表零新列），形状对准 scheduler
// 海洋的 节点×run 格阵（S5 AnRunMatrix）。一次有界批查答完整个格阵：总共两条查询（近 N run，再一条
// flowrun_id IN (…) 取这批 run 的全部节点行），绝不逐 run 拉详情（N+1）。
package flowrun

import "time"

// Matrix bounds. The window is the spec's SchedulerWindows constant (矩阵=近 20); default == max
// because the client renders a fixed-width grid — a narrower viewport may ask for fewer, nothing
// ever needs more. RecentN follows the flowrun-stats sibling parameter VERBATIM (≤0 → default,
// > max → clamp, non-numeric/<1 → 400 at the handler): a window is a VIEW, and clamping it renders
// 20 columns instead of 25 — a visual downgrade, not a lie. (Contrast StatsMaxWorkflowIDs, which
// rejects loudly: silently truncating requested ids WOULD lie — the client zips request→response
// 1:1 and would read a short answer as complete.)
//
// 矩阵边界。窗口 = 规范 SchedulerWindows 常量（矩阵=近 20）；default == max 因为客户端渲染定宽格阵——
// 窄视口可要更少，但没有任何东西需要更多。RecentN **逐字**沿用 flowrun-stats 的同名兄弟参数（≤0 取默认、
// >上限钳制、非数字/<1 由 handler 400）：窗口是**视图**，钳制它只是渲 20 列而非 25——视觉降级、不是撒谎。
// （对比 StatsMaxWorkflowIDs 大声拒：静默截断请求 id **会**撒谎——客户端请求↔响应 1:1 对拉，会把短答案
// 读成完整。）
const (
	MatrixDefaultRecentN = 20
	MatrixMaxRecentN     = 20
)

// MatrixQuery is the batch request: one workflow's last RecentN runs. WorkflowID is required
// (it IS the grid's axis); defaults/guards are applied by the app service, not the store.
//
// MatrixQuery 是批查请求：一个 workflow 的近 RecentN 个 run。WorkflowID 必填（它**就是**格阵的轴）；
// 默认与守卫由 app service 应用、非 store。
type MatrixQuery struct {
	WorkflowID string
	RecentN    int
}

// MatrixCol is one run = one grid column, newest→oldest. ElapsedMs is the RUN's wall time
// (completed_at−started_at), feeding the column-top duration micro-bar; a still-running run has
// no completed_at, so the key is absent (never a zero that reads as "instant").
//
// MatrixCol 是一个 run = 一列，新→旧。ElapsedMs 是 **run** 的墙钟时长（completed_at−started_at），
// 喂列顶时长微条；仍在跑的 run 无 completed_at，故键缺席（绝不发会被读成「瞬时」的 0）。
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

// Matrix is the endpoint's data payload: {cols, rows, cells}. All three are non-nil (an unknown /
// never-ran workflow returns three empty lists, never null) — the endpoint is a pure flowruns
// projection and does not check workflow existence, same stance as flowrun-stats (orphan runs are
// first-class in the scheduler ocean).
//
// Matrix 是端点的 data 载荷：{cols, rows, cells}。三者恒非 nil（未知/从未跑的 workflow 返三个空列表、
// 绝不 null）——端点是纯 flowruns 投影、不校验 workflow 存在性，与 flowrun-stats 同立场（孤儿 run 在
// scheduler 海洋是一等公民）。
type Matrix struct {
	Cols  []*MatrixCol  `json:"cols"`
	Rows  []*MatrixRow  `json:"rows"`
	Cells []*MatrixCell `json:"cells"`
}
