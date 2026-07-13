import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_kv.dart';
import 'package:anselm/core/ui/an_window.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/run_ledger.dart';
import 'package:anselm/features/chat/ui/tool_card_io_section.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/features/chat/ui/tool_card_skins.dart' show WindowCopyButton, rawMonoWindow;
import 'package:anselm/features/chat/ui/tool_card_runlog.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F09 run-log search (B5.6) — aggregate families: ok✓/failed✗ rollup receipt, slim RunLedger, empty→no
// body, and the SLIM PROJECTION invariant (input/output/logs/transcript never render). F09 检索族。

BlockNode _search(String name, String args, String result, {String? entityName}) =>
    BlockNode(id: 'tc_s', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args, 'entityName': ?entityName}
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

  testWidgets('fn executions header shows the resolved function NAME, not the id (B4)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _search('search_function_executions', '{"functionId":"fn_1"}',
        _page('executions', [_exec('fnexec_01', 'ok')], ok: 1, failed: 0),
        entityName: 'sync_inventory'))));
    await tester.pump();
    // The collapsed header chip is the backend-resolved function name (search scoped to that function). 头 chip 显函数名。
    expect(find.textContaining('sync_inventory'), findsOneWidget);
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

  group('count families (flowruns/firings/activations)', () {
    test('countListReceipt: N 条 / N+ 条 (hasMore); no fabricated ✓✗; empty → 无记录', () {
      final r = countListReceipt(t, jsonEncode({'count': 3, 'firings': [1, 2, 3]}), 'firings')!;
      expect(r.text, contains('3'));
      expect(r.text, isNot(contains('✓'))); // count families NEVER fabricate an ok/failed split
      expect(countListReceipt(t, jsonEncode({'runs': [1], 'hasMore': true}), 'runs')!.text, contains('+'));
      expect(countListReceipt(t, jsonEncode({'count': 0, 'firings': []}), 'firings')!.text, t.chat.tool.logNoRecords);
    });

    testWidgets('flowruns: pageScoped bead strip + replay badge + failed subtext + park caption', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _search('search_flowruns', '{"workflowId":"wf_1"}',
          jsonEncode({
            'runs': [
              {'id': 'fr_02', 'workflowId': 'wf_1', 'status': 'failed', 'replayCount': 2, 'error': 'node charge failed', 'startedAt': '2026-07-05T14:00:00Z', 'updatedAt': '2026-07-05T14:00:00Z'},
            ],
            'hasMore': false,
          })))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.searchedFlowruns), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(t.chat.tool.beadPageScope), findsOneWidget); // 本页
      expect(find.textContaining(t.chat.tool.replayTimes(n: '2')), findsOneWidget);
      expect(find.textContaining('node charge failed'), findsOneWidget); // run-level error subtext
      expect(find.textContaining(t.chat.tool.parkRunCaption), findsOneWidget);
    });

    testWidgets('firings: disposition badges (started/skipped/pending); started carries a flowrunId', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _search('search_firings', '{"triggerId":"trg_1"}',
          jsonEncode({
            'count': 2,
            'firings': [
              {'id': 'frg_01', 'triggerId': 'trg_1', 'status': 'started', 'flowrunId': 'fr_abc123def456', 'dedupKey': 'k1', 'createdAt': '2026-07-05T14:00:00Z'},
              {'id': 'frg_02', 'triggerId': 'trg_1', 'status': 'skipped', 'dedupKey': 'k2', 'createdAt': '2026-07-05T13:00:00Z'},
            ],
          })))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.searchedFirings), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(t.chat.tool.firingStarted), findsOneWidget);
      expect(find.text(t.chat.tool.firingSkipped), findsOneWidget);
      expect(find.textContaining('fr_abc123def'), findsOneWidget); // started → flowrunId chip (truncated to 12)
    });

    testWidgets('activations: fired mark + returnValue expands inline on tap', (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: _search('search_activations', '{"triggerId":"trg_1"}',
          jsonEncode({
            'count': 1,
            'activations': [
              // Nested returnValue (≥2 keys + a Map value) — routes ToolIOSection to its JSON-tree
              // branch, the bare-gated window seam. A scalar map walks the per-key inline path and
              // never consumes bare (复审:假钉,mutation 实证). 嵌套值才踩到 bare 承重的出窗分支。
              {'id': 'act_01', 'triggerId': 'trg_1', 'kind': 'sensor', 'fired': true, 'firingCount': 2, 'returnValue': {'temp': 31.4, 'series': {'p50': 12, 'p99': 88}}, 'createdAt': '2026-07-05T14:00:00Z'},
            ],
          })))));
      await tester.pump();
      await tester.tap(find.textContaining(t.chat.tool.searchedActivations), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('act_01'), findsOneWidget);
      expect(find.textContaining(t.chat.tool.actFanout(n: '2')), findsOneWidget);
      // returnValue is behind a row tap (lazy) — not shown until the row is tapped. 惰性:点前不渲。
      expect(find.textContaining('temp'), findsNothing);
      await tester.tap(find.text('act_01'));
      await tester.pumpAndSettle();
      expect(find.textContaining('temp'), findsOneWidget); // now the returnValue tree is inline
      // LEAF LAW regression (批4 复审 HIGH): the ledger already lives in the ONE machine window —
      // the expanded returnValue must render BARE (a second window here nests window-in-window and
      // trips AnWindow's debug assert). 叶子律回归钉:台账已在唯一窗内,展开值必须裸渲(再出窗即套窗)。
      expect(find.byType(AnWindow), findsOneWidget);
    });
  });

  group('ToolIOSection bare 缝 (批4 复审 HIGH 的修法)', () {
    testWidgets('bare: a LIST renders the JSON tree with NO window of its own', (tester) async {
      // Since 批6's value-shape split EVERY Map exits before _jsonTree (AnKv / per-key recursion) —
      // only a List still reaches the bare-gated tree, so this pin rides a List fixture
      // (批6 复审:旧 Map 夹具再不进树,门空真). List 才进 bare 承重分支。
      await tester.pumpWidget(_host(const ToolIOSection(label: 'v', value: [1, 2, 'x'], bare: true)));
      await tester.pumpAndSettle();
      expect(find.byType(AnWindow), findsNothing);
    });
    testWidgets('not bare: the same list wears its own window (the inverse edge)', (tester) async {
      await tester.pumpWidget(_host(const ToolIOSection(label: 'v', value: [1, 2, 'x'])));
      await tester.pumpAndSettle();
      expect(find.byType(AnWindow), findsOneWidget);
    });
    testWidgets('value-shape split: an all-short-scalar map rides the family AnKv, bools on the flag row (批6 A-077)',
        (tester) async {
      await tester.pumpWidget(_host(const ToolIOSection(
          label: 'v', value: {'status': 200, 'ok': true, 'path': '/tmp/a'}, bare: true)));
      await tester.pumpAndSettle();
      expect(find.byType(AnKv), findsOneWidget); // the KV branch, not per-key sections KV 分支
      expect(find.text('✓'), findsOneWidget); // the bool routed to the flag row bool 走 flag 行
      expect(find.text('true'), findsNothing); // never the raw literal 绝不裸渲字面量
    });
    testWidgets('value-shape split: a map holding a long value keeps per-key label-above recursion', (tester) async {
      final long = List.filled(90, 'word').join(' ');
      await tester.pumpWidget(_host(ToolIOSection(label: 'v', value: {'summary': long, 'n': 2}, bare: true)));
      await tester.pumpAndSettle();
      expect(find.byType(AnKv), findsNothing); // a long value never squeezes into the KV face 长值不进 KV 脸
      expect(find.text('summary'), findsOneWidget); // its own per-key section head 逐键节头
      expect(find.text('n'), findsOneWidget);
    });
    testWidgets('bare + renderAsProse inside a host window: typeset bare, no nested window (leaf law)', (tester) async {
      final long = 'paragraph\n\n' * 30;
      await tester.pumpWidget(_host(AnWindow(child: ToolIOSection(label: 'v', value: long, renderAsProse: true, bare: true))));
      await tester.pumpAndSettle();
      expect(find.byType(AnWindow), findsOneWidget); // only the host — ProseWindow's shell withheld 仅宿主窗
    });
    testWidgets('bare truncated mono keeps the full-payload copy escape (显示可截,copy 永不截)', (tester) async {
      final big = 'x' * 7000;
      await tester.pumpWidget(_host(AnWindow(child: ToolIOSection(label: 'v', value: big, bare: true))));
      await tester.pumpAndSettle();
      expect(find.byType(WindowCopyButton), findsOneWidget);
    });
    testWidgets('default (not bare): a multi-line value owns its window', (tester) async {
      await tester.pumpWidget(_host(const ToolIOSection(label: 'v', value: 'line one\nline two')));
      await tester.pumpAndSettle();
      expect(find.byType(AnWindow), findsOneWidget);
    });
  });

  group('rawMonoWindow 共享 helper (A-003)', () {
    testWidgets('wraps mono text in the family window; maxLines tier caps the render', (tester) async {
      await tester.pumpWidget(_host(Builder(builder: (c) => rawMonoWindow(c, 'k=v', maxLines: AnCap.monoErrorLines))));
      await tester.pumpAndSettle();
      expect(find.byType(AnWindow), findsOneWidget);
      final t = tester.widget<Text>(find.text('k=v'));
      expect(t.maxLines, AnCap.monoErrorLines); // named line tier 命名行档
      expect(t.overflow, TextOverflow.ellipsis);
    });
    testWidgets('null maxLines = unbounded (clip, no ellipsis)', (tester) async {
      await tester.pumpWidget(_host(Builder(builder: (c) => rawMonoWindow(c, 'x'))));
      await tester.pumpAndSettle();
      final t = tester.widget<Text>(find.text('x'));
      expect(t.maxLines, isNull);
      expect(t.overflow, TextOverflow.clip);
    });
  });
}
