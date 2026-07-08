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

/// F04 create_workflow — a two-act show. Act one (args streaming, [workflowOpLiveBody]): the graph is NOT
/// drawn (streaming re-layout would jitter — graph.md); instead an OP TICKER counts add_node / add_edge as
/// [partialJsonEvents] surfaces each completed op, and a kind-coloured chip lights per node — the build is
/// visible here. Act two (settled, [workflowBuildBody]): the full graph is built from the ops and rendered
/// by [AnGraphCanvas] — the SAME widget the entity page uses, so the tool-card graph is 1:1 with it (B5).
///
/// F04 create_workflow 两幕。幕一(args 流入):不画图(流中重布局跳变),op ticker 数 add_node/add_edge、
/// 每节点亮一枚 kind 色 chip——生长感在此;幕二(落定):ops 建全图,由 [AnGraphCanvas] 渲染(实体页同款
/// widget),故 tool 卡图与实体页 1:1(B5)。

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
/// mid-stream fragment (only COMPLETED ops surface via [PartialJsonSession.arrayItemsAt]). For CREATE the ops ARE
/// the whole graph (from zero); edit_workflow's after-graph needs the fetch seam (B2.6). 从 ops 建全图。
Graph graphFromWorkflowOps(PartialJsonSession args) {
  final ops = args.arrayItemsAt(['ops']);
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

_OpCounts _countOps(PartialJsonSession args) {
  var nodes = 0, edges = 0;
  final kinds = <NodeKind>[];
  for (final raw in args.arrayItemsAt(['ops'])) {
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
  final counts = _countOps(state.argsSession);
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

// ── edit_workflow morph (WRK-056 §edit_workflow, ★pivot 场景「旧图变成新图」) ──

/// The precise delta of an edit_workflow ops fragment — added / updated / deleted nodes + edge counts,
/// derived ENTIRELY from the ops (add_node / update_node / delete_node / add_edge / update_edge /
/// delete_edge), with ZERO before-graph dependency (the after-graph canvas needs the fetch seam, #50;
/// this roster is the always-works baseline). edit_workflow 增量精确导出(零 before 依赖)。
typedef WorkflowDelta = ({
  List<Node> addedNodes,
  List<String> updatedNodes,
  List<String> deletedNodes,
  int addedEdges,
  int updatedEdges,
  int deletedEdges,
  bool metaOnly,
});

WorkflowDelta workflowEditDelta(PartialJsonSession args) {
  final added = <Node>[];
  final updated = <String>[];
  final deleted = <String>[];
  var addedE = 0, updatedE = 0, deletedE = 0;
  var sawGraphOp = false;
  for (final raw in args.arrayItemsAt(['ops'])) {
    if (raw is! Map) continue;
    switch (raw['op']) {
      case 'add_node':
        sawGraphOp = true;
        final n = raw['node'];
        if (n is Map && n['id'] is String) {
          added.add(Node(id: n['id'] as String, kind: workflowNodeKind(n['kind']), ref: (n['ref'] ?? '').toString()));
        }
      case 'update_node':
        sawGraphOp = true;
        if (raw['id'] is String) updated.add(raw['id'] as String);
      case 'delete_node':
        sawGraphOp = true;
        if (raw['id'] is String) deleted.add(raw['id'] as String);
      case 'add_edge':
        sawGraphOp = true;
        addedE++;
      case 'update_edge':
        sawGraphOp = true;
        updatedE++;
      case 'delete_edge':
        sawGraphOp = true;
        deletedE++;
    }
  }
  return (
    addedNodes: added,
    updatedNodes: updated,
    deletedNodes: deleted,
    addedEdges: addedE,
    updatedEdges: updatedE,
    deletedEdges: deletedE,
    metaOnly: !sawGraphOp,
  );
}

/// edit_workflow — the morph roster (pure-delta form, WRK-056 三级降级基线): a coloured legend
/// (+added / ~updated / −deleted, nodes · edges) + the change chips (added = green kind chips /
/// updated = amber id / deleted = red strikethrough), all from the ops — no fetch. The after-graph
/// canvas + green-halo/pulse overlay is the enhancement (needs the fetch seam #50, a Consumer body
/// that gallery-embedded cards can't host). meta-only edits say so honestly.
/// edit_workflow morph 花名册(纯 delta 形):彩色图例 + 变更花名册(绿添/琥珀改/红删划线),全从 ops、
/// 不 fetch;after 图画布 + 绿晕/脉冲覆层是增强(需取数缝 #50)。纯改元数据诚实说明。
Widget editWorkflowBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  final d = workflowEditDelta(state.argsSession);

  if (d.metaOnly && state.resultText.isNotEmpty) {
    // Only set_meta ops — the graph didn't change. 仅 set_meta:图未变。
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (state.summary.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
      Text(t.chat.tool.wfDeltaEmpty, style: AnText.label.copyWith(color: c.inkFaint)),
      RunStatBar(state: state),
    ]);
  }

  final legend = <InlineSpan>[];
  void part(String text, Color color) {
    if (legend.isNotEmpty) legend.add(TextSpan(text: ' · ', style: AnText.meta.copyWith(color: c.inkFaint)));
    legend.add(TextSpan(text: text, style: AnText.metaTabular().copyWith(color: color)));
  }
  final nodeParts = <String>[];
  if (d.addedNodes.isNotEmpty) nodeParts.add('+${d.addedNodes.length}');
  if (d.updatedNodes.isNotEmpty) nodeParts.add('~${d.updatedNodes.length}');
  if (d.deletedNodes.isNotEmpty) nodeParts.add('−${d.deletedNodes.length}');
  if (nodeParts.isNotEmpty) part('${nodeParts.join(' ')} ${t.chat.tool.wfNodeUnit}', c.ink);
  final edgeParts = <String>[];
  if (d.addedEdges > 0) edgeParts.add('+${d.addedEdges}');
  if (d.updatedEdges > 0) edgeParts.add('~${d.updatedEdges}');
  if (d.deletedEdges > 0) edgeParts.add('−${d.deletedEdges}');
  if (edgeParts.isNotEmpty) part('${edgeParts.join(' ')} ${t.chat.tool.wfEdgeUnit}', c.inkMuted);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (state.summary.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
      if (legend.isNotEmpty) Text.rich(TextSpan(children: legend)),
      const SizedBox(height: AnGap.stack),
      Wrap(
        spacing: AnGap.inline,
        runSpacing: AnGap.stackTight,
        children: [
          for (final n in d.addedNodes) _morphChip(context, icon: nodeKindIcon(n.kind), label: n.ref.isEmpty ? n.id : n.ref, tone: c.ok, deco: false),
          for (final id in d.updatedNodes) _morphChip(context, icon: AnIcons.edit, label: id, tone: c.warn, deco: false),
          for (final id in d.deletedNodes) _morphChip(context, icon: AnIcons.trash, label: id, tone: c.danger, deco: true),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: AnSpace.s6),
        child: Text(t.chat.tool.wfMorphNote, style: AnText.meta.copyWith(color: c.inkFaint)),
      ),
      RunStatBar(state: state),
    ],
  );
}

