// WRK-082 B1 人眼验收:把「人眼侧」那五格各截一张,供人真的看一眼。
//
// 终点验收 §0.2 的每一行都分两半记:模型侧(机器可判,H7 真钱验收已覆盖)与人眼侧(渲染/交互)。
// 模型侧全过**不代表**用户看得见——`ToolResultContentParts` 把像素送进了 prompt,和一张图在
// transcript 里长什么样,是两件毫无关系的事。这个夹具产出的是后者的证据。
//
// **它刻意不是断言测试。** 断言只能证「某个 widget 在树里」,而这五格要问的恰恰是断言问不出的东西:
// 图有没有糊、卡片有没有挤成一团、播放按钮认不认得出来。故本文件只产 PNG,判断留给看图的人。
// 因此它也**不入 `make -C frontend verify`**(与 capture_demo / capture_example 同族,按需手跑)。
//
// The B1 human-eye pass: five PNGs, one per unverified acceptance cell. Deliberately NOT an
// assertion test — assertions can only prove a widget is in the tree, and these five cells ask
// exactly what assertions cannot: is the image sharp, is the card cramped, is the play button
// recognizable. Output is pixels; the judgement belongs to whoever looks at them.
//
// 跑:`cd frontend && mise exec -- flutter test test/dev/capture_media_b1.dart`
//     → `frontend/test/dev/out/b1_*.png`
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/media/media_cards.dart';
import 'package:anselm/core/media/media_ref.dart';
import 'package:anselm/core/media/media_source.dart';
import 'package:anselm/core/net/api_client.dart' show NativeFetchTarget;
import 'package:anselm/core/ui/an_audio_attachment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_support.dart';

const _imageId = 'att_b1000000000000aa';
const _chartId = 'att_b1000000000000bb';
const _audioId = 'att_b1000000000000cc';
const _videoId = 'att_b1000000000000dd';

/// A real bar chart drawn on a real canvas — NOT a solid colour block. The cell being verified is
/// "a chart produced by a function is legible in the card", and a flat rectangle would render
/// perfectly at any resolution while telling us nothing about whether a chart does.
///
/// 一张画在真 canvas 上的真柱状图——**不是**一块纯色。这一格要验的是「函数产出的图表在卡里看得清」,
/// 而一块纯色矩形在任何分辨率下都渲得完美、却对「图表能不能看清」一个字都没说。
Future<Uint8List> _chartPng() async {
  const w = 640.0, h = 400.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final axis = Paint()
    ..color = const Color(0xFF8A8A8A)
    ..strokeWidth = 1.5;
  canvas.drawLine(const Offset(64, 40), const Offset(64, 340), axis);
  canvas.drawLine(const Offset(64, 340), const Offset(600, 340), axis);

  const values = [12, 19, 7, 23, 15];
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  final bar = Paint()..color = const Color(0xFF4C78A8);
  for (var i = 0; i < values.length; i++) {
    final x = 96.0 + i * 100;
    final barH = values[i] / 25 * 280;
    canvas.drawRect(Rect.fromLTWH(x, 340 - barH, 56, barH), bar);
    _text(canvas, labels[i], Offset(x + 8, 348), 16, const Color(0xFF333333));
    _text(
      canvas,
      '${values[i]}',
      Offset(x + 16, 340 - barH - 22),
      15,
      const Color(0xFF444444),
    );
  }
  _text(
    canvas,
    'Weekly builds',
    const Offset(64, 10),
    22,
    const Color(0xFF111111),
  );

  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return png!.buffer.asUint8List();
}

void _text(Canvas c, String s, Offset at, double size, Color color) {
  // Name a family that loadAppFonts actually registered. A raw ParagraphBuilder does NOT inherit the
  // app's text theme, and the test environment's default family resolves to nothing — leaving every
  // label as a tofu block. That would be MY fixture's defect masquerading as a rendering finding.
  // 必须点名 loadAppFonts 真注册过的 family。裸 ParagraphBuilder **不**继承 app 文字主题,而测试环境
  // 的默认 family 解析不到任何字体——于是每个标签都成了豆腐块,那会让**我夹具的缺陷**冒充渲染发现。
  final p =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(fontSize: size, fontFamily: 'Inter'),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(s);
  final para = p.build()..layout(const ui.ParagraphConstraints(width: 300));
  c.drawParagraph(para, at);
}

/// The platform media seam, fed fixtures. Overriding HERE (not the per-card providers) is the point:
/// every surface below reaches media through this one port, so one stub drives all five captures.
///
/// 平台媒体缝,喂 fixture。**在这里**覆盖(而非逐卡 provider)正是要点:下面每个面都经这一个端口取媒体,
/// 故一个 stub 驱动全部五张截图。
class _FixtureSource implements MediaSource {
  _FixtureSource(this._chart);
  final Uint8List _chart;

  static const _rows = {
    _imageId: AttachmentMeta(
      id: _imageId,
      filename: 'lighthouse-at-dusk.png',
      mimeType: 'image/png',
      sizeBytes: 1523916,
      kind: 'image',
    ),
    _chartId: AttachmentMeta(
      id: _chartId,
      filename: 'weekly-builds.png',
      mimeType: 'image/png',
      sizeBytes: 10478,
      kind: 'image',
    ),
    _audioId: AttachmentMeta(
      id: _audioId,
      filename: 'read-aloud.wav',
      mimeType: 'audio/wav',
      sizeBytes: 286720,
      kind: 'audio',
    ),
    _videoId: AttachmentMeta(
      id: _videoId,
      filename: 'a-boat-leaving-harbour.mp4',
      mimeType: 'video/mp4',
      sizeBytes: 3355443,
      kind: 'video',
    ),
  };

