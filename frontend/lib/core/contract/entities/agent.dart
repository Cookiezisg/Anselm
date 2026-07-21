import 'package:freezed_annotation/freezed_annotation.dart';

import '../workspace.dart'; // ModelRef (reused for agent modelOverride)
import 'values.dart';

part 'agent.freezed.dart';
part 'agent.g.dart';

/// Agent entity (Quadrinity :invoke kind). Common header + embedded activeVersion. agent.go。
@freezed
abstract class AgentEntity with _$AgentEntity {
  const factory AgentEntity({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default('') String activeVersionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    AgentVersion? activeVersion,
  }) = _AgentEntity;
  factory AgentEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentEntityFromJson(json);
}

/// Agent version (append-only): prompt + at-most-one skill + knowledge docs + tool mounts + I/O +
/// optional model override (reuses [ModelRef]). agent.go:73。
@freezed
abstract class AgentVersion with _$AgentVersion {
  const factory AgentVersion({
    required String id,
    required String agentId,
    required int version,
    @Default('') String prompt,
    String? skill,
    @Default(<String>[]) List<String> knowledge,
    @Default(<ToolRef>[]) List<ToolRef> tools,
    @Default(<Field>[]) List<Field> inputs,
    @Default(<Field>[]) List<Field> outputs,
    ModelRef? modelOverride,
    String? changeReason,
    String? builtInConversationId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AgentVersion;
  factory AgentVersion.fromJson(Map<String, dynamic> json) =>
      _$AgentVersionFromJson(json);
}

/// One agent execution log row (no `logs` field; carries the model used + the durable transcript JSON).
/// execution.go:70。
@freezed
abstract class AgentExecution with _$AgentExecution {
  const factory AgentExecution({
    required String id,
    required String agentId,
    @Default('') String versionId,
    @Default('') String status,
    @Default('') String triggeredBy,
    @Default(<String, Object?>{}) Map<String, Object?> input,
    Object? output,
    String? errorMessage,
    @Default(0) int elapsedMs,
    String? modelId,
    String? apiKeyId,
    String? provider,
    Object? transcript,
    DateTime? startedAt,
    DateTime? endedAt,
    String? conversationId,
    String? messageId,
    String? toolCallId,
    String? flowrunId,
    String? flowrunNodeId,
    int? flowrunIteration,
    required DateTime createdAt,
  }) = _AgentExecution;
  factory AgentExecution.fromJson(Map<String, dynamic> json) =>
      _$AgentExecutionFromJson(json);
}

/// The BARE synchronous `:invoke` result (returned directly, not enveloped). invoke.go:63。
@freezed
abstract class InvokeResult with _$InvokeResult {
  const factory InvokeResult({
    @Default('') String executionId,
    @Default(false) bool ok,
    Object? output,
    @Default('') String status,
    String? stopReason,
    @Default(0) int steps,
    @Default(0) int tokensIn,
    @Default(0) int tokensOut,
    String? errorMsg,
    @Default(0) int elapsedMs,
  }) = _InvokeResult;
  factory InvokeResult.fromJson(Map<String, dynamic> json) =>
      _$InvokeResultFromJson(json);
}

/// One mounted-tool health row (GET /agents/{id}/mount-health). agent.go:62。
@freezed
abstract class MountHealth with _$MountHealth {
  const factory MountHealth({
    required String ref,
    String? name,
    @Default(false) bool healthy,
    String? error,
  }) = _MountHealth;
  factory MountHealth.fromJson(Map<String, dynamic> json) =>
      _$MountHealthFromJson(json);
}

/// The agent mount-health report (`data` of GET /agents/{id}/mount-health). agent.go:62。
@freezed
abstract class MountHealthReport with _$MountHealthReport {
  const factory MountHealthReport({
    @Default(<MountHealth>[]) List<MountHealth> mounts,
    @Default(false) bool allHealthy,
  }) = _MountHealthReport;
  factory MountHealthReport.fromJson(Map<String, dynamic> json) =>
      _$MountHealthReportFromJson(json);
}
