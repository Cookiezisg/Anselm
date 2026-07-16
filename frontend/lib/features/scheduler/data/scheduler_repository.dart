import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/net/api_client.dart';
import '../../../core/runtime.dart';

/// One workflow as the Scheduler sees it — the operations projection's thin row (the rail/overview
/// need identity + lifecycle only; health comes from [SchedulerStats]). Deliberately NOT entities'
/// EntityRow (features 互不依赖 — this feature parses the same wire itself).
/// Scheduler 视角的 workflow 薄行(身份+生命周期;健康归 stats)——刻意不复用 entities 的 EntityRow。
class SchedulerWorkflowRow {
  const SchedulerWorkflowRow({
    required this.id,
    required this.name,
    this.lifecycleState = '',
    this.needsAttention = false,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String lifecycleState;
  final bool needsAttention;
  final DateTime? updatedAt;

  factory SchedulerWorkflowRow.fromJson(Map<String, dynamic> json) => SchedulerWorkflowRow(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lifecycleState: json['lifecycleState'] as String? ?? '',
        needsAttention: json['needsAttention'] as bool? ?? false,
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      );
}

/// THE data seam for the Scheduler ocean (WRK-069) — Live over the Phase-4.0 ApiClient /
/// [FixtureSchedulerRepository] for demo + tests, swapped at [schedulerRepositoryProvider].
/// Scheduler 海洋数据缝。
abstract interface class SchedulerRepository {
  /// Every workflow in the workspace (pages through GET /workflows; a single-user workspace holds
  /// dozens, hard-capped defensively). 全部 workflow(翻页取全,防御性硬帽)。
  Future<List<SchedulerWorkflowRow>> listWorkflows();

  /// Batched operations stats (工单③, ids ≤50 per call — the repo chunks internally). 批量统计。
  Future<SchedulerStats> stats(List<String> workflowIds, {int recentN, String since});

  /// Every trigger (pages through GET /triggers) — nextFireAt/listening for the rail's ⏱ meta and the
  /// schedule surfaces. 全部 trigger(⏱ meta 与调度面数据)。
  Future<List<TriggerEntity>> listTriggers();

  /// workflow→trigger equip edges (GET /relations, fromKind=workflow&toKind=trigger) — the reverse
  /// lookup that joins a workflow to its schedule. 反查连接:workflow 的 triggers。
  Future<List<EntityRelation>> workflowTriggerEdges();

  /// Runs waiting on a human — the rail's ONE number (WRK-069 §2), derived from the flowrun inbox,
  /// NEVER `?status=parked` (parked is a node state, not in the run-status closed set — 422).
  /// 等人处理的 run 数——inbox 派生,绝不 ?status=parked(封闭集无此值)。
  Future<int> waitingCount();
}

/// The production seam. Thin envelope decoding only. 生产缝:薄信封解码。
class LiveSchedulerRepository implements SchedulerRepository {
  LiveSchedulerRepository(this._api);

  final ApiClient _api;

  static const _pageCap = 20; // × limit 50 = 1000 rows — a defensive bound, not a product limit. 防御帽。

  Future<List<T>> _drain<T>(String path, T Function(Map<String, dynamic>) parse,
      {Map<String, String> query = const {}}) async {
    final out = <T>[];
    String? cursor;
    for (var i = 0; i < _pageCap; i++) {
      final page = await _api.getPage(
        path,
        parse,
        query: {...query, 'limit': '50', 'cursor': ?cursor},
      );
      out.addAll(page.items);
      cursor = page.nextCursor;
      if (cursor == null) break;
    }
    return out;
  }

  @override
  Future<List<SchedulerWorkflowRow>> listWorkflows() =>
      _drain('/api/v1/workflows', SchedulerWorkflowRow.fromJson);

  @override
  Future<SchedulerStats> stats(List<String> workflowIds, {int recentN = 10, String since = '168h'}) async {
    if (workflowIds.isEmpty) {
      // totals are workspace-wide — still worth one call with no ids. totals 全局,空 ids 也取。
      return _statsCall(const [], recentN, since);
    }
    // Chunk to the backend's ≤50-id bound and merge. 按 ≤50 分片合并。
    SchedulerTotals? totals;
    final rows = <WorkflowRunStats>[];
    for (var i = 0; i < workflowIds.length; i += 50) {
      final chunk = workflowIds.sublist(i, i + 50 > workflowIds.length ? workflowIds.length : i + 50);
      final s = await _statsCall(chunk, recentN, since);
      totals ??= s.totals; // workspace totals are identical across chunks. 全局数各片相同,取首片。
      rows.addAll(s.byWorkflow);
    }
    return SchedulerStats(totals: totals ?? const SchedulerTotals(), byWorkflow: rows);
  }

  Future<SchedulerStats> _statsCall(List<String> ids, int recentN, String since) =>
      _api.getEntity('/api/v1/flowrun-stats', SchedulerStats.fromJson, query: {
        if (ids.isNotEmpty) 'workflowIds': ids.join(','),
        'recentN': '$recentN',
        'since': since,
      });

  @override
  Future<List<TriggerEntity>> listTriggers() => _drain('/api/v1/triggers', TriggerEntity.fromJson);

  @override
  Future<List<EntityRelation>> workflowTriggerEdges() => _drain(
        '/api/v1/relations',
        EntityRelation.fromJson,
        query: const {'fromKind': 'workflow', 'toKind': 'trigger'},
      );

  @override
  Future<int> waitingCount() async {
    final data = await _api.getData('/api/v1/flowrun-inbox');
    return (data['parked'] as List? ?? const []).length;
  }
}

/// Overridden by demo (`FixtureSchedulerRepository`) at the app root. app 根被 demo override。
final schedulerRepositoryProvider = Provider<SchedulerRepository>(
  (ref) => LiveSchedulerRepository(ref.watch(apiClientProvider)),
);
