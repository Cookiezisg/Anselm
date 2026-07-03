import 'package:flutter/widgets.dart';

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
import '../../../data/entity_format.dart';
import '../detail_sections.dart';

/// Function 概览:变换盒 hero(签名即接口)→ 代码(50 行渐隐收合——实现是细节)→ 环境合卡
/// (deps + venv 一张卡,envError 红字直出)。meta KV 缩到说明 + 标签(名称/版本在页头)。
class FunctionOverview extends StatelessWidget {
  const FunctionOverview({required this.fn, super.key});

  final FunctionEntity fn;

  /// 50 code lines at the code style's line box, plus the editor chrome — the collapse threshold.
  /// 代码样式行盒 × 50 行 + 编辑器 chrome = 收合高度。
  static const double _collapsedCodeHeight = 50 * 12 * 1.6 + 44;

  @override
  Widget build(BuildContext context) {
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
        if (fn.description.isNotEmpty || fn.tags.isNotEmpty)
          AnSection(variant: AnSectionVariant.plain, children: [
            if (fn.description.isNotEmpty) AnField(label: d.kv.desc, value: fn.description, wrap: true),
            if (fn.tags.isNotEmpty) kvList([(d.kv.tags, fn.tags.join(' · '))]),
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
