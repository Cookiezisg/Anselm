// Dev screenshot harness — NOT part of the `flutter test` suite (no _test.dart suffix; it
// depends on macOS system fonts + the Lucide package font, and writes a PNG). Run explicitly:
//   flutter test test/dev/capture_shell.dart
// Renders the real AppShell on fixtures headlessly via Skia (no Xcode) → test/dev/out/shell.png
// (collapsed variant → shell-collapsed.png), so the three-island layout/spacing can be
// inspected without launching the app. The macOS traffic lights are OS-drawn (absent here), so
// the left/ocean leading zone shows as reserved empty space — layout spacing is still faithful.
// 开发截图夹具:无头渲染真 AppShell(fixture)成 PNG,免起 app 看三岛布局/间距。红绿灯是 OS 画的
// (此处无),故前导区显为留白——布局间距仍忠实。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/app/shell/app_shell.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/entities/data/entities_repository.dart';
import 'package:anselm/features/entities/state/entities_providers.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = await boundary.toImage(pixelRatio: 1.0);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('test/dev/out')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    // Same bundled MiSans VF the app uses. 与 app 同款打包 MiSans VF。
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('PingFang SC', '/System/Library/Fonts/Hiragino Sans GB.ttc');
    await _load('SF Mono', '/System/Library/Fonts/SFNSMono.ttf');
    final lucide = _lucideTtf();
    if (lucide != null) await _load('packages/lucide_icons_flutter/Lucide', lucide);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness(Key key) => ProviderScope(
        overrides: [
          entitiesRepositoryProvider.overrideWithValue(const FixtureEntitiesRepository()),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: RepaintBoundary(key: key, child: const AppShell()),
          ),
        ),
      );

  // pump() not pumpAndSettle (status dots animate forever); flush futures + entrance motion.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  testWidgets('shell', (tester) async {
    const key = ValueKey('capture');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 820);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(key));
    await settle(tester);

    // Select an entity so the ocean header (big title + crumb + meta) renders → top spacing.
    await tester.tap(find.text('greet_user'));
    await settle(tester);
    await _shoot(tester, key, 'shell');
    // NOTE: a collapsed-state shot is intentionally omitted — toImage after the collapse
    // animation hangs headlessly. The collapsed chrome geometry is covered by the unit test
    // `every chrome bar shares the traffic-light vertical center` (an_shell_test.dart).
    // 收起态截图刻意省略(收起动画后 toImage 无头会挂);收起几何由对齐单测守。
  });
}
