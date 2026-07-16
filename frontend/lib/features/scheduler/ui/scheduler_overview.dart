import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/shell/oceans.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/scheduler_overview_provider.dart';
import 'overview_zones.dart';

/// The Scheduler Overview board (WRK-069 §3, S2a+S2b) — `/scheduler` with nothing selected. Zones
/// top-down by how much they need a human: KPI strip → «等你处理» (inbox rows + in-place ApprovalGate
/// + batch approve/reject, [SchedulerWaitingZone]) → running now (hover ⏹ cancel + batch cancel,
/// [SchedulerRunningZone]) → next-24h schedule → 7d failure aggregation; zero workflows collapses the
/// whole page into one first-use education card. 活性军规: the half-minute [AnTimePulse] refreshes
/// TIME TEXT only (running elapsed / waited-for / next-fire relatives); rows appear/disappear only on
/// user action or durable refetch. Saturated colour goes to red/amber only — success stays background
/// hum. Scheduler 总览看板:KPI 牌 → 等你处理(就地审批+批量)→ 正在跑(hover 取消+批量)→ 未来 24h →
/// 失败聚合;零数据整页一张教育卡。脉搏只刷时间字,行增删只随用户动作/durable refetch;饱和色只给红/琥珀。
class SchedulerOverviewView extends ConsumerStatefulWidget {
  const SchedulerOverviewView({super.key});

  @override
  ConsumerState<SchedulerOverviewView> createState() => _SchedulerOverviewViewState();
}

class _SchedulerOverviewViewState extends ConsumerState<SchedulerOverviewView> {
  /// The schedule zone's anchor + wash trigger — the 「错过 N」 card's drill-down (判决⑥). The zone is
  /// where the ticks the card counted actually live (each one a ✕ on its lane at the instant it was
  /// due), so «open the list this number counts» is: scroll it into view and wash it. [_washSeq] only
  /// ever changes on a USER TAP, so the wash cannot fire on a refetch — 活性军规 (geometry and attention
  /// move on user action or durable landing, never on their own).
  /// 调度区的锚 + 洗亮触发器——「错过 N」牌的钻取(判决⑥):牌数的那些刻度就活在那个区里(每一个都是它到期那一刻
  /// 泳道上的一个 ✕),故「点开它数的那个列表」=把它滚进视野并洗亮。_washSeq **只在用户点击时**变,故洗亮不可能
  /// 因重取而发生(活性军规:几何与注意力只随用户动作或 durable 落账而动)。
  final GlobalKey _scheduleKey = GlobalKey();
  int _washSeq = 0;

  @override
  void initState() {
    super.initState();
    AnTimePulse.instance.addListener(_onPulse);
  }

  @override
  void dispose() {
    AnTimePulse.instance.removeListener(_onPulse);
    super.dispose();
  }

  void _onPulse() {
    if (mounted) setState(() {});
  }

