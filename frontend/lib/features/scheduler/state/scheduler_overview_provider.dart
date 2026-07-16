import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/trigger_schedule.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import '../data/scheduler_repository.dart';
import '../scheduler_windows.dart';
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

/// One lane of the Overview's schedule track = one (workflow × cron trigger) pair. [futureAt] are the
/// endpoint's scheduled ticks inside the window; a [paused] lane legitimately carries NONE (the
/// backend refuses to stamp a next-fire on a paused trigger) and must still be shown, greyed (判决①).
/// Overview 时间轴的一条泳道=一个 (workflow × cron trigger) 对。futureAt=端点给的窗内刻度;**暂停**的
/// 泳道合法地一个都没有(后端拒绝给暂停的 trigger 盖下次时间戳),但仍必须灰显着出现(判决①)。
class ScheduleLane {
  const ScheduleLane({
    required this.triggerId,
    required this.triggerName,
    required this.workflowId,
    required this.workflowName,
    required this.paused,
    this.futureAt = const [],
  });

  final String triggerId;
  final String triggerName;
  final String workflowId;
  final String workflowName;
  final bool paused;
  final List<DateTime> futureAt;
}

/// The whole track. [truncated] rides straight from the endpoint — the window really holds more ticks
/// than [lanes] shows, and the board must SAY so rather than let the track read as complete.
/// 整条轨;truncated 原样来自端点——窗内确实还有更多刻度,看板必须**明说**,不能让轨道读起来像是全部。
class ScheduleTrackData {
  const ScheduleTrackData({this.lanes = const [], this.truncated = false});

  final List<ScheduleLane> lanes;
  final bool truncated;
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
    this.track = const ScheduleTrackData(),
    this.failures = const [],
  });

  final bool firstUse;
  final SchedulerKpi kpi;
  final List<SchedulerInboxRow> waiting;
  final List<RunningRunRow> runningRuns;
  final ScheduleTrackData track;
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

/// Build the schedule track's lanes (工单⑧ + 判决①).
///
/// **The lane set comes from the TRIGGER LIST, never from the schedule points** — this is the whole
/// hinge of 判决①. The endpoint only emits ticks for LISTENING, UNPAUSED crons, so reverse-deriving
/// lanes from points would make a paused trigger's lane silently vanish, and a vanished lane reads as
/// «there is no such schedule» instead of «you paused this». The points are hung ONTO the lanes.
///
/// Only cron triggers get a lane: webhook/fsnotify/sensor have no knowable next fire, so they are
/// honestly absent rather than present-and-empty (§3.4「仅 cron 有未来点,其余 kind 如实缺席」).
///
/// 泳道**行集取自 trigger 列表,绝不取自调度点**——这是判决① 的全部枢纽:端点只为**监听中且未暂停**的
/// cron 发刻度,故从点反推泳道会让暂停的 trigger 静默消失,而消失的泳道会被读成「没有这条排程」而非
/// 「你暂停了它」。点只是**挂**到泳道上。只有 cron 得泳道:webhook/fsnotify/sensor 下次 fire 不可知,
/// 故如实缺席,而非在场且空。
List<ScheduleLane> scheduleLanes({
  required List<TriggerEntity> triggers,
  required List<EntityRelation> edges,
  required Map<String, String> workflowNames,
  required TriggerSchedule schedule,
  required DateTime now,
  Duration window = SchedulerWindows.trackWindow,
}) {
  final horizon = now.add(window);
  final byTrigger = {for (final t in triggers) t.id: t};
  final out = <ScheduleLane>[];
  for (final e in edges) {
    final t = byTrigger[e.toId];
    if (t == null || t.kind != TriggerSource.cron) continue;
    final wfId = e.fromId;
    final at = <DateTime>[
      for (final p in schedule.points)
        // A point promises a run only for the workflows the listener table actually reverse-resolved
        // — so a point never lights a lane it cannot fire. 点只对监听表真反查出的 workflow 承诺运行。
        if (p.triggerId == t.id && p.workflowIds.contains(wfId))
          if (!p.at.isBefore(now) && !p.at.isAfter(horizon)) p.at,
    ]..sort();
    out.add(ScheduleLane(
      triggerId: t.id,
      triggerName: t.name,
      workflowId: wfId,
      workflowName: workflowNames[wfId] ?? e.fromName,
      paused: t.paused,
      futureAt: at,
    ));
  }
  // Soonest first; lanes with nothing coming (paused, or nothing due in the window) sink to the
  // bottom rather than disappear. 最近的在前;没有将至之事的泳道(暂停/窗内无刻度)沉底而非消失。
  out.sort((a, b) {
    final an = a.futureAt.isEmpty ? null : a.futureAt.first;
    final bn = b.futureAt.isEmpty ? null : b.futureAt.first;
    if (an == null && bn == null) return a.workflowName.compareTo(b.workflowName);
    if (an == null) return 1;
    if (bn == null) return -1;
    return an.compareTo(bn);
  });
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
      repo.stats(const [], since: SchedulerWindows.kpiFailedSince),
      repo.stats(const [], since: SchedulerWindows.kpiFailedDeltaSince),
      // The forward schedule (工单⑧) — ONE bounded call for the whole board's track. 整块看板的轨,一次有界调用。
      repo.triggerSchedule(within: SchedulerWindows.trackWithin),
      for (final id in runningIds) repo.listFlowruns(workflowId: id, status: 'running'),
      for (final s in failing)
        repo.listFlowruns(workflowId: s.workflowId, status: 'failed', limit: 1),
    ]);
    // The fixed head of the batch, NAMED: the two probe lists below index off it, and a bare `2`
    // repeated at three sites is one inserted call away from silently reading a stats object as a
    // page (a crash at best, the WRONG workflow's runs at worst).
    // 批次的定长头部,**具名**:下面两条探针列表按它取偏移;裸 2 抄在三处,只要插一个调用就会静默把 stats
    // 读成 page(轻则崩,重则读成**别的 workflow** 的 run)。
    const fixed = 3;
    final stats24 = results[0] as SchedulerStats;
    final stats48 = results[1] as SchedulerStats;
    final schedule = results[2] as TriggerSchedule;

    final names = {for (final w in rail.workflows) w.id: w.name};

    // Running rows: flatten the per-workflow pages, newest start first. 正在跑行:新启动在前。
    final runningRuns = <RunningRunRow>[];
    for (var i = 0; i < runningIds.length; i++) {
      final page = results[fixed + i] as Page<Flowrun>;
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
      final page = results[fixed + runningIds.length + i] as Page<Flowrun>;
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
      track: ScheduleTrackData(
        lanes: scheduleLanes(
          triggers: rail.triggers,
          edges: rail.edges,
          workflowNames: names,
          schedule: schedule,
          now: now,
        ),
        truncated: schedule.truncated,
      ),
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
