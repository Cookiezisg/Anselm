import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/function.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';
import '../detail_sections.dart';

/// Function 概览:说明 + KV → 代码(只读)→ 输入/输出 → 环境(依赖 + venv 状态)。
class FunctionOverview extends StatelessWidget {
  const FunctionOverview({required this.fn, super.key});

  final FunctionEntity fn;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final v = fn.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSection(variant: AnSectionVariant.plain, children: [
          if (fn.description.isNotEmpty) AnField(label: d.kv.desc, value: fn.description, wrap: true),
          kvList([
            (d.kv.name, fn.name),
            (d.kv.tags, fn.tags.join(' · ')),
            (d.kv.activeVersion, 'v${v.version}'),
            (d.kv.python, v.pythonVersion),
          ]),
        ]),
        AnSection(label: d.sec.code, variant: AnSectionVariant.plain, children: [
          AnCodeEditor(code: v.code, lang: 'py', wrap: true),
        ]),
        AnSection(label: d.sec.input, variant: AnSectionVariant.plain, grid: true, children: [
          AnInfoCard(title: d.sec.input, icon: AnIcons.byKey('enter'), child: fieldList(v.inputs, emptyTitle: d.val.none)),
          AnInfoCard(title: d.sec.output, icon: AnIcons.byKey('run'), child: fieldList(v.outputs, emptyTitle: d.val.none)),
        ]),
        AnSection(label: d.sec.env, variant: AnSectionVariant.plain, grid: true, children: [
          AnInfoCard(
            title: d.card.deps,
            icon: AnIcons.byKey('tool'),
            child: v.dependencies.isEmpty
                ? insetEmpty(d.val.none)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final dep in v.dependencies) AnRow(label: dep, passive: true)],
                  ),
          ),
          AnInfoCard(
            title: d.card.venv,
            icon: AnIcons.byKey('check'),
            child: kvList([
              (d.kv.envId, v.envId),
              (d.kv.status, v.envStatus),
              (d.kv.syncedAt, fmtTime(v.envSyncedAt)),
              (d.kv.error, v.envError ?? '—'),
            ]),
          ),
        ]),
      ],
    );
  }
}
