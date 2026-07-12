import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_exec.dart';
import 'package:anselm/features/chat/ui/tool_card_io_section.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F08 exec (B5.1) — run_function / call_handler over their real ExecutionResult / {result} wire shapes.
// F08 执行卡:输入→黑箱→输出 + 结果条(成功耗时 / 失败红 / call_handler 无耗时)。

BlockNode _node(String name, String args, String result, {String? progress, String? entityName}) {
  final call = BlockNode(id: 'tc_x', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {'name': name, 'arguments': args, 'entityName': ?entityName};
  if (progress != null) {
    call.children.add(BlockNode(id: 'pg_x', kind: BlockKind.progress)
      ..status = 'completed'
      ..content = {'text': progress});
  }
  call.children.add(BlockNode(id: 'tr_x', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});
  return call;
}

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('fmtElapsed', () {
    test('sub-second / seconds / minutes', () {
      expect(fmtElapsed(940), '940ms');
      expect(fmtElapsed(1240), '1.2s');
      expect(fmtElapsed(30021), '30s');
      expect(fmtElapsed(123456), '2m 3s');
    });
  });

  group('execReceipt', () {
    test('ok → elapsed, no danger', () {
      final r = execReceipt(t, '{"ok":true,"output":1,"errorMsg":"","elapsedMs":942}')!;
      expect(r.text, '942ms');
      expect(r.tone, isNot(ToolReceiptTone.danger));
    });
    test('ok:false → red 运行失败 · elapsed', () {
      final r = execReceipt(t, '{"ok":false,"output":null,"errorMsg":"boom","elapsedMs":30021}')!;
      expect(r.text, contains(t.chat.tool.execFailed));
      expect(r.text, contains('30s'));
      expect(r.tone, ToolReceiptTone.danger);
    });
    test('unparseable → null (a non-exec string never fakes a receipt)', () {
      expect(execReceipt(t, 'just a string'), isNull);
      expect(execReceipt(t, '{"result":5}'), isNull); // call_handler shape, not exec
    });
  });

  group('execResultFailed', () {
    test('ok:false → true (green but broken); ok:true / non-exec → false', () {
      expect(execResultFailed('{"ok":false,"output":null,"errorMsg":"x","elapsedMs":1}'), isTrue);
      expect(execResultFailed('{"ok":true,"output":1,"errorMsg":"","elapsedMs":1}'), isFalse);
      expect(execResultFailed('{"result":5}'), isFalse);
    });
  });

  testWidgets('run_function ok: input keys + output + exec bar (运行成功 · elapsed)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('run_function',
        '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"url":"https://x.io","retries":3}}',
        '{"ok":true,"output":{"status":200,"bytes":18422},"errorMsg":"","elapsedMs":942}'))));
    await tester.pump();
    // Verb + chip on the collapsed row (functionId truncated to 12 + …). 收起行动词 + chip。
    expect(find.textContaining(t.chat.tool.ranFn), findsOneWidget);
    await tester.tap(find.textContaining(t.chat.tool.ranFn), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolIOSection), findsWidgets); // input + output sections
    expect(find.text('输入'), findsOneWidget);
    expect(find.text('输出'), findsOneWidget);
    expect(find.byType(AnStatBar), findsOneWidget);
    expect(find.text(t.chat.tool.execOk), findsOneWidget);
    expect(find.textContaining('942ms'), findsWidgets); // receipt + bar
  });

  testWidgets('run_function target chip shows the resolved entity NAME, not the id (B3/B4)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('run_function',
        '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{}}',
        '{"ok":true,"output":1,"errorMsg":"","elapsedMs":10}',
        entityName: 'sync_inventory'))));
    await tester.pump();
    // The collapsed header chip is the NAME; the bare functionId is nowhere on that row. 收起头 chip 显名、无裸 id。
    expect(find.textContaining('sync_inventory'), findsOneWidget);
    expect(find.textContaining('fn_1a2b3c4d'), findsNothing);
  });

  testWidgets('run_function falls back to the truncated id when no name is resolved', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('run_function',
        '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{}}',
        '{"ok":true,"output":1,"errorMsg":"","elapsedMs":10}')))); // no entityName
    await tester.pump();
    expect(find.textContaining('fn_1a2b3c4d'), findsOneWidget); // truncated id chip (12 + …)
  });

  testWidgets('run_function ok:false auto-expands, shows red errorMsg + 失败 bar', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('run_function',
        '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"url":"https://down"}}',
        '{"ok":false,"output":null,"errorMsg":"ConnectionError: max retries exceeded","elapsedMs":30021}'))));
    await tester.pump();
    await tester.pumpAndSettle();
    // resultFailed → the card auto-expanded, the errorMsg body is on screen without a tap. 失败自动展开。
    expect(find.textContaining('ConnectionError: max retries exceeded'), findsOneWidget);
    expect(find.text(t.chat.tool.execFailed), findsWidgets); // bar + receipt both say 运行失败
  });

  testWidgets('run_function logs drawer folds print() output', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('run_function',
        '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{}}',
        '{"ok":true,"output":"done","errorMsg":"","elapsedMs":10,"logs":"line1\\nline2\\nline3"}'))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.ranFn), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.execLogs(n: '3')), findsOneWidget); // 日志 · 3 行
  });

  testWidgets('call_handler: method() label, scalar result preview receipt, no fabricated elapsed', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('call_handler',
        '{"handlerId":"hd_5c4b3a2f1e0d9c8b","method":"balance","args":{"account":"acct_88"}}',
        '{"result":18240.5}'))));
    await tester.pump();
    // The chip is `balance()`. chip = 方法名()。
    expect(find.textContaining('balance()'), findsWidgets);
    // The receipt previews the scalar result `→ 18240.5`. 标量结果预览。
    expect(find.textContaining('→ 18240.5'), findsOneWidget);
    await tester.tap(find.textContaining(t.chat.tool.calledMethod), warnIfMissed: false);
    await tester.pumpAndSettle();
    // No exec bar (call_handler carries no ok/elapsed — never fabricated). 无结果条(无耗时字段)。
    expect(find.byType(AnStatBar), findsNothing);
  });

  testWidgets('call_handler streamed progress → logs drawer', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('call_handler',
        '{"handlerId":"hd_5c4b3a2f1e0d9c8b","method":"reconcile","args":{}}',
        '{"result":{"matched":312,"unmatched":4}}',
        progress: 'scanning…\nmatched 312\n4 to review'))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.calledMethod), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.execLogs(n: '3')), findsOneWidget); // progress folded as 日志 · 3 行
  });

  group('invoke_agent', () {
    String res(String status, {String? output, String? errorMsg, int steps = 5}) =>
        '{"executionId":"agexec_1a2b3c4d5e6f7a8b","ok":${status == 'ok'},'
        '"output":${output ?? 'null'},"status":"$status","steps":$steps,'
        '"tokensIn":8420,"tokensOut":1203,${errorMsg != null ? '"errorMsg":"$errorMsg",' : ''}"elapsedMs":8400}';

    test('receipt: ok→steps·elapsed (none); failed/timeout→danger; cancelled→grey', () {
      expect(invokeReceipt(t, res('ok', output: '"done"', steps: 9))!.text, contains(t.chat.tool.agentSteps(n: '9')));
      expect(invokeReceipt(t, res('ok', output: '"done"'))!.tone, isNot(ToolReceiptTone.danger));
      expect(invokeReceipt(t, res('failed'))!.tone, ToolReceiptTone.danger);
      expect(invokeReceipt(t, res('timeout'))!.tone, ToolReceiptTone.danger);
      expect(invokeReceipt(t, res('cancelled'))!.tone, isNot(ToolReceiptTone.danger)); // user stop, not red
      expect(invokeReceipt(t, 'boom'), isNull);
    });

    test('resultFailed: failed/timeout true; ok/cancelled false (cancelled never auto-expands)', () {
      expect(invokeResultFailed(res('failed')), isTrue);
      expect(invokeResultFailed(res('timeout')), isTrue);
      expect(invokeResultFailed(res('ok', output: '"x"')), isFalse);
      expect(invokeResultFailed(res('cancelled')), isFalse);
    });

    testWidgets('ok string output → prose; stat bar shows steps/tokens + agent pill + executionId', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _node('invoke_agent',
          '{"agentId":"ag_9f8e7d6c5b4a3f2e","input":{"quarter":"2026Q2"}}',
          res('ok', output: '"季度已归类,无异常。"', steps: 9)))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.invokedAgent), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('季度已归类'), findsOneWidget); // the prose answer
      expect(find.textContaining(t.chat.tool.agentSteps(n: '9')), findsWidgets); // steps in bar
      expect(find.textContaining('↑8420 ↓1203'), findsOneWidget); // tokens
      expect(find.textContaining('ag_9f8e7d6c5b4a3f2e'), findsWidgets); // navigable agent pill
      expect(find.textContaining('agexec_1a2b3c4d5e6f7a8b'), findsWidgets); // executionId copy
    });

    testWidgets('failed auto-expands and shows the red errorMsg', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _node('invoke_agent',
          '{"agentId":"ag_9f8e7d6c5b4a3f2e","input":{}}',
          res('failed', errorMsg: 'AGENT_OUTPUT_NOT_STRUCTURED: prose but schema needs int')))));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining('AGENT_OUTPUT_NOT_STRUCTURED'), findsOneWidget); // auto-expanded
    });
  });

  group('fire_trigger', () {
    test('fireReceipt → activationId truncated, never danger', () {
      final r = fireReceipt(t, '{"fired":true,"triggerId":"trg_1","activationId":"act_1f2e3d4c5b6a7980"}')!;
      expect(r.text, 'act_1f2e3d4c…'); // 12 + …
      expect(r.tone, isNot(ToolReceiptTone.danger)); // firing is success — never red
      expect(fireReceipt(t, 'not json'), isNull);
    });

    testWidgets('body: navigable trigger pill + activation copy chip + payload note', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _node('fire_trigger',
          '{"triggerId":"trg_7a8b9c0d1e2f3a4b"}',
          '{"fired":true,"triggerId":"trg_7a8b9c0d1e2f3a4b","activationId":"act_1f2e3d4c5b6a7980"}'))));
      await tester.pump();
      expect(find.textContaining(t.chat.tool.firedTrigger), findsOneWidget);
      await tester.tap(find.textContaining(t.chat.tool.firedTrigger), warnIfMissed: false);
      await tester.pumpAndSettle();
      // The trigger pill (full id label) is present + navigable; the activation copy chip shows the id;
      // the fixed grey note never fabricates a fan-out count. 触发器药丸 + 活化 copy + payload 灰注。
      expect(find.byType(AnRefPill), findsWidgets);
      expect(find.byType(AnCopyChip), findsOneWidget);
      expect(find.textContaining('act_1f2e3d4c5b6a7980'), findsWidgets); // full id in the copy chip
      expect(find.text(t.chat.tool.firePayloadNote), findsOneWidget);
    });
  });

  testWidgets('invoke TIMEOUT keeps the danger tone (fromRaw has no timeout alias — 批3 突变闸)',
      (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('invoke_agent',
        '{"agentId":"ag_1","input":{}}',
        '{"executionId":"exec_9","ok":false,"status":"timeout","steps":2,"elapsedMs":60000}'))));
    // timeout = failure → the card auto-expands ONCE (no tap needed; a tap would re-collapse).
    // 超时=失败→自动展开一次(点了反而收起)。
    await tester.pumpAndSettle();
    final bar = tester.widget<AnStatBar>(find.byType(AnStatBar));
    // The mutation `AnStatus.fromRaw(status)` folds timeout to idle (grey) — this pins err (red).
    // fromRaw 突变会把 timeout 折成 idle 灰;此断言钉死 err 红。
    expect(bar.status, AnStatus.err);
    expect(bar.statusLabel, t.chat.tool.agentTimeout);
  });
}
