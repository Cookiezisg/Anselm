// Dev screenshot — the REWRITTEN (virtualized) AnSidebarList with dynamic ancestor sticky. Scrolled into
// a deep Documents › src › ui tree so the overlay pins the mixed section-head + branch-head ancestor
// chain, with an All(5000) section proving virtualization. Run: flutter test test/dev/capture_sidebar.dart
// 重写后(虚拟化)AnSidebarList 截图:滚进深树,overlay 吸顶「段头+分支头」混合祖先链;All(5000) 证虚拟化。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
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

SidebarModel _model() => SidebarModel(
      newLabel: 'New',
      filterPlaceholder: 'Filter…',
      groups: [
        SidebarGroup(types: [
          SidebarType(label: 'Functions', icon: AnIcons.function, count: 6, rows: [
            for (var i = 0; i < 6; i++) SidebarRow(id: 'fn$i', label: 'function-$i'),
          ]),
          SidebarType(label: 'Documents', icon: AnIcons.doc, count: 16, rows: [
            SidebarRow(id: 'src', label: 'src', icon: AnIcons.doc, children: [
              SidebarRow(id: 'ui', label: 'ui', icon: AnIcons.doc, children: [
                for (var i = 0; i < 8; i++) SidebarRow(id: 'ui$i', label: 'widget_$i.dart', icon: AnIcons.doc),
              ]),
              SidebarRow(id: 'core', label: 'core', icon: AnIcons.doc, children: [
                for (var i = 0; i < 6; i++) SidebarRow(id: 'core$i', label: 'service_$i.dart', icon: AnIcons.doc),
              ]),
            ]),
          ]),
          SidebarType(label: 'All', icon: AnIcons.entities, count: 5000, rows: [
            for (var i = 0; i < 5000; i++) SidebarRow(id: 'a$i', label: 'entity-$i'),
          ]),
        ]),
      ],
    );

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('AnSidebarList capture — virtualized + dynamic ancestor sticky', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(560, 900);
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
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 560,
                height: 900,
                child: AnSidebarList(model: _model(), showNew: false, onSelect: (_) {}),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Scroll into Documents › src › ui so the overlay pins the section head + branch chain.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -548));
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
    File('${dir.path}/sidebar.png').writeAsBytesSync(bytes);
  });
}
