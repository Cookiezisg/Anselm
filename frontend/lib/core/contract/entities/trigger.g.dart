// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trigger.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TriggerEntity _$TriggerEntityFromJson(Map<String, dynamic> json) =>
    _TriggerEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      kind:
          $enumDecodeNullable(
            _$TriggerSourceEnumMap,
            json['kind'],
            unknownValue: TriggerSource.unknown,
          ) ??
          TriggerSource.unknown,
      config:
          json['config'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      outputs:
          (json['outputs'] as List<dynamic>?)
              ?.map((e) => Field.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Field>[],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      refCount: (json['refCount'] as num?)?.toInt() ?? 0,
      listening: json['listening'] as bool? ?? false,
      paused: json['paused'] as bool? ?? false,
      lastFiredAt: json['lastFiredAt'] == null
          ? null
          : DateTime.parse(json['lastFiredAt'] as String),
      nextFireAt: json['nextFireAt'] == null
          ? null
          : DateTime.parse(json['nextFireAt'] as String),
    );

Map<String, dynamic> _$TriggerEntityToJson(_TriggerEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'kind': _$TriggerSourceEnumMap[instance.kind]!,
      'config': instance.config,
      'outputs': instance.outputs.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'refCount': instance.refCount,
      'listening': instance.listening,
      'paused': instance.paused,
      'lastFiredAt': instance.lastFiredAt?.toIso8601String(),
      'nextFireAt': instance.nextFireAt?.toIso8601String(),
    };

const _$TriggerSourceEnumMap = {
  TriggerSource.cron: 'cron',
  TriggerSource.webhook: 'webhook',
  TriggerSource.fsnotify: 'fsnotify',
  TriggerSource.sensor: 'sensor',
  TriggerSource.unknown: 'unknown',
};

_Activation _$ActivationFromJson(Map<String, dynamic> json) => _Activation(
  id: json['id'] as String,
  triggerId: json['triggerId'] as String? ?? '',
  kind:
      $enumDecodeNullable(
        _$TriggerSourceEnumMap,
        json['kind'],
        unknownValue: TriggerSource.unknown,
      ) ??
      TriggerSource.unknown,
  fired: json['fired'] as bool? ?? false,
  returnValue:
      json['returnValue'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  payload:
      json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  error: json['error'] as String? ?? '',
  detail: json['detail'] as String? ?? '',
  firingCount: (json['firingCount'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ActivationToJson(_Activation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'triggerId': instance.triggerId,
      'kind': _$TriggerSourceEnumMap[instance.kind]!,
      'fired': instance.fired,
      'returnValue': instance.returnValue,
      'payload': instance.payload,
      'error': instance.error,
      'detail': instance.detail,
      'firingCount': instance.firingCount,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_Firing _$FiringFromJson(Map<String, dynamic> json) => _Firing(
  id: json['id'] as String,
  triggerId: json['triggerId'] as String? ?? '',
  workflowId: json['workflowId'] as String? ?? '',
  activationId: json['activationId'] as String? ?? '',
  payload:
      json['payload'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  dedupKey: json['dedupKey'] as String? ?? '',
  status:
      $enumDecodeNullable(
        _$FiringStatusEnumMap,
        json['status'],
        unknownValue: FiringStatus.unknown,
      ) ??
      FiringStatus.unknown,
  flowrunId: json['flowrunId'] as String? ?? '',
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$FiringToJson(_Firing instance) => <String, dynamic>{
  'id': instance.id,
  'triggerId': instance.triggerId,
  'workflowId': instance.workflowId,
  'activationId': instance.activationId,
  'payload': instance.payload,
  'dedupKey': instance.dedupKey,
  'status': _$FiringStatusEnumMap[instance.status]!,
  'flowrunId': instance.flowrunId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$FiringStatusEnumMap = {
  FiringStatus.pending: 'pending',
  FiringStatus.claimed: 'claimed',
  FiringStatus.started: 'started',
  FiringStatus.skipped: 'skipped',
  FiringStatus.superseded: 'superseded',
  FiringStatus.shed: 'shed',
  FiringStatus.missed: 'missed',
  FiringStatus.unknown: 'unknown',
};
