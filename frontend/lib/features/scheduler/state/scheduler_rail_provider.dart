import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/bool_pref.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/runtime.dart';
import '../../../core/sse/sse_gateway.dart';
import '../../../core/ui/an_time_pulse.dart';
import '../data/scheduler_repository.dart';

/// Everything the Scheduler rail projects (WRK-069 §2) — workflows + per-workflow health + the
/// next-fire join + the enriched flowrun [inbox]. The raw [triggers]/[edges] ride along so the
/// Overview's schedule zone derives from the SAME fetch (one truth, no double drain); likewise the
/// rail's waiting badge and the Overview's «等你处理» zone both read [inbox] (S2b — the badge is its
/// length, the zone its rows, so the two can never disagree). DB rows are the truth; frames only
/// trigger refetch. rail 的全部输入;行是真相,帧只触发 refetch;triggers/edges 与 inbox 原样带出供
/// Overview 同源派生(徽=length、区=行,两处数天然一致,不二次拉取)。
class SchedulerRailData {
  const SchedulerRailData({
    required this.workflows,
    required this.stats,
    required this.nextFireByWorkflow,
    this.inbox = const [],
    this.triggers = const [],
    this.edges = const [],
  });

  final List<SchedulerWorkflowRow> workflows;
  final Map<String, WorkflowRunStats> stats;
  final Map<String, DateTime> nextFireByWorkflow;

  /// Every parked approval waiting on a human (enriched, 工单④). 收件箱 enrich 行。
  final List<SchedulerInboxRow> inbox;

  /// The rail's ONE number — derived, never a second fetch. rail 唯一数字(派生,绝不二次拉)。
  int get waitingCount => inbox.length;

  final List<TriggerEntity> triggers;
  final List<EntityRelation> edges;
}

/// The STALENESS fingerprint of a cached next-fire join: the fires that have slipped into the PAST,
/// canonically ordered — null while every cached fire is still ahead of [now].
///
/// A past next-fire is never news about the SCHEDULE; it is news about our SNAPSHOT. The backend
/// computes `nextFireAt` as `cron.Next(time.Now())` at READ time (a `db:"-"` projection, not a stored
/// column — `app/trigger/lifecycle.go`), so a listening trigger's answer is future BY CONSTRUCTION;
/// the only way we can be holding a past one is that our copy aged. Close the laptop at 17:00, open
/// it at 09:05 and EVERY cached fire is yesterday's. Filtering those out of the KPI / rail meta is
/// right («in -5m» is nonsense) — but filtering them out WITHOUT refetching renders «—» over a
/// workflow that fires at 09:00 every morning, and if that fire was booked `missed` (判决⑥ — the
/// sleeping machine, which produces no run at all) no durable frame will ever arrive to heal it.
/// So: stale ⇒ our data expired ⇒ refetch. Never «there is no schedule».
///
/// The fingerprint is what makes ONE ask per answer provable: ask, and if the wire hands back the
/// same past instants, that IS the answer — stop asking (see [SchedulerRailController._onPulse]).
///
/// 陈旧指纹:已滑入过去的缓存 fire(规范序);全部仍在未来则 null。过去的 next-fire 从来不是「调度」的消息,
/// 而是「我们这份快照」的消息——后端的 nextFireAt 是**读时投影**(`cron.Next(now())`,`db:"-"` 非存储列),
/// 监听中的 trigger 给出的答案**按构造**必在未来;我们手里会有过去值,只可能是自己的副本变老了:17:00 合盖、
/// 09:05 开盖,每个缓存 fire 都是昨天的。把它们滤出 KPI/rail meta 是对的(「in -5m」是胡话),但滤掉**却不
/// 重取**,就会在一个每天 09:00 都跑的 workflow 上渲「—」;而若那次 fire 被记成 missed(判决⑥ 的睡眠机器:
/// 根本不产生 run),永远不会有 durable 帧来治它。故:陈旧 ⇒ 数据过期 ⇒ 重取,绝不说「没有调度」。
/// 指纹让「一个答案只问一次」可证:问过了、线缆递回同样的过去时刻,那**就是**答案——别再问。
String? staleFireFingerprint(Iterable<DateTime> fires, DateTime now) {
  final stale = [
    for (final f in fires)
      if (!f.isAfter(now)) f.toUtc().toIso8601String(),
  ]..sort();
  return stale.isEmpty ? null : stale.join('|');
}

