import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/log_drawer.dart';
import 'package:anselm/features/chat/ui/run_dossier.dart';
import 'package:anselm/features/chat/ui/transcript_peek.dart';
import 'package:anselm/features/chat/ui/tool_card_runlog.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F09 get-record (B5.8) — RunDossier (status·elapsed receipt, failed auto-expand, double-ended log cap,
// MCP stderr split), ProvenanceLine, and the activation fire record. F09 卷宗卡。

BlockNode _get(String name, String args, Map<String, dynamic> record) => BlockNode(id: 'tc_g', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': name, 'arguments': args}
  ..children.add(BlockNode(id: 'tr_g', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': jsonEncode(record)});

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 660, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('capLog (double-ended)', () {
    test('short → whole; long → head+tail with a middle elision (tail preserved)', () {
      final short = capLog('hello');
      expect(short.omitted, 0);
      expect(short.head, 'hello');
      final long = capLog('H' * 2000 + 'M' * 5000 + 'T' * 4000); // 11000 > 6000
      expect(long.omitted, 11000 - 2000 - 4000);
      expect(long.head.length, 2000);
      expect(long.tail.length, 4000);
      expect(long.tail.endsWith('T'), isTrue); // the diagnostic tail is NEVER truncated away
    });
  });

  group('receipts', () {
    test('statusElapsedReceipt: ok→grey, failed/timeout→danger', () {
      expect(statusElapsedReceipt(t, 'ok', 942)!.tone, isNot(ToolReceiptTone.danger));
      expect(statusElapsedReceipt(t, 'failed', 30021)!.tone, ToolReceiptTone.danger);
      expect(statusElapsedReceipt(t, 'timeout', 60000)!.tone, ToolReceiptTone.danger);
      expect(statusElapsedReceipt(t, '', null), isNull);
    });
    test('activationFireReceipt: fired→已fire·扇出N; not fired→grey; error→danger', () {
      final f = activationFireReceipt(t, jsonEncode({'fired': true, 'firingCount': 2}))!;
      expect(f.text, contains(t.chat.tool.fireYes));
      expect(f.text, contains('2'));
      expect(f.tone, isNot(ToolReceiptTone.danger));
      expect(activationFireReceipt(t, jsonEncode({'fired': false, 'firingCount': 0}))!.text, t.chat.tool.fireNo);
      expect(activationFireReceipt(t, jsonEncode({'fired': false, 'error': 'probe crashed'}))!.tone, ToolReceiptTone.danger);
    });
  });

  testWidgets('fn execution ok: dossier head + input/output + log drawer + provenance', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _get('get_function_execution', '{"executionId":"fnexec_1"}', {
      'id': 'fnexec_1', 'status': 'ok', 'triggeredBy': 'chat', 'input': {'url': 'https://x'},
      'output': {'code': 200}, 'logs': 'a\nb\nc', 'elapsedMs': 942,
      'startedAt': '2026-07-05T14:03:00Z', 'endedAt': '2026-07-05T14:03:01Z', 'conversationId': 'conv_abc123def',
    }))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.gotFnExec), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(RunDossier), findsOneWidget);
    expect(find.textContaining('https://x'), findsOneWidget); // input
    expect(find.textContaining(t.run.provConversation), findsOneWidget); // navigable conversation pill
    // the conversationId in the provenance is truncated to 12
    expect(find.textContaining('conv_abc123d'), findsOneWidget);
  });

  testWidgets('fn execution failed auto-expands, shows errorMessage; flowrunId = mono badge', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _get('get_function_execution', '{"executionId":"fnexec_bad"}', {
      'id': 'fnexec_bad', 'status': 'failed', 'triggeredBy': 'workflow',
      'input': {'url': 'https://down'}, 'errorMessage': 'ConnectionError: max retries exceeded',
      'elapsedMs': 30021, 'startedAt': '2026-07-05T14:03:00Z', 'endedAt': '2026-07-05T14:03:30Z',
      'flowrunId': 'fr_9a8b7c6d5e4f3a2b',
    }))));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('ConnectionError'), findsOneWidget); // auto-expanded
    expect(find.textContaining(t.run.provFlowrun), findsOneWidget); // flowrun mono badge
  });

  testWidgets('mcp call: the stderr tail splits into its own danger segment on the fixed separator', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _get('get_mcp_call', '{"callId":"mcl_1"}', {
      'id': 'mcl_1', 'serverId': 'mcp_acme', 'tool': 'fetch', 'status': 'failed', 'triggeredBy': 'agent',
      'errorMessage': 'failed',
      'logs': 'main log line\n$mcpStderrSeparator\nTraceback: TimeoutError',
      'elapsedMs': 5000, 'startedAt': '2026-07-05T14:03:00Z', 'endedAt': '2026-07-05T14:03:05Z',
    }))));
    await tester.pump();
    await tester.pumpAndSettle(); // failed → auto-expanded
    await tester.tap(find.textContaining('日志')); // open the log drawer (LogDrawer 计行标签)
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.dossierStderr), findsOneWidget); // the stderr segment header (danger)
    expect(find.textContaining('Traceback: TimeoutError'), findsOneWidget);
    expect(find.textContaining('main log line'), findsOneWidget); // main segment
    // the separator line itself is consumed, not shown raw. 分隔行被吃掉、不裸显。
    expect(find.textContaining(mcpStderrSeparator), findsNothing);
  });

  testWidgets('get_agent_execution: modelId micro + hydrated TranscriptPeek (thought/tool/reply)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _get('get_agent_execution', '{"executionId":"agexec_1"}', {
      'id': 'agexec_1', 'agentId': 'ag_1', 'modelId': 'claude-sonnet-5', 'provider': 'anselm', 'status': 'ok',
      'triggeredBy': 'chat', 'input': {'q': 1}, 'output': 'done', 'elapsedMs': 8400,
      'startedAt': '2026-07-05T14:03:00Z', 'endedAt': '2026-07-05T14:03:08Z',
      'transcript': [
        {'type': 'reasoning', 'content': 'PLANNING_THE_WORK', 'status': 'completed'},
        {'id': 'tc_1', 'type': 'tool_call', 'content': '{}', 'attrs': {'tool': 'run_function', 'summary': 'fetch'}, 'status': 'completed'},
        {'type': 'text', 'content': 'FINAL_REPLY_TEXT', 'status': 'completed'},
      ],
    }))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.gotAgentExec), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(TranscriptPeek), findsOneWidget);
    expect(find.text('claude-sonnet-5'), findsOneWidget); // modelId micro badge
    expect(find.textContaining(t.chat.tool.transcriptSteps(n: '3')), findsOneWidget); // 3 blocks
    expect(find.textContaining('PLANNING_THE_WORK', findRichText: true), findsOneWidget); // reasoning line
    expect(find.textContaining('run_function'), findsWidgets); // tool_call row
    expect(find.textContaining('FINAL_REPLY_TEXT', findRichText: true), findsOneWidget); // text reply line
  });

  testWidgets('activation fired: fire conclusion + returnValue + payload + trigger provenance', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _get('get_activation', '{"activationId":"act_1"}', {
      'id': 'act_1', 'triggerId': 'trg_7a8b9c0d1e2f3a4b', 'kind': 'sensor', 'fired': true, 'firingCount': 2,
      'returnValue': {'temp': 31.4}, 'payload': {'temp': 31.4}, 'createdAt': '2026-07-05T14:03:00Z',
    }))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.gotActivation), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.fireYes), findsWidgets);
    expect(find.textContaining(t.chat.tool.actReturnValue), findsOneWidget);
    expect(find.textContaining(t.run.provTrigger), findsOneWidget); // navigable trigger pill
  });
}
