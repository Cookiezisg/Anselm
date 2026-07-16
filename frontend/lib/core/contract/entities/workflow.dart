import 'package:freezed_annotation/freezed_annotation.dart';

import 'values.dart'; // Graph

part 'workflow.freezed.dart';
part 'workflow.g.dart';

/// Workflow entity (Quadrinity :trigger kind). lifecycleState ∈ active/draining/inactive; concurrency ∈
/// serial/skip/buffer_one/replace/allow_all (open Strings). needsAttention is scheduler self-heal
/// semantics. workflow.go:42。
@freezed
abstract class WorkflowEntity with _$WorkflowEntity {
  const factory WorkflowEntity({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default(false) bool active,
    @Default('') String lifecycleState,
    @Default('serial') String concurrency,
    @Default(false) bool needsAttention,
    String? attentionReason,
    @Default('') String lastActionBy,
    @Default('') String activeVersionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    WorkflowVersion? activeVersion,
  }) = _WorkflowEntity;
  factory WorkflowEntity.fromJson(Map<String, dynamic> json) => _$WorkflowEntityFromJson(json);
}

/// Workflow version (append-only). `graph` is the raw JSON blob (source of truth); `graphParsed` is the
/// decoded [Graph] attached on read. workflow.go:72。
@freezed
abstract class WorkflowVersion with _$WorkflowVersion {
  const factory WorkflowVersion({
    required String id,
    required String workflowId,
    required int version,
    @Default('') String graph,
    String? changeReason,
    String? builtInConversationId,
    required DateTime createdAt,
    required DateTime updatedAt,
    Graph? graphParsed,
  }) = _WorkflowVersion;
  factory WorkflowVersion.fromJson(Map<String, dynamic> json) => _$WorkflowVersionFromJson(json);
}

/// One workflow run (the 日志 tab for workflow = flowruns, NOT executions/calls). flowrun.go:113。
/// [origin]/[conversationId] are creation-time provenance (scheduler 工单①): origin ∈ manual/chat/
/// cron/webhook/fsnotify/sensor, omitted (null) on pre-provenance rows — render "unknown", never a
/// zero-value lie; conversationId rides only origin=chat. 溯源两键 omitempty,旧行 null→前端 unknown。
@freezed
abstract class Flowrun with _$Flowrun {
  const factory Flowrun({
    required String id,
    required String workflowId,
    @Default('') String versionId,
    @Default(<String, String>{}) Map<String, String> pinnedRefs,
    String? triggerId,
    String? firingId,
    String? origin,
    String? conversationId,
    @Default('') String status,
    @Default(0) int replayCount,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
    required DateTime updatedAt,
  }) = _Flowrun;
  factory Flowrun.fromJson(Map<String, dynamic> json) => _$FlowrunFromJson(json);
}

/// One flowrun node row (record-once memoization; the timeline cell). flowrun.go:137。
@freezed
abstract class FlowrunNode with _$FlowrunNode {
  const factory FlowrunNode({
    required String id,
    required String flowrunId,
    required String nodeId,
    @Default(0) int iteration,
    @Default('') String kind,
    @Default('') String ref,
    @Default('') String status,
    @Default(<String, Object?>{}) Map<String, Object?> result,
    String? error,
    required DateTime createdAt,
    DateTime? completedAt,
    required DateTime updatedAt,
  }) = _FlowrunNode;
  factory FlowrunNode.fromJson(Map<String, dynamic> json) => _$FlowrunNodeFromJson(json);
}

/// The F173 80-node cap summary — present in a get_flowrun / replay_flowrun tool result ONLY when the
/// run was capped (`nodes` then holds every non-completed node + a recent-completed tail up to 80).
/// ABSENT = `nodes` is the full set. Counts come from HERE, NEVER `nodes.length` (which is 80 when
/// capped). runs.go:294. 80 封顶诚实账:计数取此、绝不数 nodes.length(截断时恒 80)。
@freezed
abstract class FlowrunNodeSummary with _$FlowrunNodeSummary {
  const factory FlowrunNodeSummary({
    @Default(0) int totalNodes,
    @Default(0) int shownNodes,
    @Default(<String, int>{}) Map<String, int> byStatus,
    @Default('') String note,
  }) = _FlowrunNodeSummary;
  factory FlowrunNodeSummary.fromJson(Map<String, dynamic> json) => _$FlowrunNodeSummaryFromJson(json);
}

/// The composite `data` of GET /flowruns/{id} = {flowrun, nodes, nextCursor} AND the get_flowrun /
/// replay_flowrun tool result = {flowrun, nodes, nodeSummary?} (one bespoke decode for both — the REST
/// shape paginates via [nextCursor], the tool caps at 80 via [nodeSummary]; both optional). flowrun.go。
@freezed
abstract class FlowrunComposite with _$FlowrunComposite {
  const factory FlowrunComposite({
    required Flowrun flowrun,
    @Default(<FlowrunNode>[]) List<FlowrunNode> nodes,
    String? nextCursor,
    FlowrunNodeSummary? nodeSummary,
  }) = _FlowrunComposite;
  factory FlowrunComposite.fromJson(Map<String, dynamic> json) => _$FlowrunCompositeFromJson(json);
}