  @override
  Future<AttachmentMeta> meta(String id) async =>
      _rows[id] ?? AttachmentMeta(id: id);

  @override
  Future<List<int>> bytes(String id) async => _chart;

  @override
  NativeFetchTarget nativeTarget(String id) =>
      const NativeFetchTarget(uri: 'http://127.0.0.1:0/stub', headers: {});

  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => throw UnimplementedError();

  @override
  Future<bool> readAloudAvailable() async => true;

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      const ReadAloudResult(attachmentId: _audioId, mimeType: 'audio/wav');
}

/// One labelled slab per capture, so a reader can tell WHICH cell a PNG is without opening the source.
/// 每张截图配一条标题带,使看图的人不必开源码就知道这是哪一格。
Widget _slab(String title, Widget child) => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.all(AnSpace.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AnText.label.copyWith(color: context.colors.inkMuted),
        ),
        const SizedBox(height: AnSpace.s8),
        child,
      ],
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  late Uint8List chart;

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Size size,
    Widget body,
  ) async {
    setCaptureSurface(tester, size);
    await tester.runAsync(() async => chart = await _chartPng());
    await tester.pumpWidget(
      CaptureHost(
        overrides: [
          mediaSourceProvider.overrideWithValue(_FixtureSource(chart)),
        ],
        home: body,
      ),
    );
    // Decoding real bytes needs a real event loop: pumpAndSettle alone leaves the image at its
    // placeholder frame, and the shot would then "prove" a grey box.
    // 解真字节需要真事件循环:只 pumpAndSettle 会停在占位帧,那张截图就成了「证明有个灰块」。
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await capturePng(tester, name);
  }

  testWidgets('b1_1 chat 生成图工具卡', (tester) async {
    await shoot(
      tester,
      'b1_1_chat_generated_image',
      const Size(520, 560),
      _slab(
        '① chat 里「画一张…」的产物卡(generate_image 族体)',
        const AnMediaRefCard(
          mediaRef: AnMediaRef(
            attachmentId: _imageId,
            width: 1536,
            height: 1024,
          ),
        ),
      ),
    );
  });

  testWidgets('b1_2 函数图表产物卡', (tester) async {
    await shoot(
      tester,
      'b1_2_function_chart',
      const Size(560, 560),
      _slab(
        '③ fn 跑 matplotlib 的图表产物(整份结果 payload 递给 AnMediaRefStrip)',
        const AnMediaRefStrip(
          payload: {
            'text':
                '{"attachmentId":"$_chartId","mime":"image/png",'
                '"source":"function_artifact"}',
          },
          maxWidth: 420,
        ),
      ),
    );
  });

  testWidgets('b1_3 朗读音频卡三态', (tester) async {
    await shoot(
      tester,
      'b1_3_read_aloud_audio',
      const Size(520, 460),
      // onPlayTap must be non-null or the card is by contract NOT playable and says so
      // (`audioPlaybackUnavailable`) — a fixture that omits it screenshots the unavailable face and
      // then blames the widget. 必须给 onPlayTap,否则卡按契约就是**不可播**并明说;省掉它等于截了
      // 「不可用」那一态,再去怪 widget。
      _slab(
        '④ 朗读产物:空闲 / 加载中 / 播放中(带进度)',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnAudioAttachmentCard(
              filename: 'read-aloud.wav',
              metaLine: '280 KB',
              durationLabel: '0:12',
              onPlayTap: () {},
            ),
            const SizedBox(height: AnSpace.s12),
            AnAudioAttachmentCard(
              filename: 'read-aloud.wav',
              metaLine: '280 KB',
              durationLabel: '0:12',
              busy: true,
              onPlayTap: () {},
            ),
            const SizedBox(height: AnSpace.s12),
            AnAudioAttachmentCard(
              filename: 'read-aloud.wav',
              metaLine: '280 KB',
              durationLabel: '0:05',
              playing: true,
              progress: 0.42,
              onPlayTap: () {},
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('b1_4 视频卡未播放态', (tester) async {
    await shoot(
      tester,
      'b1_4_video_card',
      const Size(520, 420),
      _slab(
        '⑤ 直连生成的视频产物(播放器只在点击时才构造,故这是用户先看到的那一态)',
        const AnMediaRefCard(mediaRef: AnMediaRef(attachmentId: _videoId)),
      ),
    );
  });

  testWidgets('b1_5 编辑器里的图', (tester) async {
    await shoot(
      tester,
      'b1_5_editor_image',
      const Size(800, 900),
      _slab(
        '⑥ 文档正文里的图(编辑器把 AnSize.content 宽交给同一族卡)',
        const SizedBox(
          width: AnSize.content,
          child: AnMediaRefCard(
            mediaRef: AnMediaRef(attachmentId: _chartId),
            maxWidth: AnSize.content,
          ),
        ),
      ),
    );
  });
}
