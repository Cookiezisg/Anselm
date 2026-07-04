// Dev diagnostic: render AnMarkdown with a representative mixed-block document to expose the vertical
// rhythm (inconsistent block gaps). NOT part of the gate.
// Run: flutter test test/dev/capture_markdown_rhythm.dart → test/dev/out/markdown_rhythm.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_markdown.dart';
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

const _md = '''
# Release notes — v4.2

This release focuses on the documents ocean and a product-wide typography pass. The reading rhythm was reworked so every block sits on one cadence, and the prose line-height was opened up for comfort while the dense UI chrome stays compact.

## What changed

The biggest change is the spacing system. Every block — paragraphs, headings, lists, code, tables, quotes — now separates on a single `AnFlow.block` unit, so nothing is cramped and nothing floats away from what it belongs to.

Some inline flavors to check in a running line: a bit of *italic*, some **bold**, an inline `identifier`, and a [link to the docs](https://example.com). These should not disturb the line rhythm around them at all.

### Highlights

1. Unified block rhythm across chat and documents
2. Reading line-height opened to a comfortable value
3. Headings now breathe more above than below
4. A semantic spacing tier, so a retune is one line

- A plain bullet to compare list spacing
- A nested list to check indentation rhythm
    - first nested item
    - second nested item
- Back to the top level

### A short table

| Surface | Before | After |
| --- | --- | --- |
| Blockquote | cramped (2px) | uniform 12 |
| Code block | loose (16px) | uniform 12 |
| Paragraph | ~15px | uniform 12 |

## Tasks

- [x] Define the semantic tokens
- [x] Fix the markdown flow
- [ ] Sweep the primitives
- [ ] Verify every surface

## Notes

> A blockquote aside — it should read as a quiet indented voice, on the same 12px rhythm as everything around it, neither jammed against the paragraph above nor floating away from the one below.

Here is a fenced code block, which should sit on the same rhythm as the prose around it:

```dart
void main() {
  final gap = AnFlow.block; // one rhythm
  print('spacing = \$gap');
}
```

A closing paragraph after the code, to confirm the gap below a block matches the gap above it.
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

  testWidgets('capture markdown vertical rhythm', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 1680);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    LocaleSettings.setLocaleRaw('en');
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
                width: 640,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: const AnMarkdown(_md),
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
    File('${dir.path}/markdown_rhythm.png').writeAsBytesSync(bytes);
  });
}
