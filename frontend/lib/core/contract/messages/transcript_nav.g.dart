// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_nav.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessagesWindow _$MessagesWindowFromJson(Map<String, dynamic> json) =>
    _MessagesWindow(
      messages:
          (json['data'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ChatMessage>[],
      targetId: json['targetId'] as String? ?? '',
      olderCursor: json['olderCursor'] as String? ?? '',
      newerCursor: json['newerCursor'] as String? ?? '',
      hasOlder: json['hasOlder'] as bool? ?? false,
      hasNewer: json['hasNewer'] as bool? ?? false,
    );

Map<String, dynamic> _$MessagesWindowToJson(_MessagesWindow instance) =>
    <String, dynamic>{
      'data': instance.messages.map((e) => e.toJson()).toList(),
      'targetId': instance.targetId,
      'olderCursor': instance.olderCursor,
      'newerCursor': instance.newerCursor,
      'hasOlder': instance.hasOlder,
      'hasNewer': instance.hasNewer,
    };

_TranscriptAnchor _$TranscriptAnchorFromJson(Map<String, dynamic> json) =>
    _TranscriptAnchor(
      kind: json['kind'] as String,
      messageId: json['messageId'] as String? ?? '',
      blockId: json['blockId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      at: DateTime.parse(json['at'] as String),
    );

Map<String, dynamic> _$TranscriptAnchorToJson(_TranscriptAnchor instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'messageId': instance.messageId,
      'blockId': instance.blockId,
      'title': instance.title,
      'count': instance.count,
      'at': instance.at.toIso8601String(),
    };
