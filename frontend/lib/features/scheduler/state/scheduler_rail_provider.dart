import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/runtime.dart';
import '../../../core/sse/sse_gateway.dart';
import '../data/scheduler_repository.dart';

/// Everything the Scheduler rail projects (WRK-069 §2) — workflows + per-workflow health + the
/// next-fire join + the one waiting-on-human number. DB rows are the truth; frames only trigger
/// refetch. rail 的全部输入;行是真相,帧只触发 refetch。
class SchedulerRailData {
  const SchedulerRailData({
    required this.workflows,
    required this.stats,
    required this.nextFireByWorkflow,
    required this.waitingCount,
  });

  final List<SchedulerWorkflowRow> workflows;
  final Map<String, WorkflowRunStats> stats;
  final Map<String, DateTime> nextFireByWorkflow;
  final int waitingCount;
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
      repo.waitingCount(),
    ]);
    final workflows = results[0] as List<SchedulerWorkflowRow>;
    final triggers = results[1] as List;
    final edges = results[2] as List;
    final waiting = results[3] as int;

    final stats = workflows.isEmpty
        ? const SchedulerStats()
        : await repo.stats([for (final w in workflows) w.id]);

    // Join: workflow → earliest FUTURE fire among its equipped, listening triggers. 连接:最早未来 fire。
    final fireByTrigger = <String, DateTime>{};
    for (final t in triggers) {
      final next = t.nextFireAt as DateTime?;
      if (next != null && (t.listening as bool? ?? false)) fireByTrigger[t.id as String] = next;
    }
    final nextFire = <String, DateTime>{};
    for (final e in edges) {
      final fire = fireByTrigger[e.toId as String];
      if (fire == null) continue;
      final wfId = e.fromId as String;
      final prior = nextFire[wfId];
      if (prior == null || fire.isBefore(prior)) nextFire[wfId] = fire;
    }

    return SchedulerRailData(
      workflows: workflows,
      stats: {for (final s in stats.byWorkflow) s.workflowId: s},
      nextFireByWorkflow: nextFire,
      waitingCount: waiting,
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
