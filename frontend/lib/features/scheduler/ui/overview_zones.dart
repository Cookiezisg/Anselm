import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/trigger.dart';
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

/// The schedule zone (S5 + 工单⑭/判决⑥) — ONE [AnScheduleTrack] carrying BOTH halves of one timeline:
/// an absolute axis, a now line at the centre, one lane per (workflow × cron trigger), the past 24h of
/// firings to the left of now and the next 24h of forecast ticks to its right.
///
/// **Three faces, three different claims, and the difference is the whole point** (§3.4): a `past` dot
/// is solid in its status colour — a fire that really happened; a `future` dot is a hollow ring — a
/// FORECAST, and the zone's words say 「预计」 so a prediction never reads as a measurement; a `missed`
/// tick is a grey ✕ — a cron tick that came due while the machine slept, booked and never caught up.
/// The ✕ is grey, not red, on purpose (§7 状态学「未执行」中性桶): a desktop app's machine sleeping at
/// night is its first reality, not a fault — a deliberate departure from Temporal's «missed = red».
///
/// **Why the past half only became possible now**: it needs a workspace-level, time-windowed firing
/// query, and until 工单⑭ `GET /triggers/{id}/firings` was per-trigger with no time filter — a 24h
/// history meant draining every trigger's whole ledger. S5 shipped no past half at all rather than
/// draw the reachable subset, because a track that looks complete while hiding holes is worse than a
/// track that admits it starts at now. `GET /firings?createdAfter=` closed that, and the SAME honesty
/// still governs the remaining edge: the ledger is unbounded and pages newest-first, so a capped page
/// makes everything before [ScheduleTrackData.pastFrom] unknown — and the zone SAYS so.
///
/// 调度区(S5 + 工单⑭/判决⑥):**一条** [AnScheduleTrack] 装下一条时间轴的**两半**——绝对轴、now 线居中、
/// 逐 (workflow×cron) 泳道,now 左边是过去 24h 真开过的火、右边是未来 24h 的预告刻度。**三张脸=三种不同的
/// 断言,而这个区别就是全部要害**:past 实心着状态色=真发生过;future 空心环=**预告**(区里的词说「预计」,
/// 预测绝不读成实测);missed 灰 ✕=机器睡着时到期、记账且不补跑的刻度。✕ **刻意灰不红**(§7 状态学「未执行」
/// 中性桶):桌面 app 的机器夜里睡觉是第一现实、不是故障——刻意背离 Temporal「missed=红」。**过去半为何现在才可能**:
/// 它需要 workspace 级 + 带时间窗的 firing 查询,而工单⑭ 之前 `GET /triggers/{id}/firings` 逐 trigger、无时间
/// 过滤——拉 24h 史等于把每本账拖干。S5 宁可一个过去点都不发,也不画「拿得到的那部分」:一条看起来完整却藏着洞的
/// 轨道,比一条老实承认自己从 now 开始的轨道更糟。`GET /firings?createdAfter=` 补上了这个口子,而**同一条诚实**
/// 仍管着剩下的边界:账无界、按新→旧翻页,故撞帽的一页会让 pastFrom 之前成为未知——区**明说**它。
class SchedulerScheduleZone extends StatelessWidget {
  const SchedulerScheduleZone({required this.track, required this.now, super.key});

  final ScheduleTrackData track;
  final DateTime now;

