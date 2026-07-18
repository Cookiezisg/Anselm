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
import 'run_peek_card.dart';
import 'run_phrase.dart';
import 'scheduler_home_model.dart';

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
        // ONE body child (0718 对齐审计,大表控制块同法): the collapsed batch bar must not earn
        // AnSection's 12px inter-child gap (静息态题→卡曾 20px 应 8px). 合一子件:塌缩条不吃子距。
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        AnExpandReveal(
          open: barVisible,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AnGap.block),
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
          // A responsive TWO-column card grid (WRK-070 B13 用户裁:Overview 审批卡=双列、带边框;
          // 720 列下 AnAutoGrid 的 280 最小列宽恰流成两列). 双列有边卡网格。
          AnAutoGrid(children: [
            for (final r in widget.rows)
              AnExpandReveal(
                  open: !leaving.contains(_keyOf(r)), child: _card(context, r)),
          ]),
        ]),
      ],
    );
  }

  Widget _card(BuildContext context, SchedulerInboxRow r) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    final key = _keyOf(r);
    final isPending = pending.contains(key) || batchBusy && selected.contains(key);
    final selecting = selected.isNotEmpty;
    final showCheck = (selecting || hoveredKey == key) && !isPending;
    // Scroll-freeze the hover (0718 滚动闪烁审定,AnHoverRegion): the row/card swaps its lead
    // (dot↔spinner↔check) on hover, so an overscroll dragging content under a parked cursor must
    // not relayout mid-drag. 滚动中冻 hover:hover 换 lead,overscroll 拖内容过静止光标时不中途 relayout。
    return AnHoverRegion(
      onEnter: (_) => setState(() => hoveredKey = key),
      onExit: (_) => setState(() {
        if (hoveredKey == key) hoveredKey = null;
      }),
      child: AnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              SizedBox(
                width: AnSize.iconSm,
                child: Center(
                  child: isPending
                      ? const AnSpinner(size: AnSize.iconSm)
                      : showCheck
                          ? AnBatchCheck(
                              checked: selected.contains(key),
                              semanticLabel: t.selectRow(name: r.workflowName),
                              onChanged: (v) => setState(
                                  () => v ? selected.add(key) : selected.remove(key)),
                            )
                          : const AnStatusDot(AnStatus.wait),
                ),
              ),
              const SizedBox(width: AnSpace.s8),
              // The workflow NAME is the card's door to the run flagship (the old row-tap deep
              // link, kept). 名字即门:保留旧行点击的旗舰深链。
              Expanded(
                child: AnInteractive(
                  onTap: () =>
                      context.go('/scheduler/w/${r.workflowId}/runs/${r.node.flowrunId}'),
                  builder: (context, states) => Text(
                    r.workflowName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.body
                        .weight(AnText.emphasisWeight)
                        .copyWith(color: states.isActive ? c.accent : c.ink),
                  ),
                ),
              ),
              const SizedBox(width: AnSpace.s8),
              Text(t.waitedFor(d: fmtWaited(widget.now.difference(r.node.createdAt))),
                  style: AnText.meta.copyWith(color: c.inkFaint)),
            ]),
            const SizedBox(height: AnSpace.s8),
            // Node word + countdown; the raw fr_ pill is GONE (B1 裸 id 清除). 节点词+倒计时;裸 id 药丸删。
            Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s6, children: [
              AnChip(r.node.nodeId, look: AnChipLook.outlined),
              if (r.deadline != null) AnCountdown(deadline: r.deadline!),
            ]),
            const SizedBox(height: AnFlow.headBodyTight),
            ApprovalGate(
              parked: r.node,
              framed: false,
              showHint: false,
              collectReason: true,
              busy: isPending,
              onDecide: (v, reason) => _decideOne(r, v, reason),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── 未来调度 ───────────────────────────────────

/// The schedule zone (WRK-070 调度轨重造 0718) — ONE [AnScheduleTrack] carrying both halves of one row
/// per schedule, split by the now line. It maps the provider's [ScheduleLane]s onto the widget's core
/// types: the PAST half is [binTrackEvents] over the lane's runs (health, all sources — 裁决③) with the
/// `missed` firings laid on as ✕; the FUTURE half is a one-line forecast built from the lane's next fire.
/// Both halves' i18n words (source phrases, the schedule cadence, the relative «(in Xm)», every a11y
/// sentence, the hover card body) are assembled HERE — core holds no copy.
///
/// **Click = launch pad**: a cell with one run opens that run's flagship, several open the workflow's
/// operations home. **Hover = the detail card** ([binHoverBuilder]/[futureHoverBuilder]): the hour's
/// runs (status · time · source · elapsed, failures on top, cap 5 + an honest overflow line) or the
/// forecast. **Truncation is said out loud** (两处独立截断,两句话): a capped forecast window and a capped
/// firing page are different facts, so they get separate sentences.
///
/// 调度区(0718 重造):**一条** [AnScheduleTrack],被 now 线劈两半。把 provider 的 [ScheduleLane] 映到 widget 核心
/// 类型:过去半=对泳道 run 的 [binTrackEvents](健康、全来源——裁决③)+ missed firing 叠 ✕;未来半=从下一发建的一句
/// 话预告。两半的 i18n 词(来源短语/排程节拍/相对词/读屏句/hover 卡体)全在**此处**拼——core 无文案。**点击=发射台**
/// (一格一 run →旗舰、多 run →运营主页);**hover=明细卡**;两处独立截断各说一句。
class SchedulerScheduleZone extends StatelessWidget {
  const SchedulerScheduleZone(
      {required this.track, required this.triggersById, required this.now, super.key});

  final ScheduleTrackData track;

  /// The rail's already-fetched triggers — the source-phrase join a webhook/sensor run needs (B10 grammar,
  /// zero N+1). trigger 连接:webhook/sensor 来源短语所需(零 N+1)。
  final Map<String, TriggerEntity> triggersById;

  final DateTime now;

  static const int _cardCap = 5;

  /// Whole-hour bins (0718 v2 拍板「都弄整个小时的」): the window END is the top of the CURRENT hour's
  /// next edge, and it reaches back [SchedulerWindows.trackBinCount] (25) whole hours — 24 complete
  /// hours plus the in-progress one. INVARIANT kept: any rolling 24h KPI window (错过 N 牌) is a
  /// subset of these 25 whole hours, so every missed tick the card counts is on the track.
  /// 整点分箱:窗终=当前小时上缘,回看 25 个整点小时(24 完整+1 进行中)。不变式:任意滚动 24h KPI 窗
  /// ⊆ 这 25 个整点小时——牌数的每个 missed 都在轨上。
  DateTime get _windowEnd {
    final l = now.toLocal();
    return DateTime(l.year, l.month, l.day, l.hour).add(const Duration(hours: 1));
  }

  DateTime get _start => _windowEnd.subtract(const Duration(hours: SchedulerWindows.trackBinCount));
  int get _binCount => SchedulerWindows.trackBinCount;

  /// The column-head glyph over one cell: the hour number, or «M/D» on the midnight anchor (a date is
  /// a stronger landmark than a zero). 列头记号:小时数,0 点格改「M/D」日期锚。
  String _headOf(TrackBin bin) {
    final l = bin.start.toLocal();
    return l.hour == 0 ? '${l.month}/${l.day}' : '${l.hour}';
  }

  /// The zero-padded hour word a bin sits on («17»). 格所在的整点词。
  String _hourOf(DateTime at) => at.toLocal().hour.toString().padLeft(2, '0');

  /// Map a provider lane → the widget's core lane (bins + future), localizing every word here.
  /// 把 provider 泳道映成核心泳道(格+未来),此处本地化每个词。
  TrackLane _laneOf(BuildContext context, ScheduleLane lane) {
    final runs = <TrackRun>[
      for (final r in lane.runs)
        if (r.startedAt != null)
          TrackRun(
            id: r.id,
            workflowId: r.workflowId,
            at: r.startedAt!,
            status: AnStatus.fromRaw(r.status),
            // The honest source word (裁决③: the grid counts all sources, the card names each one).
            // 诚实来源词(裁决③:格统计所有来源、卡逐一点名)。
            sourceLabel: runBasePhrase(context, runSourceOf(r, triggersById)),
            elapsed: r.completedAt?.difference(r.startedAt!),
          ),
    ];
    // Only `missed` firings paint on the new grid — the ✕ evidence the 「错过 N」 card deep-links to; the
    // other dispositions are neither a run nor a missed tick. missed 才画在新格上(错过牌的 ✕ 证据);其余处置两不是。
    final missed = <DateTime>[
      for (final f in lane.firings)
        if (f.status == FiringStatus.missed) f.createdAt,
    ];
    return TrackLane(
      id: '${lane.triggerId}/${lane.workflowId}',
      label: lane.workflowName,
      bins: binTrackEvents(
          start: _start, end: _windowEnd, binCount: _binCount, runs: runs, missed: missed),
      // 判决①: the paused lane greys and wears «已暂停» (rendered in the future segment) — never leaves.
      // 判决①:暂停泳道灰显、戴「已暂停」(渲在未来段)——绝不离开。
      dimmed: lane.paused,
      note: lane.paused ? context.t.scheduler.home.paused : '',
      future: _futureOf(context, lane),
    );
  }

  /// The next fire as a sentence — honestly shown even beyond the 24h axis; null when paused (no next
  /// fire) or when there is no cron forecast at all. 下一发一句话——含轴外;暂停/无 cron 预告即 null。
  TrackFuture? _futureOf(BuildContext context, ScheduleLane lane) {
    final at = lane.nextFireAt;
    if (lane.paused || at == null || !at.isAfter(now)) return null;
    final t = context.t.scheduler.overview;
    return TrackFuture(
      at: at,
      time: fmtDayTime(at, now),
      // Parenthesised so it never collides with the bare KPI «in 3m». 加括号,绝不与裸 KPI「in 3m」撞。
      relative: t.trackNextIn(d: fmtWaited(at.difference(now))),
      // The schedule's own words = the trigger's name (the user's description of its cadence). 排程句=trigger 名。
      schedule: lane.triggerName,
    );
  }

  void _launch(BuildContext context, TrackLane lane, TrackBin bin) {
    if (bin.runs.isEmpty) return;
    if (bin.runs.length == 1) {
      final r = bin.runs.single;
      context.go('/scheduler/w/${r.workflowId}/runs/${r.id}');
    } else {
      // Several runs in one hour → the workflow's operations home (no single flagship to pick). 多 run→运营主页。
      context.go('/scheduler/w/${bin.runs.first.workflowId}');
    }
  }

  // ── screen-reader sentences (§12) ──

  String _binA11y(BuildContext context, TrackLane lane, TrackBin bin) {
    final t = context.t.scheduler.overview;
    final ok = bin.runs.where((r) => r.status == AnStatus.done).length;
    final fail = bin.runs.where((r) => r.status == AnStatus.err).length;
    final base =
        t.trackBinA11y(hour: _hourOf(bin.start), n: '${bin.runs.length}', ok: '$ok', fail: '$fail');
    return bin.missedCount > 0 ? '$base${t.trackBinMissedClause(x: '${bin.missedCount}')}' : base;
  }

  String _emptyBinA11y(BuildContext context, TrackLane lane, TrackBin bin) =>
      context.t.scheduler.overview.trackBinEmptyA11y(hour: _hourOf(bin.start));

  String _futureA11y(BuildContext context, TrackLane lane) {
    final t = context.t.scheduler.overview;
    final f = lane.future;
    if (f == null) return lane.dimmed ? lane.note : '';
    return t.trackFutureA11y(at: f.time, schedule: f.schedule);
  }

  String _laneA11y(BuildContext context, TrackLane lane) {
    final t = context.t.scheduler.overview;
    var n = 0, ok = 0, fail = 0, missed = 0;
    for (final b in lane.bins) {
      n += b.runs.length;
      ok += b.runs.where((r) => r.status == AnStatus.done).length;
      fail += b.runs.where((r) => r.status == AnStatus.err).length;
      missed += b.missedCount;
    }
    final next = lane.future?.time ?? (lane.dimmed ? lane.note : t.kpiNone);
    return t.trackLaneSummaryA11y(
        name: lane.label, n: '$n', ok: '$ok', fail: '$fail', missed: '$missed', next: next);
  }

  // ── hover cards ──

  Widget _binCard(BuildContext context, TrackLane lane, TrackBin bin) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    final shown = bin.runs.take(_cardCap).toList();
    final hidden = bin.runs.length > _cardCap ? bin.runs.skip(_cardCap).toList() : const <TrackRun>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header = the hour + total activity (runs + missed). 头行=时段 + 总数。
        Text(
          t.trackCardHead(
              at: fmtDayTime(bin.start, now), n: '${bin.runs.length + bin.missedCount}'),
          style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.ink),
        ),
        const SizedBox(height: AnFlow.headBodyDense),
        // Missed rows first — the ✕ evidence that drew the eye. 先列 missed:引来目光的 ✕ 证据。
        for (final m in bin.missed) _cardMissedRow(context, m),
        for (final r in shown) _cardRunRow(context, r),
        if (hidden.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: Text(_overflowLine(context, hidden),
                style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ],
    );
  }

  Widget _cardRunRow(BuildContext context, TrackRun r) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
      child: Row(children: [
        AnStatusDot(r.status),
        const SizedBox(width: AnSpace.s6),
        Text(fmtDayTime(r.at, now), style: AnText.metaTabular().copyWith(color: c.inkMuted)),
        const SizedBox(width: AnSpace.s8),
        Flexible(
          child: Text(r.sourceLabel,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
        const SizedBox(width: AnSpace.s8),
        // Elapsed — «—» while the run is still in flight (never a fabricated zero). 耗时;在跑「—」。
        Text(r.elapsed != null ? fmtDuration(r.elapsed!) : context.t.scheduler.overview.kpiNone,
            style: AnText.metaTabular().copyWith(color: c.inkFaint)),
      ]),
    );
  }

  Widget _cardMissedRow(BuildContext context, DateTime at) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
      child: Row(children: [
        Icon(AnIcons.close, size: AnSize.iconSm, color: c.inkMuted),
        const SizedBox(width: AnSpace.s6),
        Text(context.t.scheduler.overview.trackCardMissed(at: fmtDayTime(at, now)),
            style: AnText.meta.copyWith(color: c.inkFaint)),
      ]),
    );
  }

  String _overflowLine(BuildContext context, List<TrackRun> hidden) {
    final t = context.t.scheduler.overview;
    final fails = hidden.where((r) => r.status == AnStatus.err).length;
    final tail = fails > 0 ? t.trackCardMoreFailed(m: '$fails') : t.trackCardMoreOk;
    return '${t.trackCardMore(n: '${hidden.length}')} · $tail';
  }

  Widget _futureCard(BuildContext context, TrackLane lane) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    final f = lane.future;
    if (f == null) return const SizedBox.shrink();
    final text = f.schedule.isEmpty
        ? t.trackCardNextBare(at: f.time)
        : t.trackCardNext(at: f.time, schedule: f.schedule);
    return Text(text, style: AnText.meta.copyWith(color: c.ink));
  }

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
            lanes: [for (final lane in track.lanes) _laneOf(context, lane)],
            now: now,
            binHeadLabel: _headOf,
            onBin: (lane, bin) => _launch(context, lane, bin),
            binSemanticLabel: (lane, bin) => _binA11y(context, lane, bin),
            emptyBinSemanticLabel: (lane, bin) => _emptyBinA11y(context, lane, bin),
            futureSemanticLabel: (lane) => _futureA11y(context, lane),
            laneSummaryLabel: (lane) => _laneA11y(context, lane),
            binHoverBuilder: (lane, bin) => (ctx) => _binCard(ctx, lane, bin),
            futureHoverBuilder: (lane) => (ctx) => _futureCard(ctx, lane),
          ),
          // Two INDEPENDENT truncations, two sentences — they are different facts and merging them
          // would leave the reader unable to tell which half is partial. 两处**独立**截断、两句话。
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

