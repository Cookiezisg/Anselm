// Dev screenshot harness for AnDocEditor's `/` slash block menu (P3.4) — drives the real super_editor IME
// so the caret-anchored block menu opens over live prose, then screenshots it. NOT part of the gate.
// Run: flutter test test/dev/capture_doc_slash.dart → test/dev/out/doc_slash.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

const _md = '''# Runbook — inventory sync

When stock drifts, kick the reconciliation flow. Turn any line into a heading, list, or quote by opening
the block menu:

''';

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture AnDocEditor / slash block menu', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    BlinkController.indeterminateAnimationsEnabled = false;
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 900);
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
            final t = context.t;
            return Scaffold(
              backgroundColor: context.colors.surface,
              body: Center(
                child: SizedBox(
                  width: 720,
                  height: 620,
                  child: AnDocEditor(
                    initialMarkdown: _md,
                    autofocus: true,
                    slashLabels: SlashMenuLabels(
                      text: t.documents.slash.text,
                      h1: t.documents.slash.h1,
                      h2: t.documents.slash.h2,
                      h3: t.documents.slash.h3,
                      bulleted: t.documents.slash.bulleted,
                      numbered: t.documents.slash.numbered,
                      quote: t.documents.slash.quote,
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

    // Place the caret in the trailing empty paragraph and type `/` to open the full block menu.
    final doc = SuperEditorInspector.findDocument()!;
    final lastId = doc.getNodeAt(doc.nodeCount - 1)!.id;
    await tester.placeCaretInParagraph(lastId, 0);
    await tester.typeImeText('/');
    await tester.pumpAndSettle();

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/doc_slash.png').writeAsBytesSync(bytes);
  });
}
