import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/core/run/flowrun_node_list.dart';
import 'package:anselm/features/chat/ui/tool_card_flowrun.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F08 replay_flowrun (B5.3) — the {flowrun, nodes, nodeSummary?} composite → FlowrunNodeList + run
// footer. Receipt four-state (completed / still-failed / awaiting-approval / cancelled); counts always
// from nodeSummary (never nodes.length). F08 replay 节点台账。

BlockNode _replay(String result) => BlockNode(id: 'tc_r', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'replay_flowrun', 'arguments': '{"flowrunId":"fr_9a8b7c6d5e4f3a2b"}'}
  ..children.add(BlockNode(id: 'tr_r', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

String _node(String nodeId, String kind, String status, {int iteration = 0, String? error}) =>
    '{"id":"frn_${nodeId}_$iteration","flowrunId":"fr_1","nodeId":"$nodeId","iteration":$iteration,'
    '"kind":"$kind","ref":"$kind:x","status":"$status",${error != null ? '"error":"$error",' : ''}'
    '"result":{},"createdAt":"2026-07-05T14:00:00Z","updatedAt":"2026-07-05T14:00:00Z"}';

String _run(String status, List<String> nodes, {int replayCount = 1, String? runError, String? nodeSummary}) =>
    '{"flowrun":{"id":"fr_9a8b7c6d5e4f3a2b","workflowId":"wf_1a2b3c4d5e6f7a8b","versionId":"wfv_1","status":"$status",'
    '"replayCount":$replayCount,${runError != null ? '"error":"$runError",' : ''}"pinnedRefs":{},'
    '"updatedAt":"2026-07-05T14:05:00Z"},"nodes":[${nodes.join(',')}]${nodeSummary != null ? ',"nodeSummary":$nodeSummary' : ''}}';

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('replayReceipt', () {
    test('completed → 完成 · N 节点 (N from nodeSummary, never nodes.length)', () {
      final r = replayReceipt(t, _run('completed', [_node('a', 'action', 'completed')],
          nodeSummary: '{"totalNodes":213,"shownNodes":80,"byStatus":{"completed":213},"note":"x"}'))!;
      expect(r.text, contains('213')); // the REAL total, not 1 (nodes.length)
      expect(r.text, contains(t.run.runCompleted));
      expect(r.tone, isNot(ToolReceiptTone.danger));
    });
    test('failed → red 仍失败 + auto-expand signal', () {
      final r = replayReceipt(t, _run('failed', [_node('a', 'action', 'failed', error: 'boom')]))!;
      expect(r.text, t.run.runStillFailed);
      expect(r.tone, ToolReceiptTone.danger);
      expect(replayResultFailed(_run('failed', [_node('a', 'action', 'failed')])), isTrue);
    });
    test('running with a parked node → 等待审批 (grey, not danger — park is a node state)', () {
      final r = replayReceipt(t, _run('running', [_node('a', 'approval', 'parked')]))!;
      expect(r.text, t.run.runAwaitApproval);
      expect(r.tone, isNot(ToolReceiptTone.danger));
    });
    test('running with no parked node → no receipt; unparseable → null', () {
      expect(replayReceipt(t, _run('running', [_node('a', 'action', 'completed')])), isNull);
      expect(replayReceipt(t, 'not json'), isNull);
    });
    test('cancelled → 已取消, not failed', () {
      final r = replayReceipt(t, _run('cancelled', [_node('a', 'action', 'completed')]))!;
      expect(r.text, t.run.runCancelled);
      expect(replayResultFailed(_run('cancelled', [])), isFalse);
    });
  });

  testWidgets('completed run: node ledger rows + workflow pill + flowrunId copy', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _replay(_run('completed', [
      _node('trigger', 'trigger', 'completed'),
      _node('fetch', 'action', 'completed'),
      _node('classify', 'agent', 'completed'),
    ])))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.replayedRun), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(FlowrunNodeList), findsOneWidget);
    expect(find.text('trigger'), findsOneWidget);
    expect(find.text('fetch'), findsOneWidget);
    expect(find.textContaining(t.run.replayPinNote), findsOneWidget); // honesty note
    expect(find.textContaining('wf_1a2b3c4d5e6f7a8b'), findsWidgets); // navigable workflow pill
    expect(find.textContaining('fr_9a8b7c6d5e4f3a2b'), findsWidgets); // flowrunId copy chip
  });

  testWidgets('failed run auto-expands and shows the failed node error inline', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _replay(_run('failed', [
      _node('trigger', 'trigger', 'completed'),
      _node('charge', 'action', 'failed', error: 'HANDLER_RPC_TIMEOUT: charge() exceeded 30s'),
    ], runError: 'run halted at node charge')))));
    await tester.pump();
    await tester.pumpAndSettle();
    // resultFailed → auto-expanded without a tap; the failed node's error is on screen. 失败自动展开。
    expect(find.textContaining('HANDLER_RPC_TIMEOUT'), findsOneWidget);
    expect(find.textContaining('run halted at node charge'), findsOneWidget); // run-level error window
  });

  testWidgets('80-node cap: the honest summary bar reads the REAL counts, not nodes.length', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _replay(_run('completed', [
      _node('loop', 'action', 'completed', iteration: 42),
      _node('finalize', 'control', 'completed'),
    ], nodeSummary: '{"totalNodes":213,"shownNodes":80,"byStatus":{"completed":209,"failed":3,"parked":1},"note":"x"}')))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.replayedRun), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('80/213'), findsOneWidget); // shown/total honest bar
    expect(find.textContaining('#42'), findsOneWidget); // loop turn index disambiguator
  });

  group('trigger_workflow', () {
    BlockNode trig(String args, String result) => BlockNode(id: 'tc_t', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': 'trigger_workflow', 'arguments': args}
      ..children.add(BlockNode(id: 'tr_t', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result});

    test('receipt → flowrunId truncated, never danger; unparseable → null', () {
      final r = triggerWorkflowReceipt(t, '{"flowrunId":"fr_9a8b7c6d5e4f3a2b","workflowId":"wf_1"}')!;
      expect(r.text, 'fr_9a8b7c6d5…');
      expect(r.tone, isNot(ToolReceiptTone.danger));
      expect(triggerWorkflowReceipt(t, 'boom'), isNull);
    });

    testWidgets('body: payload input + navigable workflow pill + flowrunId copy + get_flowrun note', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: trig(
          '{"workflowId":"wf_1a2b3c4d5e6f7a8b","payload":{"body":{"amount":18240}}}',
          '{"flowrunId":"fr_9a8b7c6d5e4f3a2b","workflowId":"wf_1a2b3c4d5e6f7a8b"}'))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.triggeredWf), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('wf_1a2b3c4d5e6f7a8b'), findsWidgets); // navigable workflow pill
      expect(find.textContaining('fr_9a8b7c6d5e4f3a2b'), findsWidgets); // flowrunId copy chip
      expect(find.text(t.run.triggerStartedNote), findsOneWidget);
    });

    testWidgets('empty payload is stated, never dressed as an empty tree', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: trig('{"workflowId":"wf_1"}',
          '{"flowrunId":"fr_1","workflowId":"wf_1"}'))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.triggeredWf), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(t.run.emptyPayload), findsOneWidget);
    });
  });

  group('get_flowrun', () {
    BlockNode gfr(String result) => BlockNode(id: 'tc_g', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': 'get_flowrun', 'arguments': '{"flowrunId":"fr_9a8b7c6d5e4f3a2b"}'}
      ..children.add(BlockNode(id: 'tr_g', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result});

    test('receipt: status·nodes; failed→danger; capped→shown/total', () {
      expect(getFlowrunReceipt(t, _run('completed', [_node('a', 'action', 'completed')]))!.tone, isNot(ToolReceiptTone.danger));
      expect(getFlowrunReceipt(t, _run('failed', [_node('a', 'action', 'failed')]))!.tone, ToolReceiptTone.danger);
      final capped = getFlowrunReceipt(t, _run('completed', [_node('a', 'action', 'completed')],
          nodeSummary: '{"totalNodes":213,"shownNodes":80,"byStatus":{"completed":213},"note":"x"}'))!;
      expect(capped.text, contains('80/213')); // capped → shown/total, from summary
      expect(getFlowrunFailed(_run('failed', [])), isTrue);
    });

    testWidgets('completed: run header + node ledger + trigger provenance', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: gfr(
          '{"flowrun":{"id":"fr_9a8b7c6d5e4f3a2b","workflowId":"wf_1a2b3c4d5e6f7a8b","versionId":"v1","status":"completed","replayCount":0,"triggerId":"trg_abc123def456","pinnedRefs":{},"updatedAt":"2026-07-05T14:05:00Z"},"nodes":[${_node('trigger', 'trigger', 'completed')},${_node('fetch', 'action', 'completed')}]}'))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.gotFlowrun), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(FlowrunNodeList), findsOneWidget);
      expect(find.textContaining('wf_1a2b3c4d5e6f7a8b'), findsWidgets); // workflow pill in the header
      expect(find.textContaining(t.run.provTrigger), findsOneWidget); // navigable trigger provenance
    });

    testWidgets('failed run auto-expands with the run-level error window', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: gfr(_run('failed', [
        _node('charge', 'action', 'failed', error: 'boom'),
      ], runError: 'run halted at node charge')))));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining('run halted at node charge'), findsOneWidget); // auto-expanded run error
    });
  });
}
