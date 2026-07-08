import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/editor/an_editor_mention.dart';
import 'package:anselm/core/editor/an_editor_slash_menu.dart';
import 'package:anselm/core/editor/an_editor_stylesheet.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/ui/an_code_surface.dart';
import 'package:anselm/core/ui/an_mention_picker.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
// BlinkController lives here — super_editor's barrel `show`-excludes it. 关光标 ticker 用。
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

// E1 — the native super_editor editor's MINIMAL editable surface. These lock the interaction floor the
// PREVIOUS (deleted) rebuild died on — mount, type, and double/triple-tap select — all WITHOUT freezing,
// on the DEFAULT components (before any custom visual/feature layer). If a later step reintroduces the
// freeze, the bisection points straight at that step, not at a mystery. Real CJK IME composition is
// manual-only (Flutter #131510) — the harness (lib/dev/editor_harness_main.dart) covers it.
//
// The caret's blink Ticker is disabled so pumpAndSettle doesn't hang on it (a documented super_editor
// test requirement). 关光标 ticker,否则 pumpAndSettle 挂在它上。

MutableDocument _doc() => MutableDocument(
      nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('hello world foo bar')),
        ParagraphNode(id: 'p2', text: AttributedText('second paragraph here')),
      ],
    );

// A doc that exercises the heading ladder (E2a) + a blockquote (E2b). Known ids so the inspector can
// read each block's resolved style. 走标题阶梯 + 引用的文档:已知 id 供 inspector 读每块样式。
MutableDocument _ladderDoc() => MutableDocument(
      nodes: [
        ParagraphNode(id: 'h1', text: AttributedText('标题一'), metadata: {'blockType': header1Attribution}),
        ParagraphNode(id: 'body', text: AttributedText('正文一段。')),
        ParagraphNode(id: 'h2', text: AttributedText('标题二'), metadata: {'blockType': header2Attribution}),
        ParagraphNode(id: 'h3', text: AttributedText('标题三'), metadata: {'blockType': header3Attribution}),
        ParagraphNode(id: 'quote', text: AttributedText('旁白一句。'), metadata: {'blockType': blockquoteAttribution}),
        ParagraphNode(id: 'code', text: AttributedText('x = 1'), metadata: {'blockType': codeAttribution}),
        ListItemNode.unordered(id: 'ul', text: AttributedText('无序')),
        ListItemNode.ordered(id: 'ol', text: AttributedText('有序')),
        TaskNode(id: 'task-open', text: AttributedText('未完成'), isComplete: false),
        TaskNode(id: 'task-done', text: AttributedText('已完成'), isComplete: true),
      ],
    );

// AnTheme registers the AnColors extension the stylesheet reads via context.colors. 真 An 主题(供样式表取色)。
Widget _host([MutableDocument? doc]) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(body: AnEditor.withDocument(doc ?? _doc())),
    );

int _off(DocumentPosition p) => (p.nodePosition as TextNodePosition).offset;

