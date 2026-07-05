// Type-ladder DESIGN SPECIMEN — three candidate reading-body sizes side by side (13 = today / 15 =
// proposed / 16 = upper bound), each under the SAME 13px nav row for contrast, so the "nav vs prose"
// relationship is judged visually before any token changes. NOT part of the gate.
// 字号阶梯设计样张:三档正文字号并排(13=现状/15=提案/16=上限),每列顶同一条 13px 导航行作参照,先看后拍板。
// Run: flutter test test/dev/capture_type_ladder.dart → test/dev/out/type_ladder.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture type ladder specimen', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1500, 980);
    addTearDown(tester.view.reset);

    TextStyle w(double size, {double h = 1.6, FontWeight fw = FontWeight.w300, double? ls}) => TextStyle(
          fontFamily: AnText.uiFamily,
          fontFamilyFallback: AnText.uiFallback,
          fontSize: size,
          height: h,
          fontWeight: fw,
          fontVariations: [FontVariation('wght', fw == FontWeight.w300 ? 300 : 400)],
          letterSpacing: ls,
        );

    Widget navRow(AnColors c) => Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
          decoration: BoxDecoration(
            color: c.surfaceActive,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Row(children: [
            Icon(AnIcons.doc, size: AnSize.icon, color: c.inkFaint),
            const SizedBox(width: AnSpace.s8),
            Text('Getting Started', style: w(13, h: 1.4).copyWith(color: c.ink)),
            const Spacer(),
            Text('导航 13', style: w(11, h: 1.4).copyWith(color: c.inkFaint)),
          ]),
        );

    Widget column(AnColors c,
        {required String tag,
        required bool pick,
        required double body,
        required double h3,
        required double h2s,
        required double h1s}) {
      final bodyStyle = w(body).copyWith(color: c.ink);
      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: pick ? c.accent : c.line, width: pick ? 1.5 : 1),
            borderRadius: BorderRadius.circular(AnRadius.card),
          ),
          padding: const EdgeInsets.all(AnSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(tag, style: w(12, h: 1.4, fw: FontWeight.w400).copyWith(color: pick ? c.accent : c.inkFaint)),
              ]),
              const SizedBox(height: AnSpace.s12),
              navRow(c),
              const SizedBox(height: AnSpace.s16),
              Text('Concepts', style: w(24, h: 1.25, fw: FontWeight.w400, ls: -0.3).copyWith(color: c.ink)),
              const SizedBox(height: AnSpace.s16),
              Text(
                'Two ideas carry the whole system: the Quadrinity entity model and durable execution. '
                '两个想法承载整个系统:四项全能实体模型与持久执行。',
                style: bodyStyle,
              ),
              const SizedBox(height: AnSpace.s12),
              Text('The Quadrinity(h2 $h2s)',
                  style: w(h2s, h: 1.4, fw: FontWeight.w400).copyWith(color: c.ink)),
              const SizedBox(height: AnSpace.s12),
              Text(
                'Every capability belongs to exactly one of four kinds — a Function is pure code, '
                'versioned and sandboxed; a Handler connects the outside world.',
                style: bodyStyle,
              ),
              const SizedBox(height: AnSpace.s12),
              Text('Why four(h3 $h3)', style: w(h3, h: 1.5, fw: FontWeight.w400).copyWith(color: c.ink)),
              const SizedBox(height: AnSpace.s8),
              Text.rich(
                TextSpan(style: bodyStyle, children: [
                  const TextSpan(text: 'Each kind has a distinct lifecycle: run '),
                  TextSpan(
                    text: 'make verify',
                    style: AnText.mono.copyWith(color: c.ink, backgroundColor: c.surfaceSunken),
                  ),
                  const TextSpan(text: ' before every push. 层级靠字号与颜色,不靠更重的字重。'),
                ]),
              ),
              const Spacer(),
              Text('正文 $body · h3 $h3 · h2 $h2s · 文档内 h1 $h1s · 页标题 24',
                  style: w(11, h: 1.4).copyWith(color: c.inkFaint)),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Builder(builder: (context) {
          final c = context.colors;
          return Scaffold(
            backgroundColor: c.surfaceSunken,
            body: Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  column(c, tag: 'A · 现状', pick: false, body: 13, h3: 13, h2s: 16, h1s: 20),
                  const SizedBox(width: AnSpace.s16),
                  column(c, tag: 'B · 提案(推荐)', pick: true, body: 15, h3: 15, h2s: 18, h1s: 22),
                  const SizedBox(width: AnSpace.s16),
                  column(c, tag: 'C · 上限', pick: false, body: 16, h3: 16, h2s: 19, h1s: 23),
                ],
              ),
            ),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    Directory('test/dev/out').createSync(recursive: true);
    File('test/dev/out/type_ladder.png').writeAsBytesSync(bytes);
  });
}
