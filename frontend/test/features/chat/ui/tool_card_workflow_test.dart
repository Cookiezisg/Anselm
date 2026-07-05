import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_workflow.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F04 create_workflow — the two-act growth show: op ticker (streaming) → the workflow graph replaying
// its growth (settled). 两幕生长秀:op ticker → 图回放生长。

const _ops =
    '{"name":"pr-flow","ops":['
    '{"op":"add_node","node":{"id":"n1","kind":"trigger","ref":"pr-merged"}},'
    '{"op":"add_node","node":{"id":"n2","kind":"action","ref":"run-tests"}},'
    '{"op":"add_node","node":{"id":"n3","kind":"agent","ref":"summarize"}},'
    '{"op":"add_edge","edge":{"id":"e1","from":"n1","to":"n2"}},'
    '{"op":"add_edge","edge":{"id":"e2","from":"n2","to":"n3"}}]}';

BlockNode _wf({String? result, String args = _ops, bool open = false}) {
  final n = BlockNode(id: 'tc_create_workflow', kind: BlockKind.toolCall)
    ..status = open ? 'open' : 'completed'
    ..content = {'name': 'create_workflow', 'arguments': args};
  if (result != null) {
    n.children.add(BlockNode(id: 'tr_wf', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': result});
  }
  return n;
}

Widget _host(Widget child) => TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: child))),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test('graphFromWorkflowOps builds the full graph from add_node/add_edge ops', () {
    final g = graphFromWorkflowOps(_ops);
    expect(g.nodes.length, 3);
    expect(g.edges.length, 2);
    expect(g.nodes[0].kind, NodeKind.trigger);
    expect(g.nodes[1].kind, NodeKind.action);
    expect(g.nodes.map((n) => n.ref), ['pr-merged', 'run-tests', 'summarize']);
    expect(g.edges[0].from, 'n1');
  });

  test('graphFromWorkflowOps is tolerant of a partial stream (only completed ops)', () {
    // The last add_edge is cut off mid-object → only the completed ops surface. 末 op 截断→只取已闭合。
    const partial = '{"ops":[{"op":"add_node","node":{"id":"a","kind":"trigger","ref":"t"}},{"op":"add_e';
    final g = graphFromWorkflowOps(partial);
    expect(g.nodes.length, 1);
    expect(g.edges, isEmpty);
  });

  test('workflowCreateReceipt: inactive → v1 · 未激活 (warn, not a failure)', () {
    LocaleSettings.setLocaleRaw('zh-CN');
    final r = workflowCreateReceipt(
        t, _state('{"id":"wf_1","version":1,"active":false,"lifecycleState":"inactive"}'));
    expect(r!.tone, ToolReceiptTone.warn);
    expect(r.text, contains('未激活'));
    expect(r.text, contains('v1'));
  });

  testWidgets('collapsed row: 已创建工作流 + name + v1 · 未激活', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
        node: _wf(result: '{"id":"wf_1","version":1,"active":false,"lifecycleState":"inactive"}'))));
    await tester.pump();
    expect(find.textContaining('已创建工作流'), findsOneWidget);
    expect(find.text('pr-flow'), findsOneWidget); // the name target chip
    expect(find.textContaining('未激活', findRichText: true), findsWidgets);
  });

  testWidgets('settled body → the workflow graph (AnMiniGraphGrowth) replays its growth', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(
        node: _wf(result: '{"id":"wf_1","version":1,"active":false,"lifecycleState":"inactive"}'))));
    await tester.pump();
    await tester.tap(find.textContaining('已创建工作流'), warnIfMissed: false);
    await tester.pumpAndSettle(); // the growth animates then settles
    expect(find.byType(AnMiniGraphGrowth), findsOneWidget);
    expect(find.byType(AnMiniGraph), findsOneWidget);
    // The graph's nodes are the workflow steps. 图节点=工作流步骤。
    expect(find.text('pr-merged'), findsOneWidget);
    expect(find.text('summarize'), findsOneWidget);
  });
}

// Minimal ToolCardState for the pure-function test. 纯函数测的最小依赖。
ToolCardState _state(String result) => ToolCardState(
      phase: ToolCardPhase.succeeded,
      toolName: 'create_workflow',
      summary: '',
      danger: '',
      argsText: _ops,
      resultText: result,
      errorText: '',
      progressText: '',
      progressLive: false,
    );
