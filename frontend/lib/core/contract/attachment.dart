import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment.freezed.dart';
part 'attachment.g.dart';

/// An attachment row — the exact projection of the backend DTO (`POST /attachments` 201 / `GET
/// /attachments/{id}`): id (`att_`), content sha256, original filename, stored mime, byte size, the
/// 6-value `kind` the backend classifies (image|document|text|audio|video|other — an OPEN string here:
/// the vocabulary may grow, unknown renders as a generic file), and optional app-managed preparation
/// status for media proxies. Raw bytes live at `/{id}/content`.
///
/// 附件行——后端 DTO 精确投影:id(att_)/内容 sha256/原始文件名/存储 mime/字节数/后端归类的 6 值 `kind`
/// (开放字符串:词表可长,未知渲通用文件)+ 可选媒体代理准备状态。原始字节在 `/{id}/content`。
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
    AttachmentPreparation? preparation,
  }) = _AttachmentMeta;

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) =>
      _$AttachmentMetaFromJson(json);
}

/// App-managed media preparation for an attachment. Images currently report the model-default proxy
/// lifecycle (`pending|running|ready|failed`); non-media or not-yet-managed media returns `not_required`.
/// `unavailable` means the sidecar status query failed but the attachment metadata is still usable.
///
/// 附件的应用侧媒体准备状态。当前 image 报 model-default 代理生命周期；非媒体/尚未管理的媒体为
/// `not_required`；`unavailable` 表示状态查询失败但附件元数据仍可用。
@freezed
abstract class AttachmentPreparation with _$AttachmentPreparation {
  const factory AttachmentPreparation({
    @Default('not_required') String status,
    @Default('') String target,
    @Default(0) int width,
    @Default(0) int height,
    @Default('') String mimeType,
    @Default(0) int sizeBytes,
    @Default('') String errorCode,
  }) = _AttachmentPreparation;

  factory AttachmentPreparation.fromJson(Map<String, dynamic> json) =>
      _$AttachmentPreparationFromJson(json);
}
