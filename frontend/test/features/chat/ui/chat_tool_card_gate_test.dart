import 'package:anselm/core/contract/interaction.dart';
import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/an_badge.dart';
import 'package:anselm/core/ui/an_button.dart';
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
    expect(find.widgetWithText(AnBadge, '已允许'), findsNothing);
    // Expand → the provenance章 appears. 展开→出处章现。
    await tester.tap(find.text('已调用').first); // generic verb (delete_agent uncataloged until B3)
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AnBadge, '已允许'), findsOneWidget);
  });

  testWidgets('decided approve_always → the always章', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
      node: _call('delete_agent', result: '{"deleted":"ag_1"}'),
      interaction: _danger(decided: InteractionAction.approveAlways),
    )));
    await tester.pump();
    await tester.tap(find.text('已调用').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('本对话总是'), findsOneWidget);
  });
}
