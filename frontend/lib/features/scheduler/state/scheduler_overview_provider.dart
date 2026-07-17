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

  /// How many runs are in flight — **`SchedulerOverviewData.runningRuns.length`, and nothing else**.
  ///
  /// The tile deep-links to the 「正在跑」 zone, which renders one row per element of that very list, so
  /// the number and the list are the SAME FACT and must have ONE source. The tempting alternative —
  /// `flowrun-stats`' authoritative `totals.running` — is a SECOND count of the same thing, taken from
  /// a second query at a second instant, and «the tile says 3, the list it opens shows 2» is the bug
  /// this ocean was legislated against. (It was also live: totals counts orphan runs whose host is
  /// soft-deleted, and the zone's old per-workflow probe loop could never reach them.) A count that
  /// can only ever be `list.length` cannot drift from the list.
  ///
  /// 在飞的 run 数——**就是 `runningRuns.length`,别无来源**。牌深链到「正在跑」区,而那个区是这份列表的逐元素
  /// 投影,故数字与列表是**同一个事实**、必须只有**一个**源。诱人的替代品——flowrun-stats 那个权威的
  /// `totals.running`——是**同一件事的第二次计数**:第二条查询、第二个瞬间;而「牌上写 3、点开列表显示 2」正是本
  /// 海洋立法所禁的那个 bug(且它**曾经是活的**:totals 数着宿主已软删的孤儿 run,而区里旧的逐 workflow 探针循环
  /// 永远够不到它们)。一个只可能等于 `list.length` 的数,漂不出那份列表。
  final int running;

  /// How many decisions are waiting on you — **`SchedulerOverviewData.waiting.length`**, the same rows
  /// the zone renders and the rail's badge counts (工单④'s inbox, one fetch, one truth).
  ///
  /// NOT `totals.parkedNodes`, which despite its wire name counts RUNS (a run parked on two approvals
  /// is one there and two rows here) — a plausible-looking second source that answers a different
  /// question. 等你决策的条数——**就是 `waiting.length`**:区渲的那些行、rail 徽数的那些行(⑤ 收件箱,一次取数
  /// 一份真相)。**不是** `totals.parkedNodes`:它虽叫这个名,数的却是 **run**(一个 run park 在两个审批上,在那边是 1、
  /// 在这里是 2 行)——一个看起来很像、答的却是另一个问题的第二源。
  final int waiting;

  /// How many runs FAILED in the last 24h — **`SchedulerOverviewData.failedRuns.length`** (工单⑮).
  ///
  /// This tile could not be clicked until 工单⑮ gave `GET /flowruns` a `completedAfter` window: the
  /// number counts runs that REACHED failed inside the window (`failedSince` windows on completed_at),
  /// and before ⑮ every run list this ocean could ask for windowed on `started_at`, so a list built
  /// from those would drop the run that started 30h ago and failed an hour ago and include the one that
  /// started inside the window and is still running — not the runs the tile counts. Now the tile opens
  /// the drained `listFailedSince(kpiSince)` list, on the byte-identical predicate `failedSince` counts
  /// with, so — same as [running]/[waiting] — the number IS that list's length, not a second count.
  /// **NOT** the 7d 「失败聚合」 zone: that aggregates WORKFLOWS by streak, a different window and unit;
  /// linking there would make the tile say 4 and open a zone that self-healed to empty.
  ///
  /// 近 24h **失败**的 run 数——**就是 `failedRuns.length`**(工单⑮)。工单⑮ 给 `GET /flowruns` 加
  /// `completedAfter` 窗之前这张牌点不开:数字数的是窗内**落定**为 failed 的 run(failedSince 按 completed_at
  /// 开窗),而 ⑮ 前本海洋能问到的每份 run 列表都按 started_at 开窗——会漏掉 30h 前起跑一小时前失败的、又混进
  /// 窗内起跑还在跑的。现在牌点开 `listFailedSince(kpiSince)` 拉全的列表、走 failedSince 所数的**逐字节相同**
  /// 谓词,故同 running/waiting——数字**就是**那份列表的长度、非第二次计数。**不是** 7d「失败聚合」区:那按
  /// 连败聚合 **workflow**、窗与单位都不同,链去那里会让牌写 4、点开一个已自愈成空的区。
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

  /// The workspace's earliest FUTURE scheduled fire (from the rail's next-fire join) — the truest
  /// global answer to «when does my automation next do something», with NO horizon: a weekly cron three
  /// days out is still the next fire and the tile says so.
  ///
  /// It is deliberately NOT re-sourced from the track's own ticks, and the tile pays for that by only
  /// being clickable when [nextFireOnTrack] says the instant it names is really on the axis — see
  /// there for why a shared value would have been a lie in both directions.
  ///
  /// 全局最早未来调度(取自 rail 的 next-fire join)——对「我的自动化下一次做事是什么时候」最真的答案,且**无视野
  /// 上限**:三天后的周 cron 仍然是下一次,牌就这么说。它**刻意不**改从轨道自己的刻度取数,代价是这张牌只在
  /// [nextFireOnTrack] 判定「它念的那个时刻真在轴上」时才可点——为何共用一个值反而两头都是谎,见那里。
  final DateTime? nextFire;
}

