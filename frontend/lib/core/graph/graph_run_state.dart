/// The run-plane companion of GraphModel: a pure derivation from flowrun node rows (the DB truth,
/// merged with SSE tick upserts by the caller) to per-node visual states + walked/live edges. The
/// wire has NO running state (rows are terminal-only: completed/failed/parked; ticks likewise), so
/// "running" is SYNTHESIZED here — a completed node's due successor with no row yet — and clearly
/// scoped as speculative rendering (WRK-055). Iteration-exact: a back edge from iteration i targets
/// iteration i+1, so loop re-runs light correctly instead of reading as already-done.
///
/// GraphModel 的运行面伴侣:flowrun 节点行(DB 真相,调用方已合并 tick upsert)→ 每节点视觉态 +
/// 已走/活跃边的纯派生。线缆无 running 态(行只有三终态,tick 同),「正在跑」在此**合成**——已完成
/// 节点的应跑后继且尚无行——属推测渲染(WRK-055)。迭代精确:回边从 i 指向 i+1,循环重跑正确点亮。
library;

import '../contract/entities/values.dart';
import '../contract/entities/workflow.dart';
import 'graph_model.dart';

/// A node's visual run state. Nodes absent from [GraphRunState.nodes] read as future (not walked).
/// 节点视觉运行态;不在 map 里 = future(未走到)。
enum GraphNodeRun { completed, running, failed, parked, future }

/// The derived run overlay a canvas paints over the definition graph. 画布铺在定义图上的运行覆层。
class GraphRunState {
  const GraphRunState({
    this.nodes = const {},
    this.iters = const {},
    this.takenEdges = const {},
    this.liveEdges = const {},
  });

  final Map<String, GraphNodeRun> nodes;

  /// Executed iteration count per node (1-based; render ×N when > 1). 每节点已执行迭代数(>1 渲 ×N)。
  final Map<String, int> iters;

  /// Edges the walk actually traversed (iteration-matched). 真走过的边(迭代匹配)。
  final Set<String> takenEdges;

  /// Edges into synthesized-running nodes (the comet). 指向合成 running 节点的边(彗星)。
  final Set<String> liveEdges;

  static const GraphRunState empty = GraphRunState();
}

