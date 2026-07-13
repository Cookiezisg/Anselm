import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/workflow.dart'; // FlowrunNode
import '../../../core/design/tokens.dart';
import '../../../core/ui/an_group_label.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_rail_skeleton.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import 'approval_gate.dart';
import '../data/entity_providers.dart';
import '../state/flowrun_inbox_provider.dart';

/// The cross-run approval inbox (the left-island bell tray content) — every parked approval waiting for a
/// human decision, each a card with the rendered prompt + approve/reject (+ a reason note when the form
/// allows it). Decides via `:decide` (first-wins) then refreshes the list. Approval's runtime "second
/// face" (the config form lives in the entities rail). 审批收件箱(铃托盘):跨 run 待审逐卡决断。
class FlowrunInbox extends ConsumerWidget {
  const FlowrunInbox({this.sectioned = false, super.key});

  /// SECTIONED mode = the notification tray's top "Needs you" band: this collapses to nothing when there
  /// are no parked approvals (or while loading / on error) and renders a "Needs you" header + a
  /// non-scrolling card stack when there are, so the notification FEED below owns the scroll. Standalone
  /// mode (false) is the full-panel inbox with its own empty/loading/error states + internal scroll.
  ///
  /// 分段模式=通知托盘顶部「待你处理」带:无待审(或加载中/出错)时塌成空,有则渲「待你处理」头 + 不滚动卡叠,
  /// 让下方通知 feed 独占滚动。独立模式(false)=整面板收件箱,自带空/加载/错误态 + 内部滚动。
  final bool sectioned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.t.entities.run;
    final async = ref.watch(flowrunInboxProvider);
    if (sectioned) {
      // Only surface when there's something to decide; everything else collapses. 有待决才显,余皆塌。
      final parked = async.value ?? const [];
      if (parked.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnGroupLabel(context.t.notifications.needsYou, padding: const EdgeInsets.fromLTRB(AnSpace.s12, AnSpace.s12, AnSpace.s12, AnSpace.s4)),
          for (final p in parked)
            Padding(
              padding: const EdgeInsets.fromLTRB(AnSpace.s12, AnSpace.s4, AnSpace.s12, AnSpace.s4),
              child: _ApprovalCard(parked: p),
            ),
        ],
      );
    }
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
  bool _deciding = false;

  // The reason controller now lives in the shared ApprovalGate (A-011) — it hands the text back
  // through onDecide. reason 控制器归共享门,经 onDecide 回传。
  Future<void> _decide(String decision, String? reason) async {
    if (_deciding) return;
    setState(() => _deciding = true);
    final p = widget.parked;
    try {
      await ref.read(entityRepositoryProvider).decideApproval(
            p.flowrunId,
            p.nodeId,
            decision: decision,
            reason: (reason?.isEmpty ?? true) ? null : reason,
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
    // The shared decision gate (A-011) — the inbox is the ONE path that forwards a reason, so it
    // opts into the reason input; the «first-wins» hint is omitted here (a list of gates). 共享门:
    // 收件箱是唯一送 reason 的径,开 collectReason;列表脸略「先到先得」提示。
    return ApprovalGate(
      parked: widget.parked,
      busy: _deciding,
      collectReason: true,
      showHint: false,
      onDecide: (v, reason) => _decide(v, reason),
    );
  }
}
