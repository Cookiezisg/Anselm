/// Another flowrun-derived pure model (sibling of GraphRunState): the node-gantt timeline. Turns a
/// flowrun's node rows into per-node bars positioned along the run's time axis — one segment per
/// executed iteration (so a loop reads as N bars + ×N), a parked bar for a waiting approval, an empty
/// stub for a graph node that never ran. Positions are fractions [0,1] of the run span; when the span
/// collapses (a sub-millisecond run — the common local-sidecar case) it falls back to sequential
/// equal slots so the sequence still reads. No widgets — headless-testable.
///
/// A bar is THREE parts (WRK-069 §5 判决⑤), and each part appears ONLY when its data is really in the
/// DB — the segmentation follows data availability, it never invents a shape:
///   • QUEUE (grey)  readyAt → startedAt  — the row's queue stamps (工单⑫). Absent on pre-⑫ rows and
///     on seed trigger rows → queueW 0, the bar reads as two parts.
///   • EXEC (status) startedAt → the audit row's endedAt (工单⑤) when one exists, else the row's own
///     completedAt/createdAt. control/approval evaluate inline and leave NO audit row — that's why
///     the fallback is not a degraded path but the normal one for them.
///   • PARKED (amber) createdAt → completedAt — the HUMAN wait. createdAt is the row's write time =
///     the park moment, so this part is real for a still-parked row (→ now) AND for a settled
///     approval (→ its decision stamp), whose status has since flipped to completed.
/// With NO stamps at all (legacy rows) a bar degrades to the old createdAt→completedAt shape, and a
/// zero-span run degrades further to equal sequential slots. 三段条:排队(⑫)/执行(⑤ 或行自身)/停车
/// (人等);每段只在其数据真在库时出现——分段能力跟着数据可得性走,绝不编造。
///
/// 又一个 flowrun 派生纯模型(GraphRunState 的姊妹):节点甘特时间轴。把 flowrun 节点行变成每节点沿
/// run 时间轴的时段条——每执行迭代一段(循环读作 N 条 + ×N)、parked 出等待条、图上没跑过的节点出
/// 空占位。位置=run 跨度的分数 [0,1];跨度塌缩(亚毫秒 run,本地 sidecar 常态)时回退等宽顺序槽。
/// 无 widget,可无头单测。
library;

import '../contract/entities/values.dart';
import '../contract/entities/workflow.dart';

/// Parse a row's wire kind string (trigger|action|agent|control|approval) to [NodeKind], unknown
/// fallback. 行的线缆 kind 字串 → NodeKind。
NodeKind _kindOf(String raw) {
  for (final k in NodeKind.values) {
    if (k.name == raw) return k;
  }
  return NodeKind.unknown;
}

/// One bar on a gantt row. [at] is where the bar STARTS (its queue part, or its exec part when there
/// is no queue data); [w] is the EXEC width (the status-coloured part — the historical meaning of
/// this field, so a caller reading only at/w still reads the bar's identity). [queueW] is drawn from
/// [at], the exec then starts at `at + queueW`; [parkedW] trails the exec. All four are fractions of
/// the run span in [0,1] and `at + queueW + w + parkedW` never exceeds 1.
/// 甘特行的一条:at=条起点(有排队数据时=排队起点),w=执行宽(状态色),queueW/parkedW=前后两段;
/// 皆为跨度分数,总和不越界。
class GanttSegment {
  const GanttSegment(
    this.at,
    this.w, {
    this.queueW = 0,
    this.parkedW = 0,
    this.iteration = 0,
    this.from,
    this.to,
    this.execId,
    this.execStatus,
  });

  final double at;
  final double w;
  final double queueW;
  final double parkedW;

  /// The loop turn this bar records (0-based) — the hover/inspector coordinate. 本条的迭代轮次。
  final int iteration;

  /// Absolute bar start/end — the hover tooltip's truth (null when the row carried no usable
  /// stamps). 条的绝对起止(hover 用);行无可用戳时 null。
  final DateTime? from;
  final DateTime? to;

  /// The audit row behind the exec part, when this (node, iteration) left one (工单⑤) — the
  /// execution-log deep link. 执行段背后的审计行 id(有则可深链)。
  final String? execId;

  /// The audit vocabulary status (ok|failed|cancelled|timeout) — present only with an [execId].
  /// 审计词表状态(仅与 execId 同在)。
  final String? execStatus;

  /// The fraction where the whole bar ends. 整条终点分数。
  double get end => at + queueW + w + parkedW;
}

