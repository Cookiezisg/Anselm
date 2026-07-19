import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_callout.dart';
import 'package:anselm/core/ui/an_ref_pill.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_catalog.dart';
import 'package:anselm/features/chat/ui/tool_card_entity_get.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F06 get bodies (B3.5) — verb (viewing/viewed) + chip settle (id→name) + four-part exhibit; the
// read tools' string-template parsers (not-found soft-fail → note). F06 get 投影 + read 模板解析。

BlockNode _node(String name, String result, {String args = '{"id":"x"}'}) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result});

ToolCardState _state(String name, String result, {String args = '{"functionId":"fn_1"}'}) => ToolCardState(
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
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 680, child: child))),
      ),
    );

const _fnJson =
    '{"id":"fn_1a2b","name":"fetch_with_retry","description":"retry","updatedAt":"2026-07-01T09:00:00Z",'
    '"activeVersion":{"version":3,"envStatus":"ready","code":"def f(): pass","inputs":[{"name":"url","type":"string"}]}}';

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('_entityGet verb + chip settle', () {
    test('verb: viewing → viewed with the kind noun', () {
      final spec = toolCardSpecFor('get_function');
      expect(spec.verb(t, live: true), t.chat.tool.viewingKind(kind: t.chat.tool.kind.function));
      expect(spec.verb(t, live: false), t.chat.tool.viewedKind(kind: t.chat.tool.kind.function));
    });

    test('chip settles from the args id to the output name', () {
      final spec = toolCardSpecFor('get_function');
      // live (no result yet): the args id. live:args id。
      expect(spec.target!(_state('get_function', '', args: '{"functionId":"fn_1a2b"}')), 'fn_1a2b');
      // settled: the output name. 落定:输出 name。
      expect(spec.target!(_state('get_function', _fnJson)), 'fetch_with_retry');
    });

    test('receipt: the version, never danger (a bad env is body info, not a row hijack)', () {
      final spec = toolCardSpecFor('get_function');
      final r = spec.receipt!(t, _state('get_function', _fnJson));
      expect(r!.text, 'v3');
      expect(r.tone.name, 'none');
    });
  });

  testWidgets('get_function → the four-part exhibit', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('get_function', _fnJson))));
    await tester.pump();
    await tester.tap(find.textContaining('已查看函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(EntityGetBody), findsOneWidget);
    expect(find.byType(RawResultDisclosure), findsOneWidget);
    expect(find.text('fetch_with_retry'), findsWidgets); // identity pill
  });

  testWidgets('get_agent → deep-linkable capability pills', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('get_agent',
        '{"id":"ag_1","name":"triager","updatedAt":"2026-07-01T09:00:00Z","activeVersion":{"version":2,'
        '"prompt":"do things","tools":[{"kind":"function","name":"f1","id":"fn_1"}],"knowledge":["doc_9"]}}'))));
    await tester.pump();
    await tester.tap(find.textContaining('已查看智能体'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AnRefPill, 'f1'), findsOneWidget); // tool pill
    expect(find.widgetWithText(AnRefPill, 'doc_9'), findsOneWidget); // knowledge pill
  });

  testWidgets('get_skill → allowedTools WARN chips + pre-auth note', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('get_skill',
        '{"name":"triage","description":"d","context":"inline","source":"ai","body":"# body",'
        '"updatedAt":"2026-07-01T09:00:00Z","frontmatter":{"allowedTools":["Read","edit_document"]}}'))));
    await tester.pump();
    await tester.tap(find.textContaining('已查看技能'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AnChip, 'Read'), findsOneWidget);
    expect(find.textContaining('预授权'), findsOneWidget);
  });

  group('read_document / read_attachment templates', () {
    testWidgets('read_document: parses the template → header + path + rendered prose', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _node('read_document',
          '# 口径\n\nPath: /specs/口径\nID: doc_1\nTags: a, b\n\n---\n\n# 口径\n\n- 规则一', args: '{"id":"doc_1"}'))));
      await tester.pump();
      await tester.tap(find.textContaining('已阅读文档'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('/specs/口径'), findsOneWidget); // path
      expect(find.textContaining('规则一'), findsOneWidget); // rendered content
    });

    testWidgets('read_document: not-found soft-fail → an amber note (no exhibit)', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _node('read_document',
          'Document "x" not found. Call list_documents.', args: '{"id":"x"}'))));
      await tester.pump();
      await tester.tap(find.textContaining('已阅读文档'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AnCallout), findsOneWidget);
      expect(find.byType(EntityGetBody), findsNothing);
    });

    testWidgets('read_attachment: media descriptor → info note; not-found → warn', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _node('read_attachment',
          'Attachment "q3.png" (id att_1, image/png, 4096 bytes, kind image): this tool cannot turn its content into text.',
          args: '{"id":"att_1"}'))));
      await tester.pump();
      await tester.tap(find.textContaining('已读取附件'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AnCallout), findsOneWidget);
    });
  });
}
