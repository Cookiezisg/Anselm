// Dev screenshot harness — NOT part of the `flutter test` suite (no _test.dart suffix; it
// depends on macOS system fonts + the Lucide package font, and writes a PNG). Run explicitly:
//   flutter test test/dev/capture_gallery.dart
// Renders the component gallery headlessly via Skia (no Xcode) → test/dev/out/gallery.png,
// so the UI kit can be inspected without launching the app. (The shell/feature screens are
// seen live via `make demo`.)
// 开发截图夹具:经 Skia 无头渲染组件画廊成 PNG,无需起 app 即可看 UI 套件。(shell/feature 看 make demo。)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/dev/gallery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

String? _lucideTtf() {
  final home = Platform.environment['HOME'];
  if (home == null) return null;
  final dir = Directory('$home/.pub-cache/hosted/pub.dev');
  if (!dir.existsSync()) return null;
  final pkg = dir
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.split('/').last.startsWith('lucide_icons_flutter-'))
      .toList();
  if (pkg.isEmpty) return null;
  return '${pkg.first.path}/assets/lucide.ttf';
}

void main() {
  setUpAll(() async {
    // Load the SAME bundled MiSans VF the app uses, so the headless render matches the app
    // (weights come off the VF's wght axis). 载入 app 同款打包 MiSans VF,无头渲染与 app 一致。
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('PingFang SC', '/System/Library/Fonts/Hiragino Sans GB.ttc');
    await _load('SF Mono', '/System/Library/Fonts/SFNSMono.ttf');
    final lucide = _lucideTtf();
    if (lucide != null) await _load('packages/lucide_icons_flutter/Lucide', lucide);
  });

  testWidgets('gallery', (tester) async {
    const key = ValueKey('capture');
    const dpr = 1.0;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(920, 6200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: const RepaintBoundary(key: key, child: GalleryPage()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = await boundary.toImage(pixelRatio: dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/gallery.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
