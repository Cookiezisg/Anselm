// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentEntity _$AgentEntityFromJson(Map<String, dynamic> json) => _AgentEntity(
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
      : AgentVersion.fromJson(json['activeVersion'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AgentEntityToJson(_AgentEntity instance) =>
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

_AgentVersion _$AgentVersionFromJson(Map<String, dynamic> json) =>
    _AgentVersion(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      version: (json['version'] as num).toInt(),
      prompt: json['prompt'] as String? ?? '',
      skill: json['skill'] as String?,
      knowledge:
          (json['knowledge'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      tools:
          (json['tools'] as List<dynamic>?)
              ?.map((e) => ToolRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ToolRef>[],
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
      modelOverride: json['modelOverride'] == null
          ? null
          : ModelRef.fromJson(json['modelOverride'] as Map<String, dynamic>),
      changeReason: json['changeReason'] as String?,
      builtInConversationId: json['builtInConversationId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AgentVersionToJson(_AgentVersion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'version': instance.version,
      'prompt': instance.prompt,
      'skill': instance.skill,
      'knowledge': instance.knowledge,
      'tools': instance.tools.map((e) => e.toJson()).toList(),
      'inputs': instance.inputs.map((e) => e.toJson()).toList(),
      'outputs': instance.outputs.map((e) => e.toJson()).toList(),
      'modelOverride': instance.modelOverride?.toJson(),
      'changeReason': instance.changeReason,
      'builtInConversationId': instance.builtInConversationId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_AgentExecution _$AgentExecutionFromJson(Map<String, dynamic> json) =>
    _AgentExecution(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      versionId: json['versionId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      triggeredBy: json['triggeredBy'] as String? ?? '',
      input:
          json['input'] as Map<String, dynamic>? ?? const <String, Object?>{},
      output: json['output'],
      errorMessage: json['errorMessage'] as String?,
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      modelId: json['modelId'] as String?,
      apiKeyId: json['apiKeyId'] as String?,
      provider: json['provider'] as String?,
      transcript: json['transcript'],
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

Map<String, dynamic> _$AgentExecutionToJson(_AgentExecution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'agentId': instance.agentId,
      'versionId': instance.versionId,
      'status': instance.status,
      'triggeredBy': instance.triggeredBy,
      'input': instance.input,
      'output': instance.output,
      'errorMessage': instance.errorMessage,
      'elapsedMs': instance.elapsedMs,
      'modelId': instance.modelId,
      'apiKeyId': instance.apiKeyId,
      'provider': instance.provider,
      'transcript': instance.transcript,
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

_InvokeResult _$InvokeResultFromJson(Map<String, dynamic> json) =>
    _InvokeResult(
      executionId: json['executionId'] as String? ?? '',
      ok: json['ok'] as bool? ?? false,
      output: json['output'],
      status: json['status'] as String? ?? '',
      stopReason: json['stopReason'] as String?,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      tokensIn: (json['tokensIn'] as num?)?.toInt() ?? 0,
      tokensOut: (json['tokensOut'] as num?)?.toInt() ?? 0,
      errorMsg: json['errorMsg'] as String?,
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$InvokeResultToJson(_InvokeResult instance) =>
    <String, dynamic>{
      'executionId': instance.executionId,
      'ok': instance.ok,
      'output': instance.output,
      'status': instance.status,
      'stopReason': instance.stopReason,
      'steps': instance.steps,
      'tokensIn': instance.tokensIn,
      'tokensOut': instance.tokensOut,
      'errorMsg': instance.errorMsg,
      'elapsedMs': instance.elapsedMs,
    };

_MountHealth _$MountHealthFromJson(Map<String, dynamic> json) => _MountHealth(
  ref: json['ref'] as String,
  name: json['name'] as String?,
  healthy: json['healthy'] as bool? ?? false,
  error: json['error'] as String?,
);

Map<String, dynamic> _$MountHealthToJson(_MountHealth instance) =>
    <String, dynamic>{
      'ref': instance.ref,
      'name': instance.name,
      'healthy': instance.healthy,
      'error': instance.error,
    };

_MountHealthReport _$MountHealthReportFromJson(Map<String, dynamic> json) =>
    _MountHealthReport(
      mounts:
          (json['mounts'] as List<dynamic>?)
              ?.map((e) => MountHealth.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MountHealth>[],
      allHealthy: json['allHealthy'] as bool? ?? false,
    );

Map<String, dynamic> _$MountHealthReportToJson(_MountHealthReport instance) =>
    <String, dynamic>{
      'mounts': instance.mounts.map((e) => e.toJson()).toList(),
      'allHealthy': instance.allHealthy,
    };
