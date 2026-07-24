import 'package:flutter/widgets.dart' show ImageProvider, VoidCallback;

import '../../../core/contract/attachment.dart';
import '../../../core/model/byte_format.dart';
import '../../../core/ui/an_attachment_card.dart' show AnAttachmentState;
import '../../../i18n/strings.g.dart';

/// The sent-bubble view of one attachment — resolved metadata + (for images) a decoded thumb source. The
/// RESOLVER (data layer, lands with transcript assembly) produces these; fixtures/gallery hand-build them.
/// Order in the list = `attrs.attachments` order (the backend preserves send order).
///
/// 一条已发送附件的泡内视图——已解析元数据 + (图片)缩略图源。解析器(数据层,随 transcript 组装落)产出;
/// fixture/gallery 手拼。列表序 = attrs.attachments 序(后端保序)。
class UserAttachment {
  const UserAttachment({
    required this.id,
    required this.kind,
    required this.filename,
    this.mimeType,
    this.sizeBytes,
    this.durationMs,
    this.preparation,
    this.playbackProgress = 0,
    this.playing = false,
    this.state = AnAttachmentState.ready,
    this.thumb,
    this.onPlayTap,
    this.onTap,
  });

  final String id;

  /// Backend kind wire value: image|document|text|audio|video|other. 后端 kind 线缆值。
  final String kind;
  final String filename;
  final String? mimeType;
  final int? sizeBytes;
  final int? durationMs;
  final AttachmentPreparation? preparation;
  final double playbackProgress;
  final bool playing;
  final AnAttachmentState state;

  /// Decoded image source (kind==image, fetched from the loopback content endpoint — never a remote URL).
  /// 缩略图源(仅 image;来自 loopback 内容端点,绝非远程 URL)。
  final ImageProvider? thumb;

  /// Playback toggle for audio attachments. Null means playback is not wired yet and the audio card
  /// must render an honest unavailable state instead of an inert-looking play action.
  /// 音频附件播放切换。null 表示播放尚未接入，音频卡必须诚实显示不可播放，而不是给一个假按钮。
  final VoidCallback? onPlayTap;

  /// ready=open (right island later) / failed=retry / oversized=load. 打开/重试/加载。
  final VoidCallback? onTap;

  /// Renders as an inline image thumb (vs a file card): a READY image with bytes to show. Oversized /
  /// failed / missing images fall back to the card form (honest, no phantom picture box).
  /// 以图瓦片渲染(否则文件卡):ready 且有图源。超大/失败/missing 的图回落文件卡(诚实,不渲幽灵图框)。
  bool get rendersAsThumb =>
      kind == 'image' && state == AnAttachmentState.ready && thumb != null;
}

/// mm:ss / h:mm:ss audio duration label. Null or negative means unknown.
/// 音频时长标签；null/负数表示未知。
String? audioDurationLabel(int? durationMs) {
  if (durationMs == null || durationMs < 0) return null;
  final total = (durationMs / 1000).round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

/// The card's "TYPE · SIZE" meta line — extension from the filename (fallback: the mime subtype),
/// human-readable size. Pure; unit-tested. 卡的「类型·大小」行——扩展名取自文件名(兜底 mime 子类型),人话大小。
String attachmentMetaLine({
  required String filename,
  String? mimeType,
  int? sizeBytes,
}) {
  final parts = <String>[];
  final dot = filename.lastIndexOf('.');
  final ext = (dot > 0 && filename.length - dot - 1 <= 8)
      ? filename.substring(dot + 1)
      : '';
  if (ext.isNotEmpty) {
    parts.add(ext.toUpperCase());
  } else {
    final slash = (mimeType ?? '').lastIndexOf('/');
    if (slash > 0) parts.add(mimeType!.substring(slash + 1).toUpperCase());
  }
  if (sizeBytes != null && sizeBytes >= 0) parts.add(formatBytes(sizeBytes));
  return parts.join(' · ');
}

/// Stable media-preparation sidecar line for sent attachments. The backend owns the state; the UI renders
/// only coarse honest phases and never invents a percentage. Ready/not-required are intentionally silent.
/// 已发送附件的媒体准备侧车文案。状态归后端；UI 只呈现粗粒度诚实阶段，绝不伪造百分比。ready/not_required 静默。
String? attachmentPreparationLine(
  Translations t,
  AttachmentPreparation? preparation,
) {
  final p = preparation;
  if (p == null) return null;
  final status = p.status;
  final phase = p.phase;
  if (status == 'failed' || phase == 'failed') {
    return t.attach.mediaPreparationFailed;
  }
  if (status == 'cancelled' || phase == 'cancelled') {
    return t.attach.mediaPreparationCancelled;
  }
  if (status == 'unavailable' || phase == 'unavailable') {
    return t.attach.mediaPreparationUnavailable;
  }
  if (status == 'queued' ||
      status == 'processing' ||
      status == 'pending' ||
      status == 'running' ||
      phase == 'queued' ||
      phase == 'processing' ||
      phase == 'pending' ||
      phase == 'running') {
    return t.attach.preparingMedia;
  }
  return null;
}
