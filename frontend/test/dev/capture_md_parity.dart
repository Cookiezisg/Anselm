// The AnMarkdown ⇄ AnDocEditor PARITY board — the SAME markdown sample rendered by both engines side by
// side in one frame (left: the chat's read-only renderer = the visual BASELINE; right: the editable
// document editor, which must match it element for element). Regenerate + eyeball after any editor
// stylesheet/component change. NOT part of the gate.
// AnMarkdown ⇄ AnDocEditor 对照板:同一份 markdown 双引擎同框(左=聊天只读渲染器=基准;右=编辑器,须逐元素
// 对齐)。改编辑器样式/组件后重生成肉眼对照。不入门禁。
// Run: flutter test test/dev/capture_md_parity.dart → test/dev/out/md_parity.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/core/ui/an_markdown.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

/// One sample per element family both engines share (tables/images are AnMarkdown-only — excluded).
/// 每个共享元素族一段样张(表格/图片仅 AnMarkdown 有,不入)。
const _sample = '''
Body text with **bold**, *italic*, ~~strike~~, `inline code` and a [link](https://example.com).

# Heading one

## Heading two

### Heading three

- Bullet alpha
- Bullet beta

1. First step
2. Second step

- [ ] Open task
- [x] Done task

> A quiet aside — the blockquote register.

```python
@retry(times=3)
def sync_inventory():
    ...
```

---

Closing paragraph after a divider.
''';

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

  testWidgets('capture markdown parity board (AnMarkdown vs AnDocEditor)', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    BlinkController.indeterminateAnimationsEnabled = false;
    addTearDown(() => BlinkController.indeterminateAnimationsEnabled = true);
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1240, 1560);
    addTearDown(tester.view.reset);

    Widget pane(String title, Widget child) => Expanded(
          child: Builder(builder: (context) {
            final c = context.colors;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AnText.meta.copyWith(color: c.inkFaint)),
                const SizedBox(height: AnSpace.s8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(AnRadius.card),
                    ),
                    padding: const EdgeInsets.all(AnSpace.s16),
                    child: child,
                  ),
                ),
              ],
            );
          }),
        );

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Builder(builder: (context) {
            return Scaffold(
              backgroundColor: context.colors.surfaceSunken,
              body: Padding(
                padding: const EdgeInsets.all(AnSpace.s16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The editor pads every block AnInset.pageX (24) inside its column (it lines up with the
                    // page header); mirror it here so the two panes are structurally comparable. 编辑器每块
                    // 自带 pageX 列内距(与页头对齐),基准侧补同样 24,两窗格同构可比。
                    pane(
                        'AnMarkdown (baseline)',
                        const SingleChildScrollView(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: AnInset.pageX),
                                child: AnMarkdown(_sample)))),
                    const SizedBox(width: AnSpace.s16),
                    pane('AnDocEditor', const AnDocEditor(initialMarkdown: _sample)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    Directory('test/dev/out').createSync(recursive: true);
    File('test/dev/out/md_parity.png').writeAsBytesSync(bytes);
  });
}
