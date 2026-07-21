import 'dart:io';
import 'dart:ui' show BoxHeightStyle, TextBox, TextDirection;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/editor/an_editor_inline_code.dart';
import 'package:anselm/core/editor/an_editor_selection.dart';
import 'package:anselm/core/editor/an_editor_text_component.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

// The per-visual-line box merge (an_editor_selection.dart) — shared by the inline-code pill painter and
// the selection highlight. The REAL-FONT wrap case is the load-bearing one: BoxHeightStyle.max boxes of
// adjacent wrapped lines overlap by a sub-pixel with Inter+mono metrics, and the old "vertical overlap"
// test unioned both lines into one rect (the mid-code-typing pill bug). 逐视觉行并盒的锁死测:真字体下
// 相邻折行盒亚像素重叠,旧「竖向重叠」判据把两行并一(码中打字灰底断裂 bug)。

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    // The bug only reproduces with the REAL bundled faces (the test font's boxes tile exactly). 真字体才复现。
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
  });
  setUp(() => BlinkController.indeterminateAnimationsEnabled = false);
  tearDown(() => BlinkController.indeterminateAnimationsEnabled = true);

  group('mergeBoxesByLine', () {
    TextBox box(double l, double t, double r, double b) =>
        TextBox.fromLTRBD(l, t, r, b, TextDirection.ltr);

    test(
      'adjacent wrapped lines stay separate even when their boxes overlap by a sub-pixel',
      () {
        // The measured real-font shape: line1 bottom 24.0, line2 top 23.7 — 0.3px overlap. 实测真字体形状。
        final merged = mergeBoxesByLine([
          box(99.7, -0.3, 688.5, 24.0),
          box(0.0, 23.7, 534.1, 48.0),
        ]);
        expect(
          merged,
          hasLength(2),
          reason: 'two visual lines → two rects, never one union',
        );
      },
    );

    test(
      'same-line split boxes (script-run boundaries) still merge into one rect',
      () {
        // CJK-in-code splits one line into several boxes sharing the line box (same top/bottom). CJK 同行断盒。
        final merged = mergeBoxesByLine([
          box(10, 0, 40, 24),
          box(40, 0, 90, 24),
          box(90, 0, 120, 24),
        ]);
        expect(merged, hasLength(1));
        expect(merged.single, const Rect.fromLTRB(10, 0, 120, 24));
      },
    );
  });

  testWidgets(
    'a mid-run wrapped inline code keeps ONE pill rect PER line (real fonts)',
    (tester) async {
      tester.view.physicalSize = const Size(760, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The post-mid-code-typing shape: an unbreakable code run long enough to break MID-RUN across lines.
      // 码中打字后的形状:不可断的 code run 长到必须行中折断。
      const code =
          'this_is_a_very_long_inline_codabcdefghij_identifier_that_should_wrap_across_lines_and_then_some_more_padding_to_force_a_midrun_break_yes_really';
      var text = AttributedText('long-code: 前 $code 后');
      const start = 'long-code: 前 '.length;
      text.addAttribution(
        codeAttribution,
        SpanRange(start, start + code.length - 1),
      );
      text = padCodeRuns(text).text;

      final doc = MutableDocument(
        nodes: [
          ListItemNode(id: 'li', itemType: ListItemType.unordered, text: text),
        ],
      );
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(body: AnEditor.withDocument(doc)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<AnTextComponentState>(
        find.byType(AnTextComponent),
      );
      // ignore: invalid_use_of_visible_for_testing_member
      final layout = state.textLayout;
      final full = (state.widget as AnTextComponent).text;
      final span = full.getAttributionSpans({codeAttribution}).single;
      final boxes = layout.getBoxesForSelection(
        TextSelection(baseOffset: span.start, extentOffset: span.end + 1),
        boxHeightStyle: BoxHeightStyle.max,
      );
      expect(
        boxes.length,
        greaterThanOrEqualTo(2),
        reason: 'the run must actually wrap for this test to bite',
      );
      final merged = mergeBoxesByLine(boxes);
      expect(
        merged,
        hasLength(boxes.length),
        reason:
            'each wrapped line keeps its own rect — the union collapse painted only the bottom line',
      );
      // No merged rect spans more than one line box. 无 rect 高过一行盒。
      for (final r in merged) {
        expect(
          r.height,
          lessThan(30),
          reason: 'a per-line rect, not a two-line union (~48)',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
