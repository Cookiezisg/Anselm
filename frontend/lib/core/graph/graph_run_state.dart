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
/// itself is running AND nothing is parked (a parked run waits on a human, nothing advances).
/// 派生覆层。rows 任意序(REST + tick 合并后);仅 run 头 running 且无 parked 时做 running 合成。
GraphRunState deriveRunState(Graph g, {required List<FlowrunNode> rows, required String runStatus}) {
  if (rows.isEmpty) return GraphRunState.empty;

  // Latest row per node = the highest iteration (terminal rows only, one per (node, iteration)).
  // 每节点取最高迭代的行(行只有终态,(node,iteration) 唯一)。
  final latest = <String, FlowrunNode>{};
  for (final r in rows) {
    final cur = latest[r.nodeId];
    if (cur == null || r.iteration > cur.iteration) latest[r.nodeId] = r;
  }

  final nodes = <String, GraphNodeRun>{};
  final iters = <String, int>{};
  var parked = false;
  for (final e in latest.entries) {
    final s = switch (e.value.status) {
      'failed' => GraphNodeRun.failed,
      'parked' => GraphNodeRun.parked,
      _ => GraphNodeRun.completed,
    };
    if (s == GraphNodeRun.parked) parked = true;
    nodes[e.key] = s;
    iters[e.key] = e.value.iteration + 1;
  }

  final byId = {for (final n in g.nodes) n.id: n};
  final back = backEdgeIds(g);

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
    final chosen = kind == NodeKind.control ? result['__port'] : result['decision'];
    return chosen == port;
  }

  FlowrunNode? rowAt(String nodeId, int iteration) {
    for (final r in rows) {
      if (r.nodeId == nodeId && r.iteration == iteration) return r;
    }
    return null;
  }

  final taken = <String>{};
  final live = <String>{};
  final synthesize = runStatus == 'running' && !parked;

  for (final e in g.edges) {
    if (!byId.containsKey(e.from) || !byId.containsKey(e.to)) continue;
    final isBack = back.contains(e.id);
    // Walk every completed iteration of the source: the edge is taken if its port matched and the
    // target ran the DUE iteration (forward keeps i, a back edge starts i+1). 逐迭代看:口匹配且
    // 目标跑了应跑迭代(前向同 i、回边 i+1)即 taken。
    for (final r in rows) {
      if (r.nodeId != e.from || r.status != 'completed') continue;
      if (!portMatches(r, e)) continue;
      final due = isBack ? r.iteration + 1 : r.iteration;
      if (rowAt(e.to, due) != null) {
        taken.add(e.id);
      } else if (synthesize && due > (latest[e.to] == null ? -1 : latest[e.to]!.iteration)) {
        // The due iteration hasn't landed and nothing newer has — the walk is presumably here.
        // 应跑迭代未落行且无更新行——推测走到这里。
        nodes[e.to] = GraphNodeRun.running;
        iters[e.to] = due + 1;
        live.add(e.id);
      }
    }
  }

  return GraphRunState(nodes: nodes, iters: iters, takenEdges: taken, liveEdges: live);
}
