import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/contract/entities/workflow.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/graph/graph_run_state.dart';
import '../../../../../core/ui/an_graph_canvas.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';
import '../../../data/entity_kind.dart';
import '../../../data/entity_providers.dart';
import '../../../state/detail/entity_detail_provider.dart';
import '../../../state/run/run_terminal_controller.dart';
import '../../../state/selected_entity.dart';
import '../detail_sections.dart';

/// Workflow 概览(WRK-055 W2)。**编排图 hero 置顶**(拍板 #2:workflow 的本质就是那张图,与 function
/// 变换盒 hero 同构)→ meta(说明 + 标签,成熟 [AnKv] 编辑模式,PATCH 不升版;图内容 = 版本内容,
/// 手工编辑走 W5 编辑器)→ 运行治理合卡 → 告警。运行活态(taken/彗星)在 W3 接入。
class WorkflowOverview extends ConsumerWidget {
  const WorkflowOverview({required this.wf, super.key});

  final WorkflowEntity wf;

  Future<void> _patchMeta(WidgetRef ref, Map<String, dynamic> patch) async {
    await ref.read(entityRepositoryProvider).patchWorkflowMeta(wf.id, patch);
    ref.invalidate(entityDetailProvider(EntityRef(EntityKind.workflow, wf.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final v = wf.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    final g = graphOf(v);

    // Hero live overlay — the SAME run-terminal state the right island operates on (页 hero=仪表盘、
    // 右岛=操作台,同源两视角): once a run was triggered, its rows/ticks light the graph; before the
    // first reconcile lands the header status is still empty, so an in-flight phase reads as running
    // (synthesis on). No run yet → pure definition view.
    // hero 活态覆层:与右岛同一份 run 态;触发过即点亮,首个对账未落时按 running 合成;未跑=纯定义。
    final run = ref.watch(runTerminalProvider(EntityRef(EntityKind.workflow, wf.id)));
    final overlay = (g == null || run.flowrunId == null || run.flowNodes.isEmpty)
        ? null
        : deriveRunState(g,
            rows: run.flowNodes,
            runStatus: run.flowrunStatus.isEmpty && run.isRunning ? 'running' : run.flowrunStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ① The graph IS the workflow — first screenful, framed preview (auto-fit; zoom toolbar).
        // The enter-editor affordance arrives with the editor route (W5). ① 图即 workflow:第一屏
        // framed 预览;「进入编辑器」随 W5 编辑器路由接入。
        AnSection(variant: AnSectionVariant.plain, children: [
          if (g == null)
            insetEmpty(d.graph.unparseable) // bad blob — honest, not blank 坏 blob 诚实呈现
          else
            AnGraphCanvas(graph: g, framed: true, run: overlay),
        ]),
        // ② Meta — the hand-editable surface (same mature AnKv path as function; PATCH, no bump).
        // Row order [说明, 标签] is stable (AnKv keys edit state by index). ② meta 手编面,行序稳定。
        AnSection(variant: AnSectionVariant.plain, children: [
          AnKv(
            rows: [
              AnKvRow(d.kv.desc, wf.description, editable: true),
              AnKvRow.tags(d.kv.tags, wf.tags, tagsPlaceholder: d.addTag),
            ],
            onChanged: (rows) {
              final desc = rows[0].value ?? '';
              final tags = rows[1].tags ?? const [];
              final patch = <String, dynamic>{};
              if (desc != wf.description) patch['description'] = desc;
              if (!listEquals(tags, wf.tags)) patch['tags'] = tags;
              if (patch.isNotEmpty) _patchMeta(ref, patch);
            },
          ),
          kvList([
            (d.kv.id, wf.id),
            (d.kv.currentVersion, 'v${v.version}'),
            if (g != null) (d.kv.nodes, '${g.nodes.length} · ${d.graph.edges} ${g.edges.length}'),
          ]),
        ]),
        AnSection(label: d.sec.governance, variant: AnSectionVariant.plain, grid: true, children: [
          AnInfoCard(
            title: d.card.lifecycle,
            icon: AnIcons.byKey('scheduler'),
            child: kvList([
              (d.kv.status, wf.lifecycleState),
              (d.kv.active, wf.active ? d.val.listening : d.val.stopped),
              (d.kv.lastAction, wf.lastActionBy),
            ]),
          ),
          AnInfoCard(
            title: d.card.concurrency,
            icon: AnIcons.byKey('workflow'),
            child: kvList([(d.kv.concurrency, wf.concurrency)]),
          ),
        ]),
        AnSection(label: d.sec.alerts, variant: AnSectionVariant.plain, children: [
          AnRow(
            icon: AnIcons.byKey(wf.needsAttention ? 'error' : 'check'),
            dot: wf.needsAttention ? AnStatus.err : AnStatus.done,
            label: wf.needsAttention ? (wf.attentionReason ?? d.val.needsAttention) : d.val.noAlerts,
            passive: true,
          ),
        ]),
      ],
    );
  }
}
