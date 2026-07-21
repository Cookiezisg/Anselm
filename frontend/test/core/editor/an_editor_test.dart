import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/editor/an_editor_components.dart';
import 'package:anselm/core/editor/an_editor_inline_code.dart';
import 'package:anselm/core/editor/an_editor_mention.dart';
import 'package:anselm/core/editor/an_editor_quote.dart';
import 'package:anselm/core/editor/an_editor_text_component.dart';
import 'package:anselm/core/editor/an_editor_slash_menu.dart';
import 'package:anselm/core/editor/an_editor_stylesheet.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/an_mention_picker.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
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
    ParagraphNode(
      id: 'h1',
      text: AttributedText('标题一'),
      metadata: {'blockType': header1Attribution},
    ),
    ParagraphNode(id: 'body', text: AttributedText('正文一段。')),
    ParagraphNode(
      id: 'h2',
      text: AttributedText('标题二'),
      metadata: {'blockType': header2Attribution},
    ),
    ParagraphNode(
      id: 'h3',
      text: AttributedText('标题三'),
      metadata: {'blockType': header3Attribution},
    ),
    ParagraphNode(
      id: 'quote',
      text: AttributedText('旁白一句。'),
      metadata: {'blockType': blockquoteAttribution},
    ),
    CodeBlockNode(id: 'code', code: 'x = 1'),
    ListItemNode.unordered(id: 'ul', text: AttributedText('无序')),
    ListItemNode.ordered(id: 'ol', text: AttributedText('有序')),
    TaskNode(id: 'task-open', text: AttributedText('未完成'), isComplete: false),
    TaskNode(id: 'task-done', text: AttributedText('已完成'), isComplete: true),
  ],
);

// AnTheme registers the AnColors extension the stylesheet reads via context.colors; TranslationProvider
// feeds the slash palette's slang labels. 真 An 主题(供样式表取色)+ slang(slash 标签)。
Widget _host([MutableDocument? doc]) => TranslationProvider(
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(body: AnEditor.withDocument(doc ?? _doc())),
  ),
);

int _off(DocumentPosition p) => (p.nodePosition as TextNodePosition).offset;