// ─────────────────────────────────── 正在跑 / 24h 失败 共享 ───────────────────────────────────

/// The Overview run zones' shared FRONT-END paging + inline-peek expansion (WRK-070 B10). The data
/// source ([SchedulerRepository.listRunningRuns] / [SchedulerRepository.listFailedSince]) is drained
/// WHOLE into memory (never a paged endpoint), so paging here is a pure client slice — never a fetch,
/// so no backend was added. One row expands at a time ([expandedRunId]); a fast second tap on the same
/// row goes straight to the run flagship (a MANUAL double-tap so the first tap stays instant, the big
/// table's grammar). The Overview is the selection-less `/scheduler` with no `?run=` URL carrier, so
/// the expansion lives in local state rather than the route.
/// Overview 两个 run 区共享的**前端**分页 + 行内速览展开(B10):数据源(listRunningRuns/listFailedSince)抽
/// 全量到内存(非分页端点),故此处分页是纯客户端切片、绝不取数(未加后端);一次一行展开,同行快速二击直进
/// 旗舰(手工判双击、首击零延迟,大表文法);Overview 是无选区的 `/scheduler`、无 ?run= 载体,故展开态住本地。
mixin _PeekZone<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const int pageSize = 10;

  int pageNum = 1;
  String? expandedRunId;
  DateTime? _lastTapAt;
  String? _lastTapId;

  int pageCountOf(int total) => (total + pageSize - 1) ~/ pageSize;

  /// The current page's slice of the drained list; clamps the page when the list shrank on refetch.
  /// 当前页切片;列表 refetch 后缩了就把页钳回来。
  List<R> pageSlice<R>(List<R> all) {
    final pages = pageCountOf(all.length);
    final eff = pageNum.clamp(1, pages < 1 ? 1 : pages);
    return all.skip((eff - 1) * pageSize).take(pageSize).toList();
  }

  void onPageChange(int p) => setState(() => pageNum = p);

  /// First tap toggles the inline peek under the row (re-tap collapses); a fast second tap on the same
  /// row goes straight to the flagship. 首击开合行内速览(再点收起);同行快速二击直进旗舰。
  void onPeekTap(String runId, String flagshipPath) {
    final now = DateTime.now();
    final isDouble = _lastTapId == runId &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) < const Duration(milliseconds: 300);
    _lastTapAt = now;
    _lastTapId = runId;
    if (isDouble) {
      context.go(flagshipPath);
    } else {
      setState(() => expandedRunId = expandedRunId == runId ? null : runId);
    }
  }

  /// The standard page-number pager (B4 primitive), reusing the operations home's words. Hosts GATE
  /// it below a second page and OWN the gap above it (0718 对齐审计: a bare SizedBox.shrink section
  /// child still earned AnSection's 12px gap, and the old self-margin doubled the row gap to 24).
  /// 标准翻页器,复用大表文案;宿主自闸单页不渲、自持上距(空壳子件吃 12px 幽灵距 + 自夹双倍之修)。
  Widget peekPager(BuildContext context, int total) {
    final pages = pageCountOf(total);
    if (pages <= 1) return const SizedBox.shrink();
    final home = context.t.scheduler.home;
    return Center(
      child: AnPager(
        page: pageNum.clamp(1, pages),
        pageCount: pages,
        onPage: onPageChange,
        strings: AnPagerStrings(
          prevLabel: home.pagerPrev,
          nextLabel: home.pagerNext,
          jumpHint: home.pagerJump,
          pageLabel: (n) => home.pagerPage(n: '$n'),
          jumpToLabel: (n) => home.pagerJumpTo(n: '$n'),
        ),
      ),
    );
  }
}

