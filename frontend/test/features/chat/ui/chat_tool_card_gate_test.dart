import 'package:anselm/core/contract/interaction.dart';
import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_thin_table.dart';
import 'package:anselm/features/chat/state/pending_interactions_provider.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_interaction_gate.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The V6 human-gate integration into the chassis (B1.e): an awaiting danger interaction renders the
// gate LOCKED-OPEN under a bare amber verb line; a positive decision leaves a provenance章 in the
// expanded body; resolving flows through onResolve. ChatToolCard stays a PURE prop widget (the
// transcript threads the provider record), so it tests without a ProviderScope.
// V6 人闸接底盘:待决→琥珀裸行下锁定展开门;正向决议→展开体出处章;决议经 onResolve。卡纯 prop、无需 scope。

BlockNode _call(String name, {String status = 'completed', String? result}) {
  final n = BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
    ..status = status
    ..content = {'name': name, 'danger': 'dangerous'};
  if (result != null) {
    n.children.add(BlockNode(id: 'tr_x', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': result});
  }
  return n;
}

InteractionRecord _danger({InteractionAction? decided}) => InteractionRecord(
      interaction: const Interaction(
        toolCallId: 'tc_delete_agent',
        kind: InteractionKind.danger,
        tool: 'delete_agent',
        resolved: false,
        summary: 'remove the obsolete triager',
        args: {'agentId': 'ag_1'},
      ),
      decided: decided,
    );

Widget _host(Widget child) => TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: SizedBox(width: 560, child: child)),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('awaiting danger → the gate renders LOCKED-OPEN under an amber verb, no chevron', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
      node: _call('delete_agent', status: 'completed'),
      interaction: _danger(),
    )));
    await tester.pump();
    // The bare row carries the awaiting verb; the gate is open with its evidence + fail-safe buttons.
    expect(find.text('等待确认'), findsOneWidget); // chat.tool.awaitingConfirm (row verb)
    expect(find.byType(ToolInteractionGate), findsOneWidget);
    expect(find.text('remove the obsolete triager'), findsOneWidget); // summary in the gate
    expect(find.widgetWithText(AnButton, '允许'), findsOneWidget);
    expect(find.widgetWithText(AnButton, '拒绝'), findsOneWidget);
  });

  testWidgets('resolving the gate flows through onResolve with the exact action', (tester) async {
    InteractionAction? got;
    await tester.pumpWidget(_host(ChatToolCard(
      node: _call('delete_agent'),
      interaction: _danger(),
      onResolve: (a, {answer}) => got = a,
    )));
    await tester.pump();
    await tester.tap(find.widgetWithText(AnButton, '允许'));
    expect(got, InteractionAction.approve);
  });

  testWidgets('decided approve → a provenance章 sits atop the expanded body', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
      node: _call('delete_agent', result: '{"deleted":"ag_1"}'),
      interaction: _danger(decided: InteractionAction.approve),
    )));
    await tester.pump();
    // Collapsed: no gate (the decision is made), no章 yet (it lives in the body). 收起态无门无章。
    expect(find.byType(ToolInteractionGate), findsNothing);
    expect(find.widgetWithText(AnChip, '已允许'), findsNothing);
    // Expand → the provenance章 appears. 展开→出处章现。
    await tester.tap(find.text('已删除智能体').first); // delete_agent cataloged in B3.6
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AnChip, '已允许'), findsOneWidget);
  });

  testWidgets('decided approve_always → the always章', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
      node: _call('delete_agent', result: '{"deleted":"ag_1"}'),
      interaction: _danger(decided: InteractionAction.approveAlways),
    )));
    await tester.pump();
    await tester.tap(find.text('已删除智能体').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('本对话总是'), findsOneWidget);
  });

  // ── F16 ask_user (settled Q/A record, derived from the DB block; awaiting drives the gate) ──

  BlockNode askNode({String? optionsJson, String? result, bool declined = false, bool empty = false}) {
    final args = optionsJson == null
        ? '{"message":"which currency?"}'
        : '{"message":"which currency?","options":$optionsJson}';
    final n = BlockNode(id: 'tc_ask_user', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': 'ask_user', 'arguments': args};
    final res = declined
        ? 'The user declined to answer this question. Proceed without it or ask differently.'
        : empty
            ? '(the user submitted an empty answer)'
            : (result ?? 'USD');
    n.children.add(BlockNode(id: 'tr_ask', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': res});
    return n;
  }

  testWidgets('ask_user settled verbs: answered / skipped / empty by result prose', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: askNode(result: 'USD'))));
    await tester.pump();
    expect(find.text('已回答'), findsOneWidget);

    await tester.pumpWidget(_host(ChatToolCard(node: askNode(declined: true))));
    await tester.pump();
    expect(find.text('已跳过'), findsOneWidget); // decline prose → skipped, NOT the danger 已拒绝执行

    await tester.pumpWidget(_host(ChatToolCard(node: askNode(empty: true))));
    await tester.pump();
    expect(find.text('空答案'), findsOneWidget);
  });

  testWidgets('ask_user receipt is the answer first line (only for a real answer)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: askNode(result: 'euros please'))));
    await tester.pump();
    expect(find.textContaining('euros please'), findsWidgets); // in the collapsed receipt
  });

  testWidgets('ask_user expanded → frozen Q/A via the gate resolved mode (chosen option章)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
      node: askNode(optionsJson: '["CNY","USD","EUR"]', result: 'USD'))));
    await tester.pump();
    await tester.tap(find.text('已回答'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolInteractionGate), findsOneWidget);
    expect(find.text('which currency?'), findsOneWidget); // the question
    expect(find.text('2. USD'), findsOneWidget); // chosen option pinned
  });

  testWidgets('ask_user awaiting → the ask gate (options + free text) via the interaction record', (tester) async {
    final rec = InteractionRecord(
      interaction: const Interaction(
        toolCallId: 'tc_ask_user',
        kind: InteractionKind.ask,
        tool: 'ask_user',
        resolved: false,
        message: 'which currency?',
        options: ['CNY', 'USD'],
      ),
    );
    // Awaiting = NO tool_result yet (a landed result would win over the awaiting overlay). 待决=无结果子块。
    final awaitingNode = BlockNode(id: 'tc_ask_user', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': 'ask_user', 'arguments': '{"message":"which currency?","options":["CNY","USD"]}'};
    await tester.pumpWidget(_host(ChatToolCard(node: awaitingNode, interaction: rec)));
    await tester.pump();
    // The row verb 等待你回答 (ask awaiting, not danger's 等待确认) — echoed by the gate header, so ≥1.
    expect(find.text('等待你回答'), findsWidgets);
    expect(find.text('等待确认'), findsNothing); // NOT the danger awaiting verb
    expect(find.byType(ToolInteractionGate), findsOneWidget);
    expect(find.widgetWithText(AnButton, '1. CNY'), findsOneWidget);
  });

  // ── F16 decide_approval (verdict record + consequence bar; NOT_PARKED reframed) ──

  BlockNode decideNode({required String decision, String? reason, String? result, String? errorProse}) {
    final args = reason == null
        ? '{"flowrunId":"flr_1","nodeId":"n1","decision":"$decision"}'
        : '{"flowrunId":"flr_1","nodeId":"n1","decision":"$decision","reason":"$reason"}';
    final n = BlockNode(id: 'tc_decide_approval', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': 'decide_approval', 'arguments': args};
    n.children.add(BlockNode(id: 'tr_d', kind: BlockKind.toolResult)
      ..status = errorProse != null ? 'error' : 'completed'
      ..error = errorProse
      ..content = {'content': errorProse ?? result ?? '{}'});
    return n;
  }

  testWidgets('decide verbs: yes → 已批准, no → 已否决; failed → neutral 已裁决', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
        node: decideNode(decision: 'yes', result: '{"flowrun":{"status":"running"},"nodes":[]}'))));
    await tester.pump();
    expect(find.text('已批准'), findsOneWidget);

    await tester.pumpWidget(_host(ChatToolCard(
        node: decideNode(decision: 'no', result: '{"flowrun":{"status":"failed"},"nodes":[]}'))));
    await tester.pump();
    expect(find.text('已否决'), findsOneWidget);

    await tester.pumpWidget(_host(ChatToolCard(
        node: decideNode(decision: 'yes', errorProse: 'approval node is not awaiting a decision'))));
    await tester.pump();
    expect(find.text('已裁决'), findsOneWidget); // NOT falsely 已批准
    expect(find.text('已批准'), findsNothing);
  });

  testWidgets('decide approved body: verdict章 + reason + consequence counts', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
        node: decideNode(
            decision: 'yes',
            reason: '预算内,批准',
            result:
                '{"flowrun":{"status":"running"},"nodes":[{"status":"completed"},{"status":"completed"},{"status":"running"}]}'))));
    await tester.pump();
    await tester.tap(find.text('已批准'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AnChip, '批准'), findsOneWidget); // verdict章
    expect(find.text('预算内,批准'), findsOneWidget); // reason
    expect(find.text('completed 2'), findsOneWidget); // consequence count off nodes[]
    expect(find.text('running 1'), findsOneWidget);
  });

  testWidgets('decide NOT_PARKED: friendly note, no raw crash prose (ownsError)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
        node: decideNode(decision: 'yes', errorProse: 'approval node is not awaiting a decision'))));
    await tester.pump();
    await tester.pumpAndSettle(); // failed auto-expands once
    expect(find.textContaining('本次裁决未生效'), findsOneWidget); // the reframed note
    expect(find.textContaining('approval node is not awaiting'), findsNothing); // raw prose suppressed
  });

  // ── F16 list_approval_inbox (settle-only thin table; count receipt; honest empty) ──

  BlockNode inboxNode(String result) =>
      BlockNode(id: 'tc_list_approval_inbox', kind: BlockKind.toolCall)
        ..status = 'completed'
        ..content = {'name': 'list_approval_inbox', 'arguments': '{}'}
        ..children.add(BlockNode(id: 'tr_i', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result});

  testWidgets('inbox receipt: N awaiting / none awaiting by count', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
        node: inboxNode('{"count":2,"parked":[{"flowrunId":"flr_1","ref":"a","parkedAt":"2026-07-06T00:00:00Z"},{"flowrunId":"flr_2","ref":"b","parkedAt":"2026-07-06T00:00:00Z"}]}'))));
    await tester.pump();
    expect(find.textContaining('2 件待审'), findsOneWidget);

    await tester.pumpWidget(_host(ChatToolCard(node: inboxNode('{"count":0,"parked":[]}'))));
    await tester.pump();
    expect(find.textContaining('无待审'), findsOneWidget);
  });

  testWidgets('inbox body: a thin table of parked approvals (flattened summary + ref + run)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
        node: inboxNode(
            '{"count":1,"parked":[{"flowrunId":"flr_abcdefghij123","nodeId":"n","ref":"apf_spend","rendered":"# 采购审批\\n金额 ¥12,400","parkedAt":"2026-07-06T00:00:00Z"}]}'))));
    await tester.pump();
    await tester.tap(find.text('已清点'));
    await tester.pumpAndSettle();
    expect(find.byType(AnThinTable), findsOneWidget);
    expect(find.text('apf_spend'), findsOneWidget); // ref cell
    expect(find.text('# 采购审批'), findsOneWidget); // rendered FIRST LINE only (flattened)
    expect(find.textContaining('金额 ¥12,400'), findsNothing); // the 2nd line is NOT rendered in-cell
    expect(find.text('flr_abcdefgh…'), findsOneWidget); // run id truncated at the family id tier (12, 批5 A-044) 族档截断
  });

  testWidgets('inbox empty → an honest muted empty state, no table', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: inboxNode('{"count":0,"parked":[]}'))));
    await tester.pump();
    await tester.tap(find.text('已清点'));
    await tester.pumpAndSettle();
    expect(find.byType(AnThinTable), findsNothing);
    expect(find.textContaining('收件箱空'), findsOneWidget);
  });
}