/// One gantt row (a graph node). [segments] empty + not [parked] + not [inferred] → the "未运行" stub.
/// status is the LATEST row's status (drives the bar colour). [inferred] marks the SPECULATIVE
/// running front (§5.5): node rows are terminal-only, so a run that is genuinely mid-flight has NO
/// row for the node currently executing — the caller derives that front from the pinned graph via
/// [GraphRunState] and the row renders «推测执行中», never a fake authority.
/// 一条甘特行(一个图节点);段空且非 parked/inferred=未运行占位;inferred=推测执行中的前沿(行只记
/// 终态,在跑节点无行)——诚实标注,绝不装权威。
class GanttRow {
  const GanttRow({
    required this.nodeId,
    required this.kind,
    required this.ref,
    required this.status,
    required this.segments,
    required this.parked,
    required this.iterations,
    this.inferred = false,
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

  final bool inferred;
}

/// The whole chart: rows + the ABSOLUTE axis they were placed on. [timeMode] false = the fallback
/// equal-slot layout, in which the fractions carry NO time meaning — a renderer must then draw no
/// ruler and no now-line (不装权威). [nowAt] is `now`'s fraction on the axis, null when the caller
/// passed no clock or `now` sits outside the span.
/// 整张图:行 + 绝对时间轴。timeMode=false 即等宽顺序槽回退(分数无时间含义,渲染方此时不得画刻度眉/
/// now 线);nowAt=now 在轴上的分数(未传钟或越界时 null)。
class GanttChart {
  const GanttChart({
    required this.rows,
    this.start,
    this.end,
    this.timeMode = false,
    this.nowAt,
  });

  final List<GanttRow> rows;
  final DateTime? start;
  final DateTime? end;
  final bool timeMode;
  final double? nowAt;

  static const GanttChart empty = GanttChart(rows: []);
}

/// Build the timeline in GRAPH declaration order (so the gantt lines up with the graph), appending
/// any orphan nodeIds present in rows but not the graph (defensive — a renamed node). Rows the graph
/// knows but that never ran render as future stubs. Back-compat face over [flowrunChart]: callers
/// that only want the bars (the linked pane, the cockpit tab, chat's flowrun card) keep this shape.
/// 按图声明序建时间轴(与图对齐),再补 rows 里有而图没有的孤儿 nodeId(防御:改名节点)。图有而没跑
/// 过的节点渲成 future 占位。[flowrunChart] 的兼容脸:只要条的调用方照旧用它。
List<GanttRow> flowrunTimeline(Graph g, FlowrunComposite comp) =>
    flowrunChart(g, comp).rows;

/// The full chart. [activity] (工单⑤) sharpens each bar's exec part to the audit row's own span and
/// carries the execId; [now] extends live parts (a still-parked wait, an [inferredRunning] front) to
/// the present and places the now-line — pass it ONLY on a live surface (a settled archive has no
/// «now»). [inferredRunning] is the speculative front, derived by the caller from the pinned graph.
/// 整张图。activity(⑤)把执行段锐化到审计行自身跨度并带出 execId;now 让活的部分(仍在等的 parked、
/// 推测前沿)延伸到当下并定位 now 线——仅活面传它;inferredRunning=调用方按钉版图推出的前沿。
GanttChart flowrunChart(
  Graph g,
  FlowrunComposite comp, {
  List<FlowrunActivityRow> activity = const [],
  DateTime? now,
  Set<String> inferredRunning = const {},
}) {
  final rows = comp.nodes;
  final byNode = <String, List<FlowrunNode>>{};
  for (final r in rows) {
    (byNode[r.nodeId] ??= <FlowrunNode>[]).add(r);
  }
  for (final list in byNode.values) {
    list.sort((a, b) => a.iteration.compareTo(b.iteration));
  }

  // The audit row for one (node, iteration) — at most one per key in practice; a :replay leaves the
  // old ATTEMPT rows behind (Log 表不删), so the LAST one wins: it is the attempt that produced the
  // surviving truth row. 审计行按 (节点,迭代) 索引;replay 后旧尝试行仍在,取最后一条(它才是产出存活
  // 真相行的那次)。
  final actByKey = <String, FlowrunActivityRow>{};
  for (final a in activity) {
    actByKey['${a.nodeId}#${a.iteration}'] = a;
  }

  // ── the axis ────────────────────────────────────────────────────────────────
  // Span from the NODE rows themselves — NOT the run header (a header that spans 10s while every
  // node carries one coincident timestamp must still slot sequentially, not stack all bars at 0).
  // A row's earliest point is its readyAt (the queue start) when 工单⑫ stamped it, else its
  // createdAt; its latest is its completedAt / the audit end / createdAt.
  // 跨度取自节点行本身,非 run 头(头跨 10s 但节点时刻全重合时,仍要顺序分槽、而非全条堆在 0)。行的
  // 最早点=readyAt(⑫ 有戳时)否则 createdAt;最晚点=completedAt/审计终点/createdAt。
  DateTime? start;
  DateTime? end;
  void mark(DateTime? t) {
    if (t == null) return;
    if (start == null || t.isBefore(start!)) start = t;
    if (end == null || t.isAfter(end!)) end = t;
  }

  for (final r in rows) {
    mark(r.readyAt);
    mark(r.startedAt);
    mark(r.createdAt);
    mark(r.completedAt);
    final a = actByKey['${r.nodeId}#${r.iteration}'];
    mark(a?.startedAt);
    mark(a?.endedAt);
  }
  // A live surface stretches the axis to the present so a still-parked wait / the speculative front
  // has somewhere to grow. A settled run never does (its axis is history).
  // 活面把轴拉到当下,让仍在等的 parked 与推测前沿有生长空间;落定 run 绝不(它的轴就是历史)。
  final live = comp.flowrun.status == 'running';
  if (now != null && live) mark(now);

  final spanMs = (start != null && end != null)
      ? end!.difference(start!).inMilliseconds
      : 0;
  final timeMode = spanMs > 0;

  // Fallback slotting: every executed segment gets a sequential slot in time order, so a zero-span
  // run still reads left→right. Ties (coincident timestamps) break by GRAPH declaration order then
  // iteration — the execution sequence, NOT alphabetical node id. 回退分槽:按时间序给顺序槽;时刻
  // 重合按**图声明序**再迭代序破平(执行序,非字母序)。
  final graphOrder = <String, int>{};
  for (var i = 0; i < g.nodes.length; i++) {
    graphOrder[g.nodes[i].id] = i;
  }
  final ordered = <FlowrunNode>[for (final list in byNode.values) ...list]
    ..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      if (c != 0) return c;
      final go = (graphOrder[a.nodeId] ?? 1 << 30).compareTo(
        graphOrder[b.nodeId] ?? 1 << 30,
      );
      return go != 0 ? go : a.iteration.compareTo(b.iteration);
    });
  final slotOf = <String, int>{}; // "nodeId#iteration" → slot
  for (var i = 0; i < ordered.length; i++) {
    slotOf['${ordered[i].nodeId}#${ordered[i].iteration}'] = i;
  }
  final slots = ordered.isEmpty ? 1 : ordered.length;
  const minW = 0.02;

