import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment.freezed.dart';
part 'attachment.g.dart';

/// An attachment row — the exact projection of the backend DTO (`POST /attachments` 201 / `GET
/// /attachments/{id}`): id (`att_`), content sha256, original filename, stored mime, byte size, and the
/// 6-value `kind` the backend classifies (image|document|text|audio|video|other — an OPEN string here:
/// the vocabulary may grow, unknown renders as a generic file). Raw bytes live at `/{id}/content`.
///
/// 附件行——后端 DTO 精确投影:id(att_)/内容 sha256/原始文件名/存储 mime/字节数/后端归类的 6 值 `kind`
/// (开放字符串:词表可长,未知渲通用文件)。原始字节在 `/{id}/content`。
@freezed
abstract class AttachmentMeta with _$AttachmentMeta {
  const factory AttachmentMeta({
    required String id,
    @Default('') String sha256,
    @Default('') String filename,
    @Default('') String mimeType,
    @Default(0) int sizeBytes,
    @Default('other') String kind,
    DateTime? createdAt,
  }) = _AttachmentMeta;

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) =>
      _$AttachmentMetaFromJson(json);
}
