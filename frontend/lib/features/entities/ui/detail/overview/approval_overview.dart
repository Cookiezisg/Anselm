import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/approval.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';
import '../detail_sections.dart';

/// Approval 概览(支撑 kind,非可执行四大):说明 + KV → 声明入参 → 审批模板(markdown + `{{ CEL }}` 插值,
/// 只读)→ 决策规则(allowReason / timeout / timeoutBehavior)。运行时=flowrun 的 parked 行,不在此
/// (跨 run 待办收件箱是后续)。朴素 KV 文档,零 bespoke。
class ApprovalOverview extends StatelessWidget {
  const ApprovalOverview({required this.approval, super.key});

  final ApprovalForm approval;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final v = approval.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identitySection(d.kv.desc, approval.description, [
          (d.kv.id, approval.id),
          (d.kv.activeVersion, 'v${v.version}'),
          (d.kv.updated, fmtTime(approval.updatedAt)),
        ]),
        AnSection(
          label: d.sec.input,
          variant: AnSectionVariant.plain,
          children: [fieldList(v.inputs, emptyTitle: d.val.none)],
        ),
        AnSection(
          label: d.sec.template,
          variant: AnSectionVariant.plain,
          children: [
            AnCodeEditor(
              code: v.template,
              lang: 'md',
              wrap: true,
              reading: true,
            ),
          ],
        ),
        AnSection(
          label: d.sec.decisionRules,
          variant: AnSectionVariant.plain,
          children: [
            kvList([
              (d.kv.allowReason, v.allowReason ? d.val.yes : d.val.no),
              (d.kv.timeout, v.timeout.isEmpty ? d.val.never : v.timeout),
              // Behavior only applies when a timeout is set (empty → never times out). 超时行为仅在设了超时时有意义。
              (
                d.kv.timeoutBehavior,
                v.timeout.isEmpty ? null : v.timeoutBehavior,
              ),
            ]),
          ],
        ),
      ],
    );
  }
}
