import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/control.dart';
import '../../../../../core/design/colors.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/typography.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_badge.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';
import '../detail_sections.dart';

/// Control 概览(支撑 kind,非可执行四大):说明 + KV → 声明入参 → 路由分支(每出口 port / when / emit;末条兜底)。
/// 纯配置/逻辑,无执行、无 run 终端、无日志。朴素 KV 文档,零 bespoke。
class ControlOverview extends StatelessWidget {
  const ControlOverview({required this.control, super.key});

  final ControlLogic control;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final v = control.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identitySection(d.kv.desc, control.description, [
          (d.kv.id, control.id),
          (d.kv.activeVersion, 'v${v.version}'),
          (d.kv.updated, fmtTime(control.updatedAt)),
        ]),
        AnSection(label: d.sec.input, variant: AnSectionVariant.plain, children: [
          fieldList(v.inputs, emptyTitle: d.val.none),
        ]),
        AnSection(label: d.sec.branches, variant: AnSectionVariant.plain, children: [
          if (v.branches.isEmpty)
            insetEmpty(d.val.none)
          else
            for (final b in v.branches) _branchRow(context, b),
        ]),
      ],
    );
  }

  // One routing branch: port badge (catch-all = neutral) + its when-CEL (or 兜底) + emit summary (透传 if
  // empty). 一条路由分支:port 徽(兜底=中性)+ when CEL(或兜底)+ emit 摘要(空=透传)。
  Widget _branchRow(BuildContext context, Branch b) {
    final d = context.t.entities.detail;
    final c = context.colors;
    final isDefault = b.when == 'true';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnBadge(b.port, tone: isDefault ? AnTone.none : AnTone.accent),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDefault ? d.editor.branchDefault : b.when,
                  style: AnText.codeInline.copyWith(color: isDefault ? c.inkFaint : c.inkMuted),
                ),
                Text(
                  b.emit.isEmpty ? d.val.passthrough : '${d.editor.branchEmit}: ${b.emit.keys.join(', ')}',
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
