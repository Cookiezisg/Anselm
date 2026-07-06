import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_exec.dart';
import 'package:anselm/features/chat/ui/tool_card_io_section.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F08 exec (B5.1) — run_function / call_handler over their real ExecutionResult / {result} wire shapes.
// F08 执行卡:输入→黑箱→输出 + 结果条(成功耗时 / 失败红 / call_handler 无耗时)。

BlockNode _node(String name, String args, String result, {String? progress}) {
  final call = BlockNode(id: 'tc_x', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {'name': name, 'arguments': args};
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
    expect(find.byType(ExecResultBar), findsOneWidget);
    expect(find.text(t.chat.tool.execOk), findsOneWidget);
    expect(find.textContaining('942ms'), findsWidgets); // receipt + bar
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
    expect(find.byType(ExecResultBar), findsNothing);
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
}
