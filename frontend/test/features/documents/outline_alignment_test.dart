import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/features/documents/model/doc_outline.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// BlinkController lives here — super_editor's barrel `show`-excludes it. 关光标 ticker 用。
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

// THE outline-index invariant: the inspector outline comes from `extractDocOutline(markdown)` while
// jump/scroll-spy use the editor's `headingNodeIds` — the SHARED key is the document-order INDEX, with
// no stored offsets. If the two extractors ever disagree on which blocks are headings (count or order),
// every jump after the divergence lands on the WRONG heading. This battery locks them together over the
// tricky shapes: fenced `#` (not a heading), quoted `#` (not a heading), and h4–h6 (headings in BOTH,
// folded to level 3 in the outline).
// 大纲下标不变式:右岛大纲=extractDocOutline(markdown),跳转/scroll-spy=编辑器 headingNodeIds,共享键=文档序
// 下标(不存偏移)。两套提取器对「谁是标题」不一致(计数或顺序),分歧点之后全部跳错。本电池用刁钻形状锁死一致:
// 围栏内 #(非标题)/引用内 #(非标题)/h4–h6(两侧都算、大纲并 3 级)。

const _tricky = '# 甲\n\n'
    '正文一段。\n\n'
    '## 乙\n\n'
    '```\n'
    '# 围栏里不是标题\n'
    '## 也不是\n'
    '```\n\n'
    '### 丙\n\n'
    '> # 引用里也不是标题\n\n'
    '#### 丁四级\n\n'
    '##### 戊五级\n\n'
    '## 己';

Widget _host(String markdown) => TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: AnEditor(initialMarkdown: markdown)),
      ),
    );

void main() {
  setUp(() => BlinkController.indeterminateAnimationsEnabled = false);
  tearDown(() => BlinkController.indeterminateAnimationsEnabled = true);

  testWidgets('extractDocOutline and headingNodeIds agree on count AND order over tricky markdown',
      (tester) async {
    await tester.pumpWidget(_host(_tricky));
    await tester.pumpAndSettle();

    final outline = extractDocOutline(_tricky);
    final editorIds = tester.state<AnEditorState>(find.byType(AnEditor)).headingNodeIds;

    // 甲/乙/丙/丁四级/戊五级/己 — six headings; the fenced + quoted # are excluded by BOTH sides. 六标题。
    expect(outline.map((e) => e.text).toList(), ['甲', '乙', '丙', '丁四级', '戊五级', '己']);
    expect(editorIds.length, outline.length,
        reason: 'the index IS the jump key — a count mismatch misaligns every later jump 计数不齐=后续全错位');

    // Deep headings fold to level 3 in the outline (display), but still COUNT on both sides. 深标题并 3 级。
    expect(outline[3].level, 3);
    expect(outline[4].level, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the order maps 1:1 — the editor heading at index k renders the outline text at k',
      (tester) async {
    await tester.pumpWidget(_host(_tricky));
    await tester.pumpAndSettle();
    final state = tester.state<AnEditorState>(find.byType(AnEditor));
    final outline = extractDocOutline(_tricky);
    final doc = state.document;
    for (var k = 0; k < outline.length; k += 1) {
      final node = doc.getNodeById(state.headingNodeIds[k]);
      expect((node as dynamic).text.toPlainText(), outline[k].text,
          reason: 'index $k must be the SAME heading on both sides 第 $k 项两侧同标题');
    }
    expect(tester.takeException(), isNull);
  });
}
