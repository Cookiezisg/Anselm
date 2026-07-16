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
    this.missed = 0,
    this.nextFire,
  });

  final int running;
  final int waiting;
  final int failed24h;
  final int failedDelta;

  /// Cron ticks that came due while the app was asleep, booked and never caught up, inside the SAME
  /// 24h window as [failed24h] (工单⑭/判决⑥). Straight from `totals.missed` — the number is the
  /// backend's count, never re-derived here from a page of rows (a page can be truncated; the count
  /// cannot). **Zero means the card is not rendered at all**, see [_KpiStrip]: 「错过 0」 fails the
  /// decision test — it is the normal state of a machine that was awake, and a tile reading 0 every
  /// day for months is decoration, which the 禁虚荣数字 军规 forbids. 「成功是背景音」.
  /// 睡着时到期、记账且不补跑的 cron 刻度,窗与 failed24h **同一个**。直接取 totals.missed——数字是后端数的,
  /// 绝不在此从一页行里重算(页会被截断,计数不会)。**0 即整张牌不渲**:「错过 0」过不了决策测试,是机器醒着的
  /// 常态,天天读 0 的牌是装饰(禁虚荣数字 军规);成功是背景音。
  final int missed;

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

/// One lane of the Overview's schedule track = one (workflow × cron trigger) pair, carrying BOTH
/// halves of the one timeline (判决⑥): [futureAt] are the schedule endpoint's forecast ticks, [firings]
/// are the durable rows for what really happened — the fires that became runs, the dispositions that
/// didn't, and the `missed` ticks the machine slept through. A [paused] lane legitimately carries NO
/// future ticks (the backend refuses to stamp a next-fire on a paused trigger) and must still be
/// shown, greyed (判决①) — and it may well still carry past [firings], from before it was paused.
/// Overview 时间轴的一条泳道=一个 (workflow × cron trigger) 对,**一条轴上两半**(判决⑥):futureAt=端点给的
/// 预告刻度,firings=真发生过的 durable 行(成了 run 的火 / 没成的处置 / 睡过去的 missed 刻度)。**暂停**的泳道
/// 合法地一个未来刻度都没有(后端拒绝给暂停的 trigger 盖下次时间戳)但仍须灰显着出现(判决①),且它很可能仍带着
/// 暂停之前的过去 firings。
class ScheduleLane {
  const ScheduleLane({
    required this.triggerId,
    required this.triggerName,
    required this.workflowId,
    required this.workflowName,
    required this.paused,
    this.futureAt = const [],
    this.firings = const [],
  });

  final String triggerId;
  final String triggerName;
  final String workflowId;
  final String workflowName;
  final bool paused;
  final List<DateTime> futureAt;

  /// The past half's durable rows, oldest→newest. The widget layer reads [Firing.status] to pick the
  /// mark's face (`missed` → the grey ✕, everything else → a solid dot in its status colour) — the
  /// discrimination lives in ONE place and reads the sealed enum, never a string literal.
  /// 过去半的 durable 行(旧→新)。widget 层读 status 挑脸(missed→灰 ✕,其余→状态色实心点)——判别只此一处,
  /// 且读的是封闭枚举、不是字符串字面量。
  final List<Firing> firings;
}

/// The whole track — both halves and their two INDEPENDENT honesty flags.
///
/// [truncated] rides straight from the schedule endpoint: the window really holds more forecast ticks
/// than [lanes] shows. [pastTruncated] is the past half's twin and is a sharper hazard: the firing
/// ledger is unbounded and pages newest-first, so a truncated page means everything before
/// [pastFrom] is UNKNOWN rather than empty — drawn naively, the track would look complete while
/// hiding a hole, which is worse than not drawing it (the very reason S5 shipped no past half at all).
/// So [pastFrom] names where the trustworthy data starts and the zone says it out loud.
/// 整条轨与它**两个独立**的诚实旗标。truncated 原样来自调度端点(窗内还有更多**预告**刻度)。pastTruncated 是
/// 过去半的孪生,且危险得多:firing 账无界、按新→旧翻页,故截断意味着 pastFrom 之前是**未知**而非**空**——照直
/// 画,轨道会看起来完整却藏着一个洞,那比不画更糟(S5 当初干脆不发过去半正是为此)。故 pastFrom 点名可信数据从
/// 哪里开始,并由区**明说**。
class ScheduleTrackData {
  const ScheduleTrackData({
    this.lanes = const [],
    this.truncated = false,
    this.pastTruncated = false,
    this.pastFrom,
  });

