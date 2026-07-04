import 'package:freezed_annotation/freezed_annotation.dart';

import 'values.dart';

part 'handler.freezed.dart';
part 'handler.g.dart';

/// Handler entity (Quadrinity :call kind). Adds computed config/runtime state over the common header.
/// configState ∈ unconfigured/partially_configured/ready; runtimeState ∈ running/stopped/crashed (open
/// Strings). handler.go:30。
@freezed
abstract class HandlerEntity with _$HandlerEntity {
  const factory HandlerEntity({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default('') String activeVersionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    HandlerVersion? activeVersion,
    String? configState,
    @Default(<String>[]) List<String> missingConfig,
    String? runtimeState,
  }) = _HandlerEntity;
  factory HandlerEntity.fromJson(Map<String, dynamic> json) => _$HandlerEntityFromJson(json);
}

/// The masked config blob for one handler — `GET /handlers/{id}/config`. [config] carries the CURRENT
/// stored init-arg values with sensitive fields masked to `********` server-side (the client never sees
/// plaintext, so there is no reveal toggle for stored values); [schema] is the active version's
/// [InitArgSpec] list the config form renders from; [configState]/[missingConfig] gate whether the
/// resident instance can spawn. Editing (PUT, a JSON merge patch) restarts the instance. handler 的掩码
/// config blob(GET config):config=当前存值(sensitive 服务端掩 `********`,客户端无明文故存值无 reveal)、
/// schema=渲染表单的 initArgsSchema、state/missing=实例能否启动的闸门;编辑(PUT merge patch)重启实例。
@freezed
abstract class HandlerConfig with _$HandlerConfig {
  const factory HandlerConfig({
    @Default(<String, dynamic>{}) Map<String, dynamic> config,
    String? configState,
    @Default(<String>[]) List<String> missingConfig,
    @Default(<InitArgSpec>[]) List<InitArgSpec> schema,
  }) = _HandlerConfig;
  factory HandlerConfig.fromJson(Map<String, dynamic> json) => _$HandlerConfigFromJson(json);
}

/// Handler version (append-only). Carries the class shape (imports/init/shutdown/methods/initArgsSchema)
/// + the env mirror (envId/envStatus/envError/envSyncedAt). handler.go:59。
@freezed
abstract class HandlerVersion with _$HandlerVersion {
  const factory HandlerVersion({
    required String id,
    required String handlerId,
    required int version,
    @Default('') String imports,
    @Default('') String initBody,
    @Default('') String shutdownBody,
    @Default(<MethodSpec>[]) List<MethodSpec> methods,
    @Default(<InitArgSpec>[]) List<InitArgSpec> initArgsSchema,
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
  }) = _HandlerVersion;
  factory HandlerVersion.fromJson(Map<String, dynamic> json) => _$HandlerVersionFromJson(json);
}

/// One handler call log row (日志 tab; adds method + instanceId over the common execution shape; `logs`
/// only on single-GET). execution.go:70。
@freezed
abstract class HandlerCall with _$HandlerCall {
  const factory HandlerCall({
    required String id,
    required String handlerId,
    @Default('') String versionId,
    @Default('') String method,
    String? instanceId,
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
  }) = _HandlerCall;
  factory HandlerCall.fromJson(Map<String, dynamic> json) => _$HandlerCallFromJson(json);
}
