// Dev screenshot harness for F09 get-record cards (B5.8) — NOT part of the gate. Run:
//   flutter test test/dev/capture_dossier.dart
// Expands each dossier to show head/input/output/logs/provenance → out/dossier.png. F09 卷宗截图夹具。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/dev/gallery/tool_card_dossier_specimens.dart';
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

  testWidgets('capture dossier cards', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 3400);
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
                  for (final s in toolCardDossierGalleryItem.specimens) ...[
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
    // Expand the OK fn card (index 0 only — the failed fnexec_bad@1 auto-expands; tapping it would
    // collapse it), the hd call, and both activations. failed mcp auto-expands. 只点非失败卡。
    await tester.tap(find.text('已调阅函数执行档案').at(0), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 80));
    for (final v in ['已调阅处理器调用档案', '已调阅活动档案']) {
      for (var i = 0; i < find.text(v).evaluate().length; i++) {
        await tester.ensureVisible(find.text(v).at(i));
        await tester.tap(find.text(v).at(i), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 80));
      }
    }
    // Open every log drawer to show the double-ended cap + the mcp stderr segment. 打开日志抽屉。
    for (var i = 0; i < find.text(t.chat.tool.dossierLogs).evaluate().length; i++) {
      await tester.ensureVisible(find.text(t.chat.tool.dossierLogs).at(i));
      await tester.tap(find.text(t.chat.tool.dossierLogs).at(i), warnIfMissed: false);
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
    File('${dir.path}/dossier.png').writeAsBytesSync(bytes);
  });
}
