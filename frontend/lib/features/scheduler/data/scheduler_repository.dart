import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_matrix.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/trigger_schedule.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
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
  Future<SchedulerStats> stats(List<String> workflowIds, {int recentN, String since, String? until});

  /// Every trigger (pages through GET /triggers) — nextFireAt/listening for the rail's ⏱ meta and the
  /// schedule surfaces. 全部 trigger(⏱ meta 与调度面数据)。
  Future<List<TriggerEntity>> listTriggers();

  /// workflow→trigger equip edges (GET /relations?kind=equip, narrowed client-side — kind-only
  /// from/to filters are a backend 400, see the Live impl) — the reverse lookup that joins a
  /// workflow to its schedule. 反查连接:workflow 的 triggers(kind=equip 拉全量后客户端收窄)。
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
  /// AND (工单⑥+⑮): [status]/[origin] are closed sets (an out-of-set value is a loud 422 with the
  /// allowed set), [startedAfter]/[startedBefore] window started_at, [completedAfter]/[completedBefore]
  /// window completed_at (工单⑮ — "when it LANDED", excludes the unlanded whose completed_at is NULL).
  /// All four are RFC3339 UTC bounds, half-open [after, before). Same Page shape as entities' (N4).
  /// 一页 flowrun(新→旧),过滤 AND 组合(工单⑥+⑮):status/origin 封闭集、两组时间界 RFC3339 UTC 半开窗
  /// (started_at「何时开始」/ completed_at「何时落定」,后者剔除未落定的 NULL 行)。
  Future<Page<Flowrun>> listFlowruns(
      {required String workflowId,
      String? status,
      String? origin,
      String? triggerId,
      DateTime? startedAfter,
      DateTime? startedBefore,
      DateTime? completedAfter,
      DateTime? completedBefore,
      String? cursor,
      int? limit});

  /// One OFFSET page of the same history (WRK-070 B4 — the run table's page-number pager): the
  /// SAME filter grammar as [listFlowruns], addressed by `offset` instead of a cursor, and answered
  /// with `total` so the pager can speak page counts. Never pass a cursor here (线上互斥 422).
  /// 同一份历史的 offset 页(页码翻页器):同 listFlowruns 过滤文法,按 offset 定址、答 total 渲页数;
  /// 绝不带 cursor(线上互斥)。
  Future<OffsetPage<Flowrun>> listFlowrunsPage(
      {required String workflowId,
      String? status,
      String? origin,
      DateTime? startedAfter,
      DateTime? startedBefore,
      required int offset,
      required int limit});

  /// EVERY failed run in the workspace that LANDED at or after [completedAfter]
  /// (`GET /flowruns?status=failed&completedAfter=`, drained) — the ONE call behind the Overview's
  /// 「24h 失败」 KPI tile deep-link, the exact analog of [listRunningRuns].
  ///
  /// **`completedAfter` must be the byte-identical instant the tile's `failedSince` counted from**
  /// (工单⑮). The tile shows `flowrun-stats.totals.failedSince`, which windows on **completed_at**;
  /// only a completed_at window (never `startedAfter`) lists the SAME runs — a run that began 30h ago
  /// and failed an hour ago is in today's failures and in no started_at window; one that began inside
  /// the window and is still running is in neither. Send a relative word and the backend counts from
  /// ITS now while the tile drew from OURS: 「牌上写 3、点开列表显示 4」. Workspace-wide (no
  /// workflowId) so an orphan run's failure is not lost, drained so a page cap never makes the list
  /// shorter than the count it opens from — both for the running-runs reason (see [listRunningRuns]).
  ///
  /// 工作区里**每一个**在 [completedAfter] 或之后**落定**的失败 run(`GET /flowruns?status=failed&
  /// completedAfter=`,翻页拉全)——Overview「24h 失败」牌深链背后**唯一**的调用,[listRunningRuns] 的精确
  /// 对应物。**completedAfter 必须是牌的 failedSince 所数的那个逐字节相同的时刻**(工单⑮):牌显示
  /// `failedSince`、它按 **completed_at** 开窗,只有 completed_at 窗(绝非 startedAfter)才列出**同一批**
  /// run。工作区级(无 workflowId,孤儿 run 的失败不丢)、翻页拉全(页帽绝不让列表比它点开的数更短)——
  /// 皆同 listRunningRuns 之理。
  Future<List<Flowrun>> listFailedSince(DateTime completedAfter);

  /// EVERY running run in the workspace (`GET /flowruns?status=running`, drained) — the ONE call
  /// behind the Overview's 「正在跑」 zone AND its KPI tile, which is the whole reason it exists as its
  /// own door rather than a loop over [listFlowruns].
  ///
  /// **`workflowId` is deliberately absent, and that is the point.** The tile counts the WORKSPACE's
  /// running runs, so the zone must list the workspace's running runs — the same predicate, or the
  /// tile and the list it opens are two different questions wearing one number. Asking per workflow
  /// cannot answer it: the run of a SOFT-DELETED workflow is still running (孤儿 run 一等公民, §5.7),
  /// it is counted by anything that reads the flowruns table, and no per-workflow loop driven by the
  /// workflow list will ever visit it. The wire has always allowed this (`ListFilter.WorkflowID`
  /// empty = every workflow); nothing needed to change but the question.
  ///
  /// Drained rather than first-page: a page cap would make the zone — and therefore the tile that
  /// counts its rows — silently under-report. The drain's own defensive bound is far above what the
  /// machine's concurrency limits can produce.
  ///
  /// 工作区里**每一个**在跑的 run(`GET /flowruns?status=running`,翻页拉全)——Overview「正在跑」区**与**
  /// 它那张 KPI 牌背后**唯一**的一次调用;这正是它自成一扇门、而非 [listFlowruns] 循环的全部理由。
  /// **workflowId 刻意缺席,而这就是要害**:牌数的是**整个工作区**在跑的 run,故区必须列出**整个工作区**在跑的
  /// run——同一份谓词,否则牌与它点开的列表就是**两个问题共用一个数字**。逐 workflow 问答不出这个问题:**宿主已软删**
  /// 的 run 照样在跑(孤儿 run 一等公民,§5.7),凡是读 flowruns 表的都数着它,而任何由 workflow 列表驱动的逐个循环
  /// 都永远走不到它。线缆一直允许这么问(ListFilter.WorkflowID 为空=全部 workflow),要改的从来只是**问题**本身。
  /// **翻页拉全而非只取首页**:页帽会让区——以及数它行数的那张牌——静默少报;拉全自带的防御帽远高于这台机器的
  /// 并发上限所能产出的量。
  Future<List<Flowrun>> listRunningRuns();

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

  /// One keyset page of the firing ledger (工单⑭, `GET /firings`, newest first) — the timeline's PAST
  /// half, and the counterpart to [triggerSchedule]'s future half: a firing row is written the moment
  /// a trigger fires, so this answers «did the tick become a run, and if not why not»
  /// (started / skipped / superseded / shed / missed).
  ///
  /// Filters compose with AND and EVERY one is optional: [triggerId] absent spans the whole workspace
  /// (a firing is a workspace-level log row, so «every firing in the last 24h» is a first-class
  /// question — paging one trigger at a time cannot answer it without draining every trigger's whole
  /// ledger); [status] is the sealed 7-value set (out-of-set → loud 422 with `allowed`, never a silent
  /// empty page); [createdAfter]/[createdBefore] are RFC3339 UTC bounds, HALF-OPEN
  /// `[after, before)` on created_at — the [listFlowruns] window grammar verbatim.
  ///
  /// **N4-paged, and the cap is load-bearing**: a firing ledger is UNBOUNDED (a per-minute cron writes
  /// 1,440 rows a day) and rows come newest-first, so a `hasMore` page is the NEWEST slice — the older
  /// end of the window is then unknown, NOT empty. A caller that draws a page as if it were the whole
  /// window paints an invisible hole; it must say so instead (§3 zone 4's honest sentence).
  ///
  /// 一页 firing 账(工单⑭,新→旧)——时间轴的**过去**半,与 triggerSchedule 的未来半互补:trigger fire
  /// 的瞬间即写行,故它答「刻度成没成 run、没成为什么」。过滤 AND 组合且**每项可选**:triggerId 缺席即跨整个
  /// workspace;status 封闭 7 值(越集 422 带 allowed,绝不静默空页);时间界 RFC3339 UTC **半开窗**
  /// `[after, before)`——逐字同 listFlowruns 文法。**N4 分页,且帽是承重的**:firing 是**无界**日志、行新→旧,
  /// 故 hasMore 的一页是**最新**那一片——窗口更老的那端是**未知**、不是**空**;把一页当整窗画就是画出一个
  /// 隐形空洞,必须改为明说(§3 区 4 的诚实句)。
  Future<Page<Firing>> listFirings({
    String? triggerId,
    FiringStatus? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
    String? cursor,
    int? limit,
  });

  /// The node×run grid (工单⑩, `GET /flowrun-matrix?flowrunIds=<csv, ≤50 after dedup>`) — one
  /// bounded batch answering the grid for EXACTLY these runs (the caller pages `GET /flowruns` and
  /// batch-fetches per page). Empty set → 400, over-cap → 422; unknown ids are silently absent
  /// (cols carry explicit keys); output cols are canonical (started_at, id) DESC regardless of
  /// request order. 节点×run 格阵(⑩):按显式 run id 集一次批查(调用方翻 GET /flowruns 逐页批取);
  /// 空集 400、越 50 上限 422;未知 id 静默缺席;输出列恒正典新→旧、与请求顺序无关。
  Future<FlowrunMatrix> runMatrix(List<String> flowrunIds);

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
      {int recentN = 10, String since = SchedulerWindows.statsSince, String? until}) async {
    if (workflowIds.isEmpty) {
      // totals are workspace-wide — still worth one call with no ids. totals 全局,空 ids 也取。
      return _statsCall(const [], recentN, since, until);
    }
    // Chunk to the backend's ≤50-id bound and merge. 按 ≤50 分片合并。
    SchedulerTotals? totals;
    final rows = <WorkflowRunStats>[];
    for (var i = 0; i < workflowIds.length; i += 50) {
      final chunk = workflowIds.sublist(i, i + 50 > workflowIds.length ? workflowIds.length : i + 50);
      final s = await _statsCall(chunk, recentN, since, until);
      totals ??= s.totals; // workspace totals are identical across chunks. 全局数各片相同,取首片。
      rows.addAll(s.byWorkflow);
    }
    return SchedulerStats(totals: totals ?? const SchedulerTotals(), byWorkflow: rows);
  }

  Future<SchedulerStats> _statsCall(List<String> ids, int recentN, String since, String? until) =>
      _api.getEntity('/api/v1/flowrun-stats', SchedulerStats.fromJson, query: {
        if (ids.isNotEmpty) 'workflowIds': ids.join(','),
        'recentN': '$recentN',
        'since': since,
        // The window's END bound (需求②): RFC3339 only — pairs with since as [since, until).
        // 窗终点:仅 RFC3339,与 since 成对半开窗。
        'until': ?until,
      });

  @override
  Future<List<TriggerEntity>> listTriggers() => _drain('/api/v1/triggers', TriggerEntity.fromJson);

  @override
  Future<List<EntityRelation>> workflowTriggerEdges() async {
    // `kind=equip` alone is the ONLY filter shape this call may use: the backend's validateFilter
    // requires fromKind/fromId (and toKind/toId) in PAIRS, so a kind-only from/to filter is a 400 —
    // which took the whole Overview down against the real backend (found live 0717; the fixture seam
    // and testend both bypass this wire). Equip edges are a bounded single-user set, so client-side
    // narrowing is the honest fix, not a backend contract change.
    // 唯一合法的过滤形是 `kind=equip`:后端 validateFilter 要求 fromKind/fromId **成对**,只给 kind 不给
    // id 的 from/to 过滤=400 —— 真机 0717 现形,曾把整个 Overview 拖死(fixture 缝与 testend 都不走这条
    // 线)。equip 边是单用户有界集,客户端收窄即诚实修法、不动后端契约。
    final edges = await _drain(
      '/api/v1/relations',
      EntityRelation.fromJson,
      query: const {'kind': 'equip'},
    );
    return edges
        .where((e) => e.fromKind == 'workflow' && e.toKind == 'trigger')
        .toList(growable: false);
  }

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
          DateTime? completedAfter,
          DateTime? completedBefore,
          String? cursor,
          int? limit}) =>
      _api.getPage('/api/v1/flowruns', Flowrun.fromJson, query: {
        'workflowId': workflowId,
        'status': ?status,
        'origin': ?origin,
        'triggerId': ?triggerId,
        // RFC3339 in UTC — stored timestamps are UTC, a mixed-zone bound compares wrong (工单⑥+⑮).
        // RFC3339 归一 UTC(存储是 UTC,混时区界比错)。
        if (startedAfter != null) 'startedAfter': startedAfter.toUtc().toIso8601String(),
        if (startedBefore != null) 'startedBefore': startedBefore.toUtc().toIso8601String(),
        if (completedAfter != null) 'completedAfter': completedAfter.toUtc().toIso8601String(),
        if (completedBefore != null) 'completedBefore': completedBefore.toUtc().toIso8601String(),
        'cursor': ?cursor,
        if (limit != null) 'limit': '$limit',
      });

  @override
  Future<OffsetPage<Flowrun>> listFlowrunsPage(
          {required String workflowId,
          String? status,
          String? origin,
          DateTime? startedAfter,
          DateTime? startedBefore,
          required int offset,
          required int limit}) =>
      _api.getOffsetPage('/api/v1/flowruns', Flowrun.fromJson, query: {
        'workflowId': workflowId,
        'status': ?status,
        'origin': ?origin,
        if (startedAfter != null) 'startedAfter': startedAfter.toUtc().toIso8601String(),
        if (startedBefore != null) 'startedBefore': startedBefore.toUtc().toIso8601String(),
        'offset': '$offset',
        'limit': '$limit',
      });

  @override
  Future<Page<Firing>> listFirings({
    String? triggerId,
    FiringStatus? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
    String? cursor,
    int? limit,
  }) {
    // `unknown` is the inbound-only forward-compat member — sending it back as a filter would earn a
    // 422 for a status the backend has never heard of. Assert rather than silently drop the filter:
    // dropping it would widen the query and answer a DIFFERENT question than the caller asked.
    // unknown 是**入站专用**的兜底成员——把它当过滤发回去只会换来 422。用 assert 而非静默丢弃:丢掉过滤会
    // **放宽**查询、答一个与调用方所问不同的问题。
    assert(status != FiringStatus.unknown,
        'FiringStatus.unknown is inbound-only forward-compat, never a filter');
    return _api.getPage('/api/v1/firings', Firing.fromJson, query: {
      'triggerId': ?triggerId,
      if (status != null) 'status': status.name,
      // RFC3339 in UTC — same reason as listFlowruns' bounds. RFC3339 归一 UTC,同 listFlowruns。
      if (createdAfter != null) 'createdAfter': createdAfter.toUtc().toIso8601String(),
      if (createdBefore != null) 'createdBefore': createdBefore.toUtc().toIso8601String(),
      'cursor': ?cursor,
      if (limit != null) 'limit': '$limit',
    });
  }

  @override
  Future<List<Flowrun>> listRunningRuns() =>
      _drain('/api/v1/flowruns', Flowrun.fromJson, query: const {'status': 'running'});

  @override
  Future<List<Flowrun>> listFailedSince(DateTime completedAfter) => _drain(
        '/api/v1/flowruns',
        Flowrun.fromJson,
        // completedAfter (NOT startedAfter): the tile counts on completed_at (工单⑮). RFC3339 UTC,
        // same reason as listFlowruns' bounds. completedAfter(非 startedAfter):牌按 completed_at 数。
        query: {'status': 'failed', 'completedAfter': completedAfter.toUtc().toIso8601String()},
      );

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
  Future<FlowrunMatrix> runMatrix(List<String> flowrunIds) =>
      _api.getEntity('/api/v1/flowrun-matrix', FlowrunMatrix.fromJson, query: {
        'flowrunIds': flowrunIds.join(','),
      });

}

/// Overridden by demo (`FixtureSchedulerRepository`) at the app root. app 根被 demo override。
final schedulerRepositoryProvider = Provider<SchedulerRepository>(
  (ref) => LiveSchedulerRepository(ref.watch(apiClientProvider)),
);
