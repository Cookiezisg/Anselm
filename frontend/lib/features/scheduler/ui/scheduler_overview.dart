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
            child: _KpiStrip(kpi: d.kpi, now: now),
          ),
          // «等你处理» — the costliest land (S2b): inbox rows + in-place ApprovalGate + AnBatchBar
          // batch approve/reject; then «正在跑» with hover ⏹ + batch cancel. 等你处理(就地审批+批量)
          // 与 正在跑(hover 取消+批量取消)两操作区。
          SchedulerWaitingZone(rows: d.waiting, now: now),
          SchedulerRunningZone(rows: d.runningRuns, now: now),
          SchedulerScheduleZone(track: d.track, now: now),
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

/// The KPI strip — four equal [AnCard] tiles (running / waiting-on-you / failed-24h with its delta
/// arrow / next fire). Deliberately NOT tappable this batch: the pre-filtered deep links need the S3
/// big table — a click with no destination would be a lie (记偏差). KPI 牌:本拍刻意不可点,真过滤
/// 深链随 S3 大表;没有目标不做成可点。
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpi, required this.now});

  final SchedulerKpi kpi;
  final DateTime now;

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

  Widget _tile(BuildContext context, {required String label, required Widget value}) {
    final c = context.colors;
    return AnCard(
      child: Column(
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
      ),
    );
  }
}