/// Derive the overlay. [rows] = flowrun node rows (any order; the caller merges REST rows + tick
/// upserts). [runStatus] = the flowrun header status — running synthesis only happens while the run
/// itself is running. A parked node blocks only its OWN downstream (it produces no completed row);
/// parallel branches keep advancing — exactly the backend walk (a parked run's header stays
/// running and other ready nodes still dispatch).
/// 派生覆层。rows 任意序(REST + tick 合并后);仅 run 头 running 时做 running 合成。parked 只挡
/// **自身下游**(它不产完成行)——并行分支照常推进,与后端 walk 一致(parked run 头仍 running、
/// 其余 ready 节点照常派发)。
GraphRunState deriveRunState(
  Graph g, {
  required List<FlowrunNode> rows,
  required String runStatus,
}) {
  if (rows.isEmpty) return GraphRunState.empty;

  // Index once: rows by (node, iteration) — O(1) lookups keep the whole derivation linear-ish
  // (it runs on the build path; a long loop run carries hundreds of rows). 一次建索引:(node,迭代)
  // → 行,O(1) 查询让派生近线性(它在 build 路径上,长循环 run 有数百行)。
  final byNodeIter = <String, Map<int, FlowrunNode>>{};
  final latest = <String, FlowrunNode>{};
  for (final r in rows) {
    (byNodeIter[r.nodeId] ??= <int, FlowrunNode>{})[r.iteration] = r;
    final cur = latest[r.nodeId];
    if (cur == null || r.iteration > cur.iteration) latest[r.nodeId] = r;
  }
  FlowrunNode? rowAt(String nodeId, int iteration) =>
      byNodeIter[nodeId]?[iteration];

  final nodes = <String, GraphNodeRun>{};
  final iters = <String, int>{};
  for (final e in latest.entries) {
    nodes[e.key] = switch (e.value.status) {
      'failed' => GraphNodeRun.failed,
      'parked' => GraphNodeRun.parked,
      _ => GraphNodeRun.completed,
    };
    // ×N = EXECUTED count = the number of rows, NOT max-iteration+1: a loop-exit successor first
    // runs at the loop's final iteration (forward edges KEEP the source iteration in the backend
    // walk), so its single row may carry iteration 3 while it ran exactly once.
    // ×N=执行次数=行数、非最高迭代+1:循环出口后继首次执行就落在循环末迭代(后端前向边保持源
    // 迭代),单行 iteration 可能是 3 而它只跑过一次。
    iters[e.key] = byNodeIter[e.key]!.length;
  }

  final byId = {for (final n in g.nodes) n.id: n};
  final back = backEdgeIds(g);
  final inEdges = <String, List<Edge>>{};
  for (final e in g.edges) {
    if (byId.containsKey(e.from) && byId.containsKey(e.to)) {
      (inEdges[e.to] ??= <Edge>[]).add(e);
    }
  }

  // Did node [from]'s row at [iteration] choose [port]? Control rows carry the reserved __port key,
  // approval rows carry decision; ticks have no result, so a port edge resolves only after the REST
  // reconcile (honest lag, not a guess). 该迭代的行选了这个口吗?control 走 __port、approval 走
  // decision;tick 无 result——端口边要等 REST 对账才亮(诚实滞后、不瞎猜)。
  bool portMatches(FlowrunNode row, Edge e) {
    final kind = byId[e.from]?.kind;
    if (kind != NodeKind.control && kind != NodeKind.approval) return true;
    final port = (e.fromPort ?? '');
    if (port.isEmpty) return false;
    final result = row.result;
    final chosen = kind == NodeKind.control
        ? result['__port']
        : result['decision'];
    return chosen == port;
  }

  final taken = <String>{};
  final synthesize = runStatus == 'running';
  // Pass 1: taken edges + single-edge running candidates (edge, target, due iteration).
  // 第一趟:taken 边 + 单边视角的 running 候选(边,目标,应跑迭代)。
  final candidates = <(Edge, String, int)>[];
  for (final e in g.edges) {
    if (!byId.containsKey(e.from) || !byId.containsKey(e.to)) continue;
    final isBack = back.contains(e.id);
    final srcRows = byNodeIter[e.from];
    if (srcRows == null) continue;
    for (final r in srcRows.values) {
      if (r.status != 'completed' || !portMatches(r, e)) continue;
      final due = isBack ? r.iteration + 1 : r.iteration;
      if (rowAt(e.to, due) != null) {
        taken.add(e.id);
      } else if (synthesize && due > (latest[e.to]?.iteration ?? -1)) {
        candidates.add((e, e.to, due));
      }
    }
  }

  // Pass 2: AND-join filter — the backend dispatches a node only when EVERY live in-edge's source
  // has completed (predecessorsSatisfied). An in-edge feeding [due] blocks when its source is
  // reached-but-not-completed at the feeding iteration (a terminal non-completed row, or itself a
  // running candidate); an unreached/pruned in-edge is not live and is ignored.
  // 第二趟:AND-join 过滤——后端只在全部 live 入边源完成时才派发。喂 due 的入边:源在喂给迭代
  // 上「已达未完」(有非完成终态行,或它自己就是 running 候选)即阻塞;未达/被剪的入边非 live、忽略。
  final candidateAt = <String, Set<int>>{};
  for (final (_, target, due) in candidates) {
    (candidateAt[target] ??= <int>{}).add(due);
  }
  final live = <String>{};
  for (final (e, target, due) in candidates) {
    var blocked = false;
    for (final e2 in inEdges[target] ?? const <Edge>[]) {
      if (e2.id == e.id) continue;
      final feed = back.contains(e2.id) ? due - 1 : due;
      if (feed < 0) continue;
      final srcRow = rowAt(e2.from, feed);
      if (srcRow != null) {
        if (srcRow.status == 'completed') {
          continue; // satisfied or pruned-by-port 已满足/被口剪
        }
        blocked = true; // failed/parked predecessor — the join waits 未完前驱,汇聚等待
        break;
      }
      if (candidateAt[e2.from]?.contains(feed) ?? false) {
        blocked = true; // the predecessor itself is presumably running 前驱自己还在跑
        break;
      }
      // No row, not running → unreached at this iteration (e.g. a pruned branch): not live. 未达非 live。
    }
    if (blocked) continue;
    nodes[target] = GraphNodeRun.running;
    iters[target] =
        (byNodeIter[target]?.length ?? 0) +
        1; // the in-flight pass counts 在途这趟计入
    live.add(e.id);
  }

  return GraphRunState(
    nodes: nodes,
    iters: iters,
    takenEdges: taken,
    liveEdges: live,
  );
}
