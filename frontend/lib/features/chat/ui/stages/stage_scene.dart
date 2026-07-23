import 'package:flutter/widgets.dart';

import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/model/partial_json.dart';
import '../../model/stage_director.dart';
import '../../model/tool_card_state.dart';
import '../tool_card_skins.dart' show toolLive;

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

  /// The ONE liveness truth for every stage body (G4/A1-4): a tool_call closes when its ARGUMENT
  /// stream ends — the real execution is bracketed by the tool_result child, and [ToolCardPhase]
  /// already encodes that. `node.isOpen` here made cards flip to their ✓ settled face seconds into
  /// a minutes-long run. 全舞台体唯一判活(G4):参流关≠执行终态,真终态=tool_result close——
  /// ToolCardPhase 早已编码;旧 node.isOpen 让卡在长跑刚开几秒就换 ✓ 落定脸。
  bool get live => toolLive(state);
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
typedef StageBodyBuilder =
    Widget Function(BuildContext context, StageScene scene);
