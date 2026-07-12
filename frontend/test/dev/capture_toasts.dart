// Dev screenshot harness for the top-right toast stack (WRK-058 N3) — NOT part of the gate. Run:
//   flutter test test/dev/capture_toasts.dart  → test/dev/out/toasts.png
// Fires a danger (sticky) + a warn toast through the REAL AnOverlayHost so the top-right anchor + stack +
// tone bars read true against a full window. zh-CN, reduced-motion still.
//
// 右上 toast 栈开发截图夹具(非门禁)。经真 AnOverlayHost 弹 danger(常驻)+ warn,验右上锚点+堆叠+tone 条。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/ui/an_toast.dart';
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

  testWidgets('capture top-right toast stack', (tester) async {
    LocaleSettings.setLocaleRaw('zh-CN');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 560);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final navKey = GlobalKey<NavigatorState>();
    late AnOverlayController ctrl;
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            navigatorKey: navKey,
            builder: (context, child) => AnOverlayHost(navigatorKey: navKey, child: child!),
            home: Consumer(builder: (context, ref, _) {
              ctrl = ref.read(overlayProvider.notifier);
              return Scaffold(
                backgroundColor: context.colors.surfaceSubtle,
                body: Center(child: Text('App content', style: AnText.body.copyWith(color: context.colors.inkFaint))),
              );
            }),
          ),
        ),
      ),
    ));
    await tester.pump();
    // Fire (oldest first) — newest ends up on top of the top-anchored stack. 旧→新弹,最新居顶。
    ctrl.showToast('工作流「nightly_sync」运行失败', tone: AnTone.danger, duration: Duration.zero,
        action: AnToastAction(label: '查看', onPressed: () {}));
    ctrl.showToast('工作流「deploy_prod」等待审批', tone: AnTone.warn, duration: Duration.zero,
        action: AnToastAction(label: '查看', onPressed: () {}));
    ctrl.showToast('处理器「api_host」崩溃了', tone: AnTone.danger, duration: Duration.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // enters settle

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/toasts.png').writeAsBytesSync(bytes);
  });
}
