import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/contract/api_error.dart';
import '../../../../../core/contract/entities/handler.dart';
import '../../../../../core/contract/entities/values.dart';
import '../../../../../core/design/tokens.dart';
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
import '../../../data/entity_format.dart';
import '../../../data/entity_providers.dart';
import '../../../state/detail/entity_detail_provider.dart';
import '../../../state/selected_entity.dart';
import '../detail_sections.dart';
import 'environment_failure.dart';

/// Handler 概览:说明 + KV → 常驻状态(运行时/配置完整度)→ 环境失败摘要/技术详情 → init 参数(敏感默认遮蔽)
/// → 方法 + 类代码(只读)。
class HandlerOverview extends ConsumerWidget {
  const HandlerOverview({required this.hd, super.key});

  final HandlerEntity hd;

  Future<void> _patchMeta(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> patch,
  ) async {
    try {
      await ref.read(entityRepositoryProvider).patchHandlerMeta(hd.id, patch);
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
        entityDetailProvider(EntityRef(EntityKind.handler, hd.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final v = hd.activeVersion;
    if (v == null) return noVersionGuide(context);

    // Sensitive defaults are NEVER rendered. 敏感默认值绝不渲染。
    String argSummary(InitArgSpec a) => [
      a.type,
      a.required ? d.val.required : d.val.optional,
      if (a.sensitive) d.val.sensitive,
      if (!a.sensitive && a.defaultValue != null)
        '${d.val.defaultPrefix} ${a.defaultValue}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meta is the only hand-editable surface; class content stays AI-only and PATCH never bumps
        // the active version or restarts the resident instance. meta 是唯一手编面;类内容仍 AI-only,
        // PATCH 不升版本、不重启常驻实例。
        AnSection(
          variant: AnSectionVariant.plain,
          children: [
            AnKv(
              rows: [
                AnKvRow(d.kv.desc, hd.description, editable: true),
                AnKvRow.tags(d.kv.tags, hd.tags, tagsPlaceholder: d.addTag),
              ],
              onChanged: (rows) {
                final description = rows[0].value ?? '';
                final tags = rows[1].tags ?? const [];
                final patch = <String, dynamic>{};
                if (description != hd.description) {
                  patch['description'] = description;
                }
                if (!listEquals(tags, hd.tags)) patch['tags'] = tags;
                if (patch.isNotEmpty) _patchMeta(context, ref, patch);
              },
            ),
            kvList([
              (d.kv.id, hd.id),
              (d.kv.activeVersion, 'v${v.version}'),
              (d.kv.python, v.pythonVersion),
              (d.kv.updated, fmtTime(hd.updatedAt)),
            ], meta: true),
          ],
        ),
        AnSection(
          label: d.sec.runtime,
          variant: AnSectionVariant.plain,
          grid: true,
          children: [
            AnInfoCard(
              title: d.card.runtime,
              icon: AnIcons.byKey('handler'),
              child: kvList([(d.kv.status, hd.runtimeState ?? '—')]),
            ),
            AnInfoCard(
              title: d.card.config,
              icon: AnIcons.byKey('check'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  kvList([(d.kv.status, hd.configState ?? '—')]),
                  for (final m in hd.missingConfig)
                    AnRow(label: m, dot: AnStatus.wait, passive: true),
                ],
              ),
            ),
          ],
        ),
        AnSection(
          label: d.sec.env,
          variant: AnSectionVariant.plain,
          children: [
            if (v.envError != null && v.envError!.isNotEmpty)
              EnvironmentFailure(error: v.envError!),
            AnInfoCard(
              title: d.card.venv,
              icon: AnIcons.byKey('check'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  kvList([(d.kv.status, v.envStatus)]),
                  kvList([
                    (d.kv.python, v.pythonVersion),
                    (d.kv.envId, v.envId),
                    (d.kv.syncedAt, fmtTime(v.envSyncedAt)),
                  ], meta: true),
                  const SizedBox(height: AnSpace.s8),
                  AnKv(rows: [AnKvRow.tags(d.card.deps, v.dependencies)]),
                ],
              ),
            ),
          ],
        ),
        AnSection(
          label: d.sec.initArgs,
          variant: AnSectionVariant.plain,
          children: [
            if (v.initArgsSchema.isEmpty)
              // Same AnKv grammar as the populated case — one row, dash value, section's own
              // label (WRK-077 ⑫ — retired the inbox-icon tombstone). 同一套 AnKv 文法,不再起空态。
              kvList([(d.sec.initArgs, d.val.none)])
            else
              kvList([
                for (final a in v.initArgsSchema) (a.name, argSummary(a)),
              ], wrap: true),
          ],
        ),
        AnSection(
          label: d.sec.methods,
          variant: AnSectionVariant.plain,
          children: [
            for (final m in v.methods)
              AnRow(
                icon: AnIcons.byKey('tool'),
                label: m.name,
                meta: '${m.inputs.length}→${m.outputs.length}',
                hint: m.streaming
                    ? d.val.generator
                    : (m.timeout != null
                          ? d.val.timeoutMs(ms: m.timeout!)
                          : null),
                passive: true,
              ),
            AnCodeEditor(
              code: handlerSourceOf(v),
              lang: 'py',
              wrap: true,
              reading: true,
            ),
          ],
        ),
      ],
    );
  }
}
