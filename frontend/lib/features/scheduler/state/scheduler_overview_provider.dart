import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import '../data/scheduler_repository.dart';
import 'scheduler_rail_provider.dart';

// The Overview board's server-state (WRK-069 §3, S2a) — derived FROM the rail provider's truth
// (workflows/stats/triggers/edges) plus three probe fetches of its own (24h+48h failed totals for
// the KPI delta; running/failed flowrun rows per hot workflow). Watching the rail's future means
// this refetches exactly when the rail does — on durable frames, debounced — so the 活性军规 holds
// for free: ticks never reach this provider, geometry only moves on durable refetch.
// Overview 看板状态:派生自 rail 真相 + 自己的三类探针(24/48h 失败 totals、逐 workflow 在跑/最新失败
// run 行);watch rail.future = durable 去抖节拍同源,tick 永远到不了这里。

/// The KPI strip's numbers. [failedDelta] = failed(last 24h) − failed(previous 24h), derived from a
/// 24h + 48h dual stats read: delta = f24 − (f48 − f24). KPI 牌数字;delta=双窗差分。
class SchedulerKpi {
  const SchedulerKpi({
    required this.running,
    required this.waiting,
    required this.failed24h,
    required this.failedDelta,
    this.nextFire,
  });

  final int running;
  final int waiting;
  final int failed24h;
  final int failedDelta;

  /// The workspace's earliest FUTURE scheduled fire (from the rail's next-fire join). 全局最早未来调度。
  final DateTime? nextFire;
}

/// One live run row in the «正在跑» zone. 正在跑区一行。
class RunningRunRow {
  const RunningRunRow({required this.workflowId, required this.workflowName, required this.run});

  final String workflowId;
  final String workflowName;
  final Flowrun run;
}

/// One (trigger × workflow) pair firing within the next 24h. 未来 24h 一次调度。
class UpcomingFire {
  const UpcomingFire({
    required this.triggerId,
    required this.triggerName,
    required this.workflowId,
    required this.workflowName,
    required this.at,
  });

  final String triggerId;
  final String triggerName;
  final String workflowId;
  final String workflowName;
  final DateTime at;
}

/// One consecutively-failing workflow in the 7d aggregation. [error]/[latestRunId] come from the
/// latest-failed probe (`?status=failed&limit=1`) — absent when the probe returned nothing.
/// 失败聚合一行;错误首句与最新 run id 来自探针,取不到即缺席(不假造)。
class FailingWorkflowRow {
  const FailingWorkflowRow({
    required this.workflowId,
    required this.workflowName,
    required this.streak,
    this.error,
    this.latestRunId,
  });

  final String workflowId;
  final String workflowName;
  final int streak;
  final String? error;
  final String? latestRunId;
}

/// The whole board. [firstUse] = no workflows at all → the education card replaces the zones.
/// [waiting] is the rail fetch's enriched inbox verbatim (S2b — same rows the badge counts, so the
/// KPI tile, the badge and the zone can never disagree). 整块看板;firstUse=零 workflow → 教育卡替代
/// 全部区块;waiting=rail 同源 inbox 行(牌/徽/区三处同数)。
class SchedulerOverviewData {
  const SchedulerOverviewData({
    required this.firstUse,
    required this.kpi,
    this.waiting = const [],
    this.runningRuns = const [],
    this.upcoming = const [],
    this.failures = const [],
  });

  final bool firstUse;
  final SchedulerKpi kpi;
  final List<SchedulerInboxRow> waiting;
  final List<RunningRunRow> runningRuns;
  final List<UpcomingFire> upcoming;
  final List<FailingWorkflowRow> failures;
}

// ── pure derivations (unit-tested without pumping UI) 纯派生(免 UI 单测) ──

/// failed(last 24h) − failed(previous 24h). Positive = worsening (▲ red), negative = improving
/// (▼ green), 0 = hidden. delta=最近 24h 减前一个 24h。
int kpiFailedDelta({required int failed24, required int failed48}) =>
    failed24 - (failed48 - failed24);

/// The earliest FUTURE fire across the rail's per-workflow join. 全局最早未来 fire。
DateTime? earliestNextFire(Iterable<DateTime> fires, DateTime now) {
  DateTime? earliest;
  for (final f in fires) {
    if (!f.isAfter(now)) continue;
    if (earliest == null || f.isBefore(earliest)) earliest = f;
  }
  return earliest;
}

