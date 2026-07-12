import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/stage_truth.dart';
import '../tool_card_skins.dart';
import '../tool_card_workflow.dart';
import 'stage_scene.dart';

/// The WORKFLOW stage (WRK-061 §7-4, W3) — the graph grows on a real canvas as ops close: add_node
/// lands a node, add_edge draws the wire (only COMPLETED ops surface — the session's array facade),
/// node/edge counters roll, and the LATEST DISCRIMINANT drawer shows the newest node's `input` CELs
/// through [AnCelGrow] (data inlets as accent capsules). An EDIT rests on the old truth first (R-5):
/// before any op closes, the CURRENT graph sits on the canvas with a «基于 vN 起改» word — the change
/// then grows over it. Settle: counts + the result bar + the lifecycle badge from the reconciled GET.
///
/// workflow 舞台(W3)——图在真画布上随 ops 闭合生长:add_node 落点/add_edge 画线(只有闭合 op 上台),
/// 节点/边计数滚动,「最新判别式」抽屉以 AnCelGrow 渲最新节点的 input CEL。edit 先静置旧真相(R-5):
/// 首 op 闭合前画布上是现图+「基于 vN 起改」;改动长在其上。落定:计数+结果条+生命周期徽(对账 GET)。
class WorkflowStageBody extends ConsumerWidget {
  const WorkflowStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final editId = scene.editTargetId;
    final truth = editId == null ? null : ref.watch(workflowTruthProvider(editId));
    final oldGraph = truth?.asData?.value.activeVersion?.graphParsed;
    final oldVersion = truth?.asData?.value.activeVersion?.version;

    final opsGraph = graphFromWorkflowOps(session);
    final hasOps = opsGraph.nodes.isNotEmpty || opsGraph.edges.isNotEmpty;
    // The edit rests on the old truth until the first op closes; a create grows from the void.
    // edit 静置旧图直到首 op 闭合;create 从虚空长起。
    final graph = hasOps ? opsGraph : oldGraph;
    final showsOld = !hasOps && oldGraph != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (graph != null && (graph.nodes.isNotEmpty || graph.edges.isNotEmpty)) ...[
        Row(children: [
          Text(t.chat.tool.wfGraphCounts(nodes: graph.nodes.length, edges: graph.edges.length),
              style: AnText.meta.copyWith(color: c.inkMuted)),
          if (showsOld && oldVersion != null) ...[
            const SizedBox(width: AnSpace.s8),
            Text(t.chat.stage.basedOn(n: oldVersion), style: AnText.meta.copyWith(color: c.inkFaint)),
          ],
        ]),
        const SizedBox(height: AnSpace.s4),
        Opacity(
          // The resting old truth reads as the stratum (R-5) — full ink returns with the first op.
          // 静置旧图=地层(R-5);首 op 后回全墨。
          opacity: showsOld ? 0.55 : 1,
          child: AnGraphCanvas(graph: graph, framed: true, framedHeight: 190, toolbar: false),
        ),
      ],
      ..._discriminantDrawer(context, c, t, session),
      if (!scene.live && !scene.failed) ...[
        const SizedBox(height: AnSpace.s6),
        runStatBarOf(context, scene.state),
      ],
    ]);
  }

  // The newest node carrying `input` CELs — each entry grows as an [AnCelGrow] line. 最新判别式抽屉。
  List<Widget> _discriminantDrawer(BuildContext context, AnColors c, Translations t, dynamic session) {
    final ops = session.arrayItemsAt(['ops']) as List<Object?>;
    Map<Object?, Object?>? latest;
    for (var i = ops.length - 1; i >= 0; i--) {
      final raw = ops[i];
      if (raw is Map && (raw['op'] == 'add_node' || raw['op'] == 'update_node')) {
        final node = raw['node'];
        final input = node is Map ? node['input'] : (raw['input'] ?? raw['patch']);
        if (input is Map && input.isNotEmpty) {
          latest = {'id': node is Map ? node['id'] : raw['nodeId'], 'input': input};
          break;
        }
      }
    }
    if (latest == null) return const [];
    final input = latest['input'] as Map;
    return [
      const SizedBox(height: AnSpace.s6),
      Text('${t.chat.stage.latestDiscriminant} · ${latest['id'] ?? ''}',
          style: AnText.label.copyWith(color: c.inkFaint)),
      const SizedBox(height: AnSpace.s2),
      for (final e in input.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e.key} ← ', style: AnText.code.copyWith(color: c.inkFaint)),
            Expanded(child: AnCelGrow(expression: '${e.value}', live: scene.live)),
          ]),
        ),
    ];
  }
}
