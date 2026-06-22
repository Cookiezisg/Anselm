// Dev screenshot harness — NOT part of the `flutter test` suite (no _test.dart suffix; it
// depends on macOS system fonts + the Lucide package font, and writes PNGs). Run explicitly:
//   flutter test test/dev/capture_gallery.dart
// Renders widgets headlessly via Skia (no Xcode/desktop toolchain) → PNGs in test/dev/out/,
// so the rendered UI can be inspected without launching the app.
// 开发截图夹具:经 Skia 无头渲染成 PNG(加载系统字体 + Lucide 包字体),无需起桌面 app 即可看效果。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/dev/gallery_page.dart';
import 'package:anselm/dev/shell_demo.dart';
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

Future<void> _capture(WidgetTester tester, String file, Size logical, double dpr, Widget child) async {
  const key = ValueKey('capture');
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(logical.width * dpr, logical.height * dpr);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    // TickerMode off freezes infinite animations (status-dot/skeleton) so the still is
    // deterministic and teardown doesn't hang on a live ticker.
    home: TickerMode(enabled: false, child: RepaintBoundary(key: key, child: child)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = await boundary.toImage(pixelRatio: dpr);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('test/dev/out')..createSync(recursive: true);
  File('${dir.path}/$file').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    // AnText declares fontFamily 'Inter' (+ system fallbacks incl PingFang for CJK); map
    // those names onto real macOS fonts so every glyph renders. Mono + Lucide icon font too.
    await _load('Inter', '/System/Library/Fonts/SFNS.ttf');
    await _load('PingFang SC', '/System/Library/Fonts/Hiragino Sans GB.ttc');
    await _load('SF Mono', '/System/Library/Fonts/SFNSMono.ttf');
    final lucide = _lucideTtf();
    if (lucide != null) await _load('packages/lucide_icons_flutter/Lucide', lucide);
  });

  testWidgets('shell', (tester) async {
    await _capture(tester, 'shell.png', const Size(1440, 900), 2.0, const ShellDemo());
  });

  testWidgets('gallery', (tester) async {
    await _capture(tester, 'gallery.png', const Size(920, 6200), 1.0, const GalleryPage());
  });
}