/// (trigger × equipped workflow) pairs whose nextFireAt lands within [window] of [now], time-ASC.
/// Only listening triggers with a future fire qualify; a trigger equipping N workflows emits N rows
/// (the ocean's axis is the workflow); an unequipped trigger fires no workflow → excluded.
/// 未来窗内 (trigger×workflow) 对,时间升序;一 trigger 挂 N workflow 出 N 行;未挂边者不产 run,不入列。
List<UpcomingFire> upcomingFires({
  required List<TriggerEntity> triggers,
  required List<EntityRelation> edges,
  required Map<String, String> workflowNames,
  required DateTime now,
  Duration window = const Duration(hours: 24),
}) {
  final horizon = now.add(window);
  final byTrigger = {for (final t in triggers) t.id: t};
  final out = <UpcomingFire>[];
  for (final e in edges) {
    final t = byTrigger[e.toId];
    final at = t?.nextFireAt;
    if (t == null || at == null || !t.listening) continue;
    if (!at.isAfter(now) || at.isAfter(horizon)) continue;
    out.add(UpcomingFire(
      triggerId: t.id,
      triggerName: t.name,
      workflowId: e.fromId,
      workflowName: workflowNames[e.fromId] ?? e.fromName,
      at: at,
    ));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Top-[n] consecutively-failing workflows, streak-DESC (ties keep stats order). 连败 Top-N 降序。
List<WorkflowRunStats> topFailing(Iterable<WorkflowRunStats> stats, {int n = 5}) {
  final failing = [
    for (final s in stats)
      if (s.consecutiveFailures > 0) s,
  ]..sort((a, b) => b.consecutiveFailures.compareTo(a.consecutiveFailures));
  return failing.length > n ? failing.sublist(0, n) : failing;
}

/// The first non-empty line of a wire error (backend errors arrive multi-line). 错误首句。
String? errorFirstLine(String? error) {
  if (error == null) return null;
  for (final line in error.split('\n')) {
    final t = line.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

class SchedulerOverviewController extends AsyncNotifier<SchedulerOverviewData> {
  @override
  Future<SchedulerOverviewData> build() async {
    // The rail is the pulse: it refetches only on durable frames (debounced), and its new value
    // re-runs this build — one refetch topology, zero extra subscriptions. rail 即节拍。
    final rail = await ref.watch(schedulerRailProvider.future);
    final repo = ref.read(schedulerRepositoryProvider);
    final now = DateTime.now();

    if (rail.workflows.isEmpty) {
      return const SchedulerOverviewData(
        firstUse: true,
        kpi: SchedulerKpi(running: 0, waiting: 0, failed24h: 0, failedDelta: 0),
      );
    }

    // KPI failed delta: totals are workspace-wide, so both probes go id-less (one call each).
    // KPI 失败差分:totals 全 workspace,免 ids 各取一次。
    final failing = topFailing(rail.stats.values);
    final runningIds = [
      for (final s in rail.stats.values)
        if (s.running > 0) s.workflowId,
    ];
    final results = await Future.wait<Object>([
      repo.stats(const [], since: '24h'),
      repo.stats(const [], since: '48h'),
      for (final id in runningIds) repo.listFlowruns(workflowId: id, status: 'running'),
      for (final s in failing)
        repo.listFlowruns(workflowId: s.workflowId, status: 'failed', limit: 1),
    ]);
    final stats24 = results[0] as SchedulerStats;
    final stats48 = results[1] as SchedulerStats;

    final names = {for (final w in rail.workflows) w.id: w.name};

    // Running rows: flatten the per-workflow pages, newest start first. 正在跑行:新启动在前。
    final runningRuns = <RunningRunRow>[];
    for (var i = 0; i < runningIds.length; i++) {
      final page = results[2 + i] as Page<Flowrun>;
      for (final run in page.items) {
        runningRuns.add(RunningRunRow(
          workflowId: runningIds[i],
          workflowName: names[runningIds[i]] ?? runningIds[i],
          run: run,
        ));
      }
    }
    runningRuns.sort((a, b) {
      final sa = a.run.startedAt, sb = b.run.startedAt;
      if (sa == null || sb == null) return sa == sb ? 0 : (sa == null ? 1 : -1);
      return sb.compareTo(sa);
    });

    // Failure aggregation: streak badge from stats, error first-line + deep link from the probe.
    // 失败聚合:连败徽来自 stats,错误首句+直通车来自探针。
    final failures = <FailingWorkflowRow>[];
    for (var i = 0; i < failing.length; i++) {
      final page = results[2 + runningIds.length + i] as Page<Flowrun>;
      final latest = page.items.isEmpty ? null : page.items.first;
      failures.add(FailingWorkflowRow(
        workflowId: failing[i].workflowId,
        workflowName: names[failing[i].workflowId] ?? failing[i].workflowId,
        streak: failing[i].consecutiveFailures,
        error: errorFirstLine(latest?.error),
        latestRunId: latest?.id,
      ));
    }

    return SchedulerOverviewData(
      firstUse: false,
      kpi: SchedulerKpi(
        running: stats24.totals.running,
        waiting: rail.inbox.length,
        failed24h: stats24.totals.failedSince,
        failedDelta: kpiFailedDelta(
            failed24: stats24.totals.failedSince, failed48: stats48.totals.failedSince),
        nextFire: earliestNextFire(rail.nextFireByWorkflow.values, now),
      ),
      waiting: rail.inbox,
      runningRuns: runningRuns,
      upcoming: upcomingFires(
          triggers: rail.triggers, edges: rail.edges, workflowNames: names, now: now),
      failures: failures,
    );
  }

  /// Manual retry (the error state's button). 手动重试。
  Future<void> retry() async {
    ref.invalidate(schedulerRailProvider);
    ref.invalidateSelf();
  }
}

final schedulerOverviewProvider =
    AsyncNotifierProvider<SchedulerOverviewController, SchedulerOverviewData>(
        SchedulerOverviewController.new);
