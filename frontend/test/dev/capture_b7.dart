// Dev screenshot harness for B7 生态收尾 cards (todo + relations/capability/mcp/model) — NOT the gate.
//   flutter test test/dev/capture_b7.dart  → out/b7.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/dev/gallery/tool_card_ecosystem_specimens.dart';
import 'package:anselm/dev/gallery/tool_card_todo_specimens.dart';
import 'package:anselm/dev/gallery/specimen.dart';
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

  testWidgets('capture b7 cards', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 4200);
    addTearDown(tester.view.reset);

    final specimens = <GallerySpecimen>[...toolCardTodoGalleryItem.specimens, ...toolCardEcosystemGalleryItem.specimens];
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
                  for (final s in specimens) ...[
                    Builder(builder: (context) => Text(s.label, style: AnText.meta.copyWith(color: Theme.of(context).colorScheme.outline))),
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
    // Expand all settled cards (the failed capability/mcp auto-expand; tapping them would toggle — so
    // tap by verb but skip re-toggling auto-expanded ones is complex; tap each verb's cards once).
    for (final v in ['已更新任务清单', '已读取任务清单', '已查关系', '已体检工作流', '已重连 MCP', '已浏览市场', '已读模型配置']) {
      for (var i = 0; i < find.text(v).evaluate().length; i++) {
        await tester.ensureVisible(find.text(v).at(i));
        await tester.tap(find.text(v).at(i), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 60));
      }
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
    File('${dir.path}/b7.png').writeAsBytesSync(bytes);
  });
}
