import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/contract/entities/function.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/typography.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_callout.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_fade_collapse.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/an_transform_box.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_kind.dart';
import '../../../data/entity_providers.dart';
import '../../../data/entity_format.dart';
import '../../../state/detail/entity_detail_provider.dart';
import '../../../state/selected_entity.dart';
import '../detail_sections.dart';

/// Function 概览。读态:meta(说明 + 标签,手工可编)→ 变换盒 hero(签名即接口)→ 代码(50 行渐隐
/// 收合)→ 环境合卡(envError 直出)。**版本内容(签名/代码/依赖/py)只读、AI-only**(拍板 #4);手工
/// 只编 meta——说明 + 标签走**成熟的 [AnKv] 编辑模式**(与 venv 段同件,hover 铅笔 → 就地文本编辑,失焦
/// 提交),标签按逗号/空白分隔的文本行编辑。均 PATCH 不升版本。
class FunctionOverview extends ConsumerWidget {
  const FunctionOverview({required this.fn, super.key});

  final FunctionEntity fn;

  /// 50 code lines at the code style's line box, plus the editor chrome — the collapse threshold.
  /// 代码样式行盒 × 50 行 + 编辑器 chrome = 收合高度。
  static const double _collapsedCodeHeight = 50 * 12 * 1.6 + 44;

  Future<void> _patchMeta(WidgetRef ref, Map<String, dynamic> patch) async {
    await ref.read(entityRepositoryProvider).patchFunctionMeta(fn.id, patch);
    ref.invalidate(entityDetailProvider(EntityRef(EntityKind.function, fn.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final v = fn.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    final codeLines = '\n'.allMatches(v.code).length + 1;
    final meta = v.dependencies.isEmpty
        ? 'Python ${v.pythonVersion}'
        : 'Python ${v.pythonVersion} · ${d.hero.deps(n: v.dependencies.length)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meta — the ONLY hand-editable surface, edited via the mature AnKv path (PATCH, no version
        // bump). Row order [说明, 标签] is stable (AnKv keys edit state by index). 唯一手编面,走 AnKv;行序稳定。
        AnSection(variant: AnSectionVariant.plain, children: [
          AnKv(
            wrap: true,
            rows: [
              AnKvRow(d.kv.desc, fn.description, editable: true),
              // Tags row: ➕add / ✕remove pills (the mature AnKv tags kind), not text edit. 标签行:+/× 药丸。
              AnKvRow.tags(d.kv.tags, fn.tags, tagsPlaceholder: d.addTag),
            ],
            onChanged: (rows) {
              final desc = rows[0].value ?? '';
              final tags = rows[1].tags ?? const [];
              final patch = <String, dynamic>{};
              if (desc != fn.description) patch['description'] = desc;
              if (!listEquals(tags, fn.tags)) patch['tags'] = tags;
              if (patch.isNotEmpty) _patchMeta(ref, patch);
            },
          ),
        ]),
        AnSection(variant: AnSectionVariant.plain, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
            child: AnTransformBox(
              title: fn.name,
              icon: AnIcons.function,
              inputs: [for (final f in v.inputs) AnTransformField(f.name, f.type)],
              outputs: [for (final f in v.outputs) AnTransformField(f.name, f.type)],
              phase: v.envStatus == 'failed' ? AnTransformPhase.failed : AnTransformPhase.idle,
              status: AnStatus.fromRaw(v.envStatus),
              statusLabel: 'env ${v.envStatus}',
              meta: meta,
              emptyInputsLabel: d.hero.noInputs,
              emptyOutputsLabel: d.hero.noOutputs,
            ),
          ),
        ]),
        AnSection(label: d.sec.code, variant: AnSectionVariant.plain, children: [
          AnFadeCollapse(
            collapsible: codeLines > 50,
            collapsedHeight: _collapsedCodeHeight,
            expandLabel: d.codeToggle.expand(n: codeLines),
            collapseLabel: d.codeToggle.collapse,
            child: AnCodeEditor(code: v.code, lang: 'py', wrap: true),
          ),
        ]),
        AnSection(label: d.sec.env, variant: AnSectionVariant.plain, children: [
          if (v.envError != null && v.envError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s8),
              child: AnCallout(v.envError!, severity: AnCalloutSeverity.danger),
            ),
          AnInfoCard(
            title: d.card.venv,
            icon: AnIcons.byKey('check'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kvList([
                  (d.kv.python, v.pythonVersion),
                  (d.kv.envId, v.envId),
                  (d.kv.status, v.envStatus),
                  (d.kv.syncedAt, fmtTime(v.envSyncedAt)),
                ]),
                const SizedBox(height: AnSpace.s8),
                if (v.dependencies.isEmpty)
                  Text(d.val.none, style: AnText.meta)
                else
                  for (final dep in v.dependencies) AnRow(label: dep, passive: true),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}
