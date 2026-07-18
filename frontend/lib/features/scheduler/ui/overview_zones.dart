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
