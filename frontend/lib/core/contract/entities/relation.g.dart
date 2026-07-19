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

_EntityNode _$EntityNodeFromJson(Map<String, dynamic> json) => _EntityNode(
  kind: json['kind'] as String? ?? '',
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
);

Map<String, dynamic> _$EntityNodeToJson(_EntityNode instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'id': instance.id,
      'name': instance.name,
    };

_EntityRelGraph _$EntityRelGraphFromJson(Map<String, dynamic> json) =>
    _EntityRelGraph(
      nodes:
          (json['nodes'] as List<dynamic>?)
              ?.map((e) => EntityNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EntityNode>[],
      edges:
          (json['edges'] as List<dynamic>?)
              ?.map((e) => EntityRelation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EntityRelation>[],
    );

Map<String, dynamic> _$EntityRelGraphToJson(_EntityRelGraph instance) =>
    <String, dynamic>{
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
      'edges': instance.edges.map((e) => e.toJson()).toList(),
    };