  double frac(DateTime t) => t.difference(start!).inMilliseconds / spanMs;

  // Keep the whole bar inside [0,1] with a guaranteed-visible minimum width — even a bar at the very
  // end (a just-parked node) gets room. A sub-minimum bar grows its EXEC part (the bar's identity);
  // an overlong one scales all three parts together, preserving their ratio.
  // 保证整条可见且不越界(末尾 parked 也留位):过窄时长执行段(条的身份),越界时三段等比缩。
  GanttSegment place(
    double at,
    double queueW,
    double execW,
    double parkedW, {
    required int iteration,
    DateTime? from,
    DateTime? to,
    String? execId,
    String? execStatus,
  }) {
    var q = queueW.isFinite && queueW > 0 ? queueW : 0.0;
    var e = execW.isFinite && execW > 0 ? execW : 0.0;
    var p = parkedW.isFinite && parkedW > 0 ? parkedW : 0.0;
    var a = at.isFinite ? at.clamp(0.0, 1.0 - minW) : 0.0;
    var total = q + e + p;
    if (total < minW) {
      e += minW - total;
      total = minW;
    }
    if (a + total > 1.0) {
      final k = (1.0 - a) / total;
      q *= k;
      e *= k;
      p *= k;
    }
    return GanttSegment(
      a,
      e,
      queueW: q,
      parkedW: p,
      iteration: iteration,
      from: from,
      to: to,
      execId: execId,
      execStatus: execStatus,
    );
  }

