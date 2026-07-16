import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/run/approval_gate.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/scheduler_repository.dart';
import '../scheduler_windows.dart';
import '../state/scheduler_overview_provider.dart';
import '../state/scheduler_rail_provider.dart';
import 'batch_engine.dart';

// The Overview's two ACTION zones (WRK-069 §3 S2b) — «等你处理» (inbox rows + in-place ApprovalGate +
// AnBatchBar batch approve/reject) and «正在跑» (live rows + hover ⏹ cancel + batch cancel). Both share
// one selection/batch grammar — the feature-shared [BatchZone] engine (batch_engine.dart, upstreamed
// for S3's big table): hover swaps the row's status dot for an [AnBatchCheck]; ≥2 selected floats
// the [AnBatchBar]; a batch is FRONT-END SEQUENTIAL dispatch with explicit per-row settling (pending
// spinner → settle → slide out — never fake atomicity, 判决②); a lost first-wins race (422) earns an
// honest toast + refetch. Geometry only moves on user action or durable refetch (活性军规 — the
// decision IS a user action, so the slide-out is legal).
// Overview 两块操作区(S2b):等你处理(收件箱行+就地审批门+批量批准/拒绝)与正在跑(活行+hover ⏹+批量取消)。
// 选择/批量文法=feature 共享 BatchZone 引擎(batch_engine.dart,S3 大表复用故上收):hover 状态点换
// 选择框;选中≥2 浮出批量条;批量=前端逐发+显式挂账(绝不装原子);输家 422 诚实 toast+refetch。

// ─────────────────────────────────── 等你处理 ───────────────────────────────────

/// The «waiting on you» zone — the costliest land, between the KPI strip and «running now». Each row:
/// amber dot (hover → checkbox) + workflow name + node chip + mono fr_ chip + waited-for measure +
/// [AnCountdown] (only when a deadline exists) + an in-place [ApprovalGate] (reason input when the
/// node allows). 等你处理区:最贵地皮;行=琥珀点(hover 换选择框)+名+节点+fr_ chip+等待时长+倒计时
/// (有期限才渲)+就地审批门(节点允许时带理由输入)。
class SchedulerWaitingZone extends ConsumerStatefulWidget {
  const SchedulerWaitingZone({required this.rows, required this.now, super.key});

  final List<SchedulerInboxRow> rows;
  final DateTime now;

  @override
  ConsumerState<SchedulerWaitingZone> createState() => _SchedulerWaitingZoneState();
}