// ─────────────────────────────────── 正在跑 ───────────────────────────────────

/// The «running now» zone (WRK-070 B10 — collapsed onto the operations big table's row grammar): each
/// live row reads «workflow · source phrase» ([runPhrase]), carries the PERSISTENT ⏹ Stop verb right
/// after it (the old hover-only far-edge ⏹ is gone), offers multi-select batch cancel (AnBatchBar at
/// ≥2), and a single tap EXPANDS the inline [RunPeekCard] under it (gantt ⇄ graph, never a navigation)
/// — a fast double-tap goes straight to the flagship. Front-end paged at 10/page.
/// 正在跑区(B10:整体收敛到运营大表行文法):行=「workflow · 来源短语」+ **常驻** ⏹ 终止(旧 hover 行尾 ⏹ 删)
/// + 多选批量取消(≥2 出条)+ 单击展开行内速览卡(甘特⇄图,不跳转)、双击直进旗舰;前端 10/页翻页。
class SchedulerRunningZone extends ConsumerStatefulWidget {
  const SchedulerRunningZone(
      {required this.rows, required this.triggersById, required this.now, super.key});

  final List<RunningRunRow> rows;
  final Map<String, TriggerEntity> triggersById;
  final DateTime now;

  @override
  ConsumerState<SchedulerRunningZone> createState() => _SchedulerRunningZoneState();
}

