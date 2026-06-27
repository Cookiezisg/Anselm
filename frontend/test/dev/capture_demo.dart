// Dev screenshot harness for `make demo` — renders the REAL app shell ([AppShell], same as make app)
// driven by the zero-backend [demoEntityRepository], headlessly via Skia → test/dev/out/demo.png.
// STEP 6: routing is real — pre-selection is a deep link (navigate the GoRouter), not a provider override.
// Run:  flutter test test/dev/capture_demo.dart
// 截 make demo 的真壳(AppShell)+ fixture → demo.png。STEP 6:预选 = deep-link 导航(非 provider override)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/app/router.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
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

// Optional `--dart-define=SEL=function:fn_normalize` deep-links to an entity so the detail sea is
// captured (default: rail + empty ocean → demo.png; selected → demo_<id>.png). 可预选实体截详情。
const _sel = String.fromEnvironment('SEL');
// Optional `--dart-define=TAB=overview|versions|logs` taps that tab before capture. 预点某 tab。
const _tab = String.fromEnvironment('TAB');
// Optional `--dart-define=RUN=1` opens the right-island run terminal (verb CTA) + executes, to capture
// the STEP 5 run terminal with live output. Requires SEL. 打开右岛 run 终端并执行,截运行态。
const _run = String.fromEnvironment('RUN');
// Optional `--dart-define=COLLAPSE=1` collapses the left island (verify reopen-after-lights layout). 收起左岛。
const _collapse = String.fromEnvironment('COLLAPSE');

/// The capture root — the REAL [AppShell] driven by the REAL [buildAppRouter] (so routing is exercised
/// exactly as `make app`); the `builder` wraps the routed shell in a keyed RepaintBoundary to grab. 截图根。
class _CaptureApp extends ConsumerWidget {
  const _CaptureApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: ref.watch(goRouterProvider),
        builder: (context, child) =>
            RepaintBoundary(key: const ValueKey('cap'), child: child!),
      );
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
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(AnSize.windowInitialWidth * 2, AnSize.windowInitialHeight * 2);
    addTearDown(tester.view.reset);

    EntityKind? selKind;
    String? selId;
    var outName = 'demo';
    if (_sel.isNotEmpty) {
      final parts = _sel.split(':');
      selKind = EntityKind.values.byName(parts[0]);
      selId = parts[1];
      outName = 'demo_$selId';
    }

    await tester.pumpWidget(ProviderScope(
      overrides: [
        entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
        goRouterProvider.overrideWith(buildAppRouter),
      ],
      child: TranslationProvider(child: const _CaptureApp()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // let the 4 list futures resolve

    final container = ProviderScope.containerOf(tester.element(find.byType(_CaptureApp)), listen: false);

    // Pre-select via a deep link (the real navigation path). 经 deep-link 预选(真导航路径)。
    if (selKind != null && selId != null) {
      container.read(goRouterProvider).go(entityLocation(selKind, selId));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80)); // detail resolves
    }

    if (_collapse.isNotEmpty) {
      container.read(shellChromeProvider.notifier).toggleLeft();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // the collapse slide settles 收起滑动
      outName = '${outName}_collapsed';
    }

    if (_tab.isNotEmpty) {
      final detail = LocaleSettings.instance.currentTranslations.entities.detail.tab;
      final label = {'overview': detail.overview, 'versions': detail.versions, 'logs': detail.logs}[_tab]!;
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80)); // the tab's data loads
      outName = '${outName}_$_tab';
    }

    if (_run.isNotEmpty && selKind != null) {
      final verb = LocaleSettings.instance.currentTranslations.entities.detail.verb;
      final label = {
        EntityKind.function: verb.run,
        EntityKind.handler: verb.call,
        EntityKind.agent: verb.invoke,
        EntityKind.workflow: verb.trigger,
      }[selKind]!;
      // The right island is already revealed (strong-linked to the selection); the header verb CTA both
      // ensures it's open and fires the run. 右岛已随选区揭示;头部动词 CTA 展开 + 执行。
      await tester.tap(find.widgetWithText(AnButton, label).first);
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 40)); // scripted stream frames
      }
      outName = '${outName}_run';
    }

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('cap')));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/$outName.png').writeAsBytesSync(bytes);
  });
}
