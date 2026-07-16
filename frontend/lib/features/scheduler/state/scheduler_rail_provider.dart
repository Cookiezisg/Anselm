import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/runtime.dart';
import '../../../core/sse/sse_gateway.dart';
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

/// The rail's server-state. Refetches ONLY on durable workflow-kind frames (run_started /
/// run_terminal / lifecycle changes), debounced 300ms — ticks (seq=0) never touch it, so row order
/// can only move on durable ledger events (活性军规:tick 绝不重排). kindStream 一条 O(1) 常驻。
class SchedulerRailController extends AsyncNotifier<SchedulerRailData> {
  Timer? _debounce;

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
    return _fetch();
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
  /// 对账 refetch;重取期间保留旧值不闪。
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_fetch);
    // A failed refetch keeps the previous truth on screen (the rail shows data, errors surface on
    // first load only). 重取失败保留旧真相。
    if (next.hasValue || state.value == null) state = next;
  }
}

final schedulerRailProvider =
    AsyncNotifierProvider<SchedulerRailController, SchedulerRailData>(SchedulerRailController.new);
