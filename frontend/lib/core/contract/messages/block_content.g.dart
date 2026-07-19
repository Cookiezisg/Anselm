// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'block_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TextContent _$TextContentFromJson(Map<String, dynamic> json) => _TextContent(
  content: json['content'] as String? ?? '',
  signature: json['signature'] as String?,
);

Map<String, dynamic> _$TextContentToJson(_TextContent instance) =>
    <String, dynamic>{
      'content': instance.content,
      'signature': instance.signature,
    };

_ToolCallContent _$ToolCallContentFromJson(Map<String, dynamic> json) =>
    _ToolCallContent(
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] as String?,
      summary: json['summary'] as String?,
      danger: json['danger'] as String?,
      entityName: json['entityName'] as String?,
    );

Map<String, dynamic> _$ToolCallContentToJson(_ToolCallContent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'arguments': instance.arguments,
      'summary': instance.summary,
      'danger': instance.danger,
      'entityName': instance.entityName,
    };

_ToolResultContent _$ToolResultContentFromJson(Map<String, dynamic> json) =>
    _ToolResultContent(content: json['content'] as String? ?? '');

Map<String, dynamic> _$ToolResultContentToJson(_ToolResultContent instance) =>
    <String, dynamic>{'content': instance.content};

_MessageContent _$MessageContentFromJson(Map<String, dynamic> json) =>
    _MessageContent(
      role: json['role'] as String? ?? '',
      subagent: json['subagent'] as bool?,
      content: json['content'] as String?,
      status: json['status'] as String?,
      stopReason: json['stopReason'] as String?,
      inputTokens: (json['inputTokens'] as num?)?.toInt(),
      outputTokens: (json['outputTokens'] as num?)?.toInt(),
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$MessageContentToJson(_MessageContent instance) =>
    <String, dynamic>{
      'role': instance.role,
      'subagent': instance.subagent,
      'content': instance.content,
      'status': instance.status,
      'stopReason': instance.stopReason,
      'inputTokens': instance.inputTokens,
      'outputTokens': instance.outputTokens,
      'errorCode': instance.errorCode,
      'errorMessage': instance.errorMessage,
    };
