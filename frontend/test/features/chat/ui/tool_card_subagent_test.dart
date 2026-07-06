import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_subagent.dart';
import 'package:anselm/features/chat/ui/transcript_peek.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F15 nested conversation (B6) — Subagent (live NestedRunPane from the E3 subtree, settled answer) +
// get_subagent_trace (list / hydrated detail). F15 嵌套对话。

BlockNode _blk(String type, String content, {String? tool}) {
  final n = BlockNode(id: '${type}_${content.hashCode}', kind: blockKindFromWire(type))..status = 'completed';
  n.content = type == 'tool_call' ? {'name': tool, 'arguments': content} : {'content': content};
  return n;
}

BlockNode _subagent(String args, {String? result, List<BlockNode> nested = const [], bool open = false}) {
  final node = BlockNode(id: 'tc_sub', kind: BlockKind.toolCall)
    ..status = open ? 'open' : 'completed'
    ..content = {'name': 'Subagent', 'arguments': args};
  for (final n in nested) {
    node.children.add(n);
  }
  if (result != null) {
    node.children.add(BlockNode(id: 'tr_sub', kind: BlockKind.toolResult)..status = 'completed'..content = {'content': result});
  }
  return node;
}

BlockNode _trace(String args, Map<String, dynamic> result) => BlockNode(id: 'tc_t', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'get_subagent_trace', 'arguments': args}
  ..children.add(BlockNode(id: 'tr_t', kind: BlockKind.toolResult)..status = 'completed'..content = {'content': jsonEncode(result)});

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 660, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('Subagent settled: task + nested trajectory (NestedRunPane) + answer prose', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _subagent(
        '{"subagent_type":"Explore","prompt":"FIND_THE_REGISTRY"}',
        nested: [_blk('reasoning', 'LOCATING_FILE'), _blk('tool_call', '{}', tool: 'Grep'), _blk('text', 'FOUND_IT')],
        result: 'The registry is in catalog.dart.'))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.spawnedSubagent), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(NestedRunPane), findsOneWidget);
    expect(find.textContaining('FIND_THE_REGISTRY'), findsOneWidget); // the task prompt
    expect(find.textContaining('LOCATING_FILE', findRichText: true), findsOneWidget); // nested reasoning
    expect(find.textContaining('Grep'), findsWidgets); // nested tool_call row
    expect(find.textContaining('The registry is in catalog.dart'), findsWidgets); // answer prose
  });

  testWidgets('Subagent with no nested subtree (reload): falls back to the get_subagent_trace note', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _subagent('{"subagent_type":"Plan","prompt":"x"}', result: 'answer'))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.spawnedSubagent), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(NestedRunPane), findsNothing);
    expect(find.text(t.chat.tool.subagentTraceNote), findsOneWidget);
  });

  group('get_subagent_trace', () {
    test('receipt: list → N runs; detail → N blocks', () {
      expect(subTraceReceipt(t, jsonEncode({'count': 2, 'subagentRuns': [1, 2]}))!.text, contains('2'));
      expect(subTraceReceipt(t, jsonEncode({'subagentRunId': 's1', 'blocks': [1, 2, 3]}))!.text, contains('3'));
      expect(subTraceReceipt(t, 'boom'), isNull);
    });

    testWidgets('list form: a run ledger with status dots + finalText subtext + block count', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _trace('{}', {
        'count': 2,
        'subagentRuns': [
          {'subagentRunId': 'subagt_01', 'status': 'ok', 'finalText': 'FOUND_THE_REGISTRY', 'blockCount': 3},
          {'subagentRunId': 'subagt_02', 'status': 'failed', 'finalText': 'NO_MATCH', 'blockCount': 2},
        ],
      }))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.gotSubTrace), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('subagt_01'), findsOneWidget);
      expect(find.textContaining('FOUND_THE_REGISTRY'), findsOneWidget); // finalText subtext
    });

    testWidgets('detail form: blocks hydrate into a TranscriptPeek', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _trace('{"subagentRunId":"subagt_01"}', {
        'subagentRunId': 'subagt_01', 'spawningToolCallId': 'tc_a',
        'blocks': [
          {'type': 'reasoning', 'content': 'HYDRATED_THOUGHT', 'status': 'completed'},
          {'type': 'text', 'content': 'HYDRATED_REPLY', 'status': 'completed'},
        ],
      }))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.gotSubTrace), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TranscriptPeek), findsOneWidget);
      expect(find.textContaining('HYDRATED_THOUGHT', findRichText: true), findsOneWidget);
      expect(find.textContaining('HYDRATED_REPLY', findRichText: true), findsOneWidget);
    });
  });
}
