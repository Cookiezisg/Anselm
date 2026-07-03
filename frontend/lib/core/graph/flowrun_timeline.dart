/// Another flowrun-derived pure model (sibling of GraphRunState): the node-gantt timeline. Turns a
/// flowrun's node rows into per-node bars positioned along the run's time axis — one segment per
/// executed iteration (so a loop reads as N bars + ×N), a parked bar for a waiting approval, an empty
/// stub for a graph node that never ran. Positions are fractions [0,1] of the run span; when the span
/// collapses (a sub-millisecond run — the common local-sidecar case) it falls back to sequential
/// equal slots so the sequence still reads. No widgets — headless-testable.
///
/// 又一个 flowrun 派生纯模型(GraphRunState 的姊妹):节点甘特时间轴。把 flowrun 节点行变成每节点沿
/// run 时间轴的时段条——每执行迭代一段(循环读作 N 条 + ×N)、parked 出等待条、图上没跑过的节点出
/// 空占位。位置=run 跨度的分数 [0,1];跨度塌缩(亚毫秒 run,本地 sidecar 常态)时回退等宽顺序槽。
/// 无 widget,可无头单测。
library;

import '../contract/entities/values.dart';
import '../contract/entities/workflow.dart';

/// One bar on a gantt row: [at]/[w] are fractions of the run span in [0,1]. 甘特行的一条:占跨度分数。
class GanttSegment {
  const GanttSegment(this.at, this.w);
  final double at;
  final double w;
}

/// One gantt row (a graph node). [segments] empty + not [parked] → the "未运行" stub. status is the
/// LATEST row's status (drives the bar colour). 一条甘特行(一个图节点);段空且非 parked=未运行占位。
class GanttRow {
  const GanttRow({
    required this.nodeId,
    required this.kind,
    required this.ref,
    required this.status,
    required this.segments,
    required this.parked,
    required this.iterations,
  });

  final String nodeId;
  final NodeKind kind;
  final String ref;

  /// The latest row's status (completed/failed/parked); empty when the node never ran. 最新行状态。
  final String status;
  final List<GanttSegment> segments;
  final bool parked;

  /// Executed-iteration count (rows), for the ×N badge. 执行迭代数(行数),供 ×N 徽。
  final int iterations;
}

/// Build the timeline in GRAPH declaration order (so the gantt lines up with the graph), appending
/// any orphan nodeIds present in rows but not the graph (defensive — a renamed node). Rows the graph
/// knows but that never ran render as future stubs.
/// 按图声明序建时间轴(与图对齐),再补 rows 里有而图没有的孤儿 nodeId(防御:改名节点)。图有而没跑
/// 过的节点渲成 future 占位。
List<GanttRow> flowrunTimeline(Graph g, FlowrunComposite comp) {
  final rows = comp.nodes;
  final byNode = <String, List<FlowrunNode>>{};
  for (final r in rows) {
    (byNode[r.nodeId] ??= <FlowrunNode>[]).add(r);
  }
  for (final list in byNode.values) {
    list.sort((a, b) => a.iteration.compareTo(b.iteration));
  }

  // Run span from the NODE rows themselves — NOT the run header (a header that spans 10s while every
  // node carries one coincident timestamp must still slot sequentially, not stack all bars at 0).
  // 跨度取自节点行本身,非 run 头(头跨 10s 但节点时刻全重合时,仍要顺序分槽、而非全条堆在 0)。
  DateTime? start;
  DateTime? end;
  for (final r in rows) {
    if (start == null || r.createdAt.isBefore(start)) start = r.createdAt;
    final e = r.completedAt ?? r.createdAt;
    if (end == null || e.isAfter(end)) end = e;
  }
  final spanMs = (start != null && end != null) ? end.difference(start).inMilliseconds : 0;
  final timeMode = spanMs > 0;

  // Fallback slotting: every executed segment gets a sequential slot in time order, so a zero-span
  // run still reads left→right. Ties (coincident timestamps) break by GRAPH declaration order then
  // iteration — the execution sequence, NOT alphabetical node id. 回退分槽:按时间序给顺序槽;时刻
  // 重合按**图声明序**再迭代序破平(执行序,非字母序)。
  final graphOrder = <String, int>{};
  for (var i = 0; i < g.nodes.length; i++) {
    graphOrder[g.nodes[i].id] = i;
  }
  final ordered = <FlowrunNode>[
    for (final list in byNode.values) ...list
  ]..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      if (c != 0) return c;
      final go = (graphOrder[a.nodeId] ?? 1 << 30).compareTo(graphOrder[b.nodeId] ?? 1 << 30);
      return go != 0 ? go : a.iteration.compareTo(b.iteration);
    });
  final slotOf = <String, int>{}; // "nodeId#iteration" → slot
  for (var i = 0; i < ordered.length; i++) {
    slotOf['${ordered[i].nodeId}#${ordered[i].iteration}'] = i;
  }
  final slots = ordered.isEmpty ? 1 : ordered.length;
  const minW = 0.02;

  // Keep [at]+[w] inside [0,1] with a guaranteed-visible minimum width — even a bar at the very end
  // (a just-parked node) gets room. at+w never exceeds 1. 保证条可见且不越界(末尾 parked 也留位)。
  GanttSegment place(double at, double w) {
    final a = at.clamp(0.0, 1.0 - minW);
    var width = w < minW ? minW : w;
    if (a + width > 1.0) width = 1.0 - a;
    return GanttSegment(a, width);
  }

  GanttSegment segmentOf(FlowrunNode r) {
    if (timeMode) {
      final at = r.createdAt.difference(start!).inMilliseconds / spanMs;
      final endMs = (r.completedAt ?? r.createdAt).difference(start).inMilliseconds;
      return place(at, (endMs / spanMs) - at);
    }
    final slot = slotOf['${r.nodeId}#${r.iteration}'] ?? 0;
    return place(slot / slots, 1 / slots);
  }

  GanttRow rowFor(String nodeId, NodeKind kind, String ref) {
    final list = byNode[nodeId] ?? const <FlowrunNode>[];
    final latest = list.isEmpty ? null : list.last;
    final parked = latest?.status == 'parked';
    return GanttRow(
      nodeId: nodeId,
      kind: kind,
      ref: ref,
      status: latest?.status ?? '',
      // A parked bar is positioned but not "segmented" (it's a waiting box, drawn by the widget).
      // parked 条定位但不切段(等待框由 widget 画)。
      segments: parked ? [segmentOf(latest!)] : [for (final r in list) segmentOf(r)],
      parked: parked,
      iterations: list.length,
    );
  }

  final out = <GanttRow>[];
  final seen = <String>{};
  final byId = {for (final n in g.nodes) n.id: n};
  for (final n in g.nodes) {
    out.add(rowFor(n.id, n.kind, n.ref));
    seen.add(n.id);
  }
  // Orphan rows (a nodeId in the run but not the current graph def). 孤儿行。
  for (final nodeId in byNode.keys) {
    if (seen.contains(nodeId)) continue;
    final sample = byNode[nodeId]!.first;
    out.add(rowFor(nodeId, byId[nodeId]?.kind ?? NodeKind.unknown, sample.ref));
  }
  return out;
}
