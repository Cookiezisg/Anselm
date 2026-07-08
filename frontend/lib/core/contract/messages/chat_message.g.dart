// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatBlock _$ChatBlockFromJson(Map<String, dynamic> json) => _ChatBlock(
  id: json['id'] as String,
  conversationId: json['conversationId'] as String? ?? '',
  messageId: json['messageId'] as String? ?? '',
  parentBlockId: json['parentBlockId'] as String? ?? '',
  seq: (json['seq'] as num?)?.toInt() ?? 0,
  type: json['type'] as String,
  attrs: json['attrs'] as Map<String, dynamic>?,
  content: json['content'] as String? ?? '',
  status: json['status'] as String? ?? '',
  error: json['error'] as String? ?? '',
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ChatBlockToJson(_ChatBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'messageId': instance.messageId,
      'parentBlockId': instance.parentBlockId,
      'seq': instance.seq,
      'type': instance.type,
      'attrs': instance.attrs,
      'content': instance.content,
      'status': instance.status,
      'error': instance.error,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => _ChatMessage(
  id: json['id'] as String,
  conversationId: json['conversationId'] as String? ?? '',
  subagentId: json['subagentId'] as String? ?? '',
  role: json['role'] as String,
  status: json['status'] as String? ?? '',
  stopReason: json['stopReason'] as String? ?? '',
  errorCode: json['errorCode'] as String? ?? '',
  errorMessage: json['errorMessage'] as String? ?? '',
  inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
  outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
  provider: json['provider'] as String? ?? '',
  modelId: json['modelId'] as String? ?? '',
  attrs: json['attrs'] as Map<String, dynamic>?,
  blocks:
      (json['blocks'] as List<dynamic>?)
          ?.map((e) => ChatBlock.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ChatBlock>[],
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ChatMessageToJson(_ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'subagentId': instance.subagentId,
      'role': instance.role,
      'status': instance.status,
      'stopReason': instance.stopReason,
      'errorCode': instance.errorCode,
      'errorMessage': instance.errorMessage,
      'inputTokens': instance.inputTokens,
      'outputTokens': instance.outputTokens,
      'provider': instance.provider,
      'modelId': instance.modelId,
      'attrs': instance.attrs,
      'blocks': instance.blocks.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
