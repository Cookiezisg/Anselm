import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/workflow.dart'; // FlowrunNode
import '../../../core/design/tokens.dart';
import '../../../core/run/approval_gate.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/entity_providers.dart';
import '../state/flowrun_inbox_provider.dart';

/// The cross-run approval inbox (the left-island bell tray content) — every parked approval waiting for a
/// human decision, each a card with the rendered prompt + approve/reject (+ a reason note when the form
/// allows it). Decides via `:decide` (first-wins) then refreshes the list. Approval's runtime "second
/// face" (the config form lives in the entities rail). 审批收件箱(铃托盘):跨 run 待审逐卡决断。
class FlowrunInbox extends ConsumerWidget {
  const FlowrunInbox({this.sectioned = false, super.key});

  /// SECTIONED mode = the notification tray's top "Needs you" group: a COLLAPSIBLE [AnRow] head (the SAME
  /// rail primitive as the tray's time-bucket heads — permanent chevron + count ↔ hover ⋯ bulk menu 全部批准 /
  /// 全部拒绝) over a non-scrolling card stack, collapsing to nothing when there are no parked approvals (so
  /// the notification FEED below owns the scroll). Standalone mode (false) is the full-panel inbox with its
  /// own empty/loading/error states + internal scroll.
  ///
  /// 分段模式=通知托盘顶部「待你处理」组:可折叠 AnRow 头(与托盘时段头同款 rail 原语——常驻箭头 + 数字↔hover ⋯ 批量
  /// 菜单 全部批准/全部拒绝)+ 不滚动卡叠,无待审则塌成空,让下方通知 feed 独占滚动。独立模式(false)=整面板收件箱。
  final bool sectioned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.t.entities.run;
    if (sectioned) return const _NeedsYouSection();
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

/// The bell tray's "Needs you" band — a collapsible [AnRow] head over the parked approvals, with a hover ⋯
/// bulk menu. It carries state (collapse + a bulk decision in flight), so it's stateful; the app shell
/// composes it into the [NotificationTray] as the top group (one feature's widget, injected — features stay
/// independent). 铃托盘「待你处理」带:可折叠 AnRow 头 + hover ⋯ 批量菜单;持态(折叠 + 批量在途)故有状态,app 壳注入托盘顶。
class _NeedsYouSection extends ConsumerStatefulWidget {
  const _NeedsYouSection();

  @override
  ConsumerState<_NeedsYouSection> createState() => _NeedsYouSectionState();
}

class _NeedsYouSectionState extends ConsumerState<_NeedsYouSection> {
  bool _open = true;
  bool _bulkBusy = false;

