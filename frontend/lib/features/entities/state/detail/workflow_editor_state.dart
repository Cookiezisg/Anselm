import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/graph/graph_model.dart';

part 'workflow_editor_state.freezed.dart';

/// The graph-editor working state (WRK-055 W5). [original] is the loaded active-version graph;
/// [working] is the locally-edited copy. All edits mutate [working] only; save diffs the two into
/// one `:edit` ops array (one version). [dirty] gates the save/discard affordances; selection drives
/// the inspector. [saveError] holds a WORKFLOW_INVALID_GRAPH/INVALID_OPS reason (surfaced, working
/// kept for the user to fix).
///
/// 图编辑器工作态(W5)。original=加载的活跃版本图;working=本地编辑副本。所有编辑只改 working;保存时
/// diff 两者成一个 `:edit` ops 数组(一版)。dirty 门控保存/放弃;选区驱动检查器;saveError 存
/// WORKFLOW_INVALID_GRAPH/INVALID_OPS 理由(呈现,working 保留供修)。
@freezed
abstract class WorkflowEditorState with _$WorkflowEditorState {
  const factory WorkflowEditorState({
    required Graph original,
    required Graph working,
    @Default(GraphDirection.lr) GraphDirection dir,
    String? selectedNodeId,
    String? selectedEdgeId,
    @Default(false) bool saving,
    String? saveError,
  }) = _WorkflowEditorState;

  const WorkflowEditorState._();

  bool get dirty => original != working;

  Node? get selectedNode {
    final id = selectedNodeId;
    if (id == null) return null;
    for (final n in working.nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Edge? get selectedEdge {
    final id = selectedEdgeId;
    if (id == null) return null;
    for (final e in working.edges) {
      if (e.id == id) return e;
    }
    return null;
  }
}
