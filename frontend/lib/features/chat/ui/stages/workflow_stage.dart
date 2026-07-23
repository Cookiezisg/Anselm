import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/model/partial_json.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/stage_truth.dart';
import '../tool_card_skins.dart';
import '../tool_card_workflow.dart';
import 'stage_frame.dart';
import 'stage_scene.dart';

/// The WORKFLOW stage (WRK-061 §7-4, W3 · G10) — the graph grows on a real canvas as ops close. An
/// EDIT rests on the old truth first (R-5, the frozen G9 baseline) and its ops REPLAY ONTO that
/// graph (add/update/delete node+edge — the old code swapped to an ops-only island, so «add one
/// node to a ten-node workflow» collapsed the canvas to a single orphan, A3-14). The stratum ink +
/// «基于 vN 起改» are LIVE-only (a settled update-edit used to keep the 40% ghost forever, A3-15);
/// a settled edit reconciles its canvas from the FRESH truth (the G9 invalidation guarantees it).
/// The LATEST DISCRIMINANT drawer shows the newest node's `input` CELs through [AnCelGrow].
///
/// workflow 舞台(W3·G10)——图随 ops 闭合在真画布生长。edit 先静置旧真相(R-5,G9 冻结基线),ops
/// **重放在旧图上**(增/改/删节点与边——旧代码整图换成孤岛,「十节点加一个」塌成单点,A3-14);地层墨
/// 与「基于 vN」仅 live(旧落定 update-edit 永挂 40% 幽灵,A3-15);落定 edit 画布对账**新鲜真相**
/// (G9 失效保证其新)。「最新判别式」抽屉以 AnCelGrow 渲最新节点 input CEL。
class WorkflowStageBody extends ConsumerWidget {
  const WorkflowStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final editId = scene.editTargetId;
    final truth = editId == null
        ? null
        : ref.watch(
            workflowBaselineProvider((id: editId, block: scene.node.id)),
          );
    final oldGraph = truth?.asData?.value.activeVersion?.graphParsed;
    final oldVersion = truth?.asData?.value.activeVersion?.version;

