// Dev screenshot harness for the notification rows (WRK-058 N2) — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_notifications.dart  → test/dev/out/notifications.png
// Renders the gallery's NotificationRow specimens as a stacked list on a white board (= the real tray
// surface), zh-CN, reduced-motion still, at the tray's ~320px width so truncation reads true.
//
// 通知行开发截图夹具(非门禁)。衬白板(=真实托盘面)、zh-CN、~320 托盘宽,截图给用户拍板长相。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_divider.dart';
import 'package:anselm/dev/gallery/notification_specimens.dart';
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

  testWidgets('capture notification rows', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(640, 2000);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Builder(builder: (context) {
            return Scaffold(
              backgroundColor: context.colors.surface,
              body: Center(
                child: SizedBox(
                  width: 320, // the left-island tray width — force real truncation 托盘宽,逼真截断
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < notificationRowSpecimens.length; i++) ...[
                          if (i > 0) const AnDivider(),
                          notificationRowSpecimens[i].builder(context),
                        ],
                      ],
                    ),
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
    File('${dir.path}/notifications.png').writeAsBytesSync(bytes);
  });
}
