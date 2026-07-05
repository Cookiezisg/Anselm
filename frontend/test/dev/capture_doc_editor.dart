// Dev screenshot harness for AnDocEditor (P3 Notion-style WYSIWYG editor) — verify the token stylesheet
// (reading body 1.6 / heading downshift + asymmetry / block rhythm) renders like AnMarkdown's read view.
// NOT part of the gate. Run: flutter test test/dev/capture_doc_editor.dart → test/dev/out/doc_editor.png
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

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

const _md = '''# Release notes — v4.2

This release focuses on the documents ocean and a product-wide typography pass. The reading rhythm was reworked so every block sits on one cadence, edited in place.

## What changed

The biggest change is the spacing system. Every block separates on one unit, so nothing is cramped and nothing floats away from what it belongs to.

### Highlights

- Unified block rhythm across chat and documents
- Reading line-height opened to a comfortable value
- Headings breathe more above than below

A reference to another page: [[doc_concepts00000]] — it should round-trip verbatim.

```dart
void main() {
  print('a fenced code block on a sunken band');
}
```

> A blockquote aside — a quiet indented voice, inkMuted.

A closing paragraph, to confirm the gap below a block matches the gap above it.''';

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture AnDocEditor', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 1500);
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
                child: SizedBox(width: 720, height: 1160, child: AnDocEditor(initialMarkdown: _md)),
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
    File('${dir.path}/doc_editor.png').writeAsBytesSync(bytes);
  });
}