/// The rail's server-state. Refetches ONLY on durable workflow-kind frames (run_started /
/// run_terminal / lifecycle changes), debounced 300ms — ticks (seq=0) never touch it, so row order
/// can only move on durable ledger events (活性军规:tick 绝不重排). kindStream 一条 O(1) 常驻。
class SchedulerRailController extends AsyncNotifier<SchedulerRailData> {
  Timer? _debounce;

  /// The stale fingerprint we already asked the wire about — the anti-spin latch. 已问过的陈旧指纹。
  String? _staleAsked;

  @override
  Future<SchedulerRailData> build() async {
    final gateway = ref.watch(sseGatewayProvider);
    if (gateway != null) {
      final sub = gateway.kindStream(StreamName.entities, 'workflow').listen((env) {
        if (!env.durable) return; // ephemeral ticks never reorder the rail. tick 不动 rail。
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), refresh);
      });
      ref.onDispose(() {
        sub.cancel();
        _debounce?.cancel();
      });
    }
    // The app's ONE heartbeat doubles as the staleness detector: the labels it already refreshes are
    // exactly the ones that go stale, so no second clock is minted (C 轨:全 app 唯一相对时间心跳).
    // Both faces heal from this one seam — the rail's ⏱ meta and the Overview's «Next fire» KPI read
    // the SAME nextFireByWorkflow (the Overview watches rail.future), so they cannot disagree.
    // 唯一心跳兼任陈旧探测器:它本就在刷的那些字,正是会变陈旧的那些字——不铸第二口钟。两张脸同缝自愈:
    // rail 的 ⏱ meta 与 Overview 的「下次调度」牌读同一份 nextFireByWorkflow,天然不会打架。
    AnTimePulse.instance.addListener(_onPulse);
    ref.onDispose(() => AnTimePulse.instance.removeListener(_onPulse));
    // A fresh load just answered — any «already asked» bookkeeping from the old snapshot is void.
    // 刚重新取过数:旧快照的「问过了」记账作废。
    _staleAsked = null;
    return _fetch();
  }

  /// The pulse's seam, exposed for the staleness battery (a real pulse would cost the test 30 real
  /// seconds; the RULE under test is this handler). 脉搏缝测试出口:待测的是这个处理器本身。
  @visibleForTesting
  void onPulseForTest() => _onPulse();

  /// Every half minute: has our cached next-fire join aged into the past? Then the SNAPSHOT is stale
  /// — go get a fresh one instead of rendering «—» over a live schedule. At most ONE ask per distinct
  /// answer, so a wire that insists on a past instant can never spin this.
  /// 每半分钟:缓存的 next-fire 是否已老成过去?是则**快照**陈旧——去取新的,而不是在活着的调度上渲「—」。
  /// 每个不同的答案至多问一次,故线缆哪怕咬定一个过去时刻也转不起来。
  void _onPulse() {
    final data = state.value;
    if (data == null) return; // first load still in flight 首载在飞
    final stale = staleFireFingerprint(data.nextFireByWorkflow.values, DateTime.now());
    if (stale == null) {
      _staleAsked = null;
      return;
    }
    if (stale == _staleAsked) return; // asked; the wire's answer stands 问过了,答案就是它
    _staleAsked = stale;
    unawaited(_healStale(stale));
  }

  Future<void> _healStale(String asked) async {
    // A refetch that never landed is not an answer — let a later pulse ask again (the latch may only
    // hold against an answer we actually GOT, else one network blip wedges «—» until the next durable
    // frame). 没落地的重取不是答案:让后面的脉搏再问——闩只闩**真收到的**答案,否则一次网络抖动就把
    // 「—」钉死到下一个 durable 帧为止。
    if (!await refresh() && _staleAsked == asked) _staleAsked = null;
  }

  Future<SchedulerRailData> _fetch() async {
    final repo = ref.read(schedulerRepositoryProvider);
    final results = await Future.wait([
      repo.listWorkflows(),
      repo.listTriggers(),
      repo.workflowTriggerEdges(),
      repo.listInbox(),
    ]);
    final workflows = results[0] as List<SchedulerWorkflowRow>;
    final triggers = results[1] as List<TriggerEntity>;
    final edges = results[2] as List<EntityRelation>;
    final inbox = results[3] as List<SchedulerInboxRow>;

    final stats = workflows.isEmpty
        ? const SchedulerStats()
        : await repo.stats([for (final w in workflows) w.id]);

    // Join: workflow → earliest FUTURE fire among its equipped, listening triggers. 连接:最早未来 fire。
    final fireByTrigger = <String, DateTime>{};
    for (final t in triggers) {
      final next = t.nextFireAt;
      if (next != null && t.listening) fireByTrigger[t.id] = next;
    }
    final nextFire = <String, DateTime>{};
    for (final e in edges) {
      final fire = fireByTrigger[e.toId];
      if (fire == null) continue;
      final wfId = e.fromId;
      final prior = nextFire[wfId];
      if (prior == null || fire.isBefore(prior)) nextFire[wfId] = fire;
    }

    return SchedulerRailData(
      workflows: workflows,
      stats: {for (final s in stats.byWorkflow) s.workflowId: s},
      nextFireByWorkflow: nextFire,
      inbox: inbox,
      triggers: triggers,
      edges: edges,
    );
  }

  /// Durable-event / manual refetch. Keeps the last good value while reloading (no rail flash).
  /// Reports whether a fresh value LANDED — [_healStale]'s latch may only close on a real answer.
  /// 对账 refetch;重取期间保留旧值不闪;返回是否**落地**了新值(陈旧闩只认真答案)。
  Future<bool> refresh() async {
    final next = await AsyncValue.guard(_fetch);
    // A failed refetch keeps the previous truth on screen (the rail shows data, errors surface on
    // first load only). 重取失败保留旧真相。
    if (next.hasValue || state.value == null) state = next;
    return next.hasValue;
  }
}

