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
  factory FunctionEntity.fromJson(Map<String, dynamic> json) =>
      _$FunctionEntityFromJson(json);
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
  factory FunctionVersion.fromJson(Map<String, dynamic> json) =>
      _$FunctionVersionFromJson(json);
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
  factory FunctionExecution.fromJson(Map<String, dynamic> json) =>
      _$FunctionExecutionFromJson(json);
}

/// The synchronous `:run` result. It arrives INSIDE the standard N1 envelope like every other success
/// (`{"data": {...}}`) — this doc used to claim the opposite and the repository read it bare, so `ok`
/// fell back to `false` on every successful run and the terminal captioned it 失败 (WRK-083 L14).
/// 同步 `:run` 结果。它与其他所有成功响应一样**裹在 N1 信封里**(`{"data": {...}}`)——本注释原先声称相反,
/// 而仓也据此裸读,于是每一次**成功**运行的 `ok` 都退回 `false`、终端把它标成「失败」(WRK-083 L14)。
@freezed
abstract class FunctionRunResult with _$FunctionRunResult {
  const factory FunctionRunResult({
    @Default(false) bool ok,
    Object? output,
    @Default('') String errorMsg,
    @Default(0) int elapsedMs,
    String? logs,
  }) = _FunctionRunResult;
  factory FunctionRunResult.fromJson(Map<String, dynamic> json) =>
      _$FunctionRunResultFromJson(json);
}
