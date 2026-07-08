// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_McpServerStatus _$McpServerStatusFromJson(Map<String, dynamic> json) =>
    _McpServerStatus(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'disconnected',
      connectedAt: json['connectedAt'] == null
          ? null
          : DateTime.parse(json['connectedAt'] as String),
      lastError: json['lastError'] as String?,
      lastErrorAt: json['lastErrorAt'] == null
          ? null
          : DateTime.parse(json['lastErrorAt'] as String),
      consecutiveFailures: (json['consecutiveFailures'] as num?)?.toInt() ?? 0,
      totalCalls: (json['totalCalls'] as num?)?.toInt() ?? 0,
      totalFailures: (json['totalFailures'] as num?)?.toInt() ?? 0,
      tools:
          (json['tools'] as List<dynamic>?)
              ?.map((e) => McpToolDef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$McpServerStatusToJson(_McpServerStatus instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'status': instance.status,
      'connectedAt': instance.connectedAt?.toIso8601String(),
      'lastError': instance.lastError,
      'lastErrorAt': instance.lastErrorAt?.toIso8601String(),
      'consecutiveFailures': instance.consecutiveFailures,
      'totalCalls': instance.totalCalls,
      'totalFailures': instance.totalFailures,
      'tools': instance.tools.map((e) => e.toJson()).toList(),
    };

_McpToolDef _$McpToolDefFromJson(Map<String, dynamic> json) => _McpToolDef(
  serverName: json['serverName'] as String? ?? '',
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  inputSchema: json['inputSchema'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$McpToolDefToJson(_McpToolDef instance) =>
    <String, dynamic>{
      'serverName': instance.serverName,
      'name': instance.name,
      'description': instance.description,
      'inputSchema': instance.inputSchema,
    };

_McpRegistryEntry _$McpRegistryEntryFromJson(Map<String, dynamic> json) =>
    _McpRegistryEntry(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      prerequisite: json['prerequisite'] as String? ?? '',
    );

Map<String, dynamic> _$McpRegistryEntryToJson(_McpRegistryEntry instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'prerequisite': instance.prerequisite,
    };

_McpRegistryPlan _$McpRegistryPlanFromJson(Map<String, dynamic> json) =>
    _McpRegistryPlan(
      transport: json['transport'] as String,
      runtime: json['runtime'] as String? ?? '',
      oauth: json['oauth'] as bool? ?? false,
      envVars:
          (json['envVars'] as List<dynamic>?)
              ?.map((e) => McpEnvVar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      prerequisite: json['prerequisite'] as String? ?? '',
    );

Map<String, dynamic> _$McpRegistryPlanToJson(_McpRegistryPlan instance) =>
    <String, dynamic>{
      'transport': instance.transport,
      'runtime': instance.runtime,
      'oauth': instance.oauth,
      'envVars': instance.envVars.map((e) => e.toJson()).toList(),
      'prerequisite': instance.prerequisite,
    };

_McpEnvVar _$McpEnvVarFromJson(Map<String, dynamic> json) => _McpEnvVar(
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  isSecret: json['isSecret'] as bool? ?? false,
  required: json['required'] as bool? ?? false,
);

Map<String, dynamic> _$McpEnvVarToJson(_McpEnvVar instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'isSecret': instance.isSecret,
      'required': instance.required,
    };

_McpCall _$McpCallFromJson(Map<String, dynamic> json) => _McpCall(
  id: json['id'] as String,
  serverId: json['serverId'] as String? ?? '',
  tool: json['tool'] as String? ?? '',
  status: json['status'] as String? ?? '',
  triggeredBy: json['triggeredBy'] as String? ?? '',
  errorMessage: json['errorMessage'] as String?,
  elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$McpCallToJson(_McpCall instance) => <String, dynamic>{
  'id': instance.id,
  'serverId': instance.serverId,
  'tool': instance.tool,
  'status': instance.status,
  'triggeredBy': instance.triggeredBy,
  'errorMessage': instance.errorMessage,
  'elapsedMs': instance.elapsedMs,
  'startedAt': instance.startedAt?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
};
