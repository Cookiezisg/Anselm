// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'touchpoint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Touchpoint _$TouchpointFromJson(Map<String, dynamic> json) => _Touchpoint(
  id: json['id'] as String,
  conversationId: json['conversationId'] as String? ?? '',
  itemKind: json['itemKind'] as String? ?? '',
  itemId: json['itemId'] as String? ?? '',
  itemName: json['itemName'] as String? ?? '',
  verb:
      $enumDecodeNullable(
        _$TouchpointVerbEnumMap,
        json['verb'],
        unknownValue: TouchpointVerb.unknown,
      ) ??
      TouchpointVerb.unknown,
  lastActor:
      $enumDecodeNullable(
        _$TouchpointActorEnumMap,
        json['lastActor'],
        unknownValue: TouchpointActor.unknown,
      ) ??
      TouchpointActor.unknown,
  count: (json['count'] as num?)?.toInt() ?? 0,
  firstAt: DateTime.parse(json['firstAt'] as String),
  lastAt: DateTime.parse(json['lastAt'] as String),
  lastMessageId: json['lastMessageId'] as String? ?? '',
);

Map<String, dynamic> _$TouchpointToJson(_Touchpoint instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'itemKind': instance.itemKind,
      'itemId': instance.itemId,
      'itemName': instance.itemName,
      'verb': _$TouchpointVerbEnumMap[instance.verb]!,
      'lastActor': _$TouchpointActorEnumMap[instance.lastActor]!,
      'count': instance.count,
      'firstAt': instance.firstAt.toIso8601String(),
      'lastAt': instance.lastAt.toIso8601String(),
      'lastMessageId': instance.lastMessageId,
    };

const _$TouchpointVerbEnumMap = {
  TouchpointVerb.mentioned: 'mentioned',
  TouchpointVerb.created: 'created',
  TouchpointVerb.edited: 'edited',
  TouchpointVerb.viewed: 'viewed',
  TouchpointVerb.executed: 'executed',
  TouchpointVerb.attached: 'attached',
  TouchpointVerb.deleted: 'deleted',
  TouchpointVerb.unknown: 'unknown',
};

const _$TouchpointActorEnumMap = {
  TouchpointActor.user: 'user',
  TouchpointActor.assistant: 'assistant',
  TouchpointActor.subagent: 'subagent',
  TouchpointActor.unknown: 'unknown',
};
