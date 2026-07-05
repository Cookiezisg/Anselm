// Dev screenshot harness for AnDocEditor's entity-reference chips (P3.3) — loads a document whose stored
// `[[id]]` wikilinks were expanded to the editor's `[name](anselm-entity:id)` link form, so the mentions
// render as accent chips inline in prose. NOT part of the gate.
// Run: flutter test test/dev/capture_doc_chip.dart → test/dev/out/doc_chip.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/core/ui/entity_ref_codec.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

// The editor's in-memory form (what document_ocean produces from stored `[[id]]` + resolved names). Two
// entity refs sit inline as accent chips. 编辑内展开形:两处实体引用作 accent 药丸内联在文中。
const _md = '''# Runbook — inventory sync

When stock drifts, the [sync_inventory]($kEntityRefScheme:fn_0123456789abcdef) function reconciles levels,
then the [drift_auditor]($kEntityRefScheme:ag_fedcba9876543210) agent explains what moved and why.

References round-trip: on save each chip collapses back to its bare `[[id]]` wikilink, which the backend
parses to build the document's link edges.''';

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture AnDocEditor entity-ref chips', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    BlinkController.indeterminateAnimationsEnabled = false;
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 720);
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
              body: const Center(
                child: SizedBox(width: 720, height: 500, child: AnDocEditor(initialMarkdown: _md)),
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/doc_chip.png').writeAsBytesSync(bytes);
  });
}
