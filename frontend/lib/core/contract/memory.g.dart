// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Memory _$MemoryFromJson(Map<String, dynamic> json) => _Memory(
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  content: json['content'] as String? ?? '',
  pinned: json['pinned'] as bool? ?? false,
  source: json['source'] as String? ?? 'user',
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MemoryToJson(_Memory instance) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'content': instance.content,
  'pinned': instance.pinned,
  'source': instance.source,
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
