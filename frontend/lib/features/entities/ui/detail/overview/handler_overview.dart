import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/handler.dart';
import '../../../../../core/contract/entities/values.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';
import '../detail_sections.dart';

/// Handler 概览:说明 + KV → 常驻状态(运行时/配置完整度)→ init 参数(敏感默认遮蔽)→ 方法 + 类代码(只读)。
class HandlerOverview extends StatelessWidget {
  const HandlerOverview({required this.hd, super.key});

  final HandlerEntity hd;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final v = hd.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);

    // Sensitive defaults are NEVER rendered. 敏感默认值绝不渲染。
    String argSummary(InitArgSpec a) => [
          a.type,
          a.required ? d.val.required : d.val.optional,
          if (a.sensitive) d.val.sensitive,
          if (!a.sensitive && a.defaultValue != null) '${d.val.defaultPrefix} ${a.defaultValue}',
        ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSection(variant: AnSectionVariant.plain, children: [
          if (hd.description.isNotEmpty) AnField(label: d.kv.desc, value: hd.description, wrap: true),
          kvList([
            (d.kv.id, hd.id),
            (d.kv.activeVersion, 'v${v.version}'),
            (d.kv.python, v.pythonVersion),
            (d.kv.updated, fmtTime(hd.updatedAt)),
          ]),
        ]),
        AnSection(label: d.sec.runtime, variant: AnSectionVariant.plain, grid: true, children: [
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
                for (final m in hd.missingConfig) AnRow(label: m, dot: AnStatus.wait, passive: true),
              ],
            ),
          ),
        ]),
        AnSection(label: d.sec.initArgs, variant: AnSectionVariant.plain, children: [
          if (v.initArgsSchema.isEmpty)
            insetEmpty(d.val.none)
          else
            kvList([
              for (final a in v.initArgsSchema) (a.name, argSummary(a)),
            ], wrap: true),
        ]),
        AnSection(label: d.sec.methods, variant: AnSectionVariant.plain, children: [
          for (final m in v.methods)
            AnRow(
              icon: AnIcons.byKey('tool'),
              label: m.name,
              meta: '${m.inputs.length}→${m.outputs.length}',
              hint: m.streaming ? d.val.generator : (m.timeout != null ? d.val.timeoutMs(ms: m.timeout!) : null),
              passive: true,
            ),
          AnCodeEditor(code: handlerSourceOf(v), lang: 'py', wrap: true),
        ]),
      ],
    );
  }
}