class _SchedulerRunningZoneState extends ConsumerState<SchedulerRunningZone>
    with BatchZone<SchedulerRunningZone>, _PeekZone<SchedulerRunningZone> {
  static String _keyOf(RunningRunRow r) => r.run.id;

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
    final visible = pageSlice(widget.rows);
    // Prune selection to the VISIBLE page (paging away drops the old page's picks — same as the big
    // table, whose rows ARE one page). 选区修剪到可见页(翻页即弃旧页选择,同大表)。
    pruneTo({for (final r in visible) _keyOf(r)});
    // barVisible AFTER prune (复审 [3]): a stale off-page selection must not leave the batch bar's
    // AnExpandReveal half-open (an 8px phantom gap). 修剪后再判:旧页选区不得留半开条(8px 幽灵缝)。
    final barVisible = selected.length >= 2 || batchBusy;
    return AnSection(
      label: t.runningHead(n: '${widget.rows.length}'),
      children: [
        // ONE body child (0718 对齐审计,大表控制块同法): the COLLAPSED batch bar and the single-page
        // pager (SizedBox.shrink) must not each earn AnSection's 12px inter-child gap (塌缩双夹
        // bug 类 — 静息态题→首行曾 20px 应 8px、末行下曾多 12px 幽灵距) — bar/rows/pager live in one
        // Column that owns its internal rhythm. 合一子件:塌缩条与空翻页器不再吃 12px 子距,节奏自持。
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          AnExpandReveal(
            open: barVisible,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AnGap.block),
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
          else ...[
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: AnGap.block),
              AnExpandReveal(
                  open: !leaving.contains(_keyOf(visible[i])),
                  child: _row(context, visible[i])),
            ],
            if (pageCountOf(widget.rows.length) > 1) ...[
              const SizedBox(height: AnGap.block),
              peekPager(context, widget.rows.length),
            ],
          ],
        ]),
      ],
    );
  }

  /// One live row (大表 _row 照搬):「workflow · source phrase» primary · persistent ⏹ Stop · live
  /// elapsed · a single-tap peek. 一行:workflow·来源短语 + 常驻 ⏹ + 活计时 + 单击速览。
  Widget _row(BuildContext context, RunningRunRow r) {
    final t = context.t.scheduler;
    final key = _keyOf(r);
    final isPending = pending.contains(key) || batchBusy && selected.contains(key);
    final selecting = selected.isNotEmpty;
    final hovered = hoveredKey == key;
    final showCheck = (selecting || hovered) && !isPending;
    final expanded = expandedRunId == key;
    final started = r.run.startedAt;
    // Scroll-freeze the hover (0718 滚动闪烁审定,AnHoverRegion): the row/card swaps its lead
    // (dot↔spinner↔check) on hover, so an overscroll dragging content under a parked cursor must
    // not relayout mid-drag. 滚动中冻 hover:hover 换 lead,overscroll 拖内容过静止光标时不中途 relayout。
    return AnHoverRegion(
      onEnter: (_) => setState(() => hoveredKey = key),
      onExit: (_) => setState(() {
        if (hoveredKey == key) hoveredKey = null;
      }),
      child: AnLedgerRow(
        expanded: expanded,
        // Lazy (C-006): a collapsed row never builds its peek card. 惰性:收起不建卡。
        expandBuilder: (_) => RunPeekCard(workflowId: r.workflowId, flowrunId: r.run.id),
        // The disclosure hand is the PRIMITIVE's (0718 对齐审计 — the 12px icon-swap the big table
        // already retired was still living here): spinner/check win the cell, disclose yields.
        // 披露示能归原语(大表已退役的 12px 换图标此处清残);转圈/勾选赢格,该态让位。
        disclose: !isPending && !showCheck,
        lead: isPending
            ? const AnSpinner(size: AnSize.iconSm)
            : showCheck
                ? AnBatchCheck(
                    checked: selected.contains(key),
                    semanticLabel: t.overview.selectRow(name: r.workflowName),
                    onChanged: (v) =>
                        setState(() => v ? selected.add(key) : selected.remove(key)),
                  )
                : AnStatusDot(AnStatus.fromRaw(r.run.status)),
        // Cross-workflow view → keep the workflow NAME, then the source phrase (裸 fr_ 药丸删,B1).
        // 跨 workflow 视图 → 保留 workflow 名 + 来源短语;裸 id 药丸删。
        primary: '${r.workflowName} · ${runPhrase(context, r.run, widget.triggersById, widget.now)}',
        mono: false,
        chips: [
          // The persistent Stop verb, right where the eye already is (大表 _row 照搬). 常驻终止。
          AnButton(
            label: t.home.rowCancel,
            icon: AnIcons.stop,
            size: AnButtonSize.sm,
            variant: AnButtonVariant.danger,
            onPressed: isPending || batchBusy ? null : () => _cancelOne(r),
          ),
          if (r.run.replayCount > 0)
            AnChip(context.t.run.replayTimes(n: '${r.run.replayCount}'),
                look: AnChipLook.outlined),
        ],
        measure: started != null ? fmtWaited(widget.now.difference(started)) : null,
        onTap: () => onPeekTap(r.run.id, '/scheduler/w/${r.workflowId}/runs/${r.run.id}'),
      ),
    );
  }
}

