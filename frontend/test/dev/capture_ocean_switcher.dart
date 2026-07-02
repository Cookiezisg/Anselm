// Dev capture harness — NOT part of the gate. Renders the ocean-switcher PROTOTYPE frame-by-frame
// (deterministic, tickerless) into test/dev/out/ocean/frame_XXXX.png so the "water-droplet" pill
// flow can be assembled into a GIF (ffmpeg) and reviewed without launching the desktop app.
// Run: flutter test test/dev/capture_ocean_switcher.dart   (dark: --dart-define=DARK=1)
// 开发截图夹具(非门禁):逐帧确定性渲染海洋切换器原型 → PNG 序列,供 ffmpeg 拼 GIF 审阅。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_ocean_switcher.dart';
import 'package:anselm/core/ui/icons.dart';
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
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  // Fixed capture canvas (logical) so every PNG is the SAME pixel size (ffmpeg needs constant size).
  // 固定截图画布(逻辑),每帧同像素尺寸(ffmpeg 需恒定)。
  const canvasW = 300.0;
  const canvasH = 56.0;
  const dpr = 3.0;
  final dark = const String.fromEnvironment('DARK', defaultValue: '0') == '1';

  testWidgets('capture ocean-switcher droplet flow', (tester) async {
    final items = <AnOceanItem>[
      AnOceanItem(id: 'chat', icon: AnIcons.chat, label: 'Chat'),
      AnOceanItem(id: 'entities', icon: AnIcons.entities, label: 'Entities'),
      AnOceanItem(id: 'scheduler', icon: AnIcons.scheduler, label: 'Scheduler'),
      AnOceanItem(id: 'documents', icon: AnIcons.doc, label: 'Documents'),
    ];

    const key = ValueKey('cap');
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(canvasW * dpr, canvasH * dpr);
    addTearDown(tester.view.reset);

    final driver = ValueNotifier<List<double>>([0, 0, 1]); // [from, to, t]

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AnTheme.dark() : AnTheme.light(),
        // Scaffold provides a Material → a DefaultTextStyle with decoration:none (without it, bare Text
        // under MaterialApp.home falls back to the framework's yellow-underline "unstyled" debug style).
        // Scaffold 给 Material → DefaultTextStyle(无下划线);否则裸 Text 会落到框架的黄下划线兜底样式。
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: canvasW,
              height: canvasH,
              color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF), // left-island surface 左岛表面
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ValueListenableBuilder<List<double>>(
                valueListenable: driver,
                builder: (context, v, _) => AnOceanSwitcherFrame(
                  items: items,
                  fromIndex: v[0].toInt(),
                  toIndex: v[1].toInt(),
                  t: v[2],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final dir = Directory('test/dev/out/ocean')..createSync(recursive: true);
    var frame = 0;

    Future<void> shoot() async {
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: dpr);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final name = 'frame_${frame.toString().padLeft(4, '0')}.png';
        File('${dir.path}/$name').writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
        frame++;
      });
    }

    Future<void> hold(int from, int to, int n) async {
      for (var i = 0; i < n; i++) {
        driver.value = [from.toDouble(), to.toDouble(), 1];
        await shoot();
      }
    }

    Future<void> transition(int from, int to, int steps) async {
      for (var s = 1; s <= steps; s++) {
        driver.value = [from.toDouble(), to.toDouble(), s / steps];
        await shoot();
      }
    }

    const steps = 16;
    const holdN = 6;
    final order = [0, 1, 2, 3, 0]; // 0 → 1 → 2 → 3 → 0, holding on each 依次切并停顿
    await hold(0, 0, holdN); // initial rest on Chat
    for (var k = 1; k < order.length; k++) {
      await transition(order[k - 1], order[k], steps);
      await hold(order[k - 1], order[k], holdN);
    }

    // ignore: avoid_print
    print('OCEAN_FRAMES=$frame DIR=${dir.path}');
  });
}