void main() {
  setUp(() => BlinkController.indeterminateAnimationsEnabled = false);
  tearDown(() => BlinkController.indeterminateAnimationsEnabled = true);

  testWidgets('mounts with NO preset selection (#2995 discipline) and does not crash', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.byType(SuperEditor), findsOneWidget);
    expect(SuperEditorInspector.findDocumentSelection(), isNull); // no selection until the first tap
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing inserts text at the caret in the tapped paragraph', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.placeCaretInParagraph('p1', 0);
    await tester.typeImeText('X'); // super_editor's robot — auto-finds the IME client. 走 IME 路径打字。
    await tester.pumpAndSettle();
    expect(SuperEditorInspector.findTextInComponent('p1').toPlainText(), 'Xhello world foo bar');
  });

  testWidgets('double-tap selects the word — and pumpAndSettle completes (no freeze)', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.doubleTapInParagraph('p1', 2); // inside "hello"
    await tester.pumpAndSettle();
    final sel = SuperEditorInspector.findDocumentSelection();
    expect(sel, isNotNull);
    expect({_off(sel!.base), _off(sel.extent)}, {0, 5}); // "hello"
  });

  testWidgets('triple-tap selects the whole paragraph — no freeze', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.tripleTapInParagraph('p1', 2);
    await tester.pumpAndSettle();
    final sel = SuperEditorInspector.findDocumentSelection()!;
    expect({_off(sel.base), _off(sel.extent)}, {0, 'hello world foo bar'.length});
  });

  testWidgets('rapid repeated taps across paragraphs never crash or hang', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.placeCaretInParagraph(i.isEven ? 'p1' : 'p2', i % 5);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter splits a paragraph into two nodes', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.placeCaretInParagraph('p1', 5); // after "hello"
    await tester.pressEnter();
    await tester.pumpAndSettle();
    // p1 keeps "hello"; a new node holds " world foo bar" (3 nodes total now). Enter 拆块。
    expect(SuperEditorInspector.findTextInComponent('p1').toPlainText(), 'hello');
    expect(tester.takeException(), isNull);
  });

  // E2a — the stylesheet carries the An prose voice: body reads at 15/w300, the heading ladder at
  // 22/18/15 (all w400 — hierarchy is size, never weight), everything in ink. 样式表载 An prose 声。
  testWidgets('E2a stylesheet renders the An prose tiers (body 15 / h1 22 / h2 18 / h3 15, all w400 heads)',
      (tester) async {
    await tester.pumpWidget(_host(_ladderDoc()));
    await tester.pumpAndSettle();
    const ink = Color(0xFF1D1D1F);

    final body = SuperEditorInspector.findParagraphStyle('body')!;
    expect(body.fontSize, AnText.reading.fontSize); // 15
    expect(body.fontWeight, AnText.bodyWeight); // w300
    expect(body.color, ink);

    for (final t in [('h1', 22.0), ('h2', 18.0), ('h3', 15.0)]) {
      final s = SuperEditorInspector.findParagraphStyle(t.$1)!;
      expect(s.fontSize, t.$2, reason: '${t.$1} size');
      expect(s.fontWeight, AnText.emphasisWeight, reason: '${t.$1} is w400, never heavier'); // two-weight rule
      expect(s.color, ink, reason: '${t.$1} colour');
    }
  });

  // E2b — blockquote in the quiet-aside grammar: reading body dropped to inkMuted + a 2px lineStrong
  // left bar (drawn by AnBlockquoteComponentBuilder). 引用:inkMuted + 2px lineStrong 左条。
  testWidgets('E2b blockquote reads at inkMuted 15 with a 2px lineStrong left bar', (tester) async {
    await tester.pumpWidget(_host(_ladderDoc()));
    await tester.pumpAndSettle();

    final quote = SuperEditorInspector.findParagraphStyle('quote')!;
    expect(quote.fontSize, AnText.reading.fontSize); // 15 — still the reading measure
    expect(quote.color, const Color(0xFF6E6E73)); // inkMuted, not ink

    // The An left bar: a Container whose left BorderSide is 2px lineStrong (rgba(0,0,0,.13)). Assert the
    // decoration exists so a regression that drops the bar (back to the default fill) is caught.
    final bars = tester.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      return d is BoxDecoration && d.border is Border && (d.border as Border).left.width == 2;
    });
    expect(bars, isNotEmpty, reason: 'blockquote draws a 2px left bar');
    final bar = (bars.first.decoration as BoxDecoration).border as Border;
    expect(bar.left.color, const Color.fromRGBO(0, 0, 0, 0.13)); // lineStrong
    expect(tester.takeException(), isNull);
  });

  // E2c — fenced code in the An code-surface identity: mono 13/1.6 text inside a framed white island
  // (AnCodeSurface — hairline line border + card round). 围栏代码:mono 13 + AnCodeSurface 白岛框。
  testWidgets('E2c code block reads mono 13 inside an AnCodeSurface frame', (tester) async {
    await tester.pumpWidget(_host(_ladderDoc()));
    await tester.pumpAndSettle();

    final code = SuperEditorInspector.findParagraphStyle('code')!;
    expect(code.fontSize, AnText.codeReading.fontSize); // 13
    expect(code.fontFamily, AnText.codeReading.fontFamily); // mono family
    expect(code.color, const Color(0xFF1D1D1F)); // ink

    // The framed island: exactly one AnCodeSurface (the code block), not applied to prose. 白岛框只此一个。
    expect(find.byType(AnCodeSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // E2d — list items ride the reading body voice, the bullet/numeral is a quiet inkMuted marker. 列表:
  // 正文 reading 声 + inkMuted 静默 bullet。(Bullet colour is driven via the stylesheet's dotColor key.)
  testWidgets('E2d list items read at the reading body voice (15) without crashing', (tester) async {
    await tester.pumpWidget(_host(_ladderDoc()));
    await tester.pumpAndSettle();

    for (final id in ['ul', 'ol']) {
      final s = SuperEditorInspector.findParagraphStyle(id)!;
      expect(s.fontSize, AnText.reading.fontSize, reason: '$id rides reading 15');
      expect(s.color, const Color(0xFF1D1D1F), reason: '$id body is ink');
    }
    // Both list markers rendered (unordered dot + ordered numeral) without layout error. 两种标记都渲染。
    expect(SuperEditorInspector.findTextInComponent('ul').toPlainText(), '无序');
    expect(SuperEditorInspector.findTextInComponent('ol').toPlainText(), '有序');
    expect(tester.takeException(), isNull);
  });

  // E2e — tasks use the An glyph (taskOpen/taskDone at AnSize.icon, inkFaint/ok), NOT a Material
  // Checkbox, and the glyph is tappable to toggle. 任务:An 字形(非 Material Checkbox)可点切换。
  testWidgets('E2e task uses the An glyph (no Material Checkbox) and toggles on tap', (tester) async {
    await tester.pumpWidget(_host(_ladderDoc()));
    await tester.pumpAndSettle();

    // No Material Checkbox anywhere — the An glyph replaces it entirely. 全无 Material Checkbox。
    expect(find.byType(Checkbox), findsNothing);
    // The open task shows the unchecked glyph; the done task shows the checked one. 未/已勾各自字形。
    expect(find.byIcon(AnIcons.taskOpen), findsOneWidget);
    expect(find.byIcon(AnIcons.taskDone), findsOneWidget);

    // Tapping the open task's glyph toggles it complete (drives the editor). 点未完成任务的勾→切完成。
    await tester.tap(find.byIcon(AnIcons.taskOpen));
    await tester.pumpAndSettle();
    expect(find.byIcon(AnIcons.taskDone), findsNWidgets(2)); // both tasks now checked
    expect(tester.takeException(), isNull);
  });

  // E3 — the inline styler maps span attributions to An visuals: bold is w400 (never w700), inline code
  // is mono on a surfaceSunken highlight, links wear the accent. 行内样式器映射:粗 w400/码 mono/链接 accent。
  group('E3 inline styler', () {
    const colors = AnColors.light;
    final base = AnText.reading.copyWith(color: colors.ink);
    TextStyle style(Attribution a) => anInlineTextStyler(colors, {a}, base);

    test('bold is the w400 emphasis weight, NOT bold/w700 (two-weight rule)', () {
      final s = style(boldAttribution);
      expect(s.fontWeight, AnText.emphasisWeight); // w400
      expect(s.fontVariations, const [FontVariation('wght', 400)]); // VF axis moves too
      expect(s.fontWeight, isNot(FontWeight.bold)); // never w700
    });

    test('italic sets FontStyle.italic', () {
      expect(style(italicsAttribution).fontStyle, FontStyle.italic);
    });

    test('strikethrough sets lineThrough', () {
      expect(style(strikethroughAttribution).decoration, TextDecoration.lineThrough);
    });

    test('inline code is mono 13 on a surfaceSunken highlight', () {
      final s = style(codeAttribution);
      expect(s.fontFamily, AnText.mono.fontFamily); // mono face
      expect(s.fontSize, AnText.mono.fontSize); // 13 — the 0.87 prose-to-code ratio
      expect(s.backgroundColor, colors.surfaceSunken);
    });

    test('link wears the accent colour + underline (not the package lightBlue)', () {
      final s = style(LinkAttribution('https://anselm.website'));
      expect(s.color, colors.accent);
      expect(s.decoration, TextDecoration.underline);
    });

    test('bold+italic stack (both applied)', () {
      final s = anInlineTextStyler(colors, {boldAttribution, italicsAttribution}, base);
      expect(s.fontWeight, AnText.emphasisWeight);
      expect(s.fontStyle, FontStyle.italic);
    });
  });

  // E4 — the slash menu: typing `/` opens the AnSlashMenu at the caret; picking a command converts the
  // block; and — the whole reason for this careful rebuild — the overlay NEVER freezes. 斜杠菜单。
  group('E4 slash menu', () {
    // A single empty paragraph so `/` yields an empty query → all commands match. 空段:`/`→空查询→全命中。
    MutableDocument emptyDoc() => MutableDocument(nodes: [ParagraphNode(id: 'p1', text: AttributedText(''))]);
    Widget slashHost() => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: AnEditor.withDocument(emptyDoc())),
        );

    testWidgets('typing "/" opens the slash menu at the caret', (tester) async {
      await tester.pumpWidget(slashHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('/');
      await tester.pumpAndSettle();
      expect(find.byType(AnSlashMenu), findsOneWidget); // popover shown
      expect(tester.takeException(), isNull);
    });

    testWidgets('typing "/h" filters to the headings', (tester) async {
      await tester.pumpWidget(slashHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('/h');
      await tester.pumpAndSettle();
      // Headings match "h"/"h1"/"heading"; body/quote/code/list/task do not. 只标题命中。
      expect(find.text('标题 1'), findsOneWidget);
      expect(find.text('引用'), findsNothing);
    });

    testWidgets('picking a command converts the block (→ heading 1) and closes the menu', (tester) async {
      await tester.pumpWidget(slashHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('标题 1'));
      await tester.pumpAndSettle();
      expect(find.byType(AnSlashMenu), findsNothing); // menu gone
      // The `/` text was deleted and the block is now header1 (22px). `/` 已删,块变 h1。
      expect(SuperEditorInspector.findParagraphStyle('p1')!.fontSize, 22.0);
      expect(SuperEditorInspector.findTextInComponent('p1').toPlainText(), isEmpty);
    });

    testWidgets('Escape dismisses the menu without converting', (tester) async {
      await tester.pumpWidget(slashHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('/');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AnSlashMenu), findsNothing);
      expect(SuperEditorInspector.findParagraphStyle('p1')!.fontSize, AnText.reading.fontSize); // still 15 body
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening the menu then double-tapping elsewhere NEVER freezes (the whole point)', (tester) async {
      await tester.pumpWidget(slashHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('/');
      await tester.pumpAndSettle();
      expect(find.byType(AnSlashMenu), findsOneWidget);
      // Double-tap into the same paragraph while the menu is open — pumpAndSettle must COMPLETE. 菜单开时双击。
      await tester.doubleTapInParagraph('p1', 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // E5a — an entity @mention embedded as an inline placeholder renders as an icon+name pill (not styled
  // text), driven through the stylesheet's inlineWidgetBuilders. 内联提及 placeholder 渲成图标+名药丸。
  testWidgets('E5a mention placeholder renders as an inline icon+name pill', (tester) async {
    final doc = MutableDocument(nodes: [
      ParagraphNode(
        id: 'p1',
        text: AttributedText('见 。', null, {
          2: const MentionPlaceholder(id: 'wf_00000000000000a1', name: '每日销量对账', kind: 'workflow'),
        }),
      ),
    ]);
    await tester.pumpWidget(_host(doc));
    await tester.pumpAndSettle();
    // The pill shows the resolved name (not the id) + a kind glyph. 药丸显名(非 id)+ kind 图标。
    expect(find.text('每日销量对账'), findsOneWidget);
    expect(find.byIcon(AnIcons.byKey('workflow')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // E5b/c — the `@` interactive flow: typing `@` opens the AnMentionPanel picker (StableTagPlugin drives
  // tokenizing); picking deletes the `@query` and inserts the mention pill; no freeze. @ 提及交互流。
  group('E5 @ mention flow', () {
    Widget mentionHost() {
      final doc = MutableDocument(nodes: [ParagraphNode(id: 'p1', text: AttributedText(''))]);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: AnEditor.withDocument(doc, mentionSource: _FakeMentionSource())),
      );
    }

    testWidgets('typing "@" opens the mention picker with candidates', (tester) async {
      await tester.pumpWidget(mentionHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('@');
      await tester.pumpAndSettle();
      expect(find.byType(AnMentionPanel), findsOneWidget);
      expect(find.text('每日销量对账'), findsOneWidget); // a candidate row
      expect(tester.takeException(), isNull);
    });

    testWidgets('picking a candidate inserts the mention pill and closes the picker', (tester) async {
      await tester.pumpWidget(mentionHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('@');
      await tester.pumpAndSettle();
      await tester.tap(find.text('每日销量对账'));
      await tester.pumpAndSettle();
      expect(find.byType(AnMentionPanel), findsNothing); // picker closed
      // The pill (label + kind glyph) is now embedded in the paragraph. 药丸落进段落。
      expect(find.text('每日销量对账'), findsOneWidget);
      expect(find.byIcon(AnIcons.byKey('workflow')), findsOneWidget);
      // The literal `@query` text is gone (replaced by the pill placeholder). `@query` 文本已被药丸替换。
      expect(SuperEditorInspector.findTextInComponent('p1').toPlainText().contains('@'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('typing "@" then double-tapping elsewhere never freezes', (tester) async {
      await tester.pumpWidget(mentionHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('@');
      await tester.pumpAndSettle();
      await tester.doubleTapInParagraph('p1', 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // E6 — the floating format toolbar: an EXPANDED selection surfaces it; a collapsed one hides it; tapping
  // bold toggles boldAttribution over the selection. 划选浮动格式条。
  group('E6 selection toolbar', () {
    testWidgets('an expanded selection shows the toolbar; tapping bold toggles it (→ w400 in the styler)',
        (tester) async {
      final doc = MutableDocument(nodes: [ParagraphNode(id: 'p1', text: AttributedText('hello world'))]);
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      await tester.doubleTapInParagraph('p1', 2); // select "hello"
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.bold), findsOneWidget); // toolbar surfaced

      await tester.tap(find.byIcon(AnIcons.bold));
      await tester.pumpAndSettle();
      final text = SuperEditorInspector.findTextInComponent('p1');
      expect(text.getAllAttributionsThroughout(const SpanRange(0, 4)).contains(boldAttribution), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a collapsed caret shows NO toolbar', (tester) async {
      final doc = MutableDocument(nodes: [ParagraphNode(id: 'p1', text: AttributedText('hello world'))]);
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 2); // collapsed caret
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.bold), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // E9b — the markdown bridge: AnEditor loads a document from markdown (mentions inflate to named pills)
  // and reports every edit back as markdown for the caller to save. markdown 载入/回吐桥。
  group('E9b markdown bridge', () {
    testWidgets('loads a [[id]] mention from markdown, inflated to a named pill (kind from the prefix)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: AnEditor(
            initialMarkdown: '见 [[wf_00000000000000a1]] 的结果',
            resolvedNames: const {'wf_00000000000000a1': '每日销量对账'},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // The pill's label + glyph are real widgets (the paragraph text is RichText, so we assert via the
      // pill) → proves the markdown parsed AND the [[id]] inflated with the resolved name + derived kind.
      expect(find.text('每日销量对账'), findsOneWidget);
      expect(find.byIcon(AnIcons.byKey('workflow')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports edits back as markdown (onChangedMarkdown)', (tester) async {
      String? latest;
      final doc = MutableDocument(nodes: [ParagraphNode(id: 'p1', text: AttributedText('正文'))]);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: AnEditor.withDocument(doc, onChangedMarkdown: (md) => latest = md)),
      ));
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 2); // caret after "正文"
      await tester.typeImeText('X');
      await tester.pumpAndSettle();
      expect(latest, isNotNull); // an edit fired the markdown callback
      expect(latest!.contains('正文X'), isTrue); // the new text is in the serialized markdown
      expect(tester.takeException(), isNull);
    });
  });

  // E7 — code blocks get syntax highlight via the memoized style phase (through the ONE highlightCode
  // tokenizer), painted as ColorAttributions the inline styler renders. 代码块语法高亮(记忆化 style phase)。
  testWidgets('E7 code block keywords render in the syntax keyword colour', (tester) async {
    final doc = MutableDocument(nodes: [
      ParagraphNode(id: 'code', text: AttributedText('const x = 1;'), metadata: {'blockType': codeAttribution}),
    ]);
    await tester.pumpWidget(_host(doc));
    await tester.pumpAndSettle();

    final rich = SuperEditorInspector.findRichTextInParagraph('code');
    final colors = <Color>[];
    rich.visitChildren((span) {
      if (span is TextSpan && span.style?.color != null) colors.add(span.style!.color!);
      return true;
    });
    // `const` is a keyword and `1` is a number → those syntax colours appear (highlighting is on).
    // const=关键字色、1=数字色。
    expect(colors, contains(SyntaxColors.light.keyword));
    expect(colors, contains(SyntaxColors.light.number));
    expect(tester.takeException(), isNull);
  });

  // E8 — a markdown table loads (built-in codec) and renders as a real Flutter Table with the An grid.
  // markdown 表格载入 + 渲成真 Flutter Table(An 网格)。
  testWidgets('E8 a markdown table loads and renders as a Table', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: const Scaffold(body: AnEditor(initialMarkdown: '| A | B |\n| --- | --- |\n| 1 | 2 |')),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsWidgets); // the table rendered
    expect(tester.takeException(), isNull);
  });
}

/// A fixture entity source for the mention tests — three candidates, name/id substring filtered. 测试用假源。
class _FakeMentionSource implements MentionSource {
  static const _all = [
    MentionCandidate(type: 'workflow', id: 'wf_00000000000000a1', name: '每日销量对账'),
    MentionCandidate(type: 'function', id: 'fn_00000000000000b2', name: '汇总日报'),
    MentionCandidate(type: 'agent', id: 'ag_00000000000000c3', name: '数据分析助手'),
  ];

  @override
  Future<List<MentionCandidate>> search(String query) async {
    if (query.isEmpty) return _all;
    return _all.where((c) => c.name.contains(query) || c.id.contains(query)).toList();
  }

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async => const {};
}
