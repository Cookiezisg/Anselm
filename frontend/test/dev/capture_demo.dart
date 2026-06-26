// Dev screenshot harness for `make demo` — renders the REAL app shell ([AppShell], same as make app)
// driven by the zero-backend [demoEntityRepository], headlessly via Skia → test/dev/out/demo.png.
// Run:  flutter test test/dev/capture_demo.dart
// One capture for the whole demo composition (no per-feature capture — mirrors the single demo target).
// 截 make demo 的真壳(AppShell)+ fixture → demo.png。整 demo 一张图,不做 per-feature 截图。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/app/app_shell.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
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
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
    LocaleSettings.setLocaleRaw('zh-CN');
  });

  testWidgets('demo', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(AnSize.windowInitialWidth * 2, AnSize.windowInitialHeight * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(demoEntityRepository())],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const RepaintBoundary(key: key, child: AppShell()),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // let the 4 list futures resolve

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/demo.png').writeAsBytesSync(bytes);
  });
}