  /// One (node, iteration) → its three-part bar. 一个 (节点,迭代) → 三段条。
  GanttSegment segmentOf(FlowrunNode r) {
    final a = actByKey['${r.nodeId}#${r.iteration}'];
    // A node that PARKS ends its exec at the park write (createdAt) and spends the rest of its bar
    // in the amber human wait — this holds for a settled approval too, whose status has flipped to
    // completed while createdAt still marks where the waiting began. 会停车的节点:执行段止于停车写入
    // (createdAt),其后是琥珀人等段——已决审批同样如此(status 已翻 completed,createdAt 仍是等待起点)。
    final parks = r.status == 'parked' || r.kind == NodeKind.approval.name;
    final execFrom = r.startedAt ?? r.createdAt;
    final DateTime execTo;
    if (parks) {
      execTo = r.createdAt;
    } else {
      execTo = a?.endedAt ?? r.completedAt ?? r.createdAt;
    }
    // The queue part exists only with ⑫ stamps. Clamp ≥ 0: a :replay's surviving audit row can carry
    // a readyAt older than the live truth row's (api.md ⑤). 排队段仅 ⑫ 有戳时存在;钳制 ≥0。
    final queueFrom = r.readyAt;
    final parkTo = parks
        ? (r.completedAt ?? (live ? (now ?? end) : end))
        : null;
    final barFrom = queueFrom != null && queueFrom.isBefore(execFrom)
        ? queueFrom
        : execFrom;
    final barTo = parkTo != null && parkTo.isAfter(execTo) ? parkTo : execTo;

    if (!timeMode) {
      final slot = slotOf['${r.nodeId}#${r.iteration}'] ?? 0;
      return place(
        slot / slots,
        0,
        1 / slots,
        0,
        iteration: r.iteration,
        execId: a?.execId,
        execStatus: a?.status,
      );
    }
    final at = frac(barFrom);
    final qW = queueFrom != null
        ? (frac(execFrom) - frac(queueFrom)).clamp(0.0, 1.0)
        : 0.0;
    final eW = (frac(execTo) - frac(execFrom)).clamp(0.0, 1.0);
    final pW = parkTo != null
        ? (frac(parkTo) - frac(execTo)).clamp(0.0, 1.0)
        : 0.0;
    return place(
      at,
      qW,
      eW,
      pW,
      iteration: r.iteration,
      from: barFrom,
      to: barTo,
      execId: a?.execId,
      execStatus: a?.status,
    );
  }

  GanttRow rowFor(String nodeId, NodeKind kind, String ref) {
    final list = byNode[nodeId] ?? const <FlowrunNode>[];
    final latest = list.isEmpty ? null : list.last;
    final parked = latest?.status == 'parked';
    final inferred = list.isEmpty && inferredRunning.contains(nodeId);
    // The speculative front has NO row and therefore no honest start: it is drawn from the last
    // thing we truly know happened (the axis end of the settled rows) to now. It claims a POSITION,
    // never a duration. 推测前沿无行、无诚实起点:自「已知最后发生的事」画到当下——只声称位置、绝不
    // 声称时长。
    final List<GanttSegment> segments;
    if (inferred) {
      final from = timeMode && now != null
          ? (_maxSettled(rows, actByKey) ?? start!)
          : null;
      segments = from == null
          ? const []
          : [
              place(
                frac(from),
                0,
                1.0 - frac(from),
                0,
                iteration: 0,
                from: from,
                to: now,
              ),
            ];
    } else {
      segments = [for (final r in list) segmentOf(r)];
    }
    return GanttRow(
      nodeId: nodeId,
      kind: kind,
      ref: ref,
      status: latest?.status ?? '',
      segments: segments,
      parked: parked,
      iterations: list.length,
      inferred: inferred,
    );
  }

  final out = <GanttRow>[];
  final seen = <String>{};
  for (final n in g.nodes) {
    out.add(rowFor(n.id, n.kind, n.ref));
    seen.add(n.id);
  }
  // Orphan rows (a nodeId in the run but not the CURRENT graph def — a renamed/removed node). The
  // graph can't supply its kind (it isn't there), but the ROW carries the backend-written kind, so
  // read it (this is exactly when seeing the original kind matters most). 孤儿行(改名/删除的节点):
  // 图给不了 kind,但行带后端写入的 kind——读它(恰是最需看清原 kind 的场景)。
  for (final nodeId in byNode.keys) {
    if (seen.contains(nodeId)) continue;
    final sample = byNode[nodeId]!.first;
    out.add(rowFor(nodeId, _kindOf(sample.kind), sample.ref));
  }

  return GanttChart(
    rows: out,
    start: start,
    end: end,
    timeMode: timeMode,
    nowAt:
        timeMode && now != null && !now.isBefore(start!) && !now.isAfter(end!)
        ? frac(now)
        : null,
  );
}

/// The latest moment the run PROVABLY reached (the newest settled stamp) — where a speculative
/// running bar may honestly begin. run 可证实到达的最晚时刻:推测条的诚实起点。
DateTime? _maxSettled(
  List<FlowrunNode> rows,
  Map<String, FlowrunActivityRow> actByKey,
) {
  DateTime? m;
  void bump(DateTime? t) {
    if (t == null) return;
    if (m == null || t.isAfter(m!)) m = t;
  }

  for (final r in rows) {
    bump(r.completedAt ?? r.createdAt);
    bump(actByKey['${r.nodeId}#${r.iteration}']?.endedAt);
  }
  return m;
}
