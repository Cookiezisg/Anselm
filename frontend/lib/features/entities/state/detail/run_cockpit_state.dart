import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/contract/entities/workflow.dart';

part 'run_cockpit_state.freezed.dart';

/// The workflow 运行 tab (cockpit) state: the flowrun history list (paged) + the SELECTED run's full
/// node composite (paged through — a page is newest-first, one page ≠ the whole run) + the selected
/// node (drives the inline node-debug + graph/gantt highlight). The graph itself is NOT here (it
/// comes from the detail provider's active version); the tab derives gantt + run-overlay from it.
///
/// workflow 运行 tab(驾驶舱)态:flowrun 历史列表(分页)+ 选中 run 的完整节点 composite(翻页拉全——
/// 页最新在前、一页非全量)+ 选中节点(驱动内联节点调试 + 图/甘特高亮)。图不在此(取自详情 provider
/// 的活跃版本);tab 据它派生甘特 + 运行覆层。
@freezed
abstract class RunCockpitState with _$RunCockpitState {
  const factory RunCockpitState({
    @Default(<Flowrun>[]) List<Flowrun> runs,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
    String? selectedRunId,
    FlowrunComposite?
    selected, // the full composite of [selectedRunId] 选中 run 的完整 composite
    @Default(<FlowrunActivityRow>[])
    List<FlowrunActivityRow> activity, // execution audit rows 执行审计行
    @Default(false) bool loadingRun,
    String? selectedNodeId,
    @Default(false) bool busy, // replay / kill / decide in flight 动作在途
  }) = _RunCockpitState;

  const RunCockpitState._();

  Flowrun? get selectedRun {
    for (final r in runs) {
      if (r.id == selectedRunId) return r;
    }
    return null;
  }

  /// The selected node's LATEST row (highest iteration) — the node-debug subject. 选中节点最新行。
  FlowrunNode? get selectedNode {
    final id = selectedNodeId;
    final comp = selected;
    if (id == null || comp == null) return null;
    FlowrunNode? best;
    for (final n in comp.nodes) {
      if (n.nodeId != id) continue;
      if (best == null || n.iteration > best.iteration) best = n;
    }
    return best;
  }

  /// The latest execution audit for a node. Replay can leave more than one audit row for the same
  /// node/iteration, so choose by the execution's own start time rather than relying on wire order.
  /// 一个节点最新的执行审计。replay 可能留下同一节点/轮次的多条审计，按执行自身开始时间取最新，不依赖线缆顺序。
  FlowrunActivityRow? activityFor(FlowrunNode node) {
    FlowrunActivityRow? latest;
    for (final row in activity) {
      if (row.nodeId != node.nodeId || row.iteration != node.iteration) {
        continue;
      }
      if (latest == null || row.startedAt.isAfter(latest.startedAt)) {
        latest = row;
      }
    }
    return latest;
  }

  /// Sum the execution audit durations. Parallel branches may make this exceed wall-clock lifetime;
  /// that is intentional: it answers work spent executing, while the lifetime field answers elapsed
  /// run existence. If no audit row exists, fall back to measurable node spans without inventing zero.
  /// 汇总执行审计耗时。并行分支的和可能超过墙钟周期，这是刻意的：它回答执行工作量，生命周期字段回答 run 存在多久。
  /// 没有审计行时回落到可测节点跨度，不凭空制造 0。
  Duration? get executionDuration {
    if (activity.isNotEmpty) {
      var milliseconds = 0;
      for (final row in activity) {
        milliseconds += row.elapsedMs < 0 ? 0 : row.elapsedMs;
      }
      return Duration(milliseconds: milliseconds);
    }
    var measured = false;
    var milliseconds = 0;
    for (final node in selected?.nodes ?? const <FlowrunNode>[]) {
      final start = node.startedAt;
      final end = node.completedAt;
      if (start == null || end == null) continue;
      measured = true;
      final span = end.difference(start);
      milliseconds += span.isNegative ? 0 : span.inMilliseconds;
    }
    return measured ? Duration(milliseconds: milliseconds) : null;
  }

  /// The node's own execution duration, preferring the audit measurement and falling back to the
  /// node's engine stamps only when that audit row is unavailable.
  /// 节点自身执行耗时：优先审计测量，只有没有审计行时才用引擎戳回落。
  Duration? executionDurationFor(FlowrunNode node) {
    final audit = activityFor(node);
    if (audit != null) {
      return Duration(milliseconds: audit.elapsedMs < 0 ? 0 : audit.elapsedMs);
    }
    final start = node.startedAt;
    final end = node.completedAt;
    if (start == null || end == null) return null;
    final span = end.difference(start);
    return span.isNegative ? Duration.zero : span;
  }
}
