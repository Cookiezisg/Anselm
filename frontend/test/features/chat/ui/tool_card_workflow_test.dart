import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/model/partial_json.dart';
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
    n.children.add(
      BlockNode(id: 'tr_wf', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result},
    );
  }
  return n;
}

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 640, child: child)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test(
    'graphFromWorkflowOps builds the full graph from add_node/add_edge ops',
    () {
      final g = graphFromWorkflowOps(PartialJsonSession()..append(_ops));
      expect(g.nodes.length, 3);
      expect(g.edges.length, 2);
      expect(g.nodes[0].kind, NodeKind.trigger);
      expect(g.nodes[1].kind, NodeKind.action);
      expect(g.nodes.map((n) => n.ref), [
        'pr-merged',
        'run-tests',
        'summarize',
      ]);
      expect(g.edges[0].from, 'n1');
    },
  );

  test(
    'graphFromWorkflowOps is tolerant of a partial stream (only completed ops)',
    () {
      // The last add_edge is cut off mid-object → only the completed ops surface. 末 op 截断→只取已闭合。
      const partial =
          '{"ops":[{"op":"add_node","node":{"id":"a","kind":"trigger","ref":"t"}},{"op":"add_e';
      final g = graphFromWorkflowOps(PartialJsonSession()..append(partial));
      expect(g.nodes.length, 1);
      expect(g.edges, isEmpty);
    },
  );

  test('workflowCreateReceipt: inactive → v1 · 未激活 (warn, not a failure)', () {
    LocaleSettings.setLocaleRaw('zh-CN');
    final r = workflowCreateReceipt(
      t,
      _state(
        '{"id":"wf_1","version":1,"active":false,"lifecycleState":"inactive"}',
      ),
    );
    expect(r!.tone, ToolReceiptTone.warn);
    expect(r.text, contains('未激活'));
    expect(r.text, contains('v1'));
  });

  testWidgets('collapsed row: 已创建工作流 + name + v1 · 未激活', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _wf(
            result:
                '{"id":"wf_1","version":1,"active":false,"lifecycleState":"inactive"}',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('已创建工作流'), findsOneWidget);
    expect(find.text('pr-flow'), findsOneWidget); // the name target chip
    expect(find.textContaining('未激活', findRichText: true), findsWidgets);
  });

  testWidgets(
    'settled body → the workflow graph renders via AnGraphCanvas, 1:1 with the entity page (B5)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _wf(
              result:
                  '{"id":"wf_1","version":1,"active":false,"lifecycleState":"inactive"}',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已创建工作流'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // The SAME widget the entity page uses (not a bespoke mini-graph) → visual 1:1. 与实体页同款 widget。
      expect(find.byType(AnGraphCanvas), findsOneWidget);
      // The graph's nodes are the workflow steps. 图节点=工作流步骤。
      expect(find.text('pr-merged'), findsOneWidget);
      expect(find.text('summarize'), findsOneWidget);
    },
  );

  // ── edit_workflow morph (pure-delta form) ──

  const editOps =
      '{"workflowId":"wf_1","ops":['
      '{"op":"add_node","node":{"id":"n4","kind":"action","ref":"notify-slack"}},'
      '{"op":"update_node","id":"n2","patch":{"ref":"fn_new"}},'
      '{"op":"delete_node","id":"n3"},'
      '{"op":"add_edge","edge":{"id":"e5","from":"n2","to":"n4"}},'
      '{"op":"delete_edge","id":"e2"}]}';

  BlockNode editNode(
    String args, {
    String result = '{"id":"wf_1","versionId":"wfv_2","version":5}',
  }) {
    return BlockNode(id: 'tc_edit_workflow', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': 'edit_workflow', 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_ew', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
      );
  }

  test(
    'workflowEditDelta derives added / updated / deleted from the ops (zero before-graph)',
    () {
      final d = workflowEditDelta(PartialJsonSession()..append(editOps));
      expect(d.addedNodes.length, 1);
      expect(d.addedNodes.first.ref, 'notify-slack');
      expect(d.updatedNodes, ['n2']);
      expect(d.deletedNodes, ['n3']);
      expect(d.addedEdges, 1);
      expect(d.deletedEdges, 1);
      expect(d.metaOnly, isFalse);
    },
  );

  test('a set_meta-only edit is metaOnly (graph unchanged)', () {
    final d = workflowEditDelta(
      PartialJsonSession()..append(
        '{"workflowId":"wf_1","ops":[{"op":"set_meta","name":"renamed"}]}',
      ),
    );
    expect(d.metaOnly, isTrue);
    expect(d.addedNodes, isEmpty);
  });

  testWidgets(
    'edit_workflow morph roster: legend + green add / amber update / red-strike delete chips',
    (tester) async {
      await tester.pumpWidget(_host(ChatToolCard(node: editNode(editOps))));
      await tester.pump();
      await tester.tap(find.textContaining('已更新工作流'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // The change roster chips (added node's ref, updated + deleted ids). 变更花名册 chips。
      expect(find.text('notify-slack'), findsOneWidget); // added (green)
      expect(find.text('n2'), findsOneWidget); // updated (amber)
      expect(find.text('n3'), findsOneWidget); // deleted (red strikethrough)
    },
  );

  testWidgets('meta-only edit says so honestly', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: editNode(
            '{"workflowId":"wf_1","ops":[{"op":"set_meta","name":"x"}]}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已更新工作流'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('仅改元数据'), findsOneWidget);
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
