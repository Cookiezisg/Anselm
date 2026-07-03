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
    FlowrunComposite? selected, // the full composite of [selectedRunId] 选中 run 的完整 composite
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
}
