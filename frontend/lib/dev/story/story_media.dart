/// A zero-backend [MediaSource] for the story dataset. Attachment ids in the story fixtures (chat
/// attachments, generated images, document media) resolve to PNGs painted at runtime — deterministic
/// per id, so screenshots are stable and the repo ships no binary fixtures. Anything that is not an image
/// still gets a small valid PNG rather than a broken card.
///
/// story 数据集的零后端 [MediaSource]。故事里的附件 id（对话附件、生成图、文档媒体）解析为运行时绘制的 PNG——
/// 按 id 确定，截图稳定，仓库不带二进制 fixture。非图片 id 也返回一张有效的小 PNG，避免破卡。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/contract/attachment.dart';
import '../../core/media/media_source.dart';
import '../../core/net/api_client.dart';

class StoryMediaSource implements MediaSource {
  StoryMediaSource();

  final Map<String, Future<Uint8List>> _cache = {};

  static const _w = 1600;
  static const _h = 1000;

  @override
  Future<AttachmentMeta> meta(String id) async => AttachmentMeta(
    id: id,
    filename: '$id.png',
    mimeType: 'image/png',
    sizeBytes: (await bytes(id)).length,
    kind: 'image',
  );

  @override
  Future<List<int>> bytes(String id) =>
      _cache.putIfAbsent(id, () => _paint(id));

  @override
  NativeFetchTarget nativeTarget(String id) =>
      NativeFetchTarget(uri: 'story://media/$id', headers: const {});

  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => AttachmentMeta(
    id: 'att_story_upload',
    filename: filename,
    mimeType: mimeType,
    sizeBytes: bytes.length,
    kind: mimeType.startsWith('image/') ? 'image' : 'other',
  );

  @override
  Future<bool> readAloudAvailable() async => true;

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      const ReadAloudResult(
        attachmentId: 'att_story_speech',
        mimeType: 'audio/mpeg',
      );

  // A soft "product screenshot"-like composition: a tinted ground, an island card, a few bars whose
  // heights derive from the id hash. Muted palette on purpose — it must not fight the real UI around it.
  // 类产品图的柔和构图：底色、岛卡、几根由 id 哈希决定高度的柱。刻意低饱和，不与周围真实 UI 抢戏。
  static Future<Uint8List> _paint(String id) async {
    final seed = id.codeUnits.fold<int>(
      17,
      (a, c) => (a * 31 + c) & 0x7fffffff,
    );
    final hue = (seed % 360).toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final ground = ui.Paint()..color = _hsl(hue, 0.35, 0.92);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      ground,
    );
    final card = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(120, 120, _w - 240.0, _h - 240.0),
      const ui.Radius.circular(40),
    );
    canvas.drawRRect(card, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    final bars = 6 + seed % 5;
    final slot = (_w - 360) / bars;
    for (var i = 0; i < bars; i++) {
      final v = ((seed >> (i * 3)) & 0x3f) / 63.0;
      final h = 120 + v * (_h - 520);
      final rect = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(180 + i * slot, _h - 200 - h, slot * 0.62, h),
        const ui.Radius.circular(18),
      );
      canvas.drawRRect(
        rect,
        ui.Paint()..color = _hsl(hue, 0.55, 0.42 + v * 0.25),
      );
    }
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(180, 180, 420, 36),
        const ui.Radius.circular(18),
      ),
      ui.Paint()..color = _hsl(hue, 0.15, 0.80),
    );
    final image = await recorder.endRecording().toImage(_w, _h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static ui.Color _hsl(double h, double s, double l) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    final (r, g, b) = switch ((h / 60).floor() % 6) {
      0 => (c, x, 0.0),
      1 => (x, c, 0.0),
      2 => (0.0, c, x),
      3 => (0.0, x, c),
      4 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    return ui.Color.fromARGB(
      255,
      ((r + m) * 255).round(),
      ((g + m) * 255).round(),
      ((b + m) * 255).round(),
    );
  }
}
