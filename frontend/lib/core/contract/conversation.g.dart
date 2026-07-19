// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Conversation _$ConversationFromJson(Map<String, dynamic> json) =>
    _Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      autoTitled: json['autoTitled'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      modelOverride: json['modelOverride'] == null
          ? null
          : ModelRef.fromJson(json['modelOverride'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      isGenerating: json['isGenerating'] as bool? ?? false,
      awaitingInput: json['awaitingInput'] as bool? ?? false,
      hasUnread: json['hasUnread'] as bool? ?? false,
    );

Map<String, dynamic> _$ConversationToJson(_Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'autoTitled': instance.autoTitled,
      'archived': instance.archived,
      'pinned': instance.pinned,
      'modelOverride': instance.modelOverride?.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'lastMessageAt': instance.lastMessageAt.toIso8601String(),
      'isGenerating': instance.isGenerating,
      'awaitingInput': instance.awaitingInput,
      'hasUnread': instance.hasUnread,
    };

_ModelRef _$ModelRefFromJson(Map<String, dynamic> json) => _ModelRef(
  apiKeyId: json['apiKeyId'] as String? ?? '',
  modelId: json['modelId'] as String? ?? '',
);

Map<String, dynamic> _$ModelRefToJson(_ModelRef instance) => <String, dynamic>{
  'apiKeyId': instance.apiKeyId,
  'modelId': instance.modelId,
};
