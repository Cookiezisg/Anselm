import 'package:flutter/material.dart';

import '../../../core/contract/entities/values.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import 'dart:convert';

import '../../../core/model/partial_json.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';

/// F04 create_workflow — the two-act growth show (WRK-056 §create_workflow, ★pivot 场景「图一点点长
/// 出来」). Act one (args streaming, [workflowOpLiveBody]): the graph is NOT drawn (streaming re-layout
/// would jitter — graph.md); instead an OP TICKER counts add_node / add_edge as [partialJsonEvents]
/// surfaces each completed op, and a kind-coloured chip lights per node. Act two (settled,
/// [workflowBuildBody]): the full graph is built from the ops and [AnMiniGraphGrowth] REPLAYS its growth
/// on a frozen layout — the blueprint moment.
///
/// F04 create_workflow 两幕生长秀。幕一(args 流入):不画图(流中重布局跳变),op ticker 数 add_node/
/// add_edge、每节点亮一枚 kind 色 chip;幕二(落定):ops 建全图,AnMiniGraphGrowth 在冻结布局上回放生长。

/// create_workflow's collapsed-row receipt: `v1 · 未激活` — inactive is EXPECTED (create → deactivated),
/// so it's a WARN (「建了≠上线」的诚实半态),not a failure; the row nudges toward activate_workflow.
/// create_workflow 回执:v1 · 未激活(inactive 是预期半态、warn 非失败,行提示去 activate)。
ToolReceipt? workflowCreateReceipt(Translations t, ToolCardState state) {
  Map<String, dynamic>? out;
  try {
    final d = jsonDecode(state.resultText);
    if (d is Map<String, dynamic>) out = d;
  } catch (_) {}
  if (out == null) return null;
  final v = out['version'];
  if (v == null) return null;
  final inactive = out['lifecycleState'] == 'inactive' || out['active'] == false;
  return inactive
      ? (text: 'v$v · ${t.chat.tool.wfInactive}', tone: ToolReceiptTone.warn)
      : (text: 'v$v', tone: ToolReceiptTone.none);
}

/// The NodeKind for a workflow op's `kind` string (forward-compat → unknown). op kind 串 → NodeKind。
NodeKind workflowNodeKind(Object? k) => switch (k) {
      'trigger' => NodeKind.trigger,
      'action' => NodeKind.action,
      'agent' => NodeKind.agent,
      'control' => NodeKind.control,
      'approval' => NodeKind.approval,
      _ => NodeKind.unknown,
    };

/// Build a [Graph] from a create_workflow ops fragment (add_node / add_edge) — tolerant of a PARTIAL
/// mid-stream fragment (only COMPLETED ops surface via [partialJsonArrayItems]). For CREATE the ops ARE
/// the whole graph (from zero); edit_workflow's after-graph needs the fetch seam (B2.6). 从 ops 建全图。
Graph graphFromWorkflowOps(String argsText) {
  final ops = partialJsonArrayItems(argsText, ['ops']);
  final nodes = <Node>[];
  final edges = <Edge>[];
  for (final raw in ops) {
    if (raw is! Map) continue;
    switch (raw['op']) {
      case 'add_node':
        final n = raw['node'];
        if (n is Map && n['id'] is String) {
          nodes.add(Node(
            id: n['id'] as String,
            kind: workflowNodeKind(n['kind']),
            ref: (n['ref'] ?? '').toString(),
          ));
        }
      case 'add_edge':
        final e = raw['edge'];
        if (e is Map && e['id'] is String && e['from'] is String && e['to'] is String) {
          edges.add(Edge(
            id: e['id'] as String,
            from: e['from'] as String,
            to: e['to'] as String,
            fromPort: e['fromPort'] as String?,
          ));
        }
    }
  }
  return Graph(nodes: nodes, edges: edges);
}

// The embedded graph height inside a tool card (shorter than the entity-page preview). 卡内图高。
const double _graphHeight = 200;

typedef _OpCounts = ({int nodes, int edges, List<NodeKind> kinds});

_OpCounts _countOps(String argsText) {
  var nodes = 0, edges = 0;
  final kinds = <NodeKind>[];
  for (final raw in partialJsonArrayItems(argsText, ['ops'])) {
    if (raw is! Map) continue;
    if (raw['op'] == 'add_node') {
      nodes++;
      final n = raw['node'];
      kinds.add(workflowNodeKind(n is Map ? n['kind'] : null));
    } else if (raw['op'] == 'add_edge') {
      edges++;
    }
  }
  return (nodes: nodes, edges: edges, kinds: kinds);
}

/// Act one — the live OP TICKER (no graph while streaming): `节点 N · 边 M` + a kind-coloured dot per
/// add_node op, lighting up as ops complete. 幕一 op ticker(流中不画图):计数 + kind 色点逐个亮。
Widget workflowOpLiveBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  final counts = _countOps(state.argsText);
  if (counts.nodes == 0 && counts.edges == 0) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(t.chat.tool.wfGraphCounts(nodes: '${counts.nodes}', edges: '${counts.edges}'),
          style: AnText.metaTabular().copyWith(color: c.inkMuted)),
      if (counts.kinds.isNotEmpty) ...[
        const SizedBox(height: AnGap.stackTight),
        Wrap(
          spacing: AnGap.inline,
          runSpacing: AnGap.stackTight,
          children: [
            for (final k in counts.kinds)
              Container(
                width: AnSize.iconSm,
                height: AnSize.iconSm,
                decoration: BoxDecoration(
                  color: nodeKindColor(context, k),
                  borderRadius: BorderRadius.circular(AnRadius.tag),
                ),
              ),
          ],
        ),
      ],
    ],
  );
}

/// Act two — the settled body: intent · the workflow graph replaying its growth · the result bar.
/// 幕二 落定体:意图 · 工作流图回放生长 · 结果条。
Widget workflowBuildBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final graph = graphFromWorkflowOps(state.argsText);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (state.summary.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s6),
          child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted)),
        ),
      if (graph.nodes.isNotEmpty)
        AnMiniGraphGrowth(graph: graph, height: _graphHeight)
      else if (state.argsText.isNotEmpty)
        ToolWindow(child: Text(state.argsText, style: AnText.code.copyWith(color: c.inkMuted))),
      RunStatBar(state: state),
    ],
  );
}
