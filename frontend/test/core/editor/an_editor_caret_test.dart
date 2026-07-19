import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/editor/an_editor_caret.dart';
import 'package:anselm/core/editor/an_editor_table.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

// ⑤ THE ONE CARET LAW, end-to-end: width [AnSize.caret], height derived from the effective style (never a
// platform line box), colour [AnColors.ink] (never accent) — and ONE caret at a time (an embedded editable
// taking the keyboard drops the document caret). Each number here was measured on-device before the fix:
// the code block painted a 23.5pt ACCENT caret over 13px mono; the document caret kept blinking beside it.
// 唯一光标法端到端锁死:宽=AnSize.caret、高按有效样式推导(绝不平台行盒)、色=ink(绝不 accent);且一次只有一根
// (内嵌可编辑件拿走键盘 → 文档光标收起)。每个数字都是修前真机实测:码块在 13px mono 上画 23.5pt 的 accent
// 光标,文档光标还在旁边照闪。

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

Widget _host(String markdown) => TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: AnEditor(initialMarkdown: markdown)),
      ),
    );

void main() {
  setUpAll(() async {
    // The caret hugs the REAL faces' metrics — the test font would answer a different (1em) question.
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
  });
  setUp(() => BlinkController.indeterminateAnimationsEnabled = false);
  tearDown(() => BlinkController.indeterminateAnimationsEnabled = true);

  group('anCaretBand — THE one caret-height rule (shared by the document layer and AnFieldCaret)', () {
    test('sits on the MEASURED glyph box whenever there is one', () {
      // The rule that makes a caret follow the run it lands on: mono 13 inside prose 15, a cell, a heading —
      // no formula, the layout's own box. 让光标随所在 run 走的规则:正文 15 里的 mono 13/格/标题都取布局实测盒。
      final band = anCaretBand(
        glyph: const Rect.fromLTWH(40, 103.2, 8, 18.1),
        lineTop: 100,
        lineHeight: 24,
        fontSize: 15,
      );
      expect(band.top, 103.2, reason: 'the glyph box IS the caret band — never re-centred by a formula');
      expect(band.height, closeTo(18.1, 0.001));
    });

    test('with nothing to measure (empty text) falls back to the house formula, centred in the line box', () {
      final band = anCaretBand(glyph: null, lineTop: 100, lineHeight: 24, fontSize: 15);
      expect(band.height, AnText.reading.fontSize! + AnSize.caretRise, reason: '15+3');
      expect(band.top, 103, reason: 'centred: 100 + (24-18)/2');
    });

    test('the fallback never exceeds the line box, and scales with the style', () {
      expect(anCaretBand(glyph: null, lineTop: 0, lineHeight: 24, fontSize: 13).height, 16);
      expect(anCaretBand(glyph: null, lineTop: 0, lineHeight: 40, fontSize: 24).height, 27);
      expect(anCaretBand(glyph: null, lineTop: 0, lineHeight: 12, fontSize: 24).height, 12,
          reason: 'clamped to the line box');
    });

    test('a zero-height glyph box is treated as unmeasurable', () {
      final band = anCaretBand(glyph: Rect.zero, lineTop: 0, lineHeight: 24, fontSize: 15);
      expect(band.height, 18);
    });
  });

  testWidgets('the code block caret is INK, [AnSize.caret] wide, and derived from the code style', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(_host('prose\n\n```dart\nvar x = 1;\n```'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.cursorColor, AnColors.light.ink,
          reason: 'a caret is INK — the accent caret turned the document blue mid-prose');
      expect(field.cursorWidth, AnSize.caret);
      expect(field.cursorHeight, AnText.codeReading.fontSize! + AnSize.caretRise,
          reason: 'derived from the code style (16), NOT the platform line box (macOS gave 22.8)');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a table cell hides the package caret and paints the An one', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(_host('| A | B |\n| --- | --- |\n| 1 | 2 |'));
      await tester.pumpAndSettle();

      // The package's own caret must be invisible — its height is the full line box (24) and CaretStyle
      // has no height slot, so the An layer replaces it wholesale. It is hidden by ZERO WIDTH, never by a
      // transparent colour: the package paints with `color.withValues(alpha: blink)`, which overwrites the
      // alpha and resurrects a transparent black as an OPAQUE one (the bug this test now pins).
      // 包自带光标须不可见(它高=整行盒 24、CaretStyle 无 height 槽),由 An 层整体接管;**用零宽**藏、绝不用透明
      // 色——包画时 `color.withValues(alpha: 闪烁值)` 覆写 alpha,透明黑会复活成不透明黑(本测钉住的那个 bug)。
      for (final field in tester.widgetList<SuperTextField>(find.byType(SuperTextField))) {
        expect(field.caretStyle?.width, 0,
            reason: 'hidden by zero width — a transparent colour would be resurrected by the blink alpha');
      }
      expect(find.byType(AnFieldCaret), findsNWidgets(4), reason: 'one An caret per cell');
      final caret = tester.widget<AnFieldCaret>(find.byType(AnFieldCaret).first);
      expect(caret.fontSize, AnText.reading.fontSize);
      expect(caret.color, AnColors.light.ink);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the caret BESIDE an atomic block spans the WHOLE block (upstream behaviour, kept)', (tester) async {
    // Arrowing off the prose onto a table lands on the block's upstream edge. That caret is NOT sitting on
    // text — it says "you are beside this whole block", and its full-block height IS that statement, so it
    // deliberately does NOT take the glyph band (user 0716, after a round where it was capped to text size
    // and read as a stray stub). 从正文按 ↓ 落到表格=块前位置:那根光标不坐在文字上,而是在说「你在这一整块旁边」,
    // 整块高就是这句话本身,故刻意不走字形带(用户 0716 定——曾钳成文本高,读作一根没来由的小短条)。
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(_host('prose paragraph\n\n| A | B |\n| --- | --- |\n| 1 | 2 |'));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getTopLeft(find.byType(AnEditor)) + const Offset(30, 10));
      await tester.pumpAndSettle();
      await tester.pressDownArrow(); // prose → the table block's edge 正文 → 表格块边
      await tester.pumpAndSettle();

      final selection = SuperEditorInspector.findDocumentSelection();
      expect(selection?.extent.nodePosition, isA<UpstreamDownstreamNodePosition>(),
          reason: 'the arrow landed on the atomic block, as upstream intends');
      final table = find.byType(AnEditableTable);
      expect(tester.getSize(find.byKey(DocumentKeys.caret)).height, tester.getSize(table).height,
          reason: 'the block-edge caret is as tall as the block it flanks');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the cell paints ONE caret and it is the An band — not the package bar', (tester) async {
    // PIXELS, not parameters. The package paints its caret with `style.color.withValues(alpha: blink)`
    // (super_text_layout caret_layer.dart:182) — that OVERWRITES the alpha, so hiding it with a TRANSPARENT
    // BLACK resurrected it as an OPAQUE BLACK 2×24 bar painted right over ours (measured; it read as "the
    // cell caret is still huge"). Hence `CaretStyle(width: 0)`, and hence this test measures the rendered
    // frame rather than trusting a widget parameter. 量**像素**而非参数:包画光标时会覆写 alpha,故「透明黑」会
    // 复活成不透明黑 2×24 盖在我们那根上(实测,读作「格里光标还是很大」)——故用零宽藏,故本测量真实渲染帧。
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(
            body: RepaintBoundary(child: AnEditor(initialMarkdown: '| Name |\n| --- |\n| plaincell |')),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final cell = find.byType(SuperTextField).at(1);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      // Caret at offset 0 → it sits at the field's left edge, clear of every glyph. 光标置 0,避开所有字形。
      tester.widget<SuperTextField>(cell).textController!.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      final field = tester.getRect(cell);
      await tester.runAsync(() async {
        final image = await tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first).toImage();
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        final w = image.width;
        // The caret column: the bar is AnSize.caret wide centred on the field's left edge. 光标列。
        final x = field.left.floor();
        final inked = <int>[];
        for (var y = field.top.floor(); y < field.bottom.ceil(); y++) {
          final i = (y * w + x) * 4;
          if (data[i] < 200 && data[i + 1] < 200 && data[i + 2] < 200) inked.add(y);
        }
        image.dispose();
        expect(inked, isNotEmpty, reason: 'the An caret must actually paint');
        final painted = inked.last - inked.first + 1;
        // The An band = the measured glyph box (18.15 for Inter 15) ± antialiasing — NOT the 24 line box.
        expect(painted, lessThan(21),
            reason: 'the painted caret is the glyph band (~18), not the package line box (24)');
        expect(painted, greaterThan(15), reason: 'and it is really there, not a sliver');
      });
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('ONE caret at a time', () {
    testWidgets('clicking into the code block drops the document caret', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(_host('prose paragraph\n\n```dart\nvar x = 1;\n```'));
        await tester.pumpAndSettle();

        // Put the document caret in the prose first — the reported repro. 先在正文放文档光标(用户复现序)。
        await tester.tapAt(tester.getTopLeft(find.byType(AnEditor)) + const Offset(30, 10));
        await tester.pumpAndSettle();
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(find.byKey(DocumentKeys.caret), findsOneWidget);

        // Now the code field takes the keyboard. The editor's OWN focus node stays `hasFocus` (the field is
        // a descendant), which is why upstream's own "clear on lose focus" policy can't see this — the An
        // rule keys off `hasPrimaryFocus`. 码块字段拿走键盘:编辑器自身结点 hasFocus 仍 true(字段是后代),故
        // 上游「失焦清选区」看不见此情形——An 规则改看 hasPrimaryFocus。
        await tester.tap(find.byType(TextField).first);
        await tester.pumpAndSettle();

        expect(SuperEditorInspector.findDocumentSelection(), isNull,
            reason: 'the document must drop its selection when an embedded field owns the keyboard');
        expect(find.byKey(DocumentKeys.caret), findsNothing, reason: 'no second caret blinking');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('clicking into a table cell drops the document caret', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(_host('prose paragraph\n\n| A | B |\n| --- | --- |\n| 1 | 2 |'));
        await tester.pumpAndSettle();

        await tester.tapAt(tester.getTopLeft(find.byType(AnEditor)) + const Offset(30, 10));
        await tester.pumpAndSettle();
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);

        await tester.tap(find.byType(SuperTextField).at(2));
        await tester.pumpAndSettle();
        expect(SuperEditorInspector.findDocumentSelection(), isNull);
        expect(find.byKey(DocumentKeys.caret), findsNothing,
            reason: 'the block-edge caret (as tall as the whole table — 72px measured) must not linger');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
