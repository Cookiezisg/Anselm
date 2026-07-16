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
/// you» zone). [framed] wraps it in the [AnInfoCard] shell (the terminal / inbox faces); pass false
/// to append it BARE inside an existing card or ledger row. A `allowReason` node grows the reason
/// input, whose text rides [onDecide]'s second argument.
///
/// 唯一停车审批门(A-011;S2b 上收 core/run——features 互不依赖)——durable flowrun 停在审批节点,在此等
/// 批准/拒绝(先到先得,输的一方 reconcile 掉门)。四处消费(run 终端/驾驶舱 tab/收件箱/Scheduler 等你处理区)。
/// [framed] 包 AnInfoCard 壳;传 false 则裸接在既有卡/行内。allowReason 节点长出理由输入,文本走 onDecide 次参。
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

  /// Wrap in the [AnInfoCard] shell (false = bare append inside a host card). 是否包卡壳。
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

  bool get _allowReason => widget.parked.result['allowReason'] == true;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _decide(String verdict) => widget.onDecide(
      verdict, widget.collectReason && _allowReason ? _reason.text.trim() : null);

  @override
  Widget build(BuildContext context) {
    final r = context.t.run;
    final c = context.colors;
    final prompt = widget.parked.result['rendered'] as String? ?? '';

    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (prompt.isNotEmpty) ...[
        Text(prompt, style: AnText.body.copyWith(color: c.ink)),
        const SizedBox(height: AnSpace.s8),
      ],
      if (widget.collectReason && _allowReason) ...[
        AnInput(controller: _reason, placeholder: r.reasonHint, block: true),
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
    ]);

    if (!widget.framed) return body;
    return AnInfoCard(
      title: r.approvalTitle,
      icon: AnIcons.approval,
      meta: widget.parked.nodeId,
      child: body,
    );
  }
}
