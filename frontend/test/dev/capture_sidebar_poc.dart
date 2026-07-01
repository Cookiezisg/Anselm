// Dev screenshot harness for the slice-2 virtualization POC — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_sidebar_poc.dart
// Renders SidebarVirtualPoc headlessly via Skia → test/dev/out/sidebar_poc.png so the virtualized
// sidebar's look (per-section pinned headers, fold tree, rows) can be eyeballed without launching.
// 切片 2 虚拟化 POC 的开发截图夹具(非门禁):无头 Skia 渲染 POC 成 PNG 供肉眼核对。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/dev/gallery/sidebar_poc.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('sidebar POC capture — per-section pinned headers + fold tree + rows', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(560, 900);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: const Scaffold(
              body: Center(
                child: SizedBox(width: 560, height: 900, child: SidebarVirtualPoc()),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Scroll into Documents › src › ui so the shot shows the DYNAMIC ANCESTOR STICKY: the overlay pins
    // the whole Documents › src › ui chain at the top while its rows scroll under it.
    // 滚进 Documents › src › ui 以展示动态祖先吸顶:overlay 把整条 Documents › src › ui 链吸在顶部,行从其下滚过。
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
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
    File('${dir.path}/sidebar_poc.png').writeAsBytesSync(bytes);
  });
}