/// One live run row in the «正在跑» zone. 正在跑区一行。
class RunningRunRow {
  const RunningRunRow({required this.workflowId, required this.workflowName, required this.run});

  final String workflowId;
  final String workflowName;
  final Flowrun run;
}

/// One failed run in the 「24h 失败」 zone — the per-RUN list the KPI tile opens (工单⑮), NOT to be
/// confused with the 7d per-WORKFLOW aggregation ([FailingWorkflowRow]): different window (24h vs 7d),
/// different unit (run vs workflow). A run whose host is soft-deleted falls back to the bare id and
/// stays (same as the running zone — it failed, the tile counts it, so the zone shows it).
/// 「24h 失败」区的一行=牌点开的那份**按 run** 的列表(工单⑮),与 7d **按 workflow** 的聚合
/// ([FailingWorkflowRow]) 不是一回事:窗不同(24h vs 7d)、单位不同(run vs workflow)。宿主软删的 run
/// 回落裸 id 且留下(同正在跑区——它失败了、牌数着它,故区显示它)。
class FailedRunRow {
  const FailedRunRow({required this.workflowId, required this.workflowName, required this.run});

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
    this.failedRuns = const [],
    this.track = const ScheduleTrackData(),
    this.failures = const [],
    this.triggersById = const {},
  });

  final bool firstUse;
  final SchedulerKpi kpi;
  final List<SchedulerInboxRow> waiting;
  final List<RunningRunRow> runningRuns;

  /// The rail's already-fetched triggers, keyed by id — the run-phrase grammar's join (WRK-070 B10):
  /// the 「正在跑」/「24h 失败」 zones speak each run as «workflow · source phrase» with [runPhrase],
  /// which resolves a webhook path / fsnotify·sensor trigger name through THIS map (zero N+1, same
  /// join the big table's rows use). 行短语文法的连接:两区经此念「workflow · 来源短语」,零 N+1。
  final Map<String, TriggerEntity> triggersById;

  /// The 「24h 失败」 zone's rows — the per-run list the KPI tile opens (工单⑮). Its length equals
  /// [kpi].failed24h by construction (same predicate/instant as `failedSince`, drained).
  /// 「24h 失败」区的行——牌点开的按 run 列表(工单⑮);长度按构造等于 kpi.failed24h。
  final List<FailedRunRow> failedRuns;
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

