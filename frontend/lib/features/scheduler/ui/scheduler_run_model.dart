/// Pure projections for the run flagship (WRK-069 §5 S4) — widget/context-free so the SHARED TRUTHS
/// (the one error sentence, the one queue/exec split, the ledger's fold + order, the speculative
/// front) are unit-tested headless and, more importantly, are computed ONCE and projected into three
/// altitudes. §5 demands «错误摘要红句在头部,与台账失败行、甘特红条同句同源»: that is only structurally
/// true if the sentence has a single function behind it — which is [errorSentence] here.
/// run 旗舰纯投影:错误句/耗时拆分/台账折叠与排序/推测前沿,全部无 widget 可无头单测。§5 的「一份文案
/// 三处投影」只有在文案背后是同一个函数时才在结构上成立——那就是本文件。
library;

import 'dart:convert';

import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/graph/graph_run_state.dart';

/// The FIRST non-empty line of an error blob — the one red sentence the flagship head, the ledger's
/// failed row and the gantt's red bar all speak (§5.1 同句同源). Null in / all-blank in → null out
/// (an empty string would render an empty red line, which lies about there being an error).
/// 错误首句:头/台账/甘特同一句;空进空出(空串会渲出「有错误」的空红行,是撒谎)。
String? errorSentence(String? error) {
  if (error == null) return null;
  for (final line in error.split('\n')) {
    final s = line.trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// A (node, iteration)'s time split — [queue] = readyAt→startedAt (工单⑫), [exec] = the audit row's
/// own span (工单⑤) or, when the node left no audit row (control/approval evaluate inline, and a
/// parked node's exec ends at its park write), the row's own startedAt→completedAt/createdAt. Both
/// are null when the data simply isn't there — the caller then renders ONE total, never a fabricated
/// split. [parked] is the amber human wait (createdAt→completedAt), present for a settled approval
/// too.
/// 一个 (节点,迭代) 的耗时拆分:queue=⑫ 两戳、exec=⑤ 审计跨度(无审计行时回落行自身)、parked=人等段;
/// 数据不在就是 null——调用方此时只渲一个总数,绝不编造拆分。
class NodeTiming {
  const NodeTiming({this.queue, this.exec, this.parked});

  final Duration? queue;
  final Duration? exec;
  final Duration? parked;

  bool get hasSplit => queue != null || exec != null;
}

Duration? _span(DateTime? from, DateTime? to) {
  if (from == null || to == null) return null;
  final d = to.difference(from);
  // Clamp ≥ 0: a :replay's surviving audit row can carry a readyAt older than the live truth row's
  // (api.md ⑤), and clock skew is real. A negative duration is never a fact worth rendering.
  // 钳制 ≥0:replay 后旧审计行的 readyAt 可早于存活真相行;负时长绝不是值得渲的事实。
  return d.isNegative ? Duration.zero : d;
}

/// Fold one node row (+ its audit row, when the run left one) into its split. 折一行的耗时拆分。
NodeTiming nodeTiming(FlowrunNode n, {FlowrunActivityRow? activity}) {
  final parks = n.status == 'parked' || n.kind == NodeKind.approval.name;
  final execFrom = n.startedAt ?? activity?.startedAt;
  final execTo = parks
      ? n.createdAt
      : (activity?.endedAt ?? n.completedAt ?? n.createdAt);
  return NodeTiming(
    queue: _span(n.readyAt, n.startedAt),
    // Prefer the audit row's own elapsed (工单⑤ 真时长) — it is the execution's measurement, not our
    // subtraction of two engine stamps. 优先审计行自报耗时(⑤ 真时长):那是执行自己的测量,不是我们
    // 拿两个引擎戳相减。
    exec: activity != null
        ? Duration(milliseconds: activity.elapsedMs)
        : _span(execFrom, execTo),
    parked: parks ? _span(n.createdAt, n.completedAt) : null,
  );
}

/// The RUN's split — the sum of its rows' splits, so the flagship head and the ledger rows can never
/// disagree (§5.3 头/台账双数同源: the head is literally the ledger's total). Parallel branches make
/// the sums exceed wall-clock — that is the honest reading of «how much time was spent queued vs
/// executing», and the head shows the wall-clock total beside it regardless.
/// run 的拆分=各行拆分之和(头与台账双数同源:头就是台账的合计)。并行分支会让和超过墙钟——那正是
/// 「排队了多久 / 执行了多久」的诚实读法;墙钟总时长在头上另有其位。
NodeTiming runTiming(
  List<FlowrunNode> nodes,
  List<FlowrunActivityRow> activity,
) {
  final byKey = {for (final a in activity) '${a.nodeId}#${a.iteration}': a};
  Duration? queue, exec, parked;
  for (final n in nodes) {
    final t = nodeTiming(n, activity: byKey['${n.nodeId}#${n.iteration}']);
    if (t.queue != null) queue = (queue ?? Duration.zero) + t.queue!;
    if (t.exec != null) exec = (exec ?? Duration.zero) + t.exec!;
    if (t.parked != null) parked = (parked ?? Duration.zero) + t.parked!;
  }
  return NodeTiming(queue: queue, exec: exec, parked: parked);
}

/// One ledger entry = one nodeId, with every iteration it ran folded in (§5.4 循环同节点折叠 ×N 一行
/// 计数展开). [latest] is the newest iteration's row (drives the status + the error line); [rows] is
/// every iteration ascending. [inferred] entries have NO rows at all — they are the speculative
/// front, kept in the ledger so a mid-flight run never shows an empty table.
/// 一条台账 = 一个 nodeId,循环各迭代折进来(×N 一行);latest=最新迭代行;inferred=无行的推测前沿
/// (留在台账里,让在跑 run 绝不空表)。
class NodeLedgerEntry {
  const NodeLedgerEntry({
    required this.nodeId,
    required this.rows,
    this.latest,
    this.inferred = false,
  });

  final String nodeId;
  final List<FlowrunNode> rows;
  final FlowrunNode? latest;
  final bool inferred;

  int get iterations => rows.length;
  String get status => inferred ? 'running' : (latest?.status ?? '');
  bool get failed => latest?.status == 'failed';
  bool get parked => latest?.status == 'parked';
}

/// Rank: failed (0) → parked (1) → the speculative front (2) → everything else (3). §5.4 pins
/// «失败/parked 稳定置顶» — the diagnostic rows you came for sit on the first screen; the live front
/// follows them (it is where the run IS, but it is not a problem).
/// 排序:失败→parked→推测前沿→其余。失败/parked 稳定置顶(你就是为它们来的);活前沿紧随其后
/// (它是 run 的现场,但它不是问题)。
int _rank(NodeLedgerEntry e) {
  if (e.failed) return 0;
  if (e.parked) return 1;
  if (e.inferred) return 2;
  return 3;
}

/// Build the flagship's node ledger: fold iterations per node, order by GRAPH declaration (the
/// execution reading order) then stable-sort the diagnostic ranks to the top, and splice in the
/// speculative front. Orphan nodeIds (a renamed/removed node still present in the run) keep their
/// place at the end — the row is the truth, the graph is only today's map.
/// 建台账:逐节点折迭代 → 按图声明序(执行阅读序)→ 稳定排序把诊断行置顶 → 接入推测前沿。孤儿 nodeId
/// (改名/删除但 run 里still在)留在末尾——行是真相,图只是当下的地图。
List<NodeLedgerEntry> foldNodeLedger(
  Graph graph,
  List<FlowrunNode> nodes, {
  Set<String> inferredRunning = const {},
}) {
  final byNode = <String, List<FlowrunNode>>{};
  for (final n in nodes) {
    (byNode[n.nodeId] ??= <FlowrunNode>[]).add(n);
  }
  for (final list in byNode.values) {
    list.sort((a, b) => a.iteration.compareTo(b.iteration));
  }

  final order = <String>[];
  final seen = <String>{};
  for (final n in graph.nodes) {
    order.add(n.id);
    seen.add(n.id);
  }
  for (final id in byNode.keys) {
    if (seen.add(id)) order.add(id);
  }

  final entries = <NodeLedgerEntry>[];
  for (final id in order) {
    final rows = byNode[id] ?? const <FlowrunNode>[];
    final inferred = rows.isEmpty && inferredRunning.contains(id);
    // A graph node with no rows and no live front never ran — it belongs on the gantt as a stub, not
    // in the ledger (the ledger records what HAPPENED). 无行也无活前沿的图节点=从没跑过:它属于甘特的
    // 占位,不属于台账(台账记的是发生过的事)。
    if (rows.isEmpty && !inferred) continue;
    entries.add(
      NodeLedgerEntry(
        nodeId: id,
        rows: rows,
        latest: rows.isEmpty ? null : rows.last,
        inferred: inferred,
      ),
    );
  }

  // Stable: Dart's sort is not, so pair with the graph-order index. 稳定排序(Dart sort 不稳定)。
  final indexed = [for (final (i, e) in entries.indexed) (i, e)]
    ..sort((a, b) {
      final r = _rank(a.$2).compareTo(_rank(b.$2));
      return r != 0 ? r : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// The SPECULATIVE running front (§5.5 冷打开推测态) — node rows are terminal-only, so a run that is
/// genuinely mid-flight has no row for what is executing right now. Deep-linking into such a run (or
/// reopening the app) would otherwise show a blank «nothing is happening». [GraphRunState] already
/// synthesizes exactly this from the pinned graph + the settled rows, and only while the run header
/// says running — so the front is a REUSE, not a second guess. Empty for any settled run.
/// 推测执行中的前沿:行只记终态,真在跑的节点没有行——深链/重启进去否则一片空白。GraphRunState 已从
/// 钉版图+已落定行合成出它(且仅在 run 头 running 时),故这是复用而非二次猜测;落定 run 恒空。
Set<String> inferredRunningNodes(Graph graph, FlowrunComposite comp) {
  if (comp.flowrun.status != 'running') return const {};
  final st = deriveRunState(
    graph,
    rows: comp.nodes,
    runStatus: comp.flowrun.status,
  );
  return {
    for (final e in st.nodes.entries)
      if (e.value == GraphNodeRun.running) e.key,
  };
}

/// Parse a workflow version's graph — graphParsed (attached by the backend on read) beats the raw
/// blob; an unparseable blob is null so the caller renders the honest «no graph» sentence instead of
/// an empty canvas that looks like an empty workflow.
/// 解版本图:graphParsed 优先,坏 blob 归 null(调用方渲诚实句,而非看起来像「空工作流」的空画布)。
Graph? graphOfVersion(WorkflowVersion? v) {
  if (v == null) return null;
  if (v.graphParsed != null) return v.graphParsed;
  if (v.graph.trim().isEmpty) return const Graph();
  try {
    return Graph.fromJson(jsonDecode(v.graph) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}