  void _revealMissed() {
    final ctx = _scheduleKey.currentContext;
    if (ctx == null) return;
    setState(() => _washSeq++);
    Scrollable.ensureVisible(ctx,
        duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.slow,
        curve: AnMotion.easeOut,
        alignment: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler;
    final data = ref.watch(schedulerOverviewProvider);

    // Keep the last good board on refetch (no flash); loading/error only rule the FIRST load.
    // 重取期间保留旧盘面;骨架/错误只管首载。
    if (data.hasValue) return _board(context, data.value!);
    if (data.hasError) {
      return Center(
        child: AnState(
          kind: AnStateKind.error,
          title: t.overview.errorTitle,
          hint: t.overview.errorHint,
          action: AnButton(
            label: t.retry,
            onPressed: () => ref.read(schedulerOverviewProvider.notifier).retry(),
          ),
        ),
      );
    }
    return const AnPage(
      child: AnDeferredLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [AnSkeleton.card(), SizedBox(height: AnSpace.s16), AnSkeleton.lines(6)],
        ),
      ),
    );
  }

  Widget _board(BuildContext context, SchedulerOverviewData d) {
    final t = context.t.scheduler;
    final c = context.colors;
    if (d.firstUse) return _firstUse(context);

    final now = DateTime.now();
    return AnPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AnGap.section),
            child: Text(t.overviewTitle, style: AnText.h2.copyWith(color: c.ink)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AnGap.section),
            child: _KpiStrip(kpi: d.kpi, now: now, onMissed: _revealMissed),
          ),
          // «等你处理» — the costliest land (S2b): inbox rows + in-place ApprovalGate + AnBatchBar
          // batch approve/reject; then «正在跑» with hover ⏹ + batch cancel. 等你处理(就地审批+批量)
          // 与 正在跑(hover 取消+批量取消)两操作区。
          SchedulerWaitingZone(rows: d.waiting, now: now),
          SchedulerRunningZone(rows: d.runningRuns, now: now),
          _washSeq == 0
              ? SchedulerScheduleZone(key: _scheduleKey, track: d.track, now: now)
              : AnWashHighlight(
                  key: ValueKey('missed-wash-$_washSeq'),
                  child: SchedulerScheduleZone(key: _scheduleKey, track: d.track, now: now),
                ),
          AnSection(
            label: t.overview.failuresHead,
            children: d.failures.isEmpty
                ? [_emptyLine(context, t.overview.failuresEmpty)]
                : [for (final f in d.failures) _failureRow(context, f)],
          ),
        ],
      ),
    );
  }

  /// An honest quiet empty sentence under a zone head (no ghost frames). 区头下的诚实灰句。
  Widget _emptyLine(BuildContext context, String text) =>
      Text(text, style: AnText.body.copyWith(color: context.colors.inkFaint));

  /// «Failures · 7d» row: red dot · workflow name · ×N streak chip · error first line · the
  /// latest-run through-train. Replay waits for the run composite (S4). 失败聚合一行;replay 随 S4。
  Widget _failureRow(BuildContext context, FailingWorkflowRow f) {
    final t = context.t.scheduler.overview;
    void openLatest() {
      final id = f.latestRunId;
      if (id != null) context.go('/scheduler/w/${f.workflowId}/runs/$id');
    }

    return AnLedgerRow(
      lead: const AnStatusDot(AnStatus.err),
      primary: f.workflowName,
      mono: false,
      chips: [
        AnChip(t.streak(n: '${f.streak}'), tone: AnTone.danger),
        // The through-train renders only when the probe found a run — a dead affordance is a lie.
        // 直通车只在探到 run 时渲——没有目标就不做成可点。
        if (f.latestRunId != null)
          AnChip(t.latestRun, look: AnChipLook.outlined, onTap: openLatest),
      ],
      sub: f.error,
      subTone: AnTone.danger,
      onTap: f.latestRunId != null ? openLatest : null,
    );
  }

  /// The zero-data first-use card — the whole page collapses into one education card with the two
  /// deep links (Entities to build; chat to just say it). Ocean switching is provider-driven (not
  /// routed yet), same as the left-island switcher. 零数据教育卡:双深链走海洋 provider(未路由化)。
  Widget _firstUse(BuildContext context) {
    final t = context.t.scheduler.overview;
    return Center(
      child: AnState(
        kind: AnStateKind.empty,
        icon: AnIcons.scheduler,
        title: t.firstUseTitle,
        hint: t.firstUseBody,
        // Wrap, not Row: two buttons in AnState's 360 column overflow in en — they stack honestly.
        // Wrap 非 Row:360 列装不下两钮时诚实换行。
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: AnGap.inlineLoose,
          runSpacing: AnGap.stackTight,
          children: [
            AnButton(
              label: t.firstUseEntities,
              variant: AnButtonVariant.primary,
              onPressed: () =>
                  ref.read(selectedOceanProvider.notifier).select(OceanKind.entities),
            ),
            AnButton(
              label: t.firstUseChat,
              onPressed: () => ref.read(selectedOceanProvider.notifier).select(OceanKind.chat),
            ),
          ],
        ),
      ),
    );
  }
}

