// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sandbox.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SandboxRuntime _$SandboxRuntimeFromJson(Map<String, dynamic> json) =>
    _SandboxRuntime(
      id: json['id'] as String,
      kind: json['kind'] as String,
      version: json['version'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      installedAt: json['installedAt'] == null
          ? null
          : DateTime.parse(json['installedAt'] as String),
    );

Map<String, dynamic> _$SandboxRuntimeToJson(_SandboxRuntime instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'version': instance.version,
      'sizeBytes': instance.sizeBytes,
      'installedAt': instance.installedAt?.toIso8601String(),
    };

_RuntimeAvailability _$RuntimeAvailabilityFromJson(Map<String, dynamic> json) =>
    _RuntimeAvailability(
      kind: json['kind'] as String,
      defaultVersion: json['default'] as String? ?? '',
      versions:
          (json['versions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      pinned: json['pinned'] as bool? ?? false,
    );

Map<String, dynamic> _$RuntimeAvailabilityToJson(
  _RuntimeAvailability instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'default': instance.defaultVersion,
  'versions': instance.versions,
  'pinned': instance.pinned,
};

_SandboxEnv _$SandboxEnvFromJson(Map<String, dynamic> json) => _SandboxEnv(
  id: json['id'] as String,
  ownerKind: json['ownerKind'] as String? ?? '',
  ownerId: json['ownerId'] as String? ?? '',
  ownerName: json['ownerName'] as String? ?? '',
  runtimeId: json['runtimeId'] as String? ?? '',
  deps:
      (json['deps'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
  status: json['status'] as String? ?? '',
  errorMsg: json['errorMsg'] as String?,
  lastUsedAt: json['lastUsedAt'] == null
      ? null
      : DateTime.parse(json['lastUsedAt'] as String),
  runningPid: (json['runningPid'] as num?)?.toInt(),
);

Map<String, dynamic> _$SandboxEnvToJson(_SandboxEnv instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerKind': instance.ownerKind,
      'ownerId': instance.ownerId,
      'ownerName': instance.ownerName,
      'runtimeId': instance.runtimeId,
      'deps': instance.deps,
      'sizeBytes': instance.sizeBytes,
      'status': instance.status,
      'errorMsg': instance.errorMsg,
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
      'runningPid': instance.runningPid,
    };

_SandboxBootstrap _$SandboxBootstrapFromJson(Map<String, dynamic> json) =>
    _SandboxBootstrap(
      ok: json['ok'] as bool? ?? false,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$SandboxBootstrapToJson(_SandboxBootstrap instance) =>
    <String, dynamic>{'ok': instance.ok, 'error': instance.error};