/// Is the instant the 「下次调度」 card NAMES actually drawn on the track it would open?
///
/// **The card's affordance is derived from the presence of its own evidence, not from a hope that two
/// sources agree** — because here they genuinely cannot be made to agree by construction, and pretending
/// otherwise would be the lie. The card's value comes from `triggers.nextFireAt`; the track's ticks come
/// from `trigger-schedule`. Two endpoints, each projecting `cron.Next` at ITS OWN read instant, joined
/// through two different tables (relation edges vs the live listen registry), and only one of them
/// clipped to a 24h horizon. Three ways for the named instant to be off the axis, all real:
///   - **beyond the horizon** — a weekly cron's next fire is honest news for the card and simply is not
///     in the next 24h the track draws;
///   - **a lane the registry did not resolve** — equipped (edge) but not listening for that workflow, so
///     no point hangs there;
///   - **a straddled boundary** — the two calls land either side of a minute cron's tick and the two
///     projections differ by a whole period.
///
/// So: click iff the tick is there. 宪法 says a KPI must open the list it counts, and 「宁可不可点」 —
/// an inert card beats a click that scrolls to an axis the named tick is not on. Equality is by INSTANT
/// (`isAtSameMomentAs`) — the two projections of one cron expression are the same absolute moment, and
/// `DateTime ==` would additionally demand both sides agree about being UTC, which is a fact about the
/// parse, not about the schedule.
///
/// 「下次调度」牌**念出**的那个时刻,真的画在它要打开的那条轨上吗?**牌的可点性派生自它自己的证据在不在场,而不是
/// 派生自「两个源但愿一致」**——因为此处两者**构造上就是没法做到一致**,假装能才是那个谎:牌的值来自
/// `triggers.nextFireAt`,轨的刻度来自 `trigger-schedule`——两个端点、各自在**自己的**读时投影 `cron.Next`、经**两张
/// 不同的表**连接(relation 边 vs 活的监听表),且只有其中一个被钳在 24h 视野里。三条让「被念到的时刻落在轴外」的路
/// 都是真的:①**越过视野**(周 cron 的下次对牌是诚实的消息,但它本就不在轨画的这 24h 里);②**监听表没解出的泳道**
/// (装备了边、却没为那个 workflow 监听,故没有点挂在那儿);③**跨过边界**(两次调用落在分钟 cron 刻度两侧,两个投影
/// 差出整整一个周期)。故:**刻度在,才可点**。宪法要的是「点开它数的那个列表」,而「宁可不可点」——一张惰性的牌,
/// 胜过一次滚到「所念刻度并不在其上」的轴的点击。**按瞬间**比较(`isAtSameMomentAs`):一条 cron 表达式的两次投影是
/// 同一个绝对时刻,而 `DateTime ==` 还会额外要求两边对「是不是 UTC」达成一致——那是关于**解析**的事实,不是关于**排程**的。
bool nextFireOnTrack(ScheduleTrackData track, DateTime? nextFire) {
  if (nextFire == null) return false;
  for (final lane in track.lanes) {
    for (final at in lane.futureAt) {
      if (at.isAtSameMomentAs(nextFire)) return true;
    }
  }
  return false;
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
      // The 「正在跑」 zone AND its KPI tile, from ONE workspace-wide question (see listRunningRuns) —
      // never a loop over the workflow list, which cannot see an orphan's run and would therefore hand
      // the tile a list shorter than the fact it counts.
      // 「正在跑」区**与**它那张牌,出自**一次**工作区级提问(见 listRunningRuns)——绝不逐 workflow 循环:那看不见
      // 孤儿的 run,于是递给牌一份比它所数的事实更短的列表。
      repo.listRunningRuns(),
      // The 「24h 失败」 zone AND its KPI tile deep-link, from ONE workspace-wide question on the SAME
      // `kpiSince` the stats call above counted `failedSince` from (see listFailedSince). Its length
      // equals stats24.totals.failedSince by construction — same predicate, same instant, drained —
      // which is the only thing that lets the tile open «the list it counts» without 「牌上写 3、点开
      // 列表显示 4」. 「24h 失败」区**与**它那张牌的深链,出自**一次**工作区级提问、用的是上面 stats 数
      // failedSince 所用的**同一个** kpiSince——其长度按构造等于 failedSince(同谓词、同时刻、拉全)。
      repo.listFailedSince(kpiSince),
      for (final s in failing)
        repo.listFlowruns(workflowId: s.workflowId, status: 'failed', limit: 1),
    ]);
    // The fixed head of the batch, NAMED: the probe list below indexes off it, and a bare `6` repeated
    // at two sites is one inserted call away from silently reading a stats object as a page (a crash at
    // best, the WRONG workflow's runs at worst).
    // 批次的定长头部,**具名**:下面那条探针列表按它取偏移;裸 6 抄在两处,只要插一个调用就会静默把 stats
    // 读成 page(轻则崩,重则读成**别的 workflow** 的 run)。
    const fixed = 7;
    final stats24 = results[0] as SchedulerStats;
    final stats48 = results[1] as SchedulerStats;
    final schedule = results[2] as TriggerSchedule;
    final firedPage = results[3] as Page<Firing>;
    final missedPage = results[4] as Page<Firing>;
    final liveRuns = results[5] as List<Flowrun>;
    final failedRuns0 = results[6] as List<Flowrun>;
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

    // Running rows: name each run from the workflow list, newest start first. A run whose host is
    // soft-deleted has no name to join — it falls back to the bare id (the relation-Namer precedent,
    // same as the inbox's enrich) and STAYS: it is running, the tile counts it, so the zone shows it.
    // 正在跑行:逐 run 从 workflow 列表取名,新启动在前。宿主已软删的 run join 不到名字——回落**裸 id**
    // (relation-Namer 先例,同收件箱的 enrich)且**留下**:它在跑、牌数着它,故区显示它。
    final runningRuns = [
      for (final run in liveRuns)
        RunningRunRow(
          workflowId: run.workflowId,
          workflowName: names[run.workflowId] ?? run.workflowId,
          run: run,
        ),
    ];
    runningRuns.sort((a, b) {
      final sa = a.run.startedAt, sb = b.run.startedAt;
      if (sa == null || sb == null) return sa == sb ? 0 : (sa == null ? 1 : -1);
      return sb.compareTo(sa);
    });

    // Failed-in-24h rows: name each run, newest-LANDED first (completed_at — the window's axis, and
    // the field the tile counts on; a null completed_at cannot appear here because the query filters
    // it out). 24h 失败行:逐 run 取名,按**落定**时刻新→旧(completed_at 即窗轴、也是牌所数的列;查询已
    // 剔除 completed_at 为 NULL 的行故这里不可能出现)。
    final failedRuns = [
      for (final run in failedRuns0)
        FailedRunRow(
          workflowId: run.workflowId,
          workflowName: names[run.workflowId] ?? run.workflowId,
          run: run,
        ),
    ];
    failedRuns.sort((a, b) {
      final ca = a.run.completedAt, cb = b.run.completedAt;
      if (ca == null || cb == null) return ca == cb ? 0 : (ca == null ? 1 : -1);
      return cb.compareTo(ca);
    });

    // Failure aggregation: streak badge from stats, error first-line + deep link from the probe.
    // 失败聚合:连败徽来自 stats,错误首句+直通车来自探针。
    final failures = <FailingWorkflowRow>[];
    for (var i = 0; i < failing.length; i++) {
      final page = results[fixed + i] as Page<Flowrun>;
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
        // THREE tiles are now `list.length` of the very list their click opens — see the fields' docs
        // for why the authoritative-looking backend counts (`totals.running` / `totals.parkedNodes` /
        // `totals.failedSince`) are the wrong SOURCE for the displayed number: each is a second count at
        // a second instant, and 口径同源 means the tile IS the list, not a number that usually matches it.
        // 三张牌现在都是它们点击所打开的**那份列表**的 length——为何那些看着更权威的后端计数(running/
        // parkedNodes/failedSince)在此是错的**源**:每个都是「第二个瞬间的第二次计数」,而口径同源意味着牌
        // **就是**列表、不是一个通常吻合的数。
        running: runningRuns.length,
        waiting: rail.inbox.length,
        // The list `listFailedSince(kpiSince)` opens IS the tile now (工单⑮). Drained + same predicate +
        // same instant as `failedSince` ⇒ its length equals the backend count (TestListRuns_CompletedWindow
        // proves it), so taking `.length` cannot 「牌上写 3、点开列表显示 4」 even if a run fails between the
        // stats read and this one. failed24h = 它点开的列表的 length(工单⑮)。
        failed24h: failedRuns.length,
        // The delta is a secondary annotation and needs BOTH windows, so it stays stats-based (a list
        // for the prior 24h is not fetched); at the boundary failed24 == failedRuns.length. delta 是次要
        // 标注、需两个窗,故仍走 stats;边界处 failed24 == failedRuns.length。
        failedDelta: kpiFailedDelta(
            failed24: stats24.totals.failedSince, failed48: stats48.totals.failedSince),
        // The backend's count, on the same `since` the ✕ below were fetched with. 后端数的,窗同下面的 ✕。
        missed: stats24.totals.missed,
        nextFire: earliestNextFire(rail.nextFireByWorkflow.values, now),
      ),
      waiting: rail.inbox,
      runningRuns: runningRuns,
      failedRuns: failedRuns,
      // The run-phrase join, from the rail's already-fetched triggers (B10 — same source the big
      // table uses; a webhook run without it would read as the bare kind word). 行短语连接。
      triggersById: {for (final tr in rail.triggers) tr.id: tr},
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
