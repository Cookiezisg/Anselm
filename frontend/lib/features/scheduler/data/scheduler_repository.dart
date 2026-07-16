import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_matrix.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/trigger_schedule.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import '../../../core/contract/retention.dart';
import '../../../core/net/api_client.dart';
import '../../../core/runtime.dart';
import '../scheduler_windows.dart';

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

  /// One keyset page of a workflow's flowruns (`GET /flowruns`, newest first). Filters compose with
  /// AND (工单⑥): [status]/[origin] are closed sets (an out-of-set value is a loud 422 with the
  /// allowed set), [startedAfter]/[startedBefore] are RFC3339 UTC bounds (half-open [after, before)
  /// on started_at). Same Page shape as entities' listFlowruns (N4).
  /// 一页 flowrun(新→旧),过滤 AND 组合(工单⑥):status/origin 封闭集、时间界 RFC3339 UTC 半开窗。
  Future<Page<Flowrun>> listFlowruns(
      {required String workflowId,
      String? status,
      String? origin,
      String? triggerId,
      DateTime? startedAfter,
      DateTime? startedBefore,
      String? cursor,
      int? limit});

  /// The full workflow entity (`GET /workflows/{id}`) — the operations home's health head needs the
  /// lifecycle truth and the linked pane needs the active version's graph. 全量 workflow 实体
  /// (健康头生命周期 + 联动格活跃版本图)。
  Future<WorkflowEntity> getWorkflow(String id);

  /// One run with ALL its node rows (`GET /flowruns/{id}` paged through, defensively capped) — the
  /// linked pane's gantt/graph and the replay confirm's real numbers both need the complete node
  /// set (a first page would silently under-count). 单 run + 全量节点行(翻页拉全,防御帽):
  /// 联动格与 replay 真数字都需要完整节点集。
  Future<FlowrunComposite> getRunFull(String flowrunId);

  /// One run's HEADER only (`GET /flowruns/{id}?limit=1`) — the cheap durable-terminal reconcile
  /// read (patch a loaded table row from DB truth without dragging the node history).
  /// 只取 run 头(limit=1):terminal 落账的廉价对账读,原位补一行、不拖节点史。
  Future<Flowrun> getRun(String flowrunId);

  /// Run the workflow once now (`POST /workflows/{id}:trigger`, 202 → the new flowrun id). Run now。
  Future<String> runNow(String workflowId);

  /// Hard-stop the workflow (`POST /workflows/{id}:kill`): stop listening + cancel every in-flight
  /// run + inactive. Returns the post-action entity snapshot. 硬停 workflow,返动作后快照。
  Future<WorkflowEntity> killWorkflow(String workflowId);

  /// Replay a FAILED run (`POST /flowruns/{id}:replay`, 202, same envelope as :cancel). Non-failed →
  /// 422 FLOWRUN_NOT_REPLAYABLE. 重放失败 run;非 failed 422。
  Future<FlowrunComposite> replayRun(String flowrunId);

  /// Pause / resume a trigger's scheduling (工单⑦, `POST /triggers/{id}:pause|:resume`) — paused
  /// produces no new firings, in-flight runs are untouched, nextFireAt reads absent. Idempotent,
  /// 200 returns the post-action bare trigger. 暂停/恢复调度;幂等,返动作后裸 trigger。
  Future<TriggerEntity> pauseTrigger(String triggerId);
  Future<TriggerEntity> resumeTrigger(String triggerId);

  /// One run's ACTIVITY rows (工单⑤, `GET /flowruns/{id}/activity`, paged through and defensively
  /// capped) — the four execution-log tables UNIONed by flowrun_id, startedAt ASC. Feeds the
  /// flagship gantt's exec segment + the inspector's execution-log deep link. A run with no
  /// dispatched entity nodes legitimately returns []; a missing run is 404 FLOWRUN_NOT_FOUND.
  /// 单 run 活动行(⑤,翻页拉全+防御帽):喂甘特执行段与检查器执行日志深链;无审计行的 run 返 []。
  Future<List<FlowrunActivityRow>> listActivity(String flowrunId);

  /// ONE workflow version by its id (`GET /workflows/{id}/versions/{version}` — the path segment
  /// accepts a version NUMBER or a `wfv_` id; we always pass the run's pinned `versionId`). This is
  /// how the flagship renders the graph the run ACTUALLY walked instead of today's active version
  /// (the run_cockpit 错图 bug, §5). 按版本 id 取钉版(路径段接版本号或 wfv_ id):旗舰渲 run 真正走过
  /// 的图,而非当下 active 版本。
  Future<WorkflowVersion> getWorkflowVersion(String workflowId, String versionId);

  /// Open an AI triage conversation for a failed run (`POST /executions/{id}:triage` — the endpoint
  /// dispatches by id PREFIX, so a `fr_` id routes to the flowrun triager). 202 → the new
  /// conversationId (异步动作返 id 铁律), which the caller deep-links into chat.
  /// AI 诊断(按 id 前缀分发,fr_ 走 flowrun 诊断);202 返 conversationId,调用方深链进 chat。
  Future<String> triageRun(String flowrunId);

  /// The forward-looking schedule (工单⑧, `GET /trigger-schedule?within=&limit=`) — every cron tick due
  /// inside the window, `at`-ASC, bounded (no cursor). ONLY listening+unpaused crons contribute, so
  /// the caller must draw its LANES from [listTriggers] and hang these points onto them — never
  /// reverse-derive the lane set from the points (a paused lane would vanish, 判决①).
  /// 前瞻调度(⑧):窗内每个 cron 刻度,升序,有界免游标。只有监听中且未暂停的 cron 贡献点,故泳道行集须
  /// 取自 listTriggers、点只是挂件——绝不从点反推泳道(暂停泳道会消失,违判决①)。
  Future<TriggerSchedule> triggerSchedule({String within, int limit});

  /// The node×run grid (工单⑩, `GET /flowrun-matrix?workflowId=&recentN=`) — one bounded batch query
  /// answering the whole grid. [workflowId] is REQUIRED (empty → 400); an unknown id is not an error
  /// (200 + three empty lists). 节点×run 格阵(⑩):一次有界批查答完整个格阵;workflowId 必填(空→400),
  /// 未知 id 不是错误(200 + 三空列表)。
  Future<FlowrunMatrix> runMatrix(String workflowId, {int recentN});

  /// The machine-level run-history retention line (工单⑬, `GET /retention`) — READ-ONLY here: this
  /// ocean only needs it to render the run table's honest tombstone row; EDITING it lives in the
  /// settings storage panel (which parses the same wire itself — features 互不依赖).
  /// 机器级 run 保留线(⑬),此处**只读**:本海洋只需它渲大表的诚实墓碑行;编辑归设置存储面板(它自行解同
  /// 一条线缆——features 互不依赖)。
  Future<RetentionConfig> retention();
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
  Future<SchedulerStats> stats(List<String> workflowIds,
      {int recentN = SchedulerWindows.beadRecentN,
      String since = SchedulerWindows.statsSince}) async {
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
          {required String workflowId,
          String? status,
          String? origin,
          String? triggerId,
          DateTime? startedAfter,
          DateTime? startedBefore,
          String? cursor,
          int? limit}) =>
      _api.getPage('/api/v1/flowruns', Flowrun.fromJson, query: {
        'workflowId': workflowId,
        'status': ?status,
        'origin': ?origin,
        'triggerId': ?triggerId,
        // RFC3339 in UTC — stored timestamps are UTC, a mixed-zone bound compares wrong (工单⑥).
        // RFC3339 归一 UTC(存储是 UTC,混时区界比错)。
        if (startedAfter != null) 'startedAfter': startedAfter.toUtc().toIso8601String(),
        if (startedBefore != null) 'startedBefore': startedBefore.toUtc().toIso8601String(),
        'cursor': ?cursor,
        if (limit != null) 'limit': '$limit',
      });

  @override
  Future<WorkflowEntity> getWorkflow(String id) =>
      _api.getEntity('/api/v1/workflows/$id', WorkflowEntity.fromJson);

  @override
  Future<FlowrunComposite> getRunFull(String flowrunId) async {
    final comp = await _api.getEntity('/api/v1/flowruns/$flowrunId', FlowrunComposite.fromJson);
    final nodes = [...comp.nodes];
    // Page the node rows to completion (same defensive bound as _drain). The composite's
    // `nextCursor` rides INSIDE data and arrives as "" on the last page (the Go map marshals the
    // empty string, unlike the top-level Paged envelope) — treat empty as done or this loops.
    // 节点行翻页拉全(防御帽);复合形的 nextCursor 在 data 内、末页是 ""(Go map 序列化空串,与顶层
    // Paged 信封不同)——空串即完,否则死循环。
    var cursor = comp.nextCursor;
    for (var i = 0; i < _pageCap && cursor != null && cursor.isNotEmpty; i++) {
      final page = await _api.getEntity('/api/v1/flowruns/$flowrunId', FlowrunComposite.fromJson,
          query: {'cursor': cursor});
      nodes.addAll(page.nodes);
      cursor = page.nextCursor;
    }
    return FlowrunComposite(flowrun: comp.flowrun, nodes: nodes);
  }

  @override
  Future<Flowrun> getRun(String flowrunId) async =>
      (await _api.getEntity('/api/v1/flowruns/$flowrunId', FlowrunComposite.fromJson,
              query: const {'limit': '1'}))
          .flowrun;

  @override
  Future<String> runNow(String workflowId) =>
      _api.postForId('/api/v1/workflows/$workflowId:trigger');

  @override
  Future<WorkflowEntity> killWorkflow(String workflowId) =>
      _api.postEntity('/api/v1/workflows/$workflowId:kill', WorkflowEntity.fromJson);

  @override
  Future<FlowrunComposite> replayRun(String flowrunId) =>
      _api.postEntity('/api/v1/flowruns/$flowrunId:replay', FlowrunComposite.fromJson);

  @override
  Future<TriggerEntity> pauseTrigger(String triggerId) =>
      _api.postEntity('/api/v1/triggers/$triggerId:pause', TriggerEntity.fromJson);

  @override
  Future<TriggerEntity> resumeTrigger(String triggerId) =>
      _api.postEntity('/api/v1/triggers/$triggerId:resume', TriggerEntity.fromJson);

  @override
  Future<List<FlowrunActivityRow>> listActivity(String flowrunId) =>
      _drain('/api/v1/flowruns/$flowrunId/activity', FlowrunActivityRow.fromJson);

  @override
  Future<WorkflowVersion> getWorkflowVersion(String workflowId, String versionId) => _api.getEntity(
      '/api/v1/workflows/$workflowId/versions/$versionId', WorkflowVersion.fromJson);

  @override
  Future<String> triageRun(String flowrunId) =>
      _api.postForId('/api/v1/executions/$flowrunId:triage');

  @override
  Future<TriggerSchedule> triggerSchedule(
          {String within = SchedulerWindows.trackWithin, int limit = 200}) =>
      _api.getEntity('/api/v1/trigger-schedule', TriggerSchedule.fromJson, query: {
        // Go duration grammar — deliberately NOT the `?since` grammar of flowrun-stats (which also
        // takes «7d»); a `7d` here is a 422. Go duration 文法(与 flowrun-stats 的 ?since 不同,那边吃
        // 7d;这里传 7d 是 422)。
        'within': within,
        'limit': '$limit',
      });

  @override
  Future<FlowrunMatrix> runMatrix(String workflowId,
          {int recentN = SchedulerWindows.matrixRecentN}) =>
      _api.getEntity('/api/v1/flowrun-matrix', FlowrunMatrix.fromJson, query: {
        'workflowId': workflowId,
        'recentN': '$recentN',
      });

  @override
  Future<RetentionConfig> retention() =>
      _api.getEntity('/api/v1/retention', RetentionConfig.fromJson);
}

/// Overridden by demo (`FixtureSchedulerRepository`) at the app root. app 根被 demo override。
final schedulerRepositoryProvider = Provider<SchedulerRepository>(
  (ref) => LiveSchedulerRepository(ref.watch(apiClientProvider)),
);