// ─────────────────────────────────── 24h 失败 ───────────────────────────────────

/// The «failed · 24h» zone (工单⑮) — the per-RUN list the 「24h 失败」 KPI tile opens, brought onto the
/// operations big table's row grammar (WRK-070 B10): «workflow · source phrase» primary, the error
/// first line (danger sub), a «landed N ago» meta, and — NEW in B10 — the PERSISTENT ↻ Retry verb the
/// zone was missing, multi-select batch replay (AnBatchBar at ≥2), and a single-tap inline [RunPeekCard]
/// (never a navigation). Front-end paged at 10/page (the list is drained whole; see [_PeekZone]).
///
/// **It is NOT the 7d 「失败聚合」 section below it** (§3): this zone lists RUNS in a 24h completed_at
/// window (the tile's exact predicate); that section aggregates WORKFLOWS by consecutive-failure streak
/// over 7d. A workflow that failed 4× overnight and then succeeded contributes 4 rows here and is absent
/// there (self-healed). Rendered only when non-empty (the tile is inert at zero — 成功是背景音).
///
/// 「24h 失败」区(工单⑮)——牌点开的**按 run** 列表,B10 收敛到运营大表行文法:「workflow · 来源短语」+ 错误首句
/// (danger 副行)+「N 前落定」meta,并**新增** B10 之前缺失的**常驻** ↻ 重试 + 多选批量重放(≥2 出条)+ 单击行内
/// 速览(不跳转);前端 10/页(列表抽全量,见 _PeekZone)。**不是**下面 7d「失败聚合」:本区列 24h completed_at 窗内
/// 的 run,那个按连败聚合 workflow、7d 窗;整夜失败 4 次然后跑通的 workflow 在这里 4 行、在那里缺席(已自愈)。仅非空渲。
class SchedulerFailedZone extends ConsumerStatefulWidget {
  const SchedulerFailedZone(
      {required this.rows, required this.triggersById, required this.now, super.key});

