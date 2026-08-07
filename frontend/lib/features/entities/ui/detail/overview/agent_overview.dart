import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/contract/api_error.dart';
import '../../../../../core/contract/entities/agent.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/notice/notice_center.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_kv.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_kind.dart';
import '../../../data/entity_providers.dart';
import '../../../state/detail/entity_detail_provider.dart';
import '../../../state/selected_entity.dart';
import '../detail_sections.dart';

/// Agent 概览:可编辑 meta → 提示词(只读)→ 能力挂载(工具/技能/知识/模型覆盖 4 卡)→ 挂载健康 → 输入/输出。
class AgentOverview extends ConsumerWidget {
  const AgentOverview({
    required this.agent,
    required this.mountHealth,
    super.key,
  });

  final AgentEntity agent;
  final MountHealthReport? mountHealth;

  Future<void> _patchMeta(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> patch,
  ) async {
    try {
      await ref.read(entityRepositoryProvider).patchAgentMeta(agent.id, patch);
    } catch (error) {
      if (context.mounted) {
        final message = error is ApiException
            ? context.t.entities.detail.state.metaSaveFailed(
                message: error.message,
              )
            : context.t.entities.detail.state.metaSaveFailed(
                message: context.t.entities.rail.actionFailed,
              );
        ref
            .read(noticeCenterProvider.notifier)
            .show(message, tone: AnTone.danger);
      }
    } finally {
      // Re-read canonical metadata after both outcomes: a failed optimistic editor must never leave
      // a stale local row looking authoritative. 成败都重读后端真相,不让本地乐观行冒充落盘。
      ref.invalidate(
        entityDetailProvider(EntityRef(EntityKind.agent, agent.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final v = agent.activeVersion;
    if (v == null) return noVersionGuide(context);
    final mo = v.modelOverride;
    final mh = mountHealth;
    final unhealthy = mh?.mounts.where((m) => !m.healthy).length ?? 0;
    final knowledgeNames = <String, String>{
      for (final m in mh?.mounts ?? const <MountHealth>[])
        if (v.knowledge.contains(m.ref) &&
            m.name != null &&
            m.name!.trim().isNotEmpty)
          m.ref: m.name!,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Metadata is the only hand-editable surface; version content stays read-only and PATCH
        // never bumps the active version. meta 是唯一手编面;版本内容仍只读,PATCH 不升 active version。
        AnSection(
          variant: AnSectionVariant.plain,
          children: [
            AnKv(
              rows: [
                AnKvRow(d.kv.desc, agent.description, editable: true),
                AnKvRow.tags(d.kv.tags, agent.tags, tagsPlaceholder: d.addTag),
              ],
              onChanged: (rows) {
                final description = rows[0].value ?? '';
                final tags = rows[1].tags ?? const [];
                final patch = <String, dynamic>{};
                if (description != agent.description) {
                  patch['description'] = description;
                }
                if (!listEquals(tags, agent.tags)) patch['tags'] = tags;
                if (patch.isNotEmpty) _patchMeta(context, ref, patch);
              },
            ),
            kvList([
              (d.kv.id, agent.id),
              (d.kv.activeVersion, 'v${v.version}'),
              if (mh != null)
                (
                  d.sec.mountHealth,
                  mh.allHealthy
                      ? d.mounts.healthy
                      : d.mounts.unhealthy(count: unhealthy),
                ),
            ], meta: true),
          ],
        ),
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
                            label: knowledgeNames[k] ?? k,
                            meta: knowledgeNames.containsKey(k) ? k : null,
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

  /// Ref scheme → glyph, one case per BOUND-TOOL scheme the backend's mount resolver knows
  /// (`fn_` / `hd_` / `mcp:` / `sys:`). The fourth is a CAPABILITY tool (`sys:generate_image` …,
  /// WRK-082 P14): it deserves its own glyph because it is the one mount whose target is not a
  /// user's own entity — reading it as a plain `tool` row hides that this agent can produce media.
  ///
  /// ref 词法 → 字形,后端挂载解析器认识的每种**绑定工具**词法一格(`fn_`/`hd_`/`mcp:`/`sys:`)。
  /// 第四种是**能力**工具(`sys:generate_image` 等,批B' P14):它该有自己的字形,因为它是唯一目标不是
  /// 用户自己实体的挂载——渲成普通 `tool` 行会把「这个 agent 能产媒体」这件事藏起来。
  String _refKind(String ref) {
    if (ref.startsWith('fn_')) return 'function';
    if (ref.startsWith('hd_')) return 'handler';
    if (ref.startsWith('mcp:')) return 'mcp';
    if (ref.startsWith('sys:')) return 'capability';
    return 'tool';
  }
}
