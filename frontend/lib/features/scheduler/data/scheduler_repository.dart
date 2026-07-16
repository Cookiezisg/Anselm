import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
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

/// One enriched flowrun-inbox row (工单④) — the parked approval [node] plus the workflow context the
/// backend joins in: [workflowId]/[workflowName] (a soft-deleted host's name falls back to the bare
/// id — the relation-Namer precedent, guarded here too) and the optional absolute [deadline]
/// (parkedAt + the pinned approval version's timeout; the key is ABSENT when the approval never
/// times out, so null = no countdown, never a zero-value lie).
/// 收件箱 enrich 行:parked 节点 + workflow 上下文(软删宿主名回落裸 id)+ 可空绝对期限(无 timeout 键缺席)。
class SchedulerInboxRow {
  const SchedulerInboxRow({
    required this.node,
    required this.workflowId,
    required this.workflowName,
    this.deadline,
  });

  final FlowrunNode node;
  final String workflowId;
  final String workflowName;
  final DateTime? deadline;

  factory SchedulerInboxRow.fromJson(Map<String, dynamic> json) {
    final wfId = json['workflowId'] as String? ?? '';
    final name = json['workflowName'] as String? ?? '';
    return SchedulerInboxRow(
      // The row IS the node row on the wire — the enrich keys ride beside the node fields, so one
      // map feeds both decodes. 行=节点行本体,enrich 键并列同层,一张 map 双解。
      node: FlowrunNode.fromJson(json),
      workflowId: wfId,
      workflowName: name.isNotEmpty ? name : wfId,
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
    );
  }
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

  /// Every parked approval waiting on a human, enriched with workflow context (工单④,
  /// `GET /flowrun-inbox`). The rail's waiting badge AND the Overview's «等你处理» zone both read
  /// THIS (one fetch, one truth — the badge is `.length`); NEVER `?status=parked` (parked is a node
  /// state, not in the run-status closed set — 422).
  /// 跨 run 审批收件箱(enrich 行)。rail 徽与 Overview 区同源(徽=length);绝不 ?status=parked。
  Future<List<SchedulerInboxRow>> listInbox();

  /// Decide a parked approval (`POST /flowruns/{fr}/approvals/{node}:decide`, first-wins — the
  /// loser gets 422 FLOWRUN_APPROVAL_NOT_PARKED) → the fresh flowrun snapshot (202, same envelope
  /// as entities' decide). 决断 parked 审批(first-wins,输家 422)→ 新快照。
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
      {required String decision, String? reason});

  /// Cancel a RUNNING run (工单②, `POST /flowruns/{id}:cancel`; parked approvals are withdrawn).
  /// Non-running → 422 FLOWRUN_NOT_CANCELLABLE. 202 returns the `:replay`-shaped envelope.
  /// 取消在跑 run(parked 审批一并收回);非 running 422;信封形同 :replay。
  Future<FlowrunComposite> cancelRun(String flowrunId);

  /// One keyset page of a workflow's flowruns (`GET /flowruns?workflowId=&status=`, newest first) —
  /// the Overview's running rows (status=running) and the failure aggregation's latest-failed probe
  /// (status=failed&limit=1). Same Page shape as entities' listFlowruns (N4).
  /// 一页 flowrun(新→旧):Overview 正在跑区 + 失败聚合的最新失败探针;Page 形对齐 entities。
  Future<Page<Flowrun>> listFlowruns(
      {required String workflowId, String? status, String? cursor, int? limit});
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
  Future<List<SchedulerInboxRow>> listInbox() async {
    final data = await _api.getData('/api/v1/flowrun-inbox');
    return [
      for (final e in (data['parked'] as List? ?? const []))
        SchedulerInboxRow.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
          {required String decision, String? reason}) =>
      _api.postEntity('/api/v1/flowruns/$flowrunId/approvals/$nodeId:decide',
          FlowrunComposite.fromJson, body: {'decision': decision, 'reason': ?reason});

  @override
  Future<FlowrunComposite> cancelRun(String flowrunId) =>
      _api.postEntity('/api/v1/flowruns/$flowrunId:cancel', FlowrunComposite.fromJson);

  @override
  Future<Page<Flowrun>> listFlowruns(
          {required String workflowId, String? status, String? cursor, int? limit}) =>
      _api.getPage('/api/v1/flowruns', Flowrun.fromJson, query: {
        'workflowId': workflowId,
        'status': ?status,
        'cursor': ?cursor,
        if (limit != null) 'limit': '$limit',
      });
}

/// Overridden by demo (`FixtureSchedulerRepository`) at the app root. app 根被 demo override。
final schedulerRepositoryProvider = Provider<SchedulerRepository>(
  (ref) => LiveSchedulerRepository(ref.watch(apiClientProvider)),
);
