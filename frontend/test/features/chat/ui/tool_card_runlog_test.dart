import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/run_ledger.dart';
import 'package:anselm/features/chat/ui/tool_card_runlog.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F09 run-log search (B5.6) — aggregate families: ok✓/failed✗ rollup receipt, slim RunLedger, empty→no
// body, and the SLIM PROJECTION invariant (input/output/logs/transcript never render). F09 检索族。

BlockNode _search(String name, String args, String result) => BlockNode(id: 'tc_s', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': name, 'arguments': args}
  ..children.add(BlockNode(id: 'tr_s', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

String _exec(String id, String status, {int elapsed = 800, String? extra}) =>
    '{"id":"$id","status":"$status","triggeredBy":"chat","elapsedMs":$elapsed,"startedAt":"2026-07-05T14:03:00Z"${extra ?? ''}}';

String _page(String listKey, List<String> rows, {int ok = 0, int failed = 0, bool hasMore = false}) => jsonEncode({
      listKey: rows.map(jsonDecode).toList(),
      'hasMore': hasMore,
      'aggregates': {'okCount': ok, 'failedCount': failed},
    });

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 660, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('aggregatesReceipt', () {
    test('rollup ok✓·failed✗, always grey; empty → 无记录; unparseable → null', () {
      final r = aggregatesReceipt(t, _page('executions', [], ok: 41, failed: 4))!;
      expect(r.text, contains('41'));
      expect(r.text, contains('4'));
      expect(r.tone, ToolReceiptTone.none); // NEVER danger — archive failures aren't this call failing
      expect(aggregatesReceipt(t, _page('executions', [], ok: 0, failed: 0))!.text, t.chat.tool.logNoRecords);
      expect(aggregatesReceipt(t, 'boom'), isNull);
    });
    test('hasBody: records → true, none → false (receipt IS the card)', () {
      expect(aggregatesHasBody(_page('executions', [_exec('e1', 'ok')], ok: 1, failed: 0)), isTrue);
      expect(aggregatesHasBody(_page('executions', [], ok: 0, failed: 0)), isFalse);
    });
  });

  testWidgets('fn executions: bead strip + slim ledger; NO input/output/logs render', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _search('search_function_executions', '{"functionId":"fn_1"}',
        _page('executions', [
          _exec('fnexec_01', 'ok', extra: ',"output":{"secret":"SHOULD_NOT_RENDER"},"logs":"LOGLINE_SHOULD_NOT_RENDER"'),
          _exec('fnexec_02', 'failed', elapsed: 30021),
        ], ok: 41, failed: 4, hasMore: true)))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.searchedFnExec), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(RunBeadStrip), findsOneWidget);
    expect(find.byType(RunLedger), findsOneWidget);
    expect(find.text('fnexec_01'), findsOneWidget);
    // The slim projection invariant: fat fields present in the wire NEVER reach the widget tree.
    expect(find.textContaining('SHOULD_NOT_RENDER'), findsNothing);
    expect(find.textContaining('LOGLINE_SHOULD_NOT_RENDER'), findsNothing);
    expect(find.textContaining(t.chat.tool.aggNote), findsOneWidget); // ✗ incl. cancelled/timeout note
  });

  testWidgets('handler calls: method() chip renders', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _search('search_handler_calls', '{"handlerId":"hd_1"}',
        _page('calls', [_exec('hdcall_01', 'ok', extra: ',"method":"charge","instanceId":"inst_1"')], ok: 12, failed: 1)))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.searchedHdCalls), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('charge()'), findsOneWidget);
  });

  testWidgets('agent executions: the fat transcript on every row is NEVER rendered', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _search('search_agent_executions', '{"agentId":"ag_1"}',
        _page('executions', [
          _exec('agexec_01', 'timeout', extra: ',"transcript":"TRANSCRIPT_30KB_SHOULD_NOT_RENDER"'),
        ], ok: 7, failed: 2)))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.searchedAgentExec), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('agexec_01'), findsOneWidget);
    expect(find.textContaining('TRANSCRIPT_30KB_SHOULD_NOT_RENDER'), findsNothing);
  });

  testWidgets('empty (no records): the receipt IS the card — no chevron, no body', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _search('search_function_executions', '{"functionId":"fn_never"}',
        _page('executions', [], ok: 0, failed: 0)))));
    await tester.pump();
    expect(find.textContaining(t.chat.tool.logNoRecords), findsOneWidget);
    expect(find.byType(RunLedger), findsNothing); // no body
  });
}
