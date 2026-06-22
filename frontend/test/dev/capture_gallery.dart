// Dev screenshot harness — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_gallery.dart
// Renders the component gallery headlessly via Skia (no Xcode) → test/dev/out/gallery.png so the
// kit's look (spacing, type, monochrome, states) can be reviewed against the demo without launching.
// Loads the bundled UI/mono fonts + the Lucide icon font so glyphs render (brand SVG may be blank —
// flutter_svg decodes async). 开发截图夹具:无头渲染画廊成 PNG 供对照 demo 审阅(非门禁)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/dev/gallery/gallery_app.dart';
import 'package:anselm/i18n/strings.g.dart';
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

void main() {
  setUpAll(() async {
    // System SF (the real UI face) so the capture matches the live app's Latin rendering.
    await _load('.AppleSystemUIFont', '/System/Library/Fonts/SFNS.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf'); // CJK fallback
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    // Thin Lucide weight (matches AnIcons._family). 细笔画 Lucide,与 AnIcons._family 对齐。
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('gallery', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 3600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(child: const GalleryApp()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = await boundary.toImage(pixelRatio: 1.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/gallery.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