  /// Bulk approve/reject — the Overview batch engine's grammar (WRK-070): a confirm dialog naming EVERY
  /// affected node, then per-item accounting (ok / lost-the-first-wins-race 422 / failed), an honest summary
  /// toast (worst tone), and a refetch. Never a silent naked batch. 批量批准/拒绝=Overview 批量引擎文法:确认
  /// 弹窗点名每一项 + 逐条挂账(ok / 输了 first-wins 的 422 / 失败)+ 诚实汇总 toast(取最坏 tone)+ 重取;绝不裸批。
  Future<void> _bulkDecide(String verdict, List<FlowrunNode> parked) async {
    if (_bulkBusy || parked.isEmpty) return;
    final t = context.t;
    final r = t.run;
    final overlay = ref.read(overlayProvider.notifier);
    // Name every affected approval (its ref, else its node id) — the confirm dialog shows the full list.
    // 点名每一项(ref,否则 nodeId)——确认弹窗列全单。
    final list = [for (final p in parked) '· ${p.ref.isNotEmpty ? p.ref : p.nodeId}'].join('\n');
    final confirmed = await overlay.confirm(
      title: verdict == 'yes'
          ? r.batchApproveTitle(n: '${parked.length}')
          : r.batchRejectTitle(n: '${parked.length}'),
      message: r.batchDecideBody(list: list),
      confirmLabel: verdict == 'yes' ? r.approve : r.reject,
      cancelLabel: t.action.cancel,
      barrierLabel: t.feedback.dialogBarrier,
      confirmTone: verdict == 'yes' ? AnDialogTone.primary : AnDialogTone.danger,
    );
    if (!confirmed || !mounted) return;
    setState(() => _bulkBusy = true);
    final repo = ref.read(entityRepositoryProvider);
    var ok = 0, lost = 0, failed = 0;
    for (final p in parked) {
      try {
        // Bulk carries no per-item reason (reason is optional pure-audit; a batch decides fast). 批量不带逐条理由。
        await repo.decideApproval(p.flowrunId, p.nodeId, decision: verdict, reason: null);
        ok++;
      } on ApiException catch (e) {
        e.httpStatus == 422 ? lost++ : failed++; // 422 = already decided elsewhere (first-wins) 已被别处决断
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _bulkBusy = false);
    final parts = <String>[
      if (ok > 0) verdict == 'yes' ? r.sumApproved(n: '$ok') : r.sumRejected(n: '$ok'),
      if (lost > 0) r.sumLost(n: '$lost'),
      if (failed > 0) r.sumFailed(n: '$failed'),
    ];
    if (parts.isNotEmpty) {
      final tone = failed > 0 ? AnTone.danger : (lost > 0 ? AnTone.warn : AnTone.ok);
      overlay.showToast(parts.join(' · '), tone: tone);
    }
    ref.invalidate(flowrunInboxProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(flowrunInboxProvider);
    // Only surface when there's something to decide; everything else (loading / error / empty) collapses to
    // nothing so the feed owns the tray. 有待决才显,余皆塌。
    final parked = async.value ?? const <FlowrunNode>[];
    if (parked.isEmpty) return const SizedBox.shrink();
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The «Needs you» head is the SAME primitive as the notification tray's time-bucket heads and the
        // chat rail's Pinned/Recents head, rendered EXACTLY like it: a BARE AnRow (no outer padding). The
        // island gives the s12 gutter, so the hover block fills the island inner width and the chevron/count
        // sit at the rail's s8 content inset — one column with the search field / tray heads / rows. 「待你处理」头=
        // 裸 AnRow(无外距):hover 块吃满岛内宽、chevron/数字落 s8 内容列——与搜索框/时段头/行同一竖线。
        AnRow(
          collapsible: true,
          open: _open,
          label: t.notifications.needsYou,
          meta: '${parked.length}',
          onSelect: () => setState(() => _open = !_open),
          onToggle: () => setState(() => _open = !_open),
          // hover ⋯ = bulk decide (全部批准 / 全部拒绝). While a bulk decision is in flight the spinner
          // rides the same trail slot (re-trigger is guarded in _bulkDecide). 忙态 spinner 骑同一尾槽。
          actions: [
            if (_bulkBusy)
              const SizedBox(
                width: AnSize.controlSm,
                height: AnSize.controlSm,
                child: Center(child: AnSpinner(size: AnSize.iconSm)),
              )
            else
              AnMenu(
                entries: [
                  AnMenuItem(label: t.run.approveAll, icon: AnIcons.check, onTap: () => _bulkDecide('yes', parked)),
                  AnMenuItem(label: t.run.rejectAll, icon: AnIcons.close, danger: true, onTap: () => _bulkDecide('no', parked)),
                ],
                anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(AnIcons.more,
                    size: AnButtonSize.sm, semanticLabel: t.a11y.moreActions, onPressed: toggle),
              ),
          ],
        ),
        AnExpandReveal(
          open: _open,
          child: Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in parked)
                  Padding(
                    // Card edge on the hover-block line: fill the island inner width (no horizontal inset —
                    // the island's s12 gutter already sets the edge), so the card border aligns with the head
                    // block + row blocks; the card's OWN inset gives its content breathing. 卡边=hover 块线(吃满岛内宽);
                    // 卡内距管呼吸。
                    padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
                    child: _ApprovalCard(parked: p),
                  ),
              ],
            ),
          ),
        ),
      ],
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