  final List<ScheduleLane> lanes;
  final bool truncated;
  final bool pastTruncated;
  final DateTime? pastFrom;
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
/// [firings] hangs the PAST half onto the same lanes (工单⑭/判决⑥), by the (trigger × workflow) pair
/// the row records. Rows older than [pastWindow] are dropped — the axis has no room for them — and the
/// window's floor is the SAME instant the 「错过 N」 card counted from, so a tick the card counts can
/// never be off the axis of the surface the card's click opens.
List<ScheduleLane> scheduleLanes({
  required List<TriggerEntity> triggers,
  required List<EntityRelation> edges,
  required Map<String, String> workflowNames,
  required TriggerSchedule schedule,
  required DateTime now,
  List<Firing> firings = const [],
  Duration window = SchedulerWindows.trackWindow,
  Duration pastWindow = SchedulerWindows.trackPastWindow,
}) {
  final horizon = now.add(window);
  final floor = now.subtract(pastWindow);
  final byTrigger = {for (final t in triggers) t.id: t};
  // Only the rows the axis can hold. The lower bound mirrors the card's `createdAfter` exactly and
  // there is deliberately NO upper bound (the card has none either — its window is [since, ∞)); the
  // axis itself clips anything past the horizon. 只留轴装得下的行:下界逐字同牌的 createdAfter,且**刻意无上界**
  // (牌也没有——它的窗是 [since, ∞));越过视野的由轴自己裁。
  final inWindow = [
    for (final f in firings)
      if (!f.createdAt.isBefore(floor)) f,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final out = <ScheduleLane>[];
  final claimed = <String>{};
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
    claimed.add('${t.id}/$wfId');
    out.add(ScheduleLane(
      triggerId: t.id,
      triggerName: t.name,
      workflowId: wfId,
      workflowName: workflowNames[wfId] ?? e.fromName,
      paused: t.paused,
      futureAt: at,
      firings: [
        for (final f in inWindow)
          if (f.triggerId == t.id && f.workflowId == wfId) f,
      ],
    ));
  }
  // A `missed` tick whose lane no longer exists — the workflow stopped listening to that trigger, or
  // the trigger was deleted, since the tick came due — still HAPPENED, and the 「错过 N」 card still
  // counts it. Dropping it would make the card's number disagree with the ✕ marks its own click opens:
  // the one bug shape this ocean legislates against. So it gets a lane built from the durable firing
  // row itself.
  //
  // This does NOT break 判决①'s «lanes come from the trigger list, never from the points» — that law
  // guards the FUTURE half, where reverse-deriving lanes from points would make a paused trigger's lane
  // silently vanish (it emits no points) and read as «there is no such schedule». A missed firing is
  // not a forecast; it is a durable fact, and a fact must have somewhere to be shown. Only `missed`
  // earns this: an orphaned started/skipped row is context nothing counts, so it stays dropped.
  //
  // 一个**泳道已不存在**的 missed 刻度(刻度到期之后 workflow 不再监听那个 trigger、或 trigger 被删)**仍然发生过**,
  // 而「错过 N」牌**仍然数着它**。丢掉它就会让牌的数字与它自己点开的那些 ✕ 对不上——本海洋立法明禁的那一种 bug。
  // 故它从 durable firing 行本身长出一条泳道。这**不破**判决① 的「泳道行集取自 trigger 列表、绝不取自点」:
  // 那条法守的是**未来**半(从点反推会让暂停的泳道静默消失、被读成「没有这条排程」);missed firing 不是预告、
  // 是 durable **事实**,而事实必须有地方可显示。只有 missed 配得上这条:孤儿 started/skipped 行是没人数的上下文,
  // 照旧丢弃。
  final orphans = <String, List<Firing>>{};
  for (final f in inWindow) {
    if (f.status != FiringStatus.missed) continue;
    final key = '${f.triggerId}/${f.workflowId}';
    if (claimed.contains(key)) continue;
    (orphans[key] ??= []).add(f);
  }
  for (final entry in orphans.entries) {
    final f = entry.value.first;
    out.add(ScheduleLane(
      triggerId: f.triggerId,
      triggerName: byTrigger[f.triggerId]?.name ?? '',
      workflowId: f.workflowId,
      workflowName: workflowNames[f.workflowId] ?? f.workflowId,
      paused: byTrigger[f.triggerId]?.paused ?? false,
      firings: entry.value,
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
    // ── THE anchor (工单⑭/判决⑥) ──────────────────────────────────────────────────────────────────
    // ONE instant, computed once, sent to every surface that speaks about this window: `?since=` on the
    // stats call whose `totals.missed` IS the 「错过 N」 card, `?createdAfter=` on the firing page the
    // card's ✕ marks come from, and the track's past floor. The endpoints take RFC3339 absolute
    // (api.md), so the backend does not resolve a second anchor of its own — which is the whole point:
    // a relative `'24h'` would have the server count from ITS now while we drew from OURS, and the two
    // predicates would silently disagree at the window's edge. 「牌上写 3、点开列表显示 4」 is not a
    // rounding error here; it is the bug this ocean was legislated against, so the two must be the SAME
    // value rather than two values that usually match.
    // **一个**锚点,只算一次,发给每一个谈论这个窗口的面:stats 的 ?since=(其 totals.missed **就是**「错过 N」牌)、
    // ✕ 所来自的那页 firing 的 ?createdAfter=、以及轨道过去半的地板。端点收 RFC3339 绝对起点,故后端**不会**另解
    // 第二个锚——这正是要害:相对词 '24h' 会让服务端按**它的** now 数、而我们按**我们的** now 画,两份谓词在窗口边缘
    // 静默打架。「牌上写 3、点开列表显示 4」在此不是舍入误差,是本海洋立法所禁的那个 bug,故两者必须是**同一个值**、
    // 而非两个通常吻合的值。
    final kpiSince = now.subtract(SchedulerWindows.kpiWindow);
    final results = await Future.wait<Object>([
      repo.stats(const [], since: kpiSince.toUtc().toIso8601String()),
      repo.stats(const [],
          since: now.subtract(SchedulerWindows.kpiDeltaWindow).toUtc().toIso8601String()),
      // The forward schedule (工单⑧) — ONE bounded call for the whole board's track. 整块看板的轨,一次有界调用。
      repo.triggerSchedule(within: SchedulerWindows.trackWithin),
      // The past half (工单⑭), in TWO deliberate calls rather than one:
      //   [3] every firing in the window — the solid dots for what really fired. Newest-first and
      //       capped, so it may be a partial view; that is reported, not hidden (pastTruncated).
      //   [4] the missed ones ALONE, on the card's exact predicate. This one cannot be quietly
      //       incomplete the way a slice of [3] could: 200 rows of a chatty cron could push every ✕ off
      //       the newest-first page while the card still counted them. The card's evidence gets its own
      //       query so its completeness does not depend on how busy the other triggers were.
      // 过去半(工单⑭),**刻意**两次调用而非一次:[3] 窗内所有 firing(真开过的火=实心点;新→旧且有帽,故可能只是
      // 一部分——那要**报告**、不是藏起来);[4] **单取** missed,走牌的精确谓词——它不能像 [3] 的切片那样悄悄不全:
      // 一个话痨 cron 的 200 行足以把每一个 ✕ 挤出「最新一页」,而牌照数不误。牌的证据自己一条查询,其完整性不取决于
      // 别的 trigger 有多忙。
      repo.listFirings(createdAfter: kpiSince, limit: SchedulerWindows.firingPageLimit),
      repo.listFirings(
          status: FiringStatus.missed,
          createdAfter: kpiSince,
          limit: SchedulerWindows.firingPageLimit),
      for (final id in runningIds) repo.listFlowruns(workflowId: id, status: 'running'),
      for (final s in failing)
        repo.listFlowruns(workflowId: s.workflowId, status: 'failed', limit: 1),
    ]);
    // The fixed head of the batch, NAMED: the two probe lists below index off it, and a bare `2`
    // repeated at three sites is one inserted call away from silently reading a stats object as a
    // page (a crash at best, the WRONG workflow's runs at worst).
    // 批次的定长头部,**具名**:下面两条探针列表按它取偏移;裸 2 抄在三处,只要插一个调用就会静默把 stats
    // 读成 page(轻则崩,重则读成**别的 workflow** 的 run)。
    const fixed = 5;
    final stats24 = results[0] as SchedulerStats;
    final stats48 = results[1] as SchedulerStats;
    final schedule = results[2] as TriggerSchedule;
    final firedPage = results[3] as Page<Firing>;
    final missedPage = results[4] as Page<Firing>;
    // Merge the two pages into the ONE past-half set: the missed-only page is authoritative for ✕, so
    // the general page contributes everything EXCEPT missed and the two can never double-mark a tick.
    // 两页并成**一份**过去半:missed 单取那页对 ✕ 是权威,故通用页只贡献 **非** missed 的行,两者绝不把同一刻度
    // 标记两次。
    final pastFirings = <Firing>[
      for (final f in firedPage.items)
        if (f.status != FiringStatus.missed) f,
      ...missedPage.items,
    ];

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
        // The backend's count, on the same `since` the ✕ below were fetched with. 后端数的,窗同下面的 ✕。
        missed: stats24.totals.missed,
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
          firings: pastFirings,
          now: now,
        ),
        truncated: schedule.truncated,
        // Either page hitting the cap means the past half is a NEWEST-first slice, so everything before
        // the oldest row we hold is unknown. 任一页撞帽 = 过去半只是最新那一片,故我们手上最老那行之前是未知。
        pastTruncated: firedPage.hasMore || missedPage.hasMore,
        pastFrom: (firedPage.hasMore || missedPage.hasMore) && pastFirings.isNotEmpty
            ? pastFirings.map((f) => f.createdAt).reduce((a, b) => a.isBefore(b) ? a : b)
            : null,
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
