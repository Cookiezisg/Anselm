import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/contract/entities/function.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/ui/an_callout.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_fade_collapse.dart';
import '../../../../../core/ui/an_kv.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_section.dart';
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

  /// Code longer than this many lines gets a fade-collapse (the single threshold source). 超此行数收合(阈值单源)。
  static const int _maxCollapsedLines = 50;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meta — the ONLY hand-editable surface, edited via the mature AnKv path (PATCH, no version
        // bump). Row order [说明, 标签] is stable (AnKv keys edit state by index). 唯一手编面,走 AnKv;行序稳定。
        AnSection(
          variant: AnSectionVariant.plain,
          children: [
            AnKv(
              rows: [
                AnKvRow(d.kv.desc, fn.description, editable: true),
                // Tags row: hover → per-pill ✕ + far-right ➕; press ➕ → the add input appears. 标签行:➕→输入框。
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
          ],
        ),
        AnSection(
          label: d.sec.code,
          variant: AnSectionVariant.plain,
          children: [
            AnFadeCollapse(
              collapsible: codeLines > _maxCollapsedLines,
              // Geometry from the family head (B-002); `reading` matches the child editor below.
              // 几何归族头(B-002);reading 与下方子件同档。
              collapsedHeight: AnCodeEditor.collapsedHeightFor(
                _maxCollapsedLines,
                reading: true,
              ),
              expandLabel: d.codeToggle.expand(n: codeLines),
              collapseLabel: d.codeToggle.collapse,
              child: AnCodeEditor(
                code: v.code,
                lang: 'py',
                wrap: true,
                reading: true,
              ),
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
              child: fieldList(v.inputs, emptyTitle: d.val.none),
            ),
            AnInfoCard(
              title: d.sec.output,
              icon: AnIcons.byKey('run'),
              child: fieldList(v.outputs, emptyTitle: d.val.none),
            ),
          ],
        ),
        AnSection(
          label: d.sec.env,
          variant: AnSectionVariant.plain,
          children: [
            // Bare child — AnSection owns the inter-block gap (children never self-margin). 间距归容器。
            if (v.envError != null && v.envError!.isNotEmpty)
              AnCallout(v.envError!, severity: AnCalloutSeverity.danger),
            AnInfoCard(
              title: d.card.venv,
              icon: AnIcons.byKey('check'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status word = content (15, cross-kind consistency); version/id/timestamp = meta.
                  // 状态词=内容 15(跨类一致);版本/id/时间戳=元数据 13。
                  kvList([(d.kv.status, v.envStatus)]),
                  kvList([
                    (d.kv.python, v.pythonVersion),
                    (d.kv.envId, v.envId),
                    (d.kv.syncedAt, fmtTime(v.envSyncedAt)),
                  ], meta: true),
                  const SizedBox(height: AnSpace.s8),
                  if (v.dependencies.isEmpty)
                    insetEmpty(
                      d.val.none,
                    ) // the feature's one empty-state idiom 同一空态惯用法
                  else
                    // A LABELED tags row — bare unlabeled rows read as mystery words («pydantic»,
                    // WRK-070 B12 用户点名帧). KV grammar like every sibling line of this card.
                    // 带标签的 tags 行——无标签裸行读作神秘词;与本卡每一行同一套 KV 文法。
                    AnKv(rows: [AnKvRow.tags(d.card.deps, v.dependencies)]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
