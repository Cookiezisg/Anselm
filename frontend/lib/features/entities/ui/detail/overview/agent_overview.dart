import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/agent.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../detail_sections.dart';

/// Agent 概览:说明 + KV → 提示词(只读)→ 能力挂载(工具/技能/知识/模型覆盖 4 卡)→ 挂载健康 → 输入/输出。
class AgentOverview extends StatelessWidget {
  const AgentOverview({
    required this.agent,
    required this.mountHealth,
    super.key,
  });

  final AgentEntity agent;
  final MountHealthReport? mountHealth;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final v = agent.activeVersion;
    if (v == null) return noVersionGuide(context);
    final mo = v.modelOverride;
    final mh = mountHealth;
    final unhealthy = mh?.mounts.where((m) => !m.healthy).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identity keeps pure metadata only — the Model row was a verbatim dupe of the Model
        // card below rendered at the OTHER tier (13 vs 15 for one datum on one page).
        // 身份段只留纯元数据——Model 行与下方 Model 卡同数据异档(同页一数据两档),删重复。
        identitySection(d.kv.desc, agent.description, [
          (d.kv.id, agent.id),
          (d.kv.activeVersion, 'v${v.version}'),
          if (mh != null)
            (
              d.sec.mountHealth,
              mh.allHealthy
                  ? d.mounts.healthy
                  : d.mounts.unhealthy(count: unhealthy),
            ),
        ]),
        AnSection(
          label: d.sec.prompt,
          variant: AnSectionVariant.plain,
          children: [
            AnCodeEditor(code: v.prompt, lang: 'md', wrap: true, reading: true),
          ],
        ),
        AnSection(
          label: d.sec.capabilities,
          variant: AnSectionVariant.plain,
          grid: true,
          children: [
            AnInfoCard(
              title: d.card.tools,
              icon: AnIcons.byKey('tool'),
              // The wrapper (Column) stays mounted either way — only its `children` list flips
              // (WRK-077 ⑫: a bare dash row, same AnRow grammar as the populated rows, replaces
              // the old inbox-icon tombstone). 包装层恒挂,只翻 children;空表用同一套 AnRow 文法。
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: v.tools.isEmpty
                    ? [AnRow(label: d.val.none, passive: true)]
                    : [
                        for (final tr in v.tools)
                          AnRow(
                            icon: AnIcons.byKey(_refKind(tr.ref)),
                            label: tr.name,
                            meta: tr.ref,
                            passive: true,
                          ),
                      ],
              ),
            ),
            AnInfoCard(
              title: d.card.skill,
              icon: AnIcons.byKey('skill'),
              child: kvList([
                (
                  d.kv.name,
                  (v.skill == null || v.skill!.isEmpty) ? d.val.none : v.skill,
                ),
              ]),
            ),
            AnInfoCard(
              title: d.card.knowledge,
              icon: AnIcons.byKey('doc'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: v.knowledge.isEmpty
                    ? [AnRow(label: d.val.none, passive: true)]
                    : [
                        for (final k in v.knowledge)
                          AnRow(
                            icon: AnIcons.byKey('doc'),
                            label: k,
                            passive: true,
                          ),
                      ],
              ),
            ),
            AnInfoCard(
              title: d.card.model,
              icon: AnIcons.byKey('agent'),
              // mo == null → this agent INHERITS the workspace default (not "empty" — WRK-077 ⑫
              // fixed a mis-rendered tombstone here). Same AnKv row grammar either way; `meta: true`
              // rides the existing chrome-13 value tier as the weak "inherited" cue (no new
              // primitive). mo==null=继承工作区默认(非空,此前误渲墓碑);仍同一套 AnKv 行文法,
              // meta:true 借既有 chrome 13 档权充「弱继承」标记,不新造件。
              child: mo == null
                  ? kvList([(d.kv.model, d.val.modelDefault)], meta: true)
                  : kvList([
                      (d.kv.model, mo.modelId),
                      for (final o in mo.options.entries) (o.key, o.value),
                    ]),
            ),
          ],
        ),
        if (mh != null && mh.mounts.isNotEmpty)
          AnSection(
            label: d.sec.mountHealth,
            variant: AnSectionVariant.plain,
            children: [
              for (final m in mh.mounts)
                AnRow(
                  dot: m.healthy ? AnStatus.done : AnStatus.err,
                  label: m.name ?? m.ref,
                  meta: m.ref,
                  hint: m.healthy ? null : (m.error ?? ''),
                  passive: true,
                ),
            ],
          ),
        AnSection(
          label: d.sec.input,
          variant: AnSectionVariant.plain,
          grid: true,
          children: [
            AnInfoCard(
              title: d.sec.input,
              icon: AnIcons.byKey('enter'),
              child: fieldList(v.inputs, emptyLabel: d.sec.input),
            ),
            AnInfoCard(
              title: d.sec.output,
              icon: AnIcons.byKey('run'),
              child: fieldList(v.outputs, emptyLabel: d.sec.output),
            ),
          ],
        ),
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
