import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anselm/features/chat/data/attachment_image_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// R2 — decode-time downsampling: a provider with [targetWidth] must decode a wide source AT the
// cap (aspect kept), never upscale a narrow one, and carry the cap in its cache identity (one id
// at two targets = two bitmaps, no collision). R2:解码期下采样——宽源按上限解码(保纵横比)、
// 窄源绝不放大、上限入缓存键(同 id 两目标=两位图,不得撞)。
void main() {
  // A real PNG of the given size, generated in-process (no fixtures on disk). 程序内生成真 PNG。
  Future<Uint8List> pngOf(int w, int h) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF336699),
    );
    final img = await recorder.endRecording().toImage(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes!.buffer.asUint8List();
  }

  Future<ui.Image> decodeVia(AttachmentImageProvider p) async {
    final completer = p.loadImage(
      p,
      PaintingBinding.instance.instantiateImageCodecWithSize,
    );
    final done = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) => done.complete(info.image),
      onError: (e, st) => done.completeError(e, st),
    );
    completer.addListener(listener);
    final img = await done.future;
    completer.removeListener(listener);
    return img;
  }

  testWidgets('a wide source decodes AT the cap, aspect kept', (tester) async {
    await tester.runAsync(() async {
      final bytes = await pngOf(800, 400);
      final p = AttachmentImageProvider(
        'att_wide',
        fetch: () async => bytes,
        targetWidth: 200,
      );
      final img = await decodeVia(p);
      expect(img.width, 200);
      expect(img.height, 100, reason: 'aspect ratio must survive the cap');
    });
  });

  testWidgets('a narrow source is never upscaled', (tester) async {
    await tester.runAsync(() async {
      final bytes = await pngOf(120, 90);
      final p = AttachmentImageProvider(
        'att_narrow',
        fetch: () async => bytes,
        targetWidth: 500,
      );
      final img = await decodeVia(p);
      expect(img.width, 120);
      expect(img.height, 90);
    });
  });

  test('the decode cap rides the cache identity', () {
    Future<List<int>> fetch() async => const <int>[];
    final full = AttachmentImageProvider('att_x', fetch: fetch);
    final capped = AttachmentImageProvider(
      'att_x',
      fetch: fetch,
      targetWidth: 560,
    );
    final cappedToo = AttachmentImageProvider(
      'att_x',
      fetch: fetch,
      targetWidth: 560,
    );
    expect(capped, equals(cappedToo));
    expect(capped.hashCode, cappedToo.hashCode);
    expect(
      full,
      isNot(equals(capped)),
      reason: 'full vs capped are different bitmaps',
    );
  });
}