    final opsGraph = graphFromWorkflowOps(session);
    final hasOps = _hasAnyOp(session);
    // Settled EDITS reconcile from the FRESH truth (G9 invalidated it at the terminal). 落定对账新真相。
    final fresh = (!scene.live && editId != null)
        ? ref.watch(workflowTruthProvider(editId))
        : null;
    final freshGraph = fresh?.asData?.value.activeVersion?.graphParsed;
    // Live: an edit's ops replay ONTO the old truth (never an ops-only island); a create grows from
    // the void. Settled: edit=reconciled truth, create=its own ops. live:edit ops 重放旧图上/create
    // 从虚空长;落定:edit=对账真相、create=自身 ops。
    final Graph? graph;
    if (scene.live) {
      graph = oldGraph != null && hasOps
          ? _applyOps(oldGraph, session)
          : (hasOps ? opsGraph : oldGraph);
    } else {
      graph = editId != null ? (freshGraph ?? oldGraph) : opsGraph;
    }
    final showsOld = scene.live && !hasOps && oldGraph != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (graph != null &&
            (graph.nodes.isNotEmpty || graph.edges.isNotEmpty)) ...[
          // 假想框律:计数句(裸文字)归假想框(X=8);真画布(framed 图)贴 X=0。The imaginary-frame law:
          // the count line (bare text) joins the frame (X=8); the real canvas (a framed graph) stays at X=0.
          stageFramed(
            Row(
              children: [
                Text(
                  t.chat.tool.wfGraphCounts(
                    nodes: graph.nodes.length,
                    edges: graph.edges.length,
                  ),
                  style: AnText.meta.copyWith(color: c.inkMuted),
                ),
                if (showsOld && oldVersion != null) ...[
                  const SizedBox(width: AnSpace.s8),
                  Text(
                    t.chat.stage.basedOn(n: oldVersion),
                    style: AnText.meta.copyWith(color: c.inkFaint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AnSpace.s4),
          Opacity(
            // The resting old truth reads as the stratum (R-5) — full ink returns with the first op.
            // 静置旧图=地层(R-5);首 op 后回全墨。
            opacity: showsOld ? AnOpacity.stratum : 1,
            child: AnGraphCanvas(
              graph: graph,
              framed: true,
              framedHeight: AnSize.graphStage,
              toolbar: false,
            ),
          ),
        ],
        ..._discriminantDrawer(context, c, t, session),
        if (!scene.live && !scene.failed) ...[
          const SizedBox(height: AnSpace.s6),
          runStatBarOf(context, scene.state),
        ],
      ],
    );
  }

  /// ANY completed op counts as «the edit started» — update/delete ops never fed the add-only
  /// graph builder, so an update-only edit read as «no ops yet» forever. 任何闭合 op 都算开工:
  /// update/delete 不进只加图,旧判据让 update-only 编辑恒「未开工」。
  bool _hasAnyOp(PartialJsonSession session) =>
      session.arrayItemsAt(['ops']).whereType<Map>().isNotEmpty;

  /// G10/A3-14 — replay the edit's completed ops ONTO the baseline graph (REAL wire shapes:
  /// add_node `node{…}` / update_node `id`+`patch` / delete_node `id` / add_edge `edge{…}` /
  /// delete_edge `id`, backend domain/workflow/ops.go). Deleting a node drops its touching edges,
  /// mirroring the backend apply. 把闭合 ops 重放在基线图上(真线缆形);删节点连带删其边,镜像后端。
  Graph _applyOps(Graph base, PartialJsonSession session) {
    final nodes = <String, Node>{for (final n in base.nodes) n.id: n};
    final edges = <String, Edge>{for (final e in base.edges) e.id: e};
    for (final raw in session.arrayItemsAt(['ops'])) {
      if (raw is! Map) continue;
      switch (raw['op']) {
        case 'add_node':
          final n = raw['node'];
          if (n is Map && n['id'] is String) {
            nodes[n['id'] as String] = Node(
              id: n['id'] as String,
              kind: workflowNodeKind(n['kind']),
              ref: (n['ref'] ?? '').toString(),
            );
          }
        case 'update_node':
          final id = raw['id'];
          final patch = raw['patch'];
          final cur = id is String ? nodes[id] : null;
          if (cur != null && patch is Map) {
            nodes[id as String] = cur.copyWith(
              kind: patch['kind'] == null
                  ? cur.kind
                  : workflowNodeKind(patch['kind']),
              ref: patch['ref'] is String ? patch['ref'] as String : cur.ref,
            );
          }
        case 'delete_node':
          final id = raw['id'];
          if (id is String) {
            nodes.remove(id);
            edges.removeWhere((_, e) => e.from == id || e.to == id);
          }
        case 'add_edge':
          final e = raw['edge'];
          if (e is Map &&
              e['id'] is String &&
              e['from'] is String &&
              e['to'] is String) {
            edges[e['id'] as String] = Edge(
              id: e['id'] as String,
              from: e['from'] as String,
              to: e['to'] as String,
              fromPort: e['fromPort'] as String?,
            );
          }
        case 'delete_edge':
          final id = raw['id'];
          if (id is String) edges.remove(id);
      }
    }
    return Graph(
      nodes: nodes.values.toList(growable: false),
      edges: edges.values.toList(growable: false),
    );
  }

  // The newest node carrying `input` CELs — each entry grows as an [AnCelGrow] line. 最新判别式抽屉。
  List<Widget> _discriminantDrawer(
    BuildContext context,
    AnColors c,
    Translations t,
    dynamic session,
  ) {
    final ops = session.arrayItemsAt(['ops']) as List<Object?>;
    Map<Object?, Object?>? latest;
    for (var i = ops.length - 1; i >= 0; i--) {
      final raw = ops[i];
      if (raw is Map &&
          (raw['op'] == 'add_node' || raw['op'] == 'update_node')) {
        // REAL wire shapes (G8/A3-16): add_node carries `node:{id,…,input}`; update_node carries
        // top-level `id` + an RFC-7396 `patch`, of which only `patch.input` is discriminant
        // material — rendering other patch fields here forged fake discriminants («ref ← trg_b»)
        // and the old `nodeId` key never existed, so the title was always blank.
        // 真线缆形:add_node=node{…};update_node=顶层 id+patch,仅 patch.input 配进判别式抽屉
        // (其余 patch 字段渲进来即伪造判别式;旧 nodeId 键不存在,标题恒空)。
        final node = raw['node'];
        final patch = raw['patch'];
        final input = node is Map
            ? node['input']
            : (patch is Map ? patch['input'] : null);
        if (input is Map && input.isNotEmpty) {
          latest = {'id': node is Map ? node['id'] : raw['id'], 'input': input};
          break;
        }
      }
    }
    if (latest == null) return const [];
    final input = latest['input'] as Map;
    // 假想框律:判别式抽屉的裸字(标题 + emit 行)归假想框(X=8),与计数句同一条框线。The imaginary-frame
    // law: the discriminant drawer's bare text (title + emit rows) joins the frame (X=8), on the count line.
    return [
      const SizedBox(height: AnSpace.s6),
      stageFramed(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${t.chat.stage.latestDiscriminant} · ${latest['id'] ?? ''}',
              style: AnText.label.copyWith(color: c.inkFaint),
            ),
            const SizedBox(height: AnSpace.s2),
            for (final e in input.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AnSpace.s2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.key} ← ',
                      style: AnText.code.copyWith(color: c.inkFaint),
                    ),
                    Expanded(
                      child: AnCelGrow(
                        expression: '${e.value}',
                        live: scene.live,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