class _SchedulerWaitingZoneState extends ConsumerState<SchedulerWaitingZone>
    with BatchZone<SchedulerWaitingZone> {
  final TextEditingController _batchReason = TextEditingController();
  bool _rejectOpen = false;

  static String _keyOf(SchedulerInboxRow r) => '${r.node.flowrunId}/${r.node.nodeId}';

  @override
  void didUpdateWidget(covariant SchedulerWaitingZone old) {
    super.didUpdateWidget(old);
    pruneTo({for (final r in widget.rows) _keyOf(r)});
  }

  @override
  void dispose() {
    _batchReason.dispose();
    super.dispose();
  }

  List<SchedulerInboxRow> get _selectedRows =>
      [for (final r in widget.rows) if (selected.contains(_keyOf(r))) r];

  Future<void> _decideOne(SchedulerInboxRow row, String verdict, String? reason) async {
    final key = _keyOf(row);
    if (pending.contains(key) || batchBusy) return;
    final t = context.t.scheduler.overview;
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => pending.add(key));
    try {
      await ref.read(schedulerRepositoryProvider).decideApproval(
            row.node.flowrunId,
            row.node.nodeId,
            decision: verdict,
            reason: (reason == null || reason.isEmpty) ? null : reason,
          );
      if (!mounted) return;
      setState(() {
        pending.remove(key);
        leaving.add(key);
      });
      await settleRefetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pending.remove(key));
      if (e.httpStatus == 422) {
        // Lost the first-wins race — honest toast, then reconcile the row away. 输家诚实对账。
        overlay.showToast(t.alreadyHandled, tone: AnTone.warn);
        await ref.read(schedulerRailProvider.notifier).refresh();
      } else {
        overlay.showToast(e.message, tone: AnTone.danger);
      }
    }
  }

  Future<void> _batchDecide(String verdict, {String? reason}) async {
    final t = context.t.scheduler.overview;
    final rows = _selectedRows;
    if (rows.isEmpty) return;
    setState(() => _rejectOpen = false);
    final repo = ref.read(schedulerRepositoryProvider);
    final (ok, lost, failed) = await runBatch<SchedulerInboxRow>(rows, _keyOf, (r) {
      // The shared reason only rides where the node ACCEPTS one (no silent drop on the backend).
      // 共用理由只送给接受理由的节点。
      final allow = r.node.result['allowReason'] == true;
      return repo.decideApproval(r.node.flowrunId, r.node.nodeId,
          decision: verdict, reason: allow && reason != null && reason.isNotEmpty ? reason : null);
    });
    if (!mounted) return;
    summaryToast(
      okPart: ok > 0
          ? (verdict == 'yes' ? t.sumApproved(n: '$ok') : t.sumRejected(n: '$ok'))
          : null,
      lostPart: lost > 0 ? t.sumLost(n: '$lost') : null,
      failedPart: failed > 0 ? t.sumFailed(n: '$failed') : null,
    );
    await settleRefetch();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    final barVisible = selected.length >= 2 || batchBusy;
    return AnSection(
      label: t.waitingHead(n: '${widget.rows.length}'),
      children: [
        AnExpandReveal(
          open: barVisible,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AnBatchBar(
                count: selected.length,
                busy: batchBusy,
                actions: [
                  BatchAction(
                      label: t.batchApprove,
                      icon: AnIcons.check,
                      tone: AnTone.accent,
                      onRun: () => _batchDecide('yes')),
                  BatchAction(
                      label: t.batchReject,
                      tone: AnTone.danger,
                      onRun: () => setState(() => _rejectOpen = !_rejectOpen)),
                ],
                onClear: () => setState(() {
                  selected.clear();
                  _rejectOpen = false;
                }),
              ),
              // The shared-reason strip for batch reject (an inline reveal — the modal confirm has
              // no input seat, and the reason belongs next to the bar it qualifies). 批量拒绝的共用
              // 理由条:内联浮出(模态确认框无输入位,理由就该贴着它所修饰的条)。
              AnExpandReveal(
                open: _rejectOpen && !batchBusy,
                child: Padding(
                  padding: const EdgeInsets.only(top: AnSpace.s8),
                  child: Row(children: [
                    Expanded(
                        child: AnInput(
                            controller: _batchReason,
                            placeholder: context.t.run.reasonHint,
                            block: true)),
                    const SizedBox(width: AnSpace.s8),
                    AnButton(
                        label: t.batchRejectConfirm(n: '${selected.length}'),
                        variant: AnButtonVariant.danger,
                        size: AnButtonSize.sm,
                        onPressed: () => _batchDecide('no', reason: _batchReason.text.trim())),
                    const SizedBox(width: AnSpace.s8),
                    AnButton(
                        label: context.t.action.cancel,
                        size: AnButtonSize.sm,
                        onPressed: () => setState(() => _rejectOpen = false)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        if (widget.rows.isEmpty)
          Text(t.waitingEmpty, style: AnText.body.copyWith(color: c.inkFaint))
        else
          for (final r in widget.rows)
            AnExpandReveal(
                open: !leaving.contains(_keyOf(r)), child: _row(context, r)),
      ],
    );
  }

  Widget _row(BuildContext context, SchedulerInboxRow r) {
    final t = context.t.scheduler.overview;
    final key = _keyOf(r);
    final isPending = pending.contains(key) || batchBusy && selected.contains(key);
    final selecting = selected.isNotEmpty;
    final showCheck = (selecting || hoveredKey == key) && !isPending;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredKey = key),
      onExit: (_) => setState(() {
        if (hoveredKey == key) hoveredKey = null;
      }),
      child: AnLedgerRow(
        lead: isPending
            ? const AnSpinner(size: AnSize.iconSm)
            : showCheck
                ? AnBatchCheck(
                    checked: selected.contains(key),
                    semanticLabel: t.selectRow(name: r.workflowName),
                    onChanged: (v) => setState(() => v ? selected.add(key) : selected.remove(key)),
                  )
                : const AnStatusDot(AnStatus.wait),
        primary: r.workflowName,
        mono: false,
        chips: [
          AnChip(r.node.nodeId, look: AnChipLook.outlined),
          AnChip(truncate(r.node.flowrunId, AnTrunc.id),
              mono: true, look: AnChipLook.outlined, tooltip: r.node.flowrunId),
          // The countdown renders ONLY when a deadline exists — no deadline, no lie. 无期限不渲。
          if (r.deadline != null) AnCountdown(deadline: r.deadline!),
        ],
        measure: t.waitedFor(d: fmtWaited(widget.now.difference(r.node.createdAt))),
        onTap: () => context.go('/scheduler/w/${r.workflowId}/runs/${r.node.flowrunId}'),
        expanded: true,
        expandChild: Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s8),
          child: ApprovalGate(
            parked: r.node,
            framed: false,
            showHint: false,
            collectReason: true,
            busy: isPending,
            onDecide: (v, reason) => _decideOne(r, v, reason),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────── 未来调度 ───────────────────────────────────

/// The «next 24h» zone (S5) — S2a's plain row list replaced by the real [AnScheduleTrack]: an absolute
/// axis, a now line, and one lane per (workflow × cron trigger).
///
/// **Only FUTURE points are fed, and the now line therefore sits at the axis's left edge.** Past dots
/// (§3.4「过去实心点着状态色」) and the missed ✕ would need a workspace-level, time-windowed firing
/// query — and `GET /triggers/{id}/firings` is per-trigger with NO time filter and no count/aggregate,
/// so a 24h history would mean draining every trigger's whole firing log page by page, unbounded and
/// degrading as the window moves. That is not «awkward», it is a capability the contract does not
/// have; rendering only the runs we CAN reach would be worse than rendering none — the skipped /
/// superseded / missed dispositions would be invisible holes in a track that looks complete. So the
/// track shows what it can prove and says nothing about what it cannot (记偏差,见 §14 S5).
///
/// 未来 24h 区(S5):S2a 的简版行列表换成真 [AnScheduleTrack]——绝对轴 + now 线 + 逐 (workflow×cron) 泳道。
/// **只喂未来点,故 now 线坐在轴的最左**。过去实心点与 missed ✕ 需要一个 **workspace 级 + 带时间窗**的
/// firing 查询,而 `GET /triggers/{id}/firings` 是**逐 trigger、无时间过滤、无计数聚合**——拉 24h 历史
/// 等于把每个 trigger 的整本 firing 账逐页拖干,无界且随窗口回滚线性劣化。这不是「麻烦」,是契约层面
/// **没有这个能力**;而只渲「拿得到的那部分 run」比一个不渲更糟——skipped/superseded/missed 会成为一条
/// 看起来完整的轨道上的**隐形空洞**。故轨道只显示它能证明的,对它证明不了的**闭嘴**(记偏差,§14 S5)。
class SchedulerScheduleZone extends StatelessWidget {
  const SchedulerScheduleZone({required this.track, required this.now, super.key});

  final ScheduleTrackData track;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    return AnSection(
      label: t.upcomingHead,
      children: [
        if (track.lanes.isEmpty)
          Text(t.upcomingEmpty, style: AnText.body.copyWith(color: c.inkFaint))
        else ...[
          AnScheduleTrack(
            lanes: [
              for (final lane in track.lanes)
                TrackLane(
                  id: '${lane.triggerId}/${lane.workflowId}',
                  label: lane.workflowName,
                  // 判决①: the paused lane greys and wears the word — it never leaves the board.
                  // 判决①:暂停泳道灰显并戴上词——它绝不离开看板。
                  dimmed: lane.paused,
                  note: lane.paused ? context.t.scheduler.home.paused : '',
                  events: [
                    for (final at in lane.futureAt)
                      TrackEvent(
                        at: at,
                        kind: TrackEventKind.future,
                        // «预计» — a forecast must never read as a measured fact. 预告绝不读成实测。
                        label: '${lane.workflowName} · ${lane.triggerName}',
                      ),
                  ],
                ),
            ],
            now: now,
            window: SchedulerWindows.trackWindow,
            eventSemanticLabel: (lane, e) =>
                t.trackPointA11y(name: lane.label, at: fmtDateTime(e.at)),
            foldedLabel: (n) => t.trackFolded(n: '$n'),
          ),
          // The endpoint capped the window — say so, or the track reads as the whole truth.
          // 端点截断了窗——必须明说,否则轨道会被读成全部真相。
          if (track.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s8),
              child: Text(t.trackTruncated, style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────── 正在跑 ───────────────────────────────────

/// The «running now» zone — S2a's live rows grown the S2b operating power: a hover ⏹ (danger confirm
/// → `:cancel`) and multi-select batch cancel (danger dialog listing the victims). 正在跑区:S2a 活行
/// 长出操作权力——hover ⏹(danger 确认→取消)+ 多选批量取消(danger 弹窗带行清单)。
class SchedulerRunningZone extends ConsumerStatefulWidget {
  const SchedulerRunningZone({required this.rows, required this.now, super.key});

  final List<RunningRunRow> rows;
  final DateTime now;

  @override
  ConsumerState<SchedulerRunningZone> createState() => _SchedulerRunningZoneState();
}

class _SchedulerRunningZoneState extends ConsumerState<SchedulerRunningZone>
    with BatchZone<SchedulerRunningZone> {
  static String _keyOf(RunningRunRow r) => r.run.id;

  @override
  void didUpdateWidget(covariant SchedulerRunningZone old) {
    super.didUpdateWidget(old);
    pruneTo({for (final r in widget.rows) _keyOf(r)});
  }

  List<RunningRunRow> get _selectedRows =>
      [for (final r in widget.rows) if (selected.contains(_keyOf(r))) r];

  Future<void> _cancelOne(RunningRunRow r) async {
    final t = context.t.scheduler.overview;
    final overlay = ref.read(overlayProvider.notifier);
    final ok = await overlay.confirm(
      title: t.cancelConfirmTitle,
      message: t.cancelConfirmBody(name: r.workflowName, id: r.run.id),
      confirmLabel: t.cancelConfirmAction,
      cancelLabel: t.cancelKeep,
      barrierLabel: t.cancelKeep,
    );
    if (!ok || !mounted) return;
    final key = _keyOf(r);
    setState(() => pending.add(key));
    try {
      await ref.read(schedulerRepositoryProvider).cancelRun(r.run.id);
      if (!mounted) return;
      setState(() {
        pending.remove(key);
        leaving.add(key);
      });
      await settleRefetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pending.remove(key));
      if (e.httpStatus == 422) {
        // Already terminal — honest toast + reconcile (the row settles by truth, not by wish).
        // run 已自行结束:诚实 toast+对账。
        overlay.showToast(t.alreadyFinished, tone: AnTone.warn);
        await ref.read(schedulerRailProvider.notifier).refresh();
      } else {
        overlay.showToast(e.message, tone: AnTone.danger);
      }
    }
  }

  Future<void> _batchCancel() async {
    final t = context.t.scheduler.overview;
    final rows = _selectedRows;
    if (rows.isEmpty) return;
    final overlay = ref.read(overlayProvider.notifier);
    // The danger dialog lists every victim by name + id — the user confirms the LIST, not a number.
    // danger 弹窗带行清单:确认的是名单,不是数字。
    final list = [for (final r in rows) '${r.workflowName} · ${r.run.id}'].join('\n');
    final ok = await overlay.confirm(
      title: t.batchCancelTitle(n: '${rows.length}'),
      message: t.batchCancelBody(list: list),
      confirmLabel: t.cancelConfirmAction,
      cancelLabel: t.cancelKeep,
      barrierLabel: t.cancelKeep,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(schedulerRepositoryProvider);
    final (done, ended, failed) =
        await runBatch<RunningRunRow>(rows, _keyOf, (r) => repo.cancelRun(r.run.id));
    if (!mounted) return;
    summaryToast(
      okPart: done > 0 ? t.sumCancelled(n: '$done') : null,
      lostPart: ended > 0 ? t.sumEnded(n: '$ended') : null,
      failedPart: failed > 0 ? t.sumFailed(n: '$failed') : null,
    );
    await settleRefetch();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    final barVisible = selected.length >= 2 || batchBusy;
    return AnSection(
      label: t.runningHead(n: '${widget.rows.length}'),
      children: [
        AnExpandReveal(
          open: barVisible,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s8),
            child: AnBatchBar(
              count: selected.length,
              busy: batchBusy,
              actions: [
                BatchAction(
                    label: t.batchCancel,
                    icon: AnIcons.stop,
                    tone: AnTone.danger,
                    onRun: _batchCancel),
              ],
              onClear: () => setState(selected.clear),
            ),
          ),
        ),
        if (widget.rows.isEmpty)
          Text(t.runningEmpty, style: AnText.body.copyWith(color: c.inkFaint))
        else
          for (final r in widget.rows)
            AnExpandReveal(open: !leaving.contains(_keyOf(r)), child: _row(context, r)),
      ],
    );
  }

  /// One live row: status dot (hover → checkbox) · workflow name · mono fr_ chip · live elapsed ·
  /// hover ⏹. Node progress needs the run detail (S4) — absent, not faked. 活行;节点进度依赖 S4,
  /// 缺席不假造。
  Widget _row(BuildContext context, RunningRunRow r) {
    final t = context.t.scheduler.overview;
    final key = _keyOf(r);
    final isPending = pending.contains(key) || batchBusy && selected.contains(key);
    final selecting = selected.isNotEmpty;
    final hovered = hoveredKey == key;
    final showCheck = (selecting || hovered) && !isPending;
    final started = r.run.startedAt;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredKey = key),
      onExit: (_) => setState(() {
        if (hoveredKey == key) hoveredKey = null;
      }),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: AnLedgerRow(
            lead: isPending
                ? const AnSpinner(size: AnSize.iconSm)
                : showCheck
                    ? AnBatchCheck(
                        checked: selected.contains(key),
                        semanticLabel: t.selectRow(name: r.workflowName),
                        onChanged: (v) =>
                            setState(() => v ? selected.add(key) : selected.remove(key)),
                      )
                    : AnStatusDot(AnStatus.fromRaw(r.run.status)),
            primary: r.workflowName,
            mono: false,
            chips: [
              AnChip(truncate(r.run.id, AnTrunc.id),
                  mono: true, look: AnChipLook.outlined, tooltip: r.run.id),
            ],
            measure: started != null ? fmtWaited(widget.now.difference(started)) : null,
            onTap: () => context.go('/scheduler/w/${r.workflowId}/runs/${r.run.id}'),
          ),
        ),
        const SizedBox(width: AnSpace.s6),
        // The hover ⏹ — a RESERVED cell (no layout shift on hover); hidden it leaves the a11y tree.
        // hover ⏹:定宽格 hover 零位移;隐藏时退出语义树。
        Visibility(
          visible: hovered && !isPending && !batchBusy,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: AnButton.iconOnly(
            AnIcons.stop,
            size: AnButtonSize.sm,
            variant: AnButtonVariant.danger,
            semanticLabel: t.cancelRunA11y(id: r.run.id),
            onPressed: () => _cancelOne(r),
          ),
        ),
      ]),
    );
  }
}
