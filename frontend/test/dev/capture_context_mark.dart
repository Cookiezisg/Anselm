// Dev screenshot for the context-compaction whisper (V5) — NOT a gate. Run:
//   flutter test test/dev/capture_context_mark.dart  → test/dev/out/context_mark.png
// Renders ChatContextMark between two assistant lines on the white reading column, zh-CN.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/features/chat/ui/chat_context_mark.dart';
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
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture context-compaction whisper', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 340);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Builder(builder: (context) {
            final ink = AnText.body.copyWith(color: context.colors.ink);
            return Scaffold(
              backgroundColor: context.colors.surface,
              body: Center(
                child: SizedBox(
                  width: 680,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('好的,已经帮你把前面 40 轮对话里查过的日志、跑过的命令都整理进摘要了。', style: ink),
                      const SizedBox(height: AnSpace.s12),
                      const ChatContextMark(marker: 'Context compacted — 42 earlier blocks folded into the running summary.'),
                      const SizedBox(height: AnSpace.s12),
                      Text('接着上面的进度,我们继续看 nightly_sync 那个失败的节点。', style: ink),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/context_mark.png').writeAsBytesSync(bytes);
  });
}
