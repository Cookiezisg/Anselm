// Dev screenshot harness for the AnKv/AnField two-end alignment — NOT part of the gate.
// Run: flutter test test/dev/capture_kv_align.dart
// Renders a mixed AnKv (editable + read-only + mono + long) → every value rests flush-right (key left,
// value right = two-end aligned); a second frame hovers an editable row so its pencil grows on the far
// right and pushes that value left. → test/dev/out/kv_align{,_hover}.png
//
// AnKv/AnField 两端对齐开发截图夹具(非门禁)。混排 AnKv → 值静态全贴右(键左值右=两端对齐);第二帧悬停
// 编辑行 → 铅笔在最右长出、把该值挤左。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
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

Future<void> _shot(WidgetTester tester, Key key, String name) async {
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = await boundary.toImage(pixelRatio: 3.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = png!.buffer.asUint8List();
    image.dispose();
  });
  final dir = Directory('test/dev/out')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes);
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

  testWidgets('capture AnKv two-end alignment (rest + hover)', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(380, 260);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: AnIsland(
                  child: AnKv(
                    onChanged: (_) {},
                    rows: const [
                      AnKvRow('Name', 'normalize-input', editable: true),
                      AnKvRow('Kind', 'function'),
                      AnKvRow('Created', '2026-06-24'),
                      AnKvRow('Reference', 'mcp:github/create_issue', editable: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 60));
    await _shot(tester, key, 'kv_align'); // rest: every value flush-right (two-end aligned)

    // Hover the first editable row → its pencil grows on the far right, pushing that value left. 悬停第一编辑行。
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byType(AnEditableValue).first));
    addTearDown(g.removePointer);
    await tester.pumpAndSettle();
    await _shot(tester, key, 'kv_align_hover');
  });
}