  final List<FailedRunRow> rows;
  final Map<String, TriggerEntity> triggersById;
  final DateTime now;

  @override
  ConsumerState<SchedulerFailedZone> createState() => _SchedulerFailedZoneState();
}

class _SchedulerFailedZoneState extends ConsumerState<SchedulerFailedZone>
    with BatchZone<SchedulerFailedZone>, _PeekZone<SchedulerFailedZone> {
  static String _keyOf(FailedRunRow r) => r.run.id;

  List<FailedRunRow> get _selectedRows =>
      [for (final r in widget.rows) if (selected.contains(_keyOf(r))) r];

  /// Single replay (the row's ↻ verb): pre-flight the REAL numbers off the run's node rows
  /// (记忆化承诺文案 §10), confirm, replay, then slide out. 单行重放:先取真数字→确认→重放→滑出。
  Future<void> _replayOne(FailedRunRow r) async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    final repo = ref.read(schedulerRepositoryProvider);
    final key = _keyOf(r);
    setState(() => pending.add(key));
    (int, int)? counts;
    try {
      final comp = await repo.getRunFull(r.run.id);
      final c = replayCounts(comp.nodes);
      counts = (c.failed, c.completed);
    } catch (_) {
      // Numbers unavailable → still replay, with the numberless sentence. 取不到数字仍可重放。
    } finally {
      if (mounted) setState(() => pending.remove(key));
    }
    if (!mounted) return;
    final ok = await overlay.confirm(
      title: t.replayTitle,
      message: counts != null
          ? t.replayBody(failed: '${counts.$1}', completed: '${counts.$2}')
          : t.replayBodyUnknown,
      confirmLabel: t.replayAction,
      cancelLabel: context.t.action.cancel,
      barrierLabel: context.t.action.cancel,
      confirmTone: AnDialogTone.primary,
    );
    if (!ok || !mounted) return;
    setState(() => pending.add(key));
    try {
      await repo.replayRun(r.run.id);
      if (!mounted) return;
      overlay.showToast(t.replayed, tone: AnTone.ok);
      setState(() {
        pending.remove(key);
        leaving.add(key);
      });
      await settleRefetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pending.remove(key));
      overlay.showToast(e.httpStatus == 422 ? t.notReplayable : e.message,
          tone: e.httpStatus == 422 ? AnTone.warn : AnTone.danger);
    }
  }

  Future<void> _batchReplay() async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    final repo = ref.read(schedulerRepositoryProvider);
    final targets = _selectedRows;
    if (targets.isEmpty) return;
    // Merge the REAL numbers across every target (合并真数字弹窗). 逐 run 取数合并。
    var failed = 0, completed = 0;
    var counted = true;
    setState(() => batchBusy = true);
    try {
      for (final r in targets) {
        final comp = await repo.getRunFull(r.run.id);
        final c = replayCounts(comp.nodes);
        failed += c.failed;
        completed += c.completed;
      }
    } catch (_) {
      counted = false;
    } finally {
      if (mounted) setState(() => batchBusy = false);
    }
    if (!mounted) return;
    final ok = await overlay.confirm(
      title: t.batchReplayTitle(n: '${targets.length}'),
      message: counted
          ? t.batchReplayBody(failed: '$failed', completed: '$completed')
          : t.replayBodyUnknown,
      confirmLabel: t.replayAction,
      cancelLabel: context.t.action.cancel,
      barrierLabel: context.t.action.cancel,
      confirmTone: AnDialogTone.primary,
    );
    if (!ok || !mounted) return;
    final (done, lost, err) =
        await runBatch<FailedRunRow>(targets, _keyOf, (r) => repo.replayRun(r.run.id));
    if (!mounted) return;
    summaryToast(
      okPart: done > 0 ? t.sumReplayed(n: '$done') : null,
      lostPart: lost > 0 ? t.sumNotReplayable(n: '$lost') : null,
      failedPart: err > 0 ? context.t.scheduler.overview.sumFailed(n: '$err') : null,
    );
    await settleRefetch();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    final home = context.t.scheduler.home;
    final visible = pageSlice(widget.rows);
    pruneTo({for (final r in visible) _keyOf(r)});
    final barVisible = selected.length >= 2 || batchBusy; // after prune (复审 [3]) 修剪后再判
    return AnSection(
      label: t.failed24hHead(n: '${widget.rows.length}'),
      children: [
        // ONE body child — same law as the running zone above (0718 对齐审计). 合一子件,同上区。
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          AnExpandReveal(
            open: barVisible,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AnGap.block),
              child: AnBatchBar(
                count: selected.length,
                busy: batchBusy,
                actions: [
                  BatchAction(
                      label: home.batchReplay,
                      icon: AnIcons.history,
                      tone: AnTone.accent,
                      onRun: _batchReplay),
                ],
                onClear: () => setState(selected.clear),
              ),
            ),
          ),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: AnGap.block),
            AnExpandReveal(
                open: !leaving.contains(_keyOf(visible[i])),
                child: _row(context, visible[i])),
          ],
          if (pageCountOf(widget.rows.length) > 1) ...[
            const SizedBox(height: AnGap.block),
            peekPager(context, widget.rows.length),
          ],
        ]),
      ],
    );
  }

  Widget _row(BuildContext context, FailedRunRow r) {
    final t = context.t.scheduler;
    final key = _keyOf(r);
    final isPending = pending.contains(key) || batchBusy && selected.contains(key);
    final selecting = selected.isNotEmpty;
    final hovered = hoveredKey == key;
    final showCheck = (selecting || hovered) && !isPending;
    final expanded = expandedRunId == key;
    final landed = r.run.completedAt;
    // Scroll-freeze the hover (0718 滚动闪烁审定,AnHoverRegion): the row/card swaps its lead
    // (dot↔spinner↔check) on hover, so an overscroll dragging content under a parked cursor must
    // not relayout mid-drag. 滚动中冻 hover:hover 换 lead,overscroll 拖内容过静止光标时不中途 relayout。
    return AnHoverRegion(
      onEnter: (_) => setState(() => hoveredKey = key),
      onExit: (_) => setState(() {
        if (hoveredKey == key) hoveredKey = null;
      }),
      child: AnLedgerRow(
        expanded: expanded,
        expandBuilder: (_) => RunPeekCard(workflowId: r.workflowId, flowrunId: r.run.id),
        // Same primitive hand as the running zone (0718 对齐审计清残). 同上,披露示能归原语。
        disclose: !isPending && !showCheck,
        lead: isPending
            ? const AnSpinner(size: AnSize.iconSm)
            : showCheck
                ? AnBatchCheck(
                    checked: selected.contains(key),
                    semanticLabel: t.overview.selectRow(name: r.workflowName),
                    onChanged: (v) =>
                        setState(() => v ? selected.add(key) : selected.remove(key)),
                  )
                : const AnStatusDot(AnStatus.err),
        primary: '${r.workflowName} · ${runPhrase(context, r.run, widget.triggersById, widget.now)}',
        mono: false,
        chips: [
          // The persistent Retry verb the failed zone was missing (B10 补齐,大表 _row 照搬). 常驻重试。
          AnButton(
            label: t.home.rowRetry,
            icon: AnIcons.history,
            size: AnButtonSize.sm,
            onPressed: isPending || batchBusy ? null : () => _replayOne(r),
          ),
          if (r.run.replayCount > 0)
            AnChip(context.t.run.replayTimes(n: '${r.run.replayCount}'),
                look: AnChipLook.outlined),
        ],
        // The error first line — the same projection the big table and run detail render (one text,
        // three surfaces). 错误首句:与大表/run 详情同一投影(一份文案三处)。
        sub: errorFirstLine(r.run.error),
        subTone: AnTone.danger,
        // «landed N ago» — completed_at is the window's axis, so the meta names WHEN it failed.
        // 「N 前落定」:completed_at 是窗轴,故 meta 说它**何时**失败。
        meta: landed != null ? t.agoMeta(d: fmtWaited(widget.now.difference(landed))) : null,
        onTap: () => onPeekTap(r.run.id, '/scheduler/w/${r.workflowId}/runs/${r.run.id}'),
      ),
    );
  }
}
