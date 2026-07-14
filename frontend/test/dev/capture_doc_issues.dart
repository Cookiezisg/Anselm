// Dev screenshot harness for the DOCUMENT-MODULE issue audit (goal: 5-issue optimization).
// Renders the REAL widgets so we can SEE the current truth vs the reported bugs:
//   frame 1  document editor on "Formatting Reference" → issue #3 (code block look) + #4 (markdown)
//   frame 2  the document rail tree                    → issue #5 (branch-node collapse chevrons)
//   frame 3  chat AnMarkdown of the same body          → issue #4 1:1 comparison baseline
// Run: flutter test test/dev/capture_doc_issues.dart → test/dev/out/doc_issue_*.png  (NOT a gate)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/an_markdown.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/data/documents_demo_fixture.dart';
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

// The rich "Formatting Reference" body — code block + inline code + headings + lists + quote + table.
const _richBody = '# Heading one\n\n'
    'A paragraph with **bold**, *italic*, `inline code`, an external '
    '[link to the site](https://anselm.website), and a wikilink.\n\n'
    '## Heading two\n\n'
    '### Heading three\n\n'
    '## Lists\n\n'
    '- bullet one\n'
    '- bullet two\n\n'
    '1. ordered one\n'
    '2. ordered two\n\n'
    '## Quote & code\n\n'
    '> A blockquote — the row table IS the truth.\n\n'
    '```dart\n'
    'void main() => print(\'hello, anselm\');\n'
    '```';

Future<void> _shoot(WidgetTester tester, ValueKey key, String name) async {
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
  File('${dir.path}/$name.png').writeAsBytesSync(bytes);
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

  Widget host(Widget child, ValueKey key) => RepaintBoundary(
        key: key,
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: child,
          ),
        ),
      );

  testWidgets('#3+#4 document editor on Formatting Reference', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('ed');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1100);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(ProviderScope(
      child: host(Builder(builder: (context) {
        return Scaffold(
          backgroundColor: context.colors.surface,
          body: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AnInset.pageX),
            child: AnEditor(initialMarkdown: _richBody),
          ),
        );
      }), key),
    ));
    await _shoot(tester, key, 'doc_issue_editor');
  });

  testWidgets('#1 empty doc placeholder hint', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('empty');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: host(Builder(builder: (context) {
        return Scaffold(
          backgroundColor: context.colors.surface,
          body: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AnInset.pageX),
            child: AnEditor(initialMarkdown: ''),
          ),
        );
      }), key),
    ));
    await _shoot(tester, key, 'doc_issue_empty');
  });

  testWidgets('#5 document rail tree (branch nodes)', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('rail');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [documentsRepositoryProvider.overrideWithValue(demoDocumentsRepository())],
      child: host(Builder(builder: (context) {
        return Scaffold(backgroundColor: context.colors.surface, body: const DocumentRail());
      }), key),
    ));
    await _shoot(tester, key, 'doc_issue_rail');
  });

  testWidgets('#3 AnCodeEditor seamless (framed + direct-edit + gutter)', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('seamless');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 420);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: host(Builder(builder: (context) {
        return Scaffold(
          backgroundColor: context.colors.surface,
          body: const Padding(
            padding: EdgeInsets.all(AnSpace.s24),
            child: AnCodeEditor(
              code: '# where the state of record lives\nls ~/Library/Application\\ Support/anselm/\nanselm.db   sandbox/   logs/',
              lang: 'bash',
              reading: true,
              wrap: true,
              editable: true,
              seamless: true,
            ),
          ),
        );
      }), key),
    ));
    await _shoot(tester, key, 'doc_issue_seamless');
  });

  testWidgets('#4 chat AnMarkdown of the same body (1:1 baseline)', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('md');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(720, 1100);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: host(Builder(builder: (context) {
        return Scaffold(
          backgroundColor: context.colors.surface,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AnInset.pageX, vertical: AnSpace.s24),
            child: const AnMarkdown(_richBody),
          ),
        );
      }), key),
    ));
    await _shoot(tester, key, 'doc_issue_chatmd');
  });
}
