import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/workflow.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_button.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/an_thin_table.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';
import '../detail_sections.dart';

/// Workflow 概览:说明 + KV → 运行治理(生命周期/并发)→ 告警 → 编排图(只读 stub:节点/边表 + 禁用「进入图编辑器」)。
/// 图为只读表(WRK-046 锁定,无交互画布)。
class WorkflowOverview extends StatelessWidget {
  const WorkflowOverview({required this.wf, super.key});

  final WorkflowEntity wf;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final v = wf.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    final g = graphOf(v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSection(variant: AnSectionVariant.plain, children: [
          if (wf.description.isNotEmpty) AnField(label: d.kv.desc, value: wf.description, wrap: true),
          kvList([
            (d.kv.id, wf.id),
            (d.kv.currentVersion, 'v${v.version}'),
            if (g != null) (d.kv.nodes, '${g.nodes.length} · ${d.graph.edges} ${g.edges.length}'),
            (d.kv.lifecycle, wf.lifecycleState),
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
        AnSection(label: d.sec.graph, variant: AnSectionVariant.plain, children: [
          if (g == null)
            insetEmpty(d.state.errorTitle)
          else ...[
            AnThinTable(
              columns: [
                AnTableColumn('id', label: d.graph.nodes),
                AnTableColumn('kind'),
                AnTableColumn('ref'),
              ],
              rows: [
                for (final n in g.nodes) {'id': n.id, 'kind': n.kind.name, 'ref': n.ref},
              ],
            ),
            AnThinTable(
              columns: [
                AnTableColumn('id', label: d.graph.edges),
                AnTableColumn('path', label: d.graph.path),
              ],
              rows: [
                for (final e in g.edges)
                  {'id': e.id, 'path': '${e.from}→${e.to}${e.fromPort != null ? ' [${e.fromPort}]' : ''}'},
              ],
            ),
          ],
          AnButton(label: d.graph.openEditor, onPressed: null), // STEP: graph editor (coming soon)
        ]),
      ],
    );
  }
}
