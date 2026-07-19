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
class AttachmentImageProvider extends ImageProvider<AttachmentImageProvider> {
  const AttachmentImageProvider(this.id, {required this.fetch});

  final String id;
  final Future<List<int>> Function() fetch;

  @override
  Future<AttachmentImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(AttachmentImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: 'attachment:$id',
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await fetch();
    if (bytes.isEmpty) throw StateError('attachment $id has no content');
    return decode(await ui.ImmutableBuffer.fromUint8List(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes)));
  }

  // Identity by id — the ImageCache dedupe axis. 以 id 为身份=缓存去重轴。
  @override
  bool operator ==(Object other) => other is AttachmentImageProvider && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
