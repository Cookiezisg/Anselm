// Dev screenshot harness for F08 exec cards (B5.1) — NOT part of the gate. Run:
//   flutter test test/dev/capture_exec.dart
// Expands each exec card to show ToolIOSection + logs + exec bar → out/exec.png. F08 执行卡截图夹具(非门禁)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/dev/gallery/tool_card_exec_specimens.dart';
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

  testWidgets('capture exec cards', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 4200);
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
                  for (final s in toolCardExecGalleryItem.specimens) ...[
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
    // Expand the two OK run_function cards (at 0,1); the failed one (at 2) auto-expands via resultFailed.
    // 展开两张成功 run_function;失败那张经 resultFailed 自动展开、勿再点(会收起)。
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('已运行函数').at(i), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 80));
    }
    final ch = find.text('已调用方法').evaluate().length;
    for (var i = 0; i < ch; i++) {
      await tester.tap(find.text('已调用方法').at(i), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.ensureVisible(find.text('已触发').first);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('已触发').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 80));
    // invoke_agent: expand ok-prose@0, ok-object@1, cancelled@3; failed@2 auto-expands. invoke 展开非失败。
    for (final i in [0, 1, 3]) {
      await tester.ensureVisible(find.text('已调用智能体').at(i));
      await tester.tap(find.text('已调用智能体').at(i), warnIfMissed: false);
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
    File('${dir.path}/exec.png').writeAsBytesSync(bytes);
  });
}