  /// The word a PAST mark's colour is saying — colour NEVER travels alone (WCAG 1.4.1).
  ///
  /// Derived from [TrackEvent.status], **the very value the dot paints**, so word and colour agree BY
  /// CONSTRUCTION. That is why it is not looked up from the [Firing] row: a 24h-past axis buckets at
  /// ~1.8h, so a 15-minute cron folds ~7 fires into one mark, and the fold reports the bucket's WORST
  /// status — a word fetched from any one row would then describe a different fire than the colour does.
  ///
  /// The three reachable tones get FIRING vocabulary, because the app-wide tone words would misname
  /// them: a skipped fire is not 「空闲」/idle, it is 「未执行」— it fired and deliberately did not run.
  /// run/err are unreachable by construction (the sealed 7 fold to wait/done/idle only, and `unknown`
  /// falls to idle); if the backend ever widens the set they fall back to the app-wide tone words,
  /// which stay TRUE — inventing a neutral word for a failure would not.
  ///
  /// 过去点的颜色正在说的那个词(色永不独行,WCAG 1.4.1)。取自 TrackEvent.status——**点所画的正是这个值**——
  /// 故词与色**构造上**一致。所以它不从 Firing 行里查:24h 的过去轴按 ~1.8h 分桶,一个 15 分钟的 cron 会把 ~7 次
  /// 火折成一个点,而折叠报的是该桶的**最坏**状态——从任一行取词都会描述一次与颜色所说不同的火。三个可达的调
  /// 各给 **firing** 词,因为全 app 的调词会叫错它们:被跳过的火不是「空闲」,是「未执行」——它触发了,且刻意
  /// 没有跑。run/err 构造上不可达(封闭 7 值只折到 wait/done/idle,unknown 落 idle);后端若加值,它们回落到全 app
  /// 的调词——那仍是**真话**,而给一个失败编一个中性词不是。
  static String _markWord(BuildContext context, AnStatus? s) => switch (s ?? AnStatus.idle) {
        AnStatus.done => context.t.scheduler.status.firingFired,
        AnStatus.wait => context.t.scheduler.status.firingQueued,
        AnStatus.idle => context.t.scheduler.status.firingNotRun,
        AnStatus.run => context.t.status.run,
        AnStatus.err => context.t.status.err,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    return AnSection(
      label: t.scheduleHead,
      children: [
        if (track.lanes.isEmpty)
          Text(t.scheduleEmpty, style: AnText.body.copyWith(color: c.inkFaint))
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
                    // The past half (工单⑭): `missed` wears the ✕ face, every other disposition is a
                    // solid dot in the colour AnStatus.fromRaw folds its word to — the SAME table the
                    // rest of the app reads, so the four neutral dispositions land on idle grey here
                    // without this widget deciding anything about colour.
                    // 过去半(工单⑭):missed 戴 ✕ 脸,其余处置=实心点,色由 AnStatus.fromRaw 折它的词而来
                    // ——与全 app 同一张表,故四个中性处置在此自然落 idle 灰,本件不对颜色做任何裁决。
                    for (final f in lane.firings)
                      TrackEvent(
                        at: f.createdAt,
                        kind: f.status == FiringStatus.missed
                            ? TrackEventKind.missed
                            : TrackEventKind.past,
                        status: AnStatus.fromRaw(f.status.name),
                        id: f.id,
                        label: '${lane.workflowName} · ${lane.triggerName}',
                      ),
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
            // Equal to the KPI window BY CONSTRUCTION — the 「错过 N」 card deep-links to the ✕ on this
            // very track, so it must look back exactly as far as the card counted (判决⑥).
            // **构造上**等于 KPI 窗——「错过 N」牌深链到的正是本轨的 ✕,故它必须回看得与牌数的**一样远**。
            pastWindow: SchedulerWindows.trackPastWindow,
            // One sentence per face. The forecast sentence says 「预计」 and MUST NOT be reused for a
            // past mark — a fire that already happened being announced as «scheduled» is the plainest
            // possible lie. 每张脸一句;预告句说「预计」,**绝不**给过去点复用——把已经发生的火念成「预计」是最
            // 直白的谎。
            eventSemanticLabel: (lane, e) => switch (e.kind) {
              TrackEventKind.future => t.trackPointA11y(name: lane.label, at: fmtDateTime(e.at)),
              TrackEventKind.missed => t.trackMissedA11y(name: lane.label, at: fmtDateTime(e.at)),
              TrackEventKind.past => t.trackFiredA11y(
                  name: lane.label, at: fmtDateTime(e.at), status: _markWord(context, e.status)),
            },
            foldedLabel: (n) => t.trackFolded(n: '$n'),
          ),
          // Two INDEPENDENT truncations, two sentences — they are different facts and merging them
          // would leave the reader unable to tell which half is partial. 两处**独立**截断、两句话:它们是不同的
          // 事实,合成一句会让读者分不清是哪一半不全。
          if (track.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s8),
              child: Text(t.trackTruncated, style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
          if (track.pastTruncated && track.pastFrom != null)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s8),
              child: Text(t.trackPastTruncated(at: fmtDateTime(track.pastFrom!)),
                  style: AnText.meta.copyWith(color: c.inkFaint)),
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

// ─────────────────────────────────── 24h 失败 ───────────────────────────────────

/// The «failed · 24h» zone (工单⑮) — the per-RUN list the 「24h 失败」 KPI tile opens. Each row: red dot
/// · workflow name · mono fr_ chip · error first line (danger) · «landed N ago» meta · deep-link to the
/// run detail. Passive (no batch, no cancel — these runs are already terminal); the operating power a
/// failed run offers is replay, which needs the run composite (S4) and lives on its detail page.
///
/// **It is NOT the 7d 「失败聚合」 section below it** (§3), and the difference is the whole reason it
/// exists: this zone lists RUNS in a 24h completed_at window (the tile's exact predicate); that section
/// aggregates WORKFLOWS by consecutive-failure streak over 7d. A workflow that failed 4× overnight and
/// then succeeded contributes 4 rows here and is absent there (self-healed) — two units, two windows.
///
/// Rendered only when non-empty: the tile is inert at zero (no list to open), so an always-present
/// «24h 失败 (0)» section would be an empty failure box the board never scrolls to, and 「成功是背景音」
/// says the detail layer stays silent when there is nothing wrong. The tile's clickability and this
/// zone's presence are the same condition (`failedRuns.isNotEmpty`).
///
/// 「24h 失败」区(工单⑮)——「24h 失败」牌点开的**按 run** 列表。行=红点·名·mono fr_ chip·错误首句(danger)·
/// 「N 前落定」meta·深链 run 详情。被动(无批量无取消——这些 run 已终态;失败 run 的操作权力是 replay,依赖
/// run 复合[S4]、住它的详情页)。**不是**下面那个 7d「失败聚合」(§3):本区列 24h completed_at 窗内的 **run**
/// (牌的精确谓词),那个按连败聚合 **workflow**、7d 窗——整夜失败 4 次然后跑通的 workflow 在这里贡献 4 行、在
/// 那里缺席(已自愈)。**仅非空时渲**:牌在零时惰性(无列表可开),故常驻的「24h 失败 (0)」会是看板永不滚去的
/// 空失败框,而「成功是背景音」要求明细层无事时闭嘴;牌的可点性与本区的在场是同一个条件(failedRuns.isNotEmpty)。
class SchedulerFailedZone extends StatelessWidget {
  const SchedulerFailedZone({required this.rows, required this.now, super.key});

  final List<FailedRunRow> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    return AnSection(
      label: t.failed24hHead(n: '${rows.length}'),
      children: [
        for (final r in rows) _row(context, r),
      ],
    );
  }

  Widget _row(BuildContext context, FailedRunRow r) {
    final landed = r.run.completedAt;
    return AnLedgerRow(
      lead: const AnStatusDot(AnStatus.err),
      primary: r.workflowName,
      mono: false,
      chips: [
        AnChip(truncate(r.run.id, AnTrunc.id),
            mono: true, look: AnChipLook.outlined, tooltip: r.run.id),
      ],
      // The error first line — the same projection the big table and run detail render (one text,
      // three surfaces). 错误首句:与大表/run 详情同一投影(一份文案三处)。
      sub: errorFirstLine(r.run.error),
      subTone: AnTone.danger,
      // «landed N ago» — completed_at is the window's axis, so the meta names WHEN it failed.
      // 「N 前落定」:completed_at 是窗轴,故 meta 说它**何时**失败。
      meta: landed != null
          ? context.t.scheduler.agoMeta(d: fmtWaited(now.difference(landed)))
          : null,
      onTap: () => context.go('/scheduler/w/${r.workflowId}/runs/${r.run.id}'),
    );
  }
}
