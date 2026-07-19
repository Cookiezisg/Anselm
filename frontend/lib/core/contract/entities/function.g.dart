// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'function.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FunctionEntity _$FunctionEntityFromJson(Map<String, dynamic> json) =>
    _FunctionEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      activeVersionId: json['activeVersionId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      activeVersion: json['activeVersion'] == null
          ? null
          : FunctionVersion.fromJson(
              json['activeVersion'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$FunctionEntityToJson(_FunctionEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'tags': instance.tags,
      'activeVersionId': instance.activeVersionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'activeVersion': instance.activeVersion?.toJson(),
    };

_FunctionVersion _$FunctionVersionFromJson(Map<String, dynamic> json) =>
    _FunctionVersion(
      id: json['id'] as String,
      functionId: json['functionId'] as String,
      version: (json['version'] as num).toInt(),
      code: json['code'] as String? ?? '',
      inputs:
          (json['inputs'] as List<dynamic>?)
              ?.map((e) => Field.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Field>[],
      outputs:
          (json['outputs'] as List<dynamic>?)
              ?.map((e) => Field.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Field>[],
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      pythonVersion: json['pythonVersion'] as String? ?? '3.12',
      envId: json['envId'] as String? ?? '',
      envStatus: json['envStatus'] as String? ?? '',
      envError: json['envError'] as String?,
      envSyncedAt: json['envSyncedAt'] == null
          ? null
          : DateTime.parse(json['envSyncedAt'] as String),
      changeReason: json['changeReason'] as String?,
      builtInConversationId: json['builtInConversationId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$FunctionVersionToJson(_FunctionVersion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'functionId': instance.functionId,
      'version': instance.version,
      'code': instance.code,
      'inputs': instance.inputs.map((e) => e.toJson()).toList(),
      'outputs': instance.outputs.map((e) => e.toJson()).toList(),
      'dependencies': instance.dependencies,
      'pythonVersion': instance.pythonVersion,
      'envId': instance.envId,
      'envStatus': instance.envStatus,
      'envError': instance.envError,
      'envSyncedAt': instance.envSyncedAt?.toIso8601String(),
      'changeReason': instance.changeReason,
      'builtInConversationId': instance.builtInConversationId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_FunctionExecution _$FunctionExecutionFromJson(Map<String, dynamic> json) =>
    _FunctionExecution(
      id: json['id'] as String,
      functionId: json['functionId'] as String,
      versionId: json['versionId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      triggeredBy: json['triggeredBy'] as String? ?? '',
      input:
          json['input'] as Map<String, dynamic>? ?? const <String, Object?>{},
      output: json['output'],
      errorMessage: json['errorMessage'] as String?,
      logs: json['logs'] as String?,
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      conversationId: json['conversationId'] as String?,
      messageId: json['messageId'] as String?,
      toolCallId: json['toolCallId'] as String?,
      flowrunId: json['flowrunId'] as String?,
      flowrunNodeId: json['flowrunNodeId'] as String?,
      flowrunIteration: (json['flowrunIteration'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$FunctionExecutionToJson(_FunctionExecution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'functionId': instance.functionId,
      'versionId': instance.versionId,
      'status': instance.status,
      'triggeredBy': instance.triggeredBy,
      'input': instance.input,
      'output': instance.output,
      'errorMessage': instance.errorMessage,
      'logs': instance.logs,
      'elapsedMs': instance.elapsedMs,
      'startedAt': instance.startedAt?.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'conversationId': instance.conversationId,
      'messageId': instance.messageId,
      'toolCallId': instance.toolCallId,
      'flowrunId': instance.flowrunId,
      'flowrunNodeId': instance.flowrunNodeId,
      'flowrunIteration': instance.flowrunIteration,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_FunctionRunResult _$FunctionRunResultFromJson(Map<String, dynamic> json) =>
    _FunctionRunResult(
      ok: json['ok'] as bool? ?? false,
      output: json['output'],
      errorMsg: json['errorMsg'] as String? ?? '',
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      logs: json['logs'] as String?,
    );

Map<String, dynamic> _$FunctionRunResultToJson(_FunctionRunResult instance) =>
    <String, dynamic>{
      'ok': instance.ok,
      'output': instance.output,
      'errorMsg': instance.errorMsg,
      'elapsedMs': instance.elapsedMs,
      'logs': instance.logs,
    };
