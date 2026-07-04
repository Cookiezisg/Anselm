// Dev screenshot harness for the DOCUMENTS ocean (P1/P2) — the left-island navigator (document tree +
// skills) beside the read-only center preview. NOT part of the gate.
// Run: flutter test test/dev/capture_documents.dart → test/dev/out/documents.png
// 文档海洋(P1/P2)开发截图:左岛导航(文档树 + skill)+ 中心只读预览。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/data/documents_demo_fixture.dart';
import 'package:anselm/features/documents/state/document_state.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/features/documents/ui/document_rail.dart';
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

class _Pinned extends SelectedDocController {
  @override
  DocSelection? build() => (isSkill: false, id: 'doc_start00000000');
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

  testWidgets('capture documents ocean (rail + read preview)', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 760);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(demoDocumentsRepository()),
        selectedDocProvider.overrideWith(_Pinned.new),
      ],
      child: RepaintBoundary(
        key: key,
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Builder(builder: (context) {
              final c = context.colors;
              return Scaffold(
                backgroundColor: c.surface,
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 288, child: const DocumentRail()),
                    Container(width: 1, color: c.line),
                    const Expanded(child: DocumentOcean()),
                  ],
                ),
              );
            }),
          ),
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
    File('${dir.path}/documents.png').writeAsBytesSync(bytes);
  });
}
