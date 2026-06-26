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
@freezed
abstract class Flowrun with _$Flowrun {
  const factory Flowrun({
    required String id,
    required String workflowId,
    @Default('') String versionId,
    @Default(<String, String>{}) Map<String, String> pinnedRefs,
    String? triggerId,
    String? firingId,
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

/// The composite `data` of GET /flowruns/{id} = {flowrun, nodes, nextCursor} (a bespoke decode, NOT the
/// standard bare-entity shape). flowrun.go。
@freezed
abstract class FlowrunComposite with _$FlowrunComposite {
  const factory FlowrunComposite({
    required Flowrun flowrun,
    @Default(<FlowrunNode>[]) List<FlowrunNode> nodes,
    String? nextCursor,
  }) = _FlowrunComposite;
  factory FlowrunComposite.fromJson(Map<String, dynamic> json) => _$FlowrunCompositeFromJson(json);
}
