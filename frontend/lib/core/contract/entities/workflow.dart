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
  factory WorkflowEntity.fromJson(Map<String, dynamic> json) =>
      _$WorkflowEntityFromJson(json);
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
  factory WorkflowVersion.fromJson(Map<String, dynamic> json) =>
      _$WorkflowVersionFromJson(json);
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
  factory Flowrun.fromJson(Map<String, dynamic> json) =>
      _$FlowrunFromJson(json);
}

/// One flowrun node row (record-once memoization; the timeline cell). flowrun.go:172。
///
/// [readyAt]/[startedAt] are the QUEUE-SEGMENT stamps (scheduler 工单⑫), written on the row's single
/// record-once INSERT: readyAt = when a walk turn first computed this (node, iteration) ready (the
/// queue start), startedAt = when the engine began processing it (input CEL eval + dispatch — the
/// execution entity's own start rides its audit row, see [FlowrunActivityRow]). Causal order is
/// guaranteed readyAt ≤ startedAt ≤ completedAt. BOTH are omitted (null) on rows born before the
/// columns AND on seed trigger rows (never queued) — null = no queue segment, NEVER a zero-value lie.
/// [createdAt] is the row's write time = the terminal/PARK moment (an approval's park boundary), NOT
/// the node's start; [completedAt] is nil while parked and stamps the decision when it settles.
/// readyAt/startedAt = 排队段两戳(⑫,随唯一一次 record-once INSERT 落盘);因果序 readyAt ≤ startedAt ≤
/// completedAt;旧行与 seed trigger 行两戳缺席(null=无排队段,绝不装 0)。createdAt=行写入时刻=终态/
/// 停车时刻(非节点起点);completedAt 停车期间为 nil、决断时盖章。
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
    DateTime? readyAt,
    DateTime? startedAt,
    required DateTime createdAt,
    DateTime? completedAt,
    required DateTime updatedAt,
  }) = _FlowrunNode;
  factory FlowrunNode.fromJson(Map<String, dynamic> json) =>
      _$FlowrunNodeFromJson(json);
}

/// One row of `GET /flowruns/{id}/activity` (scheduler 工单⑤) — the pure-read UNION of the four
/// execution-log tables by flowrun_id, newest-walk-order (startedAt ASC, the gantt's natural order).
/// [kind] is the AUDIT-table family (function|handler|agent|mcp — NOT the graph node kind: an `action`
/// node fans into three families by its ref prefix, and control/approval evaluate inline with no audit
/// row at all, so a node CAN legitimately have no activity row). [execId] is the audit row id
/// (fne_/hcl_/agx_/mcl_) — the execution-log deep link. [status] is the audit vocabulary
/// (ok|failed|cancelled|timeout), NOT the node-row three. [startedAt]/[endedAt]/[elapsedMs] are the
/// execution's OWN span (the gantt's exec segment); [readyAt] is joined from the truth row's queue
/// stamp (工单⑫) and is ABSENT on pre-⑫ rows / when no live truth row matches (:replay clears the old
/// failed row while its audit attempt survives — Log 表不删), so a queue segment computed from it must
/// be clamped ≥ 0.
/// 按 run 聚合的活动行(⑤):四张审计表 UNION;kind=审计表族(非图节点 kind——control/approval 无审计行);
/// execId=审计行 id(执行日志深链);status=审计词表;起止=执行自身跨度(甘特执行段);readyAt=join 自
/// 真相行的排队戳(⑫,可缺席;replay 后旧审计行可早于存活真相行的戳——排队段须钳制 ≥0)。
@freezed
abstract class FlowrunActivityRow with _$FlowrunActivityRow {
  const factory FlowrunActivityRow({
    @Default('') String nodeId,
    @Default(0) int iteration,
    @Default('') String kind,
    @Default('') String execId,
    @Default('') String status,
    DateTime? readyAt,
    required DateTime startedAt,
    required DateTime endedAt,
    @Default(0) int elapsedMs,
  }) = _FlowrunActivityRow;
  factory FlowrunActivityRow.fromJson(Map<String, dynamic> json) =>
      _$FlowrunActivityRowFromJson(json);
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
  factory FlowrunNodeSummary.fromJson(Map<String, dynamic> json) =>
      _$FlowrunNodeSummaryFromJson(json);
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
  factory FlowrunComposite.fromJson(Map<String, dynamic> json) =>
      _$FlowrunCompositeFromJson(json);
}
