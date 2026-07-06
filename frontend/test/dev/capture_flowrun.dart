// Dev screenshot harness for F08 replay_flowrun cards (B5.3) — NOT part of the gate. Run:
//   flutter test test/dev/capture_flowrun.dart
// Expands each replay card to show FlowrunNodeList + footer → out/flowrun.png. F08 replay 截图夹具。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/dev/gallery/tool_card_flowrun_specimens.dart';
import 'package:anselm/i18n/strings.g.dart';
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

  testWidgets('capture flowrun cards', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 2600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AnSpace.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in toolCardFlowrunGalleryItem.specimens) ...[
                    Builder(
                        builder: (context) => Text(s.label,
                            style: AnText.meta.copyWith(color: Theme.of(context).colorScheme.outline))),
                    const SizedBox(height: AnSpace.s6),
                    Builder(builder: (context) => s.builder(context)),
                    const SizedBox(height: AnSpace.s16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 60));
    // Tap the non-failed cards (completed@0, parked@2, capped@3); the failed one (@1) auto-expands.
    // 点非失败卡;失败那张经 resultFailed 自动展开、勿再点。
    for (final i in [0, 2, 3]) {
      await tester.tap(find.text('已重放运行').at(i), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/flowrun.png').writeAsBytesSync(bytes);
  });
}
