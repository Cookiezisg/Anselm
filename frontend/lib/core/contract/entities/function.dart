import 'package:freezed_annotation/freezed_annotation.dart';

import 'values.dart';

part 'function.freezed.dart';
part 'function.g.dart';

/// Function entity (Quadrinity :run kind). Bare entity in `data`; `activeVersion` is embedded on
/// Create+Get identically (omitempty). function.go:24。
@freezed
abstract class FunctionEntity with _$FunctionEntity {
  const factory FunctionEntity({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default('') String activeVersionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    FunctionVersion? activeVersion,
  }) = _FunctionEntity;
  factory FunctionEntity.fromJson(Map<String, dynamic> json) => _$FunctionEntityFromJson(json);
}

/// Function version (append-only, immutable). `envStatus` ∈ pending/syncing/ready/failed (open String).
/// function.go:53。
@freezed
abstract class FunctionVersion with _$FunctionVersion {
  const factory FunctionVersion({
    required String id,
    required String functionId,
    required int version,
    @Default('') String code,
    @Default(<Field>[]) List<Field> inputs,
    @Default(<Field>[]) List<Field> outputs,
    @Default(<String>[]) List<String> dependencies,
    @Default('3.12') String pythonVersion,
    @Default('') String envId,
    @Default('') String envStatus,
    String? envError,
    DateTime? envSyncedAt,
    String? changeReason,
    String? builtInConversationId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _FunctionVersion;
  factory FunctionVersion.fromJson(Map<String, dynamic> json) => _$FunctionVersionFromJson(json);
}

/// One function execution log row (the 日志 tab; `logs` present only on the single-GET, not the list).
/// execution.go:70。
@freezed
abstract class FunctionExecution with _$FunctionExecution {
  const factory FunctionExecution({
    required String id,
    required String functionId,
    @Default('') String versionId,
    @Default('') String status,
    @Default('') String triggeredBy,
    @Default(<String, Object?>{}) Map<String, Object?> input,
    Object? output,
    String? errorMessage,
    String? logs,
    @Default(0) int elapsedMs,
    DateTime? startedAt,
    DateTime? endedAt,
    String? conversationId,
    String? messageId,
    String? toolCallId,
    String? flowrunId,
    String? flowrunNodeId,
    int? flowrunIteration,
    required DateTime createdAt,
  }) = _FunctionExecution;
  factory FunctionExecution.fromJson(Map<String, dynamic> json) => _$FunctionExecutionFromJson(json);
}

/// The BARE synchronous `:run` result (NOT wrapped in an envelope `data` object — the run handler
/// returns it directly). run.go:36。
@freezed
abstract class FunctionRunResult with _$FunctionRunResult {
  const factory FunctionRunResult({
    @Default(false) bool ok,
    Object? output,
    @Default('') String errorMsg,
    @Default(0) int elapsedMs,
    String? logs,
  }) = _FunctionRunResult;
  factory FunctionRunResult.fromJson(Map<String, dynamic> json) => _$FunctionRunResultFromJson(json);
}
