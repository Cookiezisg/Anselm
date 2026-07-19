import 'package:flutter/widgets.dart';

import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/model/partial_json.dart';
import '../../model/stage_director.dart';
import '../../model/tool_card_state.dart';

/// Everything a KIND STAGE body renders from — assembled once per frame by the stage host (the brow,
/// ribbon and pin gesture stay in the host; the body swaps per kind, WRK-061 §7). Pure carrier.
///
/// kind 舞台体的全部渲染输入——宿主每帧装配一次(眉/丝带/占用手势留宿主;体按 kind 换)。纯载体。
class StageScene {
  const StageScene({
    required this.conversationId,
    required this.subject,
    required this.phase,
    required this.node,
    required this.state,
    required this.session,
  });

  final String conversationId;
  final StageActivityView subject;
  final StagePhase phase;
  final BlockNode node;
  final ToolCardState state;
  final PartialJsonSession session;

  bool get live => node.isOpen;
  bool get failed => phase == StagePhase.failedHold;

  /// The EDIT target id once the args stream resolved it (edit_* first key), null for creates.
  /// edit 目标 id(args 首键解出),create 为 null。
  String? get editTargetId {
    final key = switch (subject.toolName) {
      'edit_function' => 'functionId',
      'edit_handler' => 'handlerId',
      'edit_agent' => 'agentId',
      'edit_workflow' => 'workflowId',
      'edit_trigger' => 'triggerId',
      'edit_control' => 'controlId',
      'edit_approval' => 'approvalId',
      'edit_document' => 'id',
      'edit_skill' => 'name',
      _ => null,
    };
    if (key == null) return null;
    final v = session.closedStringAt([key]);
    return (v == null || v.isEmpty) ? null : v;
  }
}

/// A kind stage's body builder. 舞台体构建器。
typedef StageBodyBuilder = Widget Function(BuildContext context, StageScene scene);
