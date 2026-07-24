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
      preparation: json['preparation'] == null
          ? null
          : AttachmentPreparation.fromJson(
              json['preparation'] as Map<String, dynamic>,
            ),
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
      'preparation': instance.preparation?.toJson(),
    };

_AttachmentPreparation _$AttachmentPreparationFromJson(
  Map<String, dynamic> json,
) => _AttachmentPreparation(
  status: json['status'] as String? ?? 'not_required',
  target: json['target'] as String? ?? '',
  width: (json['width'] as num?)?.toInt() ?? 0,
  height: (json['height'] as num?)?.toInt() ?? 0,
  mimeType: json['mimeType'] as String? ?? '',
  sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
  errorCode: json['errorCode'] as String? ?? '',
);

Map<String, dynamic> _$AttachmentPreparationToJson(
  _AttachmentPreparation instance,
) => <String, dynamic>{
  'status': instance.status,
  'target': instance.target,
  'width': instance.width,
  'height': instance.height,
  'mimeType': instance.mimeType,
  'sizeBytes': instance.sizeBytes,
  'errorCode': instance.errorCode,
};
