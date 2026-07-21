import 'package:flutter/widgets.dart';

import '../contract/entities/workflow.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/ui.dart';
import '../../i18n/strings.g.dart';

/// The ONE parked-approval decision gate (WRK-066 A-011; upstreamed to core/run for the Scheduler
/// ocean, WRK-069 S2b — features don't import features) — a durable flowrun node stopped at an
/// approval waits here for Approve / Reject (first-wins; a lost race reconciles the gate away). Four
/// sites consume it (the run terminal, the cockpit tab, the flowrun inbox, the Scheduler «waiting on
/// you» zone). [framed] wraps it in a BORDERED [AnCard] shell (WRK-070 B13:用户裁「外面要一圈边边」,
/// 弃无边 AnInfoCard); pass false to append it BARE inside an existing card or ledger row. A
/// `allowReason` node grows the reason input ON DEMAND via a «+ 理由» pill (B13), whose text rides
/// [onDecide]'s second argument.
///
/// 唯一停车审批门(A-011;S2b 上收 core/run——features 互不依赖)——durable flowrun 停在审批节点,在此等
/// 批准/拒绝(先到先得,输的一方 reconcile 掉门)。四处消费(run 终端/驾驶舱 tab/收件箱/Scheduler 等你处理区)。
/// [framed] 包**有边 AnCard** 壳(B13:用户要一圈边框);传 false 则裸接在既有卡/行内。allowReason 节点经「+ 理由」药丸按需长出输入,文本走 onDecide 次参。
class ApprovalGate extends StatefulWidget {
  const ApprovalGate({
    required this.parked,
    required this.onDecide,
    this.busy = false,
    this.framed = true,
    this.showHint = true,
    this.collectReason = false,
    super.key,
  });

  final FlowrunNode parked;

  /// (verdict: 'yes' | 'no', reason: the reason text when [collectReason] + the node allows one, else
  /// null). 决断回调(reason 仅在 collectReason 且节点允许时非空)。
  final void Function(String verdict, String? reason) onDecide;

  /// A decision already in flight — disables both buttons. 决断在途,压双钮。
  final bool busy;

  /// Wrap in a bordered [AnCard] shell (false = bare append inside a host card). 是否包有边卡壳。
  final bool framed;

  /// Show the «first-wins» hint line (the inbox omits it). 是否显「先到先得」提示。
  final bool showHint;

  /// Grow the reason input when the node allows one — ONLY the `:decide` paths that can forward a
  /// reason to the backend opt in; the terminal / cockpit `decide` carries no reason, so they leave
  /// it false (no dead input). 仅能把理由送后端的径打开;终端/驾驶舱 decide 不带 reason,故留 false(无死输入)。
  final bool collectReason;

  @override
  State<ApprovalGate> createState() => _ApprovalGateState();
}

class _ApprovalGateState extends State<ApprovalGate> {
  final TextEditingController _reason = TextEditingController();

  /// The reason input mounts only on demand (WRK-070 B13 用户裁「常驻输入框怪恶心」): at rest a small
  /// «+ 理由» pill — the reason is optional pure-audit, so its cost must be one glyph, not a field.
  /// 理由输入按需长出:静息=「+ 理由」小药丸——理由纯审计可选,静息成本必须是一枚字形而非一整个输入框。
  bool _reasonOpen = false;

  bool get _allowReason => widget.parked.result['allowReason'] == true;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _decide(String verdict) => widget.onDecide(
    verdict,
    widget.collectReason && _allowReason ? _reason.text.trim() : null,
  );

  @override
  Widget build(BuildContext context) {
    final r = context.t.run;
    final c = context.colors;
    final prompt = widget.parked.result['rendered'] as String? ?? '';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prompt.isNotEmpty) ...[
          // The rendered prompt is a markdown template (`Deploy **v2.4.0** to production?`) — render it as
          // EMBEDDED-scale markdown so `**strong**` is bold, not literal asterisks (0719 star bug). Embedded
          // (not reading) because the gate lives inside a card / inbox / terminal, never a 720 reading column.
          // 渲染后的问题句是 markdown 模板;走嵌入档 markdown 让 **粗** 真粗、非字面星号(0719 星号 bug);
          // 嵌入档因门住在卡/收件箱/终端里、非阅读列。
          AnMarkdown(prompt, scale: AnMarkdownScale.embedded),
          const SizedBox(height: AnSpace.s8),
        ],
        if (widget.collectReason && _allowReason) ...[
          if (!_reasonOpen)
            Align(
              alignment: Alignment.centerLeft,
              child: AnChip(
                r.addReason,
                look: AnChipLook.outlined,
                onTap: () => setState(() => _reasonOpen = true),
              ),
            )
          else
            AnInput(
              controller: _reason,
              placeholder: r.reasonHint,
              block: true,
              autofocus: true,
            ),
          const SizedBox(height: AnSpace.s8),
        ],
        if (widget.showHint) ...[
          Text(r.approvalHint, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s8),
        ],
        AnActionGroup([
          AnButton(
            label: r.approve,
            variant: AnButtonVariant.primary,
            size: AnButtonSize.sm,
            onPressed: widget.busy ? null : () => _decide('yes'),
          ),
          AnButton(
            label: r.reject,
            variant: AnButtonVariant.danger,
            size: AnButtonSize.sm,
            onPressed: widget.busy ? null : () => _decide('no'),
          ),
        ]),
      ],
    );

    if (!widget.framed) return body;
    // Framed = a BORDERED card (B13 用户裁「外面要一圈边边,不要裸着」— AnCard, not the borderless
    // AnInfoCard): hairline shell + the family head row. 有边卡壳(AnCard 非无边 AnInfoCard)+族头行。
    return AnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  AnIcons.approval,
                  size: AnSize.iconSm,
                  color: c.inkFaint,
                ),
              ),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    r.approvalTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.label
                        .weight(AnText.emphasisWeight)
                        .copyWith(color: c.inkFaint),
                  ),
                ),
              ),
              Text(
                widget.parked.nodeId,
                maxLines: 1,
                style: AnText.meta.copyWith(color: c.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: AnFlow.headBodyTight),
          body,
        ],
      ),
    );
  }
}
