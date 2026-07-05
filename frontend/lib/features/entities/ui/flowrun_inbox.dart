import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/workflow.dart'; // FlowrunNode
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_action_group.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_info_card.dart';
import '../../../core/ui/an_input.dart';
import '../../../core/ui/an_rail_skeleton.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../data/entity_providers.dart';
import '../state/flowrun_inbox_provider.dart';

/// The cross-run approval inbox (the left-island bell tray content) — every parked approval waiting for a
/// human decision, each a card with the rendered prompt + approve/reject (+ a reason note when the form
/// allows it). Decides via `:decide` (first-wins) then refreshes the list. Approval's runtime "second
/// face" (the config form lives in the entities rail). 审批收件箱(铃托盘):跨 run 待审逐卡决断。
class FlowrunInbox extends ConsumerWidget {
  const FlowrunInbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.t.entities.run;
    final async = ref.watch(flowrunInboxProvider);
    return async.when(
      loading: () => const AnDeferredLoading(child: AnRailSkeleton()),
      // A failed load is an ERROR, not an empty inbox — the sibling error idiom (errorTitle + retry;
      // the old copy said "No pending approvals / Load more" on a transport failure). 加载失败=错误态,
      // 走兄弟面同款 errorTitle+重试(旧文案把故障说成「收件箱为空/加载更多」)。
      error: (_, _) => AnState(
        kind: AnStateKind.error,
        size: AnStateSize.inset,
        title: context.t.entities.detail.state.errorTitle,
        action: AnButton(label: context.t.entities.detail.state.retry, onPressed: () => ref.invalidate(flowrunInboxProvider)),
      ),
      data: (parked) => parked.isEmpty
          ? AnState(
              kind: AnStateKind.empty,
              size: AnStateSize.inset,
              title: r.inboxEmpty,
              hint: r.inboxEmptyHint,
            )
          : ScrollConfiguration(
              behavior: const AnScrollBehavior(),
              child: ListView.separated(
                padding: const EdgeInsets.all(AnSpace.s12),
                itemCount: parked.length,
                separatorBuilder: (_, _) => const SizedBox(height: AnSpace.s12),
                itemBuilder: (_, i) => _ApprovalCard(parked: parked[i]),
              ),
            ),
    );
  }
}

class _ApprovalCard extends ConsumerStatefulWidget {
  const _ApprovalCard({required this.parked});

  final FlowrunNode parked;

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  final _reason = TextEditingController();
  bool _deciding = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    if (_deciding) return;
    setState(() => _deciding = true);
    final p = widget.parked;
    try {
      await ref.read(entityRepositoryProvider).decideApproval(
            p.flowrunId,
            p.nodeId,
            decision: decision,
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          );
      // Refresh the inbox — this node is no longer parked. 刷新收件箱(本节点已决)。
      ref.invalidate(flowrunInboxProvider);
    } catch (_) {
      // Lost the first-wins race (422) or a transport error — re-enable so they can retry / it refreshes.
      // 输了 first-wins(422)或传输错——恢复可点,重试/下次刷新自纠。
      if (mounted) setState(() => _deciding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.t.entities.run;
    final c = context.colors;
    final p = widget.parked;
    final prompt = p.result['rendered'] as String? ?? '';
    final allowReason = p.result['allowReason'] == true;
    return AnInfoCard(
      title: r.approvalTitle,
      icon: AnIcons.approval,
      meta: p.nodeId,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (prompt.isNotEmpty) ...[
          Text(prompt, style: AnText.body.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s8),
        ],
        if (allowReason) ...[
          AnInput(controller: _reason, placeholder: r.reasonHint, block: true),
          const SizedBox(height: AnSpace.s8),
        ],
        AnActionGroup([
          AnButton(
            label: r.approve,
            variant: AnButtonVariant.primary,
            size: AnButtonSize.sm,
            onPressed: _deciding ? null : () => _decide('yes'),
          ),
          AnButton(
            label: r.reject,
            variant: AnButtonVariant.danger,
            size: AnButtonSize.sm,
            onPressed: _deciding ? null : () => _decide('no'),
          ),
        ]),
      ]),
    );
  }
}
