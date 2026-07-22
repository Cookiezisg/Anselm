import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// An [ImageProvider] that decodes an attachment's bytes from the sidecar (`GET
/// /attachments/{id}/content`) — how the bubble's image thumbnails render. The KEY is the attachment
/// id: attachment rows are immutable, so Flutter's global ImageCache dedupes and re-shows a decoded
/// image for free across rebuilds / thread switches (the sha-keyed-cache idea, with the id standing in
/// for the sha since one id never changes content). The fetch closure keeps this file free of any HTTP
/// dependency — the caller hands in the repository call.
///
/// 从 sidecar 解码附件字节的 ImageProvider——泡内图缩略图的图源。**键=附件 id**(附件行不可变,Flutter 全局
/// ImageCache 据此免费去重复用,id 即内容指纹)。fetch 闭包让本文件零 HTTP 依赖——调用方递入仓储调用。
///
/// [targetWidth] (PHYSICAL px) downsamples at DECODE time: a thumbnail never displays wider than
/// ~280 logical px, but a full-resolution decode of a 4000×3000 phone photo parks ~48MB of RGBA in
/// the global ImageCache (100MB cap — a few photos thrash it) and pays the full-size decode hitch.
/// Capped decode is visually lossless at thumb size and 1-2 orders of magnitude smaller. Never
/// upscales (a source narrower than the target decodes at its own size). The width RIDES THE CACHE
/// KEY — two providers for one id at different targets must not collide on one decoded bitmap.
///
/// targetWidth(物理 px)在**解码期**下采样:缩略图显示宽 ~280 逻辑 px 封顶,而 4000×3000 手机照全
/// 分辨率解码 ≈48MB RGBA 常驻全局 ImageCache(上限 100MB,几张即打爆)+全尺寸解码 hitch。按需解码
/// 在缩略尺寸下视觉无损、内存小 1-2 个数量级;绝不放大(源比目标窄按原尺寸)。宽度**入缓存键**——
/// 同 id 不同目标的两个 provider 不得撞同一张位图。
class AttachmentImageProvider extends ImageProvider<AttachmentImageProvider> {
  const AttachmentImageProvider(this.id, {required this.fetch, this.targetWidth});

  final String id;
  final Future<List<int>> Function() fetch;

  /// Decode-time width cap in PHYSICAL pixels (display logical width × devicePixelRatio); null =
  /// full resolution. 解码期宽上限(物理像素=逻辑宽×dpr);null=全分辨率。
  final int? targetWidth;

  @override
  Future<AttachmentImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    AttachmentImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: 'attachment:$id',
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await fetch();
    if (bytes.isEmpty) throw StateError('attachment $id has no content');
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    );
    final cap = targetWidth;
    if (cap == null) return decode(buffer);
    return decode(
      buffer,
      getTargetSize: (intrinsicWidth, intrinsicHeight) {
        if (intrinsicWidth <= cap) {
          // Never upscale. 绝不放大。
          return ui.TargetImageSize(
            width: intrinsicWidth,
            height: intrinsicHeight,
          );
        }
        // Width-only cap keeps the aspect ratio (the engine derives the height). 只约宽保纵横比。
        return ui.TargetImageSize(width: cap);
      },
    );
  }

  // Identity by id + decode cap — the ImageCache dedupe axis (a capped and a full decode of the
  // same id are DIFFERENT bitmaps). 身份=id+解码上限:同 id 的封顶位图与全图是两张,不得撞键。
  @override
  bool operator ==(Object other) =>
      other is AttachmentImageProvider &&
      other.id == id &&
      other.targetWidth == targetWidth;

  @override
  int get hashCode => Object.hash(id, targetWidth);
}