final schedulerRailProvider =
    AsyncNotifierProvider<SchedulerRailController, SchedulerRailData>(SchedulerRailController.new);

/// The rail's ⚙ sort axis (WRK-070 B1 sliders 菜单): activity (the standing order) or name.
/// Session-scoped like the chat rail's (chat 先例:BoolPrefNotifier 同窝,不入持久化).
/// rail ⚙ 排序轴:最近活动(现状序)或名称;会话级,同 chat rail 先例。
enum SchedRailSort { activity, name }

class SchedulerRailSortController extends Notifier<SchedRailSort> {
  @override
  SchedRailSort build() => SchedRailSort.activity;

  void set(SchedRailSort v) {
    if (v != state) state = v;
  }
}

final schedulerRailSortProvider =
    NotifierProvider<SchedulerRailSortController, SchedRailSort>(SchedulerRailSortController.new);

/// ⚙ display toggles — which meta rungs a row may speak and whether the inactive section shows.
/// ⚙ 显示开关:行 meta 可念哪些档 + 停用段是否在列。
final schedShowNextFireProvider =
    NotifierProvider<BoolPrefNotifier, bool>(() => BoolPrefNotifier(true));
final schedShowLastRunProvider =
    NotifierProvider<BoolPrefNotifier, bool>(() => BoolPrefNotifier(true));
final schedShowInactiveProvider =
    NotifierProvider<BoolPrefNotifier, bool>(() => BoolPrefNotifier(true));