/// A morph change chip: kind/action glyph + label, tinted by tone; [deco]=true strikes the label
/// through (a deleted node — its ref is gone, only the id remains). morph 变更 chip;deco=删除划线。
Widget _morphChip(BuildContext context, {required IconData icon, required String label, required Color tone, required bool deco}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s2),
    decoration: BoxDecoration(
      border: Border.all(color: tone.withValues(alpha: 0.5), width: AnSize.hairline),
      borderRadius: BorderRadius.circular(AnRadius.tag),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: AnSize.iconSm, color: tone),
      const SizedBox(width: AnGap.inlineHair),
      Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AnText.label.copyWith(
              color: tone, decoration: deco ? TextDecoration.lineThrough : null)),
    ]),
  );
}

/// Act two — the settled body: intent · the workflow graph (1:1 with the entity page's AnGraphCanvas) ·
/// the result bar. 幕二 落定体:意图 · 工作流图(与实体页 AnGraphCanvas 1:1)· 结果条。
Widget workflowBuildBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final graph = graphFromWorkflowOps(state.argsSession);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (state.summary.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s6),
          child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted)),
        ),
      if (graph.nodes.isNotEmpty)
        // 1:1 with the entity page's workflow graph (B5): the SAME AnGraphCanvas rendering (node cards,
        // orthogonal edges, kind colours, auto-fit) in a framed preview, just at a compact tool-card height.
        // The build sense lives in act one's op ticker; the settled graph is static like the entity preview.
        // 与实体页 workflow 图 1:1:同款 AnGraphCanvas 渲染(节点卡/正交边/kind 色/auto-fit),framed 预览、卡内紧凑高;
        // 生长感在幕一 op ticker,落定图与实体预览一样静态。
        AnGraphCanvas(graph: graph, framed: true, framedHeight: _graphHeight)
      else if (state.argsText.isNotEmpty)
        ToolWindow(child: Text(state.argsText, style: AnText.code.copyWith(color: c.inkMuted))),
      RunStatBar(state: state),
    ],
  );
}
