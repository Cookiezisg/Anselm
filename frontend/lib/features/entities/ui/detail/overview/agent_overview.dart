import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/agent.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../detail_sections.dart';

/// Agent 概览:说明 + KV → 提示词(只读)→ 能力挂载(工具/技能/知识/模型覆盖 4 卡)→ 挂载健康 → 输入/输出。
class AgentOverview extends StatelessWidget {
  const AgentOverview({required this.agent, required this.mountHealth, super.key});

  final AgentEntity agent;
  final MountHealthReport? mountHealth;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final v = agent.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    final mo = v.modelOverride;
    final mh = mountHealth;
    final unhealthy = mh?.mounts.where((m) => !m.healthy).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSection(variant: AnSectionVariant.plain, children: [
          if (agent.description.isNotEmpty) AnField(label: d.kv.desc, value: agent.description, wrap: true),
          kvList([
            (d.kv.id, agent.id),
            (d.kv.activeVersion, 'v${v.version}'),
            (d.kv.model, mo != null ? mo.modelId : d.val.modelDefault),
            if (mh != null) (d.sec.mountHealth, mh.allHealthy ? d.mounts.healthy : d.mounts.unhealthy(count: unhealthy)),
          ]),
        ]),
        AnSection(label: d.sec.prompt, variant: AnSectionVariant.plain, children: [
          AnCodeEditor(code: v.prompt, lang: 'md', wrap: true),
        ]),
        AnSection(label: d.sec.capabilities, variant: AnSectionVariant.plain, grid: true, children: [
          AnInfoCard(
            title: d.card.tools,
            icon: AnIcons.byKey('tool'),
            child: v.tools.isEmpty
                ? insetEmpty(d.val.none)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final tr in v.tools)
                        AnRow(icon: AnIcons.byKey(_refKind(tr.ref)), label: tr.name, meta: tr.ref, passive: true),
                    ],
                  ),
          ),
          AnInfoCard(
            title: d.card.skill,
            icon: AnIcons.byKey('skill'),
            child: (v.skill == null || v.skill!.isEmpty)
                ? insetEmpty(d.val.none)
                : kvList([(d.kv.name, v.skill)]),
          ),
          AnInfoCard(
            title: d.card.knowledge,
            icon: AnIcons.byKey('doc'),
            child: v.knowledge.isEmpty
                ? insetEmpty(d.val.none)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final k in v.knowledge) AnRow(icon: AnIcons.byKey('doc'), label: k, passive: true)],
                  ),
          ),
          AnInfoCard(
            title: d.card.model,
            icon: AnIcons.byKey('agent'),
            child: mo == null
                ? insetEmpty(d.val.modelDefault)
                : kvList([
                    (d.kv.model, mo.modelId),
                    for (final o in mo.options.entries) (o.key, o.value),
                  ]),
          ),
        ]),
        if (mh != null && mh.mounts.isNotEmpty)
          AnSection(label: d.sec.mountHealth, variant: AnSectionVariant.plain, children: [
            for (final m in mh.mounts)
              AnRow(
                dot: m.healthy ? AnStatus.done : AnStatus.err,
                label: m.name ?? m.ref,
                meta: m.ref,
                hint: m.healthy ? null : (m.error ?? ''),
                passive: true,
              ),
          ]),
        AnSection(label: d.sec.input, variant: AnSectionVariant.plain, grid: true, children: [
          AnInfoCard(title: d.sec.input, icon: AnIcons.byKey('enter'), child: fieldList(v.inputs, emptyTitle: d.val.none)),
          AnInfoCard(title: d.sec.output, icon: AnIcons.byKey('run'), child: fieldList(v.outputs, emptyTitle: d.val.none)),
        ]),
      ],
    );
  }

  String _refKind(String ref) {
    if (ref.startsWith('fn_')) return 'function';
    if (ref.startsWith('hd_')) return 'handler';
    if (ref.startsWith('mcp:')) return 'mcp';
    return 'tool';
  }
}
