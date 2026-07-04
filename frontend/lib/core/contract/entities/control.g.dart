// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'control.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ControlLogic _$ControlLogicFromJson(Map<String, dynamic> json) =>
    _ControlLogic(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      activeVersionId: json['activeVersionId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      activeVersion: json['activeVersion'] == null
          ? null
          : ControlVersion.fromJson(
              json['activeVersion'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$ControlLogicToJson(_ControlLogic instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'activeVersionId': instance.activeVersionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'activeVersion': instance.activeVersion?.toJson(),
    };

_ControlVersion _$ControlVersionFromJson(Map<String, dynamic> json) =>
    _ControlVersion(
      id: json['id'] as String,
      controlId: json['controlId'] as String,
      version: (json['version'] as num).toInt(),
      inputs:
          (json['inputs'] as List<dynamic>?)
              ?.map((e) => Field.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Field>[],
      branches:
          (json['branches'] as List<dynamic>?)
              ?.map((e) => Branch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Branch>[],
      changeReason: json['changeReason'] as String?,
      builtInConversationId: json['builtInConversationId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ControlVersionToJson(_ControlVersion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'controlId': instance.controlId,
      'version': instance.version,
      'inputs': instance.inputs.map((e) => e.toJson()).toList(),
      'branches': instance.branches.map((e) => e.toJson()).toList(),
      'changeReason': instance.changeReason,
      'builtInConversationId': instance.builtInConversationId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_Branch _$BranchFromJson(Map<String, dynamic> json) => _Branch(
  port: json['port'] as String? ?? '',
  when: json['when'] as String? ?? '',
  emit:
      (json['emit'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
);

Map<String, dynamic> _$BranchToJson(_Branch instance) => <String, dynamic>{
  'port': instance.port,
  'when': instance.when,
  'emit': instance.emit,
};