/// The KPI strip — equal [AnCard] tiles (running / waiting-on-you / failed-24h with its delta arrow /
/// next fire), plus a FIFTH「错过 N」tile that appears only when there is something to say (判决⑥).
///
/// **Why 「错过 0」 is not a tile.** 禁虚荣数字 军规: every KPI must pass the decision test — would this
/// number change what I do? A machine that was awake misses nothing, so 「错过 0」 is the normal state,
/// and a tile reading 0 every day for months is decoration that costs the other four a fifth of their
/// width. 「成功是背景音」: the absence of the tile IS the good news. It appears and disappears only on a
/// durable refetch, never on a tick — 活性军规 permits exactly that.
///
/// **The missed tile is the only tappable one, and that is not an inconsistency — it is the only one
/// that currently has somewhere true to go.** Its click reveals the schedule track, where the very
/// ticks it counted are the ✕ marks (same window, same predicate — see the anchor in
/// [SchedulerOverviewController]). The other four still owe their pre-filtered deep links (S2a recorded
/// the deviation, expecting the S3 big table to close it; S3 landed and they were never wired). They
/// stay inert rather than grow a click that lands somewhere approximate: 宪法 says a KPI must open the
/// list it counts, and a link to a nearby-but-different list is worse than none.
///
/// KPI 牌:四张等宽 + 第五张「错过 N」**有话说时才出现**(判决⑥)。**为何「错过 0」不成牌**:禁虚荣数字 军规——
/// 每个 KPI 须过决策测试(这个数会改变我做什么吗?);醒着的机器什么都不会错过,故「错过 0」是常态,一张天天读 0
/// 的牌是装饰,还要占掉另外四张五分之一的宽。成功是背景音:**牌不在,本身就是好消息**。它只随 durable 重取增删、
/// 绝不随 tick——活性军规恰好允许这一条。**错过牌是唯一可点的那张,这不是不一致——它是目前唯一有真去处的那张**:
/// 它点开调度轨,牌数的那些刻度正是轨上的 ✕(同窗、同谓词)。另外四张仍欠着各自的预过滤深链(S2a 记的偏差本指望
/// S3 大表来还,S3 落了却没接线)。它们**宁可保持不可点**,也不长出一个落在「差不多」的地方的点击:宪法说 KPI 必须
/// 点开它数的那个列表,而链到一个相近但不同的列表比没有链更糟。
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpi, required this.now, required this.onMissed});

  final SchedulerKpi kpi;
  final DateTime now;

  /// Reveal the ticks this strip's 「错过 N」 counted. 显出「错过 N」数的那些刻度。
  final VoidCallback onMissed;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    final nextFire = kpi.nextFire;
    final tiles = <Widget>[
      _tile(context, label: t.kpiRunning, value: AnCountUp(kpi.running, style: _valueStyle(c))),
      _tile(context, label: t.kpiWaiting, value: AnCountUp(kpi.waiting, style: _valueStyle(c))),
      _tile(
        context,
        label: t.kpiFailed24h,
        value: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnCountUp(kpi.failed24h, style: _valueStyle(c)),
            if (kpi.failedDelta != 0) ...[
              const SizedBox(width: AnGap.inline),
              Padding(
                padding: const EdgeInsets.only(bottom: AnSpace.s4),
                child: Semantics(
                  label: kpi.failedDelta > 0
                      ? t.deltaUpA11y(n: '${kpi.failedDelta}')
                      : t.deltaDownA11y(n: '${-kpi.failedDelta}'),
                  child: ExcludeSemantics(
                    child: Text(
                      kpi.failedDelta > 0
                          ? t.deltaUp(n: '${kpi.failedDelta}')
                          : t.deltaDown(n: '${-kpi.failedDelta}'),
                      style: AnText.metaTabular().copyWith(
                          color: kpi.failedDelta > 0 ? c.danger : c.ok),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      _tile(
        context,
        label: t.kpiNextFire,
        value: Text(
          nextFire != null && nextFire.isAfter(now)
              ? t.fireIn(d: fmtWaited(nextFire.difference(now)))
              : t.kpiNone,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _valueStyle(c),
        ),
      ),
      // The fifth tile — present only when it has news. 第五张牌:有话说才在场。
      if (kpi.missed > 0)
        Semantics(
          label: t.kpiMissedA11y(n: '${kpi.missed}'),
          button: true,
          child: ExcludeSemantics(
            child: _tile(
              context,
              label: t.kpiMissed,
              value: AnCountUp(kpi.missed, style: _valueStyle(c)),
              onTap: onMissed,
            ),
          ),
        ),
    ];
    // IntrinsicHeight equalizes the four tiles (the host Column hands the Row unbounded height, so
    // cross-axis stretch alone would blow up); four one-line tiles keep the pass cheap.
    // IntrinsicHeight 等高四牌(宿主 Column 给无界高,裸 stretch 会炸);单行牌代价可忽略。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AnGap.block),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  TextStyle _valueStyle(AnColors c) => AnText.h2.copyWith(color: c.ink);

  Widget _tile(BuildContext context,
      {required String label, required Widget value, VoidCallback? onTap}) {
    final c = context.colors;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnGap.stackTight),
        value,
      ],
    );
    // `selectable` is AnCard's «the whole card is one button» mode — the hover border IS the
    // affordance. It is not a selection: AnCard hands its `false` to AnInteractive, which routes it
    // through AnA11y.selected and therefore emits NOTHING (never `selected: false` — the pinned
    // engine reads an explicit false as «selected»).
    // selectable=AnCard 的「整卡即一个按钮」模式,hover 边即可供性。它**不是**选中:AnCard 把 false 交给
    // AnInteractive,后者经 AnA11y.selected 过滤 → **什么都不发**(绝不发 selected:false——钉住的引擎会把
    // 显式 false 念成「已选中」)。
    return onTap == null ? AnCard(child: body) : AnCard(selectable: true, onSelect: onTap, child: body);
  }
}
