// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AttachmentMeta _$AttachmentMetaFromJson(Map<String, dynamic> json) =>
    _AttachmentMeta(
      id: json['id'] as String,
      sha256: json['sha256'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? 'other',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$AttachmentMetaToJson(_AttachmentMeta instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sha256': instance.sha256,
      'filename': instance.filename,
      'mimeType': instance.mimeType,
      'sizeBytes': instance.sizeBytes,
      'kind': instance.kind,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
