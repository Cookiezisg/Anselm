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

/// The Scheduler Overview board (WRK-069 §3, S2a) — `/scheduler` with nothing selected. Zones top-down
/// by how much they need a human: KPI strip → («等你处理» lands HERE with 工单④, S2b) → running now →
/// next-24h schedule → 7d failure aggregation; zero workflows collapses the whole page into one
/// first-use education card. 活性军规: the half-minute [AnTimePulse] refreshes TIME TEXT only (running
/// elapsed / next-fire relatives); rows appear/disappear only when the provider refetches on durable
/// frames. Saturated colour goes to red/amber only — success stays background hum.
/// Scheduler 总览看板:KPI 牌 → (S2b 等你处理落位于此)→ 正在跑 → 未来 24h → 失败聚合;零数据整页一张
/// 教育卡。脉搏只刷时间字,行增删只随 durable refetch;饱和色只给红/琥珀。
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
          // ── S2b slot ──「等你处理」 (the costliest land: inbox rows + ApprovalGate + AnBatchBar)
          // lands BETWEEN the KPI strip and «running now» once 工单④ ships. S2b 区在此落位。
          AnSection(
            label: t.overview.runningHead(n: '${d.runningRuns.length}'),
            children: d.runningRuns.isEmpty
                ? [_emptyLine(context, t.overview.runningEmpty)]
                : [for (final r in d.runningRuns) _runningRow(context, r, now)],
          ),
          AnSection(
            label: t.overview.upcomingHead,
            children: d.upcoming.isEmpty
                ? [_emptyLine(context, t.overview.upcomingEmpty)]
                : [for (final u in d.upcoming) _upcomingRow(context, u, now)],
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

  /// «Running now» row: status dot · workflow name · mono fr_ chip · live elapsed. Node progress
  /// needs the run detail (S4) — absent, not faked. Row taps into the run flagship. 正在跑一行;
  /// 节点进度依赖 run 详情(S4)缺席不假造;点行进 run 旗舰页。
  Widget _runningRow(BuildContext context, RunningRunRow r, DateTime now) {
    final started = r.run.startedAt;
    return AnLedgerRow(
      lead: AnStatusDot(AnStatus.fromRaw(r.run.status)),
      primary: r.workflowName,
      mono: false,
      chips: [
        AnChip(truncate(r.run.id, AnTrunc.id),
            mono: true, look: AnChipLook.outlined, tooltip: r.run.id),
      ],
      measure: started != null ? fmtWaited(now.difference(started)) : null,
      onTap: () => context.go('/scheduler/w/${r.workflowId}/runs/${r.run.id}'),
    );
  }

  /// «Next 24h» row: ⏱ · trigger name · workflow chip · relative fire time. Not tappable — the
  /// trigger exhibit lives in the operations home (S3). 未来 24h 一行;不可点(观测面随 S3)。
  Widget _upcomingRow(BuildContext context, UpcomingFire u, DateTime now) {
    final c = context.colors;
    return AnLedgerRow(
      lead: Icon(AnIcons.scheduler, size: AnSize.iconSm, color: c.inkFaint),
      primary: u.triggerName,
      mono: false,
      chips: [AnChip(u.workflowName, look: AnChipLook.outlined)],
      meta: context.t.scheduler.overview.fireIn(d: fmtWaited(u.at.difference(now))),
    );
  }

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
