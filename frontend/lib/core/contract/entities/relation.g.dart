// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EntityRelation _$EntityRelationFromJson(Map<String, dynamic> json) =>
    _EntityRelation(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? '',
      fromKind: json['fromKind'] as String? ?? '',
      fromId: json['fromId'] as String? ?? '',
      fromName: json['fromName'] as String? ?? '',
      toKind: json['toKind'] as String? ?? '',
      toId: json['toId'] as String? ?? '',
      toName: json['toName'] as String? ?? '',
    );

Map<String, dynamic> _$EntityRelationToJson(_EntityRelation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'fromKind': instance.fromKind,
      'fromId': instance.fromId,
      'fromName': instance.fromName,
      'toKind': instance.toKind,
      'toId': instance.toId,
      'toName': instance.toName,
    };
