import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduler_matrix.freezed.dart';
part 'scheduler_matrix.g.dart';

// GET /flowrun-matrix (WRK-069 工单⑩) — the node×run status grid for ONE workflow's recent N runs.
// Read-only projection, bounded batch query (N4-exempt: two queries answer the whole grid). Feeds the
// operations home's third linked face, [AnRunMatrix].
//
// 节点×run 状态格阵(⑩):单 workflow 近 N 次 run 的纯读投影;有界批查(两条查询答完整个格阵),喂运营主页
// 联动格第三脸 AnRunMatrix。

/// One run = one column, newest→oldest (`started_at DESC` — the SAME order as every run list, so a
/// column and its row in the big table are the same run at the same position). [elapsedMs] is the
/// RUN's wall clock (`completed_at − started_at`) feeding the column-top duration sliver; it is
/// **ABSENT while the run is still going** (no completed_at — the backend refuses to send a 0 that
/// would read as «instant»). Judge NULL directly; never reverse-derive it from [status].
/// 一 run 一列(新→旧,与所有 run 列表同序,故列与大表里的行是同位同一个 run)。elapsedMs=**run** 的墙钟
/// 时长(喂列顶微条),**在跑时键缺席**(后端绝不发会被读成「瞬时」的 0)——直接判 null,别拿 status 反推。
@freezed
abstract class MatrixCol with _$MatrixCol {
  const factory MatrixCol({
    @Default('') String flowrunId,
    required DateTime startedAt,
    @Default('') String status,
    int? elapsedMs,
  }) = _MatrixCol;
  factory MatrixCol.fromJson(Map<String, dynamic> json) => _$MatrixColFromJson(json);
}

/// One node = one row. Row order = FIRST-APPEARANCE order (scan columns newest→oldest, each run in
/// its own execution order) — deliberately NOT graph-topological: every run pins its OWN version, so
/// a cross-version batch has no single graph to topo-sort, and picking one would lie about the rest.
/// First-appearance order IS a topological order where it matters (a run's execution order is one of
/// its frozen graph's), so rows read as the NEWEST run's topology, with nodes only older runs had
/// appended below. [kind] is taken from the node's LATEST appearance — kind can drift across
/// versions, and this endpoint is the row axis's ONLY honest kind source (do NOT look it up in a
/// workflow version graph).
/// 一节点一行;行序=首次出现序(**刻意不用图拓扑序**:每 run 钉死自己的版本,跨版本没有单一的图,硬解一个
/// 即对其余撒谎;而首次出现序在要紧处天然就是拓扑序)→ 读作最新 run 的拓扑,更老 run 独有的节点追加在后。
/// kind 取最新一次出现(跨版本会漂移;本端点是行轴 kind 的唯一诚实来源,别去版本图里查)。
@freezed
abstract class MatrixRow with _$MatrixRow {
  const factory MatrixRow({
    @Default('') String nodeId,
    @Default('') String kind,
  }) = _MatrixRow;
  factory MatrixRow.fromJson(Map<String, dynamic> json) => _$MatrixRowFromJson(json);
}

/// One (run, node) = one cell — **SPARSE**: a node a run never reached has NO cell (render 「未及」).
/// That is exactly why the grid ships as a flat cell LIST with each cell carrying its own
/// (flowrunId, nodeId) composite key, instead of a dense rows×cols matrix — never assume
/// `cells.length == cols.length * rows.length`.
///
/// Multi-iteration folding (a loop node has many rows in one run, but the grid has one cell per
/// (run,node)): [status] is the WORST disposition across iterations (`failed` > `parked` >
/// `completed`) — **not the last round**: a loop that failed on round 3 DID fail in this run, and a
/// later green round cannot erase it (the run head is failed too, so the cell agrees with it); ties
/// take the newest. [iteration] = the winning row's round; [iterations] = the row count (render
/// «×N» only when > 1, same law as the run ledger's fold).
///
/// **Deliberately no per-cell elapsedMs**: `flowrun_nodes` has no `ended_at`, so any per-node
/// duration derived here would be invented — the exec truth lives in `GET /flowruns/{id}/activity`
/// (工单⑤), and the grid only needs the column-top run duration. Never compute a duration from a cell.
///
/// 一 (run,节点) 一格,**稀疏**——没跑到即无格(渲「未及」);正因稀疏才以扁平格列表下发、每格自带复合键,
/// 而非 rows×cols 稠密阵(绝不假设 cells.length == cols×rows)。多迭代聚合:status 取各轮**最坏**处置
/// (failed>parked>completed),**不是最后一轮**——第 3 轮失败的 loop 就是在这次 run 里失败过,后来的绿轮
/// 抹不掉它(run 头也是 failed,格与它一致);同档取最新。iterations>1 才渲「×N」。**刻意无逐格 elapsedMs**
/// (节点行无 ended_at,凑出来的是谎;真相在工单⑤ activity)——绝不拿格算时长。
@freezed
abstract class MatrixCell with _$MatrixCell {
  const factory MatrixCell({
    @Default('') String flowrunId,
    @Default('') String nodeId,
    @Default('') String status,
    @Default(0) int iteration,
    @Default(1) int iterations,
  }) = _MatrixCell;
  factory MatrixCell.fromJson(Map<String, dynamic> json) => _$MatrixCellFromJson(json);
}

/// The whole grid. All three lists are always present (empty, never null) — an unknown workflowId is
/// NOT an error: it answers 200 with three empty lists (orphan runs are first-class in this ocean).
/// 整个格阵;三列表恒在(空而非 null);未知 workflowId 不是错误——200 + 三个空列表(孤儿 run 是一等公民)。
@freezed
abstract class FlowrunMatrix with _$FlowrunMatrix {
  const factory FlowrunMatrix({
    @Default(<MatrixCol>[]) List<MatrixCol> cols,
    @Default(<MatrixRow>[]) List<MatrixRow> rows,
    @Default(<MatrixCell>[]) List<MatrixCell> cells,
  }) = _FlowrunMatrix;
  factory FlowrunMatrix.fromJson(Map<String, dynamic> json) => _$FlowrunMatrixFromJson(json);
}
