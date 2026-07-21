import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_live_tail.dart';
import 'package:anselm/core/ui/an_window.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_document_skill.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F04 document (soft-fail, sentence result) + skill (hard-fail, JSON result) build cards — the ProseWindow
// typeset content + soft-fail reframing + allowedTools warn chips. document 稿子流 + skill 警示药丸。

BlockNode _node(String name, String args, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
      );

ToolCardState _state(String name, String args, String result) => ToolCardState(
  phase: ToolCardPhase.succeeded,
  toolName: name,
  summary: '',
  danger: '',
  argsText: args,
  resultText: result,
  errorText: '',
  progressText: '',
  progressLive: false,
);

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 640, child: child)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test(
    'docSentenceReceipt: success → path tail; soft-fail sentence → warn 未生效',
    () {
      final ok = docSentenceReceipt(
        t,
        _state(
          'create_document',
          '{}',
          'Created document "口径" (id=doc_1, path=/specs/口径).',
        ),
      );
      expect(ok!.text, '口径');
      expect(ok.tone, ToolReceiptTone.none);
      final bad = docSentenceReceipt(
        t,
        _state(
          'create_document',
          '{}',
          'Parent folder not found. Call list_documents.',
        ),
      );
      expect(bad!.tone, ToolReceiptTone.warn);
    },
  );

  test('skillReceipt: created / updated slug', () {
    expect(
      skillReceipt(
        t,
        _state('create_skill', '{}', '{"created":"invoice-triage"}'),
      )!.text,
      'invoice-triage',
    );
    expect(
      skillReceipt(
        t,
        _state('edit_skill', '{}', '{"updated":"invoice-triage"}'),
      )!.text,
      'invoice-triage',
    );
  });

  testWidgets(
    'document LIVE face: the prose tail (family head, own window) — no hand-rolled shell (批1)',
    (tester) async {
      final live = ToolCardState(
        phase: ToolCardPhase.argsStreaming,
        toolName: 'create_document',
        summary: '',
        danger: '',
        argsText: '{"title":"口径","content":"# 口径\\n第一句正在流入',
        resultText: '',
        errorText: '',
        progressText: '',
        progressLive: false,
      );
      await tester.pumpWidget(
        _host(Builder(builder: (ctx) => documentBody(ctx, live))),
      );
      await tester.pump();
      expect(find.byType(AnLiveTail), findsOneWidget); // the family head 族六当家件
      expect(
        find.byType(AnWindow),
        findsOneWidget,
      ); // exactly ONE window (the tail's own) 只有尾自带的一扇窗
      expect(
        find.textContaining('第一句正在流入'),
        findsOneWidget,
      ); // newest words visible 最新字可见
    },
  );

  testWidgets('skill LIVE face: whitespace-only draft renders NOTHING (批1)', (
    tester,
  ) async {
    final live = ToolCardState(
      phase: ToolCardPhase.argsStreaming,
      toolName: 'create_skill',
      summary: '',
      danger: '',
      argsText: '{"name":"x","body":"\\n',
      resultText: '',
      errorText: '',
      progressText: '',
      progressLive: false,
    );
    await tester.pumpWidget(
      _host(Builder(builder: (ctx) => skillBody(ctx, live))),
    );
    await tester.pump();
    expect(
      find.byType(AnWindow),
      findsNothing,
    ); // built-in empty-shell guard 空壳守卫内建
  });

  testWidgets('document body: typeset prose window + auto-rename note', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'create_document',
            r'{"name":"口径","content":"# 季度汇总口径\n\n- 退款计入当季"}',
            'Created document "口径 2" (id=doc_1, path=/口径 2). Note: requested name "口径" was taken; auto-renamed.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已创建文档'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ProseWindow), findsOneWidget);
    expect(
      find.textContaining('季度汇总口径'),
      findsOneWidget,
    ); // the rendered heading
    expect(find.textContaining('自动改名'), findsOneWidget); // the auto-rename note
  });

  testWidgets(
    'document soft failure reframes the English sentence as an amber note (no prose window)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'edit_document',
              r'{"id":"doc_1","content":"# x"}',
              'A sibling document already has that name.',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已更新文档'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A sibling document already has'),
        findsOneWidget,
      );
      expect(find.byType(ProseWindow), findsNothing);
    },
  );

  testWidgets('skill body: prose + allowedTools WARN chips + pre-auth note', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'create_skill',
            r'{"name":"invoice-triage","description":"triage invoices","body":"# 说明\n分类发票","context":"inline","allowedTools":["Read","edit_document"]}',
            '{"created":"invoice-triage"}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已创建技能'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ProseWindow), findsOneWidget);
    expect(
      find.widgetWithText(AnChip, 'Read'),
      findsOneWidget,
    ); // allowedTools chip (warn)
    expect(find.widgetWithText(AnChip, 'edit_document'), findsOneWidget);
    expect(find.textContaining('免危险确认'), findsOneWidget); // pre-auth note
    expect(
      find.widgetWithText(AnChip, '内联'),
      findsOneWidget,
    ); // context = inline
  });

  testWidgets('edit_skill shows the no-revert small print', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'edit_skill',
            r'{"name":"invoice-triage","description":"d","body":"# 新说明"}',
            '{"updated":"invoice-triage"}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已更新技能'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('无版本可回退'), findsOneWidget);
  });

  group('ProseWindow 壳 (WRK-066 批4 族一)', () {
    Widget host(Widget c) => TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: SizedBox(width: 480, child: c)),
        ),
      ),
    );

    testWidgets('short prose: ONE window, whole, no expand affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const ProseWindow(markdown: 'a short answer')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnWindow), findsOneWidget);
      expect(find.textContaining('展开'), findsNothing);
    });

    testWidgets(
      'long prose WITH a fenced code block: collapses, and the fence never nests a window (leaf law)',
      (tester) async {
        final md =
            "${'p\n\n' * 20}```dart\nvoid main() {}\n```\n${'q\n\n' * 20}";
        await tester.pumpWidget(host(ProseWindow(markdown: md)));
        await tester.pumpAndSettle();
        // AnMarkdown fences render AnCodeSurface (physically borderless-window-safe) — AnWindow's
        // debug assert would throw on a nested window. 围栏码=AnCodeSurface,套窗则叶子律 assert 已炸。
        expect(find.byType(AnWindow), findsOneWidget);
        expect(find.textContaining('展开'), findsOneWidget);
      },
    );

    // Consumer-face pin: ProseWindow (the ONE embedded prose surface — tool cards, sidestage, previews) renders
    // AnMarkdown at the EMBEDDED scale, so a heading is the 15-w400 rung, NEVER the reading 22 (which would
    // shout inside a window). ProseWindow=嵌入档:标题 15 而非阅读档 22。
    testWidgets(
      'ProseWindow renders EMBEDDED scale: a heading is 15-w400, not the reading 22',
      (tester) async {
        await tester.pumpWidget(
          host(const ProseWindow(markdown: '# 值班手册\n\n正文一句')),
        );
        await tester.pumpAndSettle();
        TextStyle? styleOf(String needle) {
          for (final rich in tester.widgetList<RichText>(
            find.byType(RichText),
          )) {
            TextStyle? hit;
            rich.text.visitChildren((span) {
              if (span is TextSpan && (span.text?.contains(needle) ?? false)) {
                hit = span.style;
              }
              return hit == null;
            });
            if (hit != null) return hit;
          }
          return null;
        }

        expect(
          styleOf('值班手册')?.fontSize,
          15,
        ); // embedded h1 = readingH3 rung, NOT 22
        expect(styleOf('值班手册')?.fontWeight, FontWeight.w400);
      },
    );
  });
}