void main() {
  setUpAll(
    () => LocaleSettings.setLocaleRaw('zh-CN'),
  ); // slash 标签断言走中文 the tests assert zh labels
  setUp(() => BlinkController.indeterminateAnimationsEnabled = false);
  tearDown(() => BlinkController.indeterminateAnimationsEnabled = true);

  testWidgets(
    'mounts with NO preset selection (#2995 discipline) and does not crash',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.byType(SuperEditor), findsOneWidget);
      expect(
        SuperEditorInspector.findDocumentSelection(),
        isNull,
      ); // no selection until the first tap
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('typing inserts text at the caret in the tapped paragraph', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.placeCaretInParagraph('p1', 0);
    await tester.typeImeText(
      'X',
    ); // super_editor's robot — auto-finds the IME client. 走 IME 路径打字。
    await tester.pumpAndSettle();
    expect(
      SuperEditorInspector.findTextInComponent('p1').toPlainText(),
      'Xhello world foo bar',
    );
  });

  testWidgets(
    'double-tap selects the word — and pumpAndSettle completes (no freeze)',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await tester.doubleTapInParagraph('p1', 2); // inside "hello"
      await tester.pumpAndSettle();
      final sel = SuperEditorInspector.findDocumentSelection();
      expect(sel, isNotNull);
      expect({_off(sel!.base), _off(sel.extent)}, {0, 5}); // "hello"
    },
  );

  testWidgets('triple-tap selects the whole paragraph — no freeze', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.tripleTapInParagraph('p1', 2);
    await tester.pumpAndSettle();
    final sel = SuperEditorInspector.findDocumentSelection()!;
    expect(
      {_off(sel.base), _off(sel.extent)},
      {0, 'hello world foo bar'.length},
    );
  });

  testWidgets('rapid repeated taps across paragraphs never crash or hang', (
    tester,
  ) async {
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
    expect(
      SuperEditorInspector.findTextInComponent('p1').toPlainText(),
      'hello',
    );
    expect(tester.takeException(), isNull);
  });

  // E2a — the stylesheet carries the An prose voice: body reads at 15/w300, the heading ladder at
  // 22/18/15 (all w400 — hierarchy is size, never weight), everything in ink. 样式表载 An prose 声。
  testWidgets(
    'E2a stylesheet renders the An prose tiers (body 15 / h1 22 / h2 18 / h3 15, all w400 heads)',
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
        expect(
          s.fontWeight,
          AnText.emphasisWeight,
          reason: '${t.$1} is w400, never heavier',
        ); // two-weight rule
        expect(s.color, ink, reason: '${t.$1} colour');
      }
    },
  );

  // E2b — blockquote in the quiet-aside grammar: reading body dropped to inkMuted + a 2px lineStrong
  // left bar (drawn by AnBlockquoteComponentBuilder). 引用:inkMuted + 2px lineStrong 左条。
  testWidgets(
    'E2b blockquote reads at inkMuted 15 with a 2px lineStrong left bar',
    (tester) async {
      await tester.pumpWidget(_host(_ladderDoc()));
      await tester.pumpAndSettle();

      final quote = SuperEditorInspector.findParagraphStyle('quote')!;
      expect(
        quote.fontSize,
        AnText.reading.fontSize,
      ); // 15 — still the reading measure
      expect(quote.color, const Color(0xFF6E6E73)); // inkMuted, not ink

      // The An left bar: a Container whose left BorderSide is 2px lineStrong (rgba(0,0,0,.13)). Assert the
      // decoration exists so a regression that drops the bar (back to the default fill) is caught.
      final bars = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final d = c.decoration;
        return d is BoxDecoration &&
            d.border is Border &&
            (d.border as Border).left.width == 2;
      });
      expect(bars, isNotEmpty, reason: 'blockquote draws a 2px left bar');
      final bar = (bars.first.decoration as BoxDecoration).border as Border;
      expect(bar.left.color, const Color.fromRGBO(0, 0, 0, 0.13)); // lineStrong
      expect(tester.takeException(), isNull);
    },
  );

  // E2c — a fenced code block IS the product's one code widget: an embedded [AnCodeEditor] (the SAME
  // widget entities/function pages use), framed + directly editable ([AnCodeEditor.seamless]) — NOT a
  // super_editor paragraph. So the document code block is pixel-1:1 with the entity pages (frame + gutter +
  // syntax + copy) and editable in place. 围栏代码=产品唯一代码件:嵌入 AnCodeEditor(entities/function 同款,有框
  // 可直接编辑),非 super_editor 段落——与实体页逐像素一致且就地可编辑。
  testWidgets(
    'E2c code block IS an embedded editable AnCodeEditor (entity-page identity)',
    (tester) async {
      await tester.pumpWidget(_host(_ladderDoc()));
      await tester.pumpAndSettle();

      // Exactly one AnCodeEditor (the code block), carrying the node's code, in the seamless framed mode. 唯一。
      final finder = find.byType(AnCodeEditor);
      expect(finder, findsOneWidget);
      final editor = tester.widget<AnCodeEditor>(finder);
      expect(editor.code, 'x = 1');
      expect(editor.seamless, isTrue); // framed + direct-edit-in-place
      expect(editor.editable, isTrue);
      // Direct edit means a live TextField (EditableText), not a read-only SelectableText. 可直接编辑=活 TextField。
      expect(
        find.descendant(of: finder, matching: find.byType(EditableText)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // E2d — list items ride the reading body voice, the bullet/numeral is a quiet inkMuted marker. 列表:
  // 正文 reading 声 + inkMuted 静默 bullet。(Bullet colour is driven via the stylesheet's dotColor key.)
  testWidgets(
    'E2d list items read at the reading body voice (15) without crashing',
    (tester) async {
      await tester.pumpWidget(_host(_ladderDoc()));
      await tester.pumpAndSettle();

      for (final id in ['ul', 'ol']) {
        final s = SuperEditorInspector.findParagraphStyle(id)!;
        expect(
          s.fontSize,
          AnText.reading.fontSize,
          reason: '$id rides reading 15',
        );
        expect(s.color, const Color(0xFF1D1D1F), reason: '$id body is ink');
      }
      // Both list markers rendered (unordered dot + ordered numeral) without layout error. 两种标记都渲染。
      expect(
        SuperEditorInspector.findTextInComponent('ul').toPlainText(),
        '无序',
      );
      expect(
        SuperEditorInspector.findTextInComponent('ol').toPlainText(),
        '有序',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // E2e — tasks use the An glyph (taskOpen/taskDone at AnSize.icon, inkFaint/ok), NOT a Material
  // Checkbox, and the glyph is tappable to toggle. 任务:An 字形(非 Material Checkbox)可点切换。
  testWidgets(
    'E2e task uses the An glyph (no Material Checkbox) and toggles on tap',
    (tester) async {
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
      expect(
        find.byIcon(AnIcons.taskDone),
        findsNWidgets(2),
      ); // both tasks now checked
      expect(tester.takeException(), isNull);
    },
  );

  // E3 — the inline styler maps span attributions to An visuals: bold is w400 (never w700), inline code
  // is mono on a surfaceSunken highlight, links wear the accent. 行内样式器映射:粗 w400/码 mono/链接 accent。
  group('E3 inline styler', () {
    const colors = AnColors.light;
    final base = AnText.reading.copyWith(color: colors.ink);
    TextStyle style(Attribution a) => anInlineTextStyler(colors, {a}, base);

    test(
      'bold is the w400 emphasis weight, NOT bold/w700 (two-weight rule)',
      () {
        final s = style(boldAttribution);
        expect(s.fontWeight, AnText.emphasisWeight); // w400
        expect(s.fontVariations, const [
          FontVariation('wght', 400),
        ]); // VF axis moves too
        expect(s.fontWeight, isNot(FontWeight.bold)); // never w700
      },
    );

    test('italic sets FontStyle.italic', () {
      expect(style(italicsAttribution).fontStyle, FontStyle.italic);
    });

    test('strikethrough sets lineThrough', () {
      expect(
        style(strikethroughAttribution).decoration,
        TextDecoration.lineThrough,
      );
    });

    test(
      'inline code is mono 13 with NO backgroundColor (paint-beneath draws the rounded block)',
      () {
        final s = style(codeAttribution);
        expect(s.fontFamily, AnText.mono.fontFamily); // mono face
        expect(
          s.fontSize,
          AnText.mono.fontSize,
        ); // 13 — the 0.87 prose-to-code ratio
        // The gray block is a per-line rounded RRect painted beneath by AnTextComponent, NOT a tight text
        // backgroundColor rect — so the styler must leave backgroundColor null. 灰块由 painter 画,样式器不设背景色。
        expect(s.backgroundColor, isNull);
      },
    );

    test(
      'link wears the accent colour + underline (not the package lightBlue)',
      () {
        final s = style(LinkAttribution('https://anselm.website'));
        expect(s.color, colors.accent);
        expect(s.decoration, TextDecoration.underline);
      },
    );

    test('bold+italic stack (both applied)', () {
      final s = anInlineTextStyler(colors, {
        boldAttribution,
        italicsAttribution,
      }, base);
      expect(s.fontWeight, AnText.emphasisWeight);
      expect(s.fontStyle, FontStyle.italic);
    });
  });

  // E4 — the slash menu: typing `/` opens the AnSlashMenu at the caret; picking a command converts the
  // block; and — the whole reason for this careful rebuild — the overlay NEVER freezes. 斜杠菜单。
  group('E4 slash menu', () {
    // A single empty paragraph so `/` yields an empty query → all commands match. 空段:`/`→空查询→全命中。
    MutableDocument emptyDoc() => MutableDocument(
      nodes: [ParagraphNode(id: 'p1', text: AttributedText(''))],
    );
    Widget slashHost() => TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: AnEditor.withDocument(emptyDoc())),
      ),
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

    testWidgets(
      'picking a command converts the block (→ heading 1) and closes the menu',
      (tester) async {
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
        expect(
          SuperEditorInspector.findTextInComponent('p1').toPlainText(),
          isEmpty,
        );
      },
    );

    testWidgets('Escape dismisses the menu without converting', (tester) async {
      await tester.pumpWidget(slashHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('/');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AnSlashMenu), findsNothing);
      expect(
        SuperEditorInspector.findParagraphStyle('p1')!.fontSize,
        AnText.reading.fontSize,
      ); // still 15 body
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'opening the menu then double-tapping elsewhere NEVER freezes (the whole point)',
      (tester) async {
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
      },
    );

    testWidgets(
      'divider on an EMPTY paragraph replaces it with an HR + a fresh trailing paragraph',
      (tester) async {
        await tester.pumpWidget(slashHost());
        await tester.pumpAndSettle();
        await tester.placeCaretInParagraph('p1', 0);
        await tester.typeImeText(
          '/fenge',
        ); // keyword filters to the one row (the full palette overflows the panel)
        await tester.pumpAndSettle();
        await tester.tap(find.text('分隔线'));
        await tester.pumpAndSettle();
        final doc = tester.state<AnEditorState>(find.byType(AnEditor)).document;
        expect(doc.toList().whereType<HorizontalRuleNode>(), hasLength(1));
        expect(
          doc.toList().last,
          isA<ParagraphNode>(),
        ); // the writer keeps typing below 尾随新段收光标
        expect(
          doc.toList().whereType<ParagraphNode>().where((n) => n.id == 'p1'),
          isEmpty,
          reason: 'the empty trigger paragraph was REPLACED',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'table on a NON-empty paragraph inserts BELOW, preserving the text',
      (tester) async {
        final doc = MutableDocument(
          nodes: [ParagraphNode(id: 'p1', text: AttributedText('前文'))],
        );
        await tester.pumpWidget(_host(doc));
        await tester.pumpAndSettle();
        await tester.placeCaretInParagraph('p1', 2);
        await tester.typeImeText('/biaoge'); // pinyin keyword hits 表格 拼音关键词命中
        await tester.pumpAndSettle();
        await tester.tap(find.text('表格'));
        await tester.pumpAndSettle();
        final nodes = doc.toList();
        expect(nodes.whereType<TableBlockNode>(), hasLength(1));
        final p1 = doc.getNodeById('p1');
        expect(p1, isA<TextNode>());
        expect(
          (p1 as TextNode).text.toPlainText(),
          '前文',
          reason: 'non-empty paragraph preserved 非空段保留',
        );
        expect(
          nodes.indexWhere((n) => n is TableBlockNode),
          greaterThan(nodes.indexWhere((n) => n.id == 'p1')),
        );
        expect(nodes.last, isA<ParagraphNode>());
        expect(tester.takeException(), isNull);
      },
    );
  });

  // E5a — an entity @mention embedded as an inline placeholder renders as an icon+name pill (not styled
  // text), driven through the stylesheet's inlineWidgetBuilders. 内联提及 placeholder 渲成图标+名药丸。
  testWidgets('E5a mention placeholder renders as an inline icon+name pill', (
    tester,
  ) async {
    final doc = MutableDocument(
      nodes: [
        ParagraphNode(
          id: 'p1',
          text: AttributedText('见 。', null, {
            2: const MentionPlaceholder(
              id: 'wf_00000000000000a1',
              name: '每日销量对账',
              kind: 'workflow',
            ),
          }),
        ),
      ],
    );
    await tester.pumpWidget(_host(doc));
    await tester.pumpAndSettle();
    // The pill shows the resolved name (not the id) + a kind glyph. 药丸显名(非 id)+ kind 图标。
    expect(find.text('每日销量对账'), findsOneWidget);
    expect(find.byIcon(AnIcons.byKey('workflow')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Notion backspace-revert: Backspace at the START of a heading reverts it to a plain paragraph (NOT a
  // merge-into-the-block-above). 退格回退:标题行首退格→普通段落(非上合并)。
  testWidgets(
    'Backspace at the start of a heading reverts it to a plain paragraph (Notion feel)',
    (tester) async {
      await tester.pumpWidget(_host(_ladderDoc()));
      await tester.pumpAndSettle();
      expect(
        SuperEditorInspector.findParagraphStyle('h2')!.fontSize,
        AnText.readingH2.fontSize,
        reason: 'starts as H2',
      );
      await tester.placeCaretInParagraph('h2', 0);
      await tester.pressBackspace();
      await tester.pumpAndSettle();
      // Now a plain paragraph — the heading was demoted, not merged upward. 降级为段落、未上合并。
      expect(
        SuperEditorInspector.findParagraphStyle('h2')!.fontSize,
        AnText.reading.fontSize,
        reason: 'reverted to body',
      );
      expect(
        SuperEditorInspector.findTextInComponent('h2').toPlainText(),
        '标题二',
        reason: 'text intact, not merged',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Backspace at the start of a blockquote reverts it to a plain paragraph',
    (tester) async {
      await tester.pumpWidget(_host(_ladderDoc()));
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('quote', 0);
      await tester.pressBackspace();
      await tester.pumpAndSettle();
      // The blockquote left bar is gone — it's a plain paragraph now (text preserved). 引用降级为段落。
      expect(
        SuperEditorInspector.findTextInComponent('quote').toPlainText(),
        '旁白一句。',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // E5a′ — inline code is a plain codeAttribution TEXT run (wrapping, editable) rendered through the vendored
  // AnTextComponent, which paints a rounded background BENEATH it (paint-beneath, via CodeBackgroundLayer) — NOT
  // an atomic chip widget. 行内代码=codeAttribution 文本,经 AnTextComponent 在底层画圆角背景(CodeBackgroundLayer),非芯片。
  testWidgets(
    'inline code renders as codeAttribution text with a CodeBackgroundLayer painted beneath',
    (tester) async {
      final text = AttributedText('调用 fetch 前先 validate 一下。');
      text.addAttribution(codeAttribution, const SpanRange(3, 7)); // "fetch"
      text.addAttribution(
        codeAttribution,
        const SpanRange(11, 18),
      ); // "validate"
      // A SECOND block so the paragraph flows through AnParagraphComponent (a single node would be a HintVM).
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(id: 'p1', text: text),
          ParagraphNode(id: 'p2', text: AttributedText('尾段')),
        ],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      // Paragraphs (incl. those with inline code) render through the vendored AnParagraphComponent → AnTextComponent.
      expect(find.byType(AnParagraphComponent), findsWidgets);
      expect(find.byType(AnTextComponent), findsWidgets);
      // The rounded gray block is a real paint layer beneath the text — the heart of the paint-beneath design.
      expect(find.byType(CodeBackgroundLayer), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  // The single-paragraph edge: an empty first node still shows the placeholder AND the code background works via
  // the An-flavored hint component. 单段边角:空首段仍显占位,行内代码走 An hint 组件也有背景。
  testWidgets(
    'a single paragraph with inline code paints the code background via AnTextWithHintComponent',
    (tester) async {
      final text = AttributedText('跑 make 一下');
      text.addAttribution(codeAttribution, const SpanRange(2, 5)); // "make"
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: 'p1', text: text)],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      // Single node → HintComponentViewModel → AnTextWithHintComponent (which still embeds AnTextComponent + bg).
      expect(find.byType(AnTextWithHintComponent), findsOneWidget);
      expect(find.byType(CodeBackgroundLayer), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  // The inline-code NBSP padding spacer keeps the FULL mono font size (its 4px width comes from negative
  // letterSpacing, NOT a shrunk font) — otherwise the caret, whose height is the height of the character it sits
  // on, turned stubby the instant it landed on the spacer at a code edge. 内距占位保持满字号(4px 靠负 letterSpacing);
  // 否则光标落到码边占位符上会变矮。
  testWidgets(
    'caret stays full height at an inline-code edge (spacer keeps full mono size)',
    (tester) async {
      final base = AttributedText('x code y');
      base.addAttribution(codeAttribution, const SpanRange(2, 5)); // "code"
      final padded = padCodeRuns(
        base,
      ).text; // → x ␣[NBSP]code[NBSP]␣ y ; leading spacer lands at offset 2
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: 'p1', text: padded)],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      final layout = SuperEditorInspector.findDocumentLayout();
      double caretH(int offset) => layout
          .getRectForPosition(
            DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: offset),
            ),
          )!
          .height;
      final atSpacer = caretH(2); // the NBSP padding spacer at the code edge
      final atCode = caretH(4); // inside "code"
      // The spacer's caret must be full height (the mono line box ~20px) — NOT the ~½-height stub a shrunk-font
      // spacer produced — and must match the code caret beside it (both mono). 占位处光标须满高(≈mono 行盒),与代码同档。
      expect(
        atSpacer,
        greaterThan(15),
        reason: 'caret at the code-edge spacer is full height, not stubby',
      );
      expect(
        (atSpacer - atCode).abs(),
        lessThan(2.0),
        reason: 'spacer caret matches the adjacent code caret (both mono)',
      );
    },
  );

  // E5b/c — the `@` interactive flow: typing `@` opens the AnMentionPanel picker (StableTagPlugin drives
  // tokenizing); picking deletes the `@query` and inserts the mention pill; no freeze. @ 提及交互流。
  group('E5 @ mention flow', () {
    Widget mentionHost() {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: 'p1', text: AttributedText(''))],
      );
      return TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: AnEditor.withDocument(
              doc,
              mentionSource: _FakeMentionSource(),
            ),
          ),
        ),
      );
    }

    testWidgets('typing "@" opens the mention picker with candidates', (
      tester,
    ) async {
      await tester.pumpWidget(mentionHost());
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 0);
      await tester.typeImeText('@');
      await tester.pumpAndSettle();
      expect(find.byType(AnMentionPanel), findsOneWidget);
      expect(find.text('每日销量对账'), findsOneWidget); // a candidate row
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'picking a candidate inserts the mention pill and closes the picker',
      (tester) async {
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
        expect(
          SuperEditorInspector.findTextInComponent(
            'p1',
          ).toPlainText().contains('@'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('typing "@" then double-tapping elsewhere never freezes', (
      tester,
    ) async {
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
    testWidgets(
      'an expanded selection shows the toolbar; tapping bold toggles it (→ w400 in the styler)',
      (tester) async {
        final doc = MutableDocument(
          nodes: [ParagraphNode(id: 'p1', text: AttributedText('hello world'))],
        );
        await tester.pumpWidget(_host(doc));
        await tester.pumpAndSettle();
        await tester.doubleTapInParagraph('p1', 2); // select "hello"
        await tester.pumpAndSettle();
        expect(find.byIcon(AnIcons.bold), findsOneWidget); // toolbar surfaced

        await tester.tap(find.byIcon(AnIcons.bold));
        await tester.pumpAndSettle();
        final text = SuperEditorInspector.findTextInComponent('p1');
        expect(
          text
              .getAllAttributionsThroughout(const SpanRange(0, 4))
              .contains(boldAttribution),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a collapsed caret shows NO toolbar', (tester) async {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: 'p1', text: AttributedText('hello world'))],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      await tester.placeCaretInParagraph('p1', 2); // collapsed caret
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.bold), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the link button opens the URL input; Enter applies a LinkAttribution (https:// added)',
      (tester) async {
        final doc = MutableDocument(
          nodes: [ParagraphNode(id: 'p1', text: AttributedText('hello world'))],
        );
        await tester.pumpWidget(_host(doc));
        await tester.pumpAndSettle();
        await tester.doubleTapInParagraph('p1', 2); // select "hello"
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(AnIcons.link));
        await tester.pumpAndSettle();
        // The bar swapped into the URL input (the format buttons are gone, a text field is up). 原位换输入。
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(AnIcons.bold), findsNothing);

        await tester.enterText(find.byType(TextField), 'anselm.website/docs');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        final text = SuperEditorInspector.findTextInComponent('p1');
        final links = text
            .getAllAttributionsThroughout(const SpanRange(0, 4))
            .whereType<LinkAttribution>()
            .toList();
        expect(links, hasLength(1));
        expect(
          links.single.plainTextUri.toString(),
          'https://anselm.website/docs',
        ); // bare domain normalized
        expect(find.byType(TextField), findsNothing); // session closed 会话已收
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tapping OUTSIDE the URL input dismisses it without linking', (
      tester,
    ) async {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: 'p1', text: AttributedText('hello world'))],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      await tester.doubleTapInParagraph('p1', 2);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AnIcons.link));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.tapAt(const Offset(500, 500)); // far from the bar 远离浮条
      await tester.pumpAndSettle();
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'outside tap cancels the session 外点即取消',
      );
      final text = SuperEditorInspector.findTextInComponent('p1');
      expect(
        text
            .getAllAttributionsThroughout(const SpanRange(0, 4))
            .whereType<LinkAttribution>(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('on an already-linked selection the same button UNLINKS', (
      tester,
    ) async {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(
            id: 'p1',
            text: AttributedText(
              'hello world',
              AttributedSpans(
                attributions: [
                  SpanMarker(
                    attribution: LinkAttribution('https://a.b'),
                    offset: 0,
                    markerType: SpanMarkerType.start,
                  ),
                  SpanMarker(
                    attribution: LinkAttribution('https://a.b'),
                    offset: 4,
                    markerType: SpanMarkerType.end,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();
      await tester.doubleTapInParagraph(
        'p1',
        2,
      ); // select "hello" (fully linked)
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AnIcons.link));
      await tester.pumpAndSettle();
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'linked selection unlinks directly — no input',
      );
      final text = SuperEditorInspector.findTextInComponent('p1');
      expect(
        text
            .getAllAttributionsThroughout(const SpanRange(0, 4))
            .whereType<LinkAttribution>(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  });

  // E9b — the markdown bridge: AnEditor loads a document from markdown (mentions inflate to named pills)
  // and reports every edit back as markdown for the caller to save. markdown 载入/回吐桥。
  group('E9b markdown bridge', () {
    testWidgets(
      'loads a [[id]] mention from markdown, inflated to a named pill (kind from the prefix)',
      (tester) async {
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AnTheme.light(),
              home: Scaffold(
                body: AnEditor(
                  initialMarkdown: '见 [[wf_00000000000000a1]] 的结果',
                  resolvedNames: const {'wf_00000000000000a1': '每日销量对账'},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // The pill's label + glyph are real widgets (the paragraph text is RichText, so we assert via the
        // pill) → proves the markdown parsed AND the [[id]] inflated with the resolved name + derived kind.
        expect(find.text('每日销量对账'), findsOneWidget);
        expect(find.byIcon(AnIcons.byKey('workflow')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reports edits back as markdown (onChangedMarkdown), serialize-on-idle',
      (tester) async {
        String? latest;
        final doc = MutableDocument(
          nodes: [ParagraphNode(id: 'p1', text: AttributedText('正文'))],
        );
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AnTheme.light(),
              home: Scaffold(
                body: AnEditor.withDocument(
                  doc,
                  onChangedMarkdown: (md) => latest = md,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.placeCaretInParagraph('p1', 2); // caret after "正文"
        await tester.typeImeText('X');
        // Serialization rides the autosave debounce tier (whole-document serialize must NOT run per
        // keystroke) — nothing fires inside the quiet window… 序列化走 autosave 防抖档,安静窗口内不发…
        await tester.pump();
        expect(
          latest,
          isNull,
          reason: 'no per-keystroke whole-document serialize',
        );
        // …and the burst's final state lands after it. …窗口过后落突发终态。
        await tester.pump(AnMotion.autosave);
        await tester.pumpAndSettle();
        expect(
          latest,
          isNotNull,
        ); // the edit fired the markdown callback on idle
        expect(
          latest!.contains('正文X'),
          isTrue,
        ); // the new text is in the serialized markdown
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ③ Blockquote mouse hit-testing — a LOADED quote (quoteDepth metadata, the codec path) must accept a
  // real tap: the bar/inset wrapper is IgnorePointer'd so the click falls through to the gesture layer
  // (which sits BENEATH the content in hit order; a bare BoxDecoration wrapper used to swallow it — caret
  // never placed, while arrow keys worked). 引用命中回归:载入引用(quoteDepth 路径)必须可点落光标——左条壳
  // IgnorePointer,点击穿透到内容层之下的手势层(裸 BoxDecoration 曾吞点击:点不进、键盘却能进)。
  testWidgets(
    '③ tap places the caret inside a loaded (quoteDepth) blockquote',
    (tester) async {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('normal paragraph')),
          ParagraphNode(
            id: 'q1',
            text: AttributedText('quoted line of prose'),
            metadata: const {quoteDepthKey: 1},
          ),
        ],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();

      await tester.placeCaretInParagraph(
        'q1',
        3,
      ); // a real tap at the character rect — exercises hit-testing
      final selection = SuperEditorInspector.findDocumentSelection();
      expect(
        selection,
        isNotNull,
        reason: 'the tap must reach the gesture layer and place a caret',
      );
      expect(selection!.extent.nodeId, 'q1');
      expect(tester.takeException(), isNull);
    },
  );

  // ⑤a — the An caret is GLYPH-sized (not the full leaded line box) and follows the block tier: the H1
  // caret is taller than the body caret, and each sits BELOW its line-box height (24 body / 28.6 H1 under
  // the 15×1.6 / 22×1.3 rhythm). In the test font the tight glyph box = 1em, so the caret height ≈ the
  // fontSize. ⑤a 光标回归:字形尺寸非整行盒、随块档走——H1 光标高于正文,且都小于各自行盒;测试字体紧盒=1em,
  // 光标高≈字号。
  testWidgets('⑤a the An caret is glyph-sized and follows the block tier', (
    tester,
  ) async {
    // The caret overlay renders on DESKTOP only (mobile draws its own handles) — the test binding defaults
    // to android, so pin macOS for the test body (reset in `finally`: the binding's invariant check runs
    // BEFORE addTearDown). 测试绑定默认 android,caret 层只在桌面渲,钉 macOS(finally 复位——不变量检查先于 tearDown)。
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(id: 'body', text: AttributedText('plain body text')),
          ParagraphNode(
            id: 'h1',
            text: AttributedText('Title'),
            metadata: {'blockType': header1Attribution},
          ),
        ],
      );
      await tester.pumpWidget(_host(doc));
      await tester.pumpAndSettle();

      await tester.placeCaretInParagraph('body', 2);
      await tester.pumpAndSettle();
      final bodyCaret = tester.getSize(find.byKey(DocumentKeys.caret));
      expect(
        bodyCaret.height,
        closeTo(AnText.reading.fontSize!, 1.0),
        reason: 'body caret ≈ glyph box (15), NOT the 24px line box',
      );

      await tester.placeCaretInParagraph('h1', 2);
      await tester.pumpAndSettle();
      final h1Caret = tester.getSize(find.byKey(DocumentKeys.caret));
      expect(
        h1Caret.height,
        closeTo(AnText.readingH1.fontSize!, 1.0),
        reason:
            'H1 caret ≈ its glyph box (22) — visibly taller than the body caret',
      );
      expect(h1Caret.height, greaterThan(bodyCaret.height));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // E7 — the embedded [AnCodeEditor] highlights the code block through the ONE [highlightCode] tokenizer
  // (唯一高亮源), so keyword/number syntax colours appear in the field's live text span. 代码块语法高亮:
  // 嵌入编辑器经唯一 highlightCode 上色,关键字/数字色出现在活字段 span 里。
  testWidgets('E7 code block keywords render in the syntax keyword colour', (
    tester,
  ) async {
    final doc = MutableDocument(
      nodes: [
        CodeBlockNode(id: 'code', code: 'const x = 1;', language: 'dart'),
      ],
    );
    await tester.pumpWidget(_host(doc));
    await tester.pumpAndSettle();

    // The seamless code field colours through its _HighlightController.buildTextSpan (native Flutter way to
    // paint an editable field). Pull the resolved spans and read their colours. 从活字段控制器拿高亮 span。
    final editableFinder = find.descendant(
      of: find.byType(AnCodeEditor),
      matching: find.byType(EditableText),
    );
    final editable = tester.widget<EditableText>(editableFinder);
    final span = editable.controller.buildTextSpan(
      context: tester.element(editableFinder),
      withComposing: false,
    );
    final colors = <Color>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.style?.color != null) colors.add(s.style!.color!);
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
  testWidgets('E8 a markdown table loads and renders as a Table', (
    tester,
  ) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(
            body: AnEditor(
              initialMarkdown: '| A | B |\n| --- | --- |\n| 1 | 2 |',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsWidgets); // the table rendered
    expect(tester.takeException(), isNull);
  });
}

/// A fixture entity source for the mention tests — three candidates, name/id substring filtered. 测试用假源。
class _FakeMentionSource implements MentionSource {
  static const _all = [
    MentionCandidate(
      type: 'workflow',
      id: 'wf_00000000000000a1',
      name: '每日销量对账',
    ),
    MentionCandidate(type: 'function', id: 'fn_00000000000000b2', name: '汇总日报'),
    MentionCandidate(type: 'agent', id: 'ag_00000000000000c3', name: '数据分析助手'),
  ];

  @override
  Future<List<MentionCandidate>> search(String query) async {
    if (query.isEmpty) return _all;
    return _all
        .where((c) => c.name.contains(query) || c.id.contains(query))
        .toList();
  }

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async => const {};
}
