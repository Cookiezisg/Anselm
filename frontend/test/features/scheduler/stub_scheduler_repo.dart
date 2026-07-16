import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_matrix.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/trigger_schedule.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/contract/page.dart' as contract;
import 'package:anselm/core/contract/retention.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';

// The ONE scriptable Scheduler seam for the test batteries (S2a board + S2b action zones + S3 home)
// — every surface's inputs are injectable, and the mutations are STATEFUL (decided rows leave the
// inbox, a second decide loses first-wins with 422, cancelled runs leave the running filter, a
// replayed failed run flips running, pause/resume flip the wire's paused+listening+nextFireAt trio)
// so widget tests can walk the full settle grammar. Call ORDER is recorded so a battery can prove a
// batch dispatched SEQUENTIALLY, and [listFilters] records the exact wire question each fetch asked
// (the count strip / window / origin filters are only honest if the URL says so).
// 全可编脚本的数据缝:全部变更有状态,widget 测试走全程;调用序与过滤参数逐次留痕(计数条/窗口/来源
// 是否真的问到线缆上,靠它证)。

class StubSchedulerRepo implements SchedulerRepository {
  StubSchedulerRepo({
    this.workflows = const [],
    this.byWorkflow = const [],
    this.failedBySince = const {},
    this.totalsRunning = 0,
    this.triggers = const [],
    this.edges = const [],
    this.inbox = const [],
    this.runs = const [],
    this.nodesByRun = const {},
    this.graphByWorkflow = const {},
    this.activityByRun = const {},
    this.pinnedGraphByVersion = const {},
    this.schedule = const TriggerSchedule(),
    this.firings = const [],
    Map<String, FlowrunMatrix>? matrixByWorkflow,
    this.retentionConfig = const RetentionConfig(runRetentionDays: 90),
    this.failWorkflows = false,
    this.failRunFull = false,
    this.failActivity = false,
    this.failSchedule = false,
    this.failFirings = false,
    this.failMatrix = false,
    this.failRetention = false,
  }) : matrixByWorkflow = matrixByWorkflow ?? {};

  final List<SchedulerWorkflowRow> workflows;
  final List<WorkflowRunStats> byWorkflow;
  final Map<String, int> failedBySince;
  final int totalsRunning;
  final List<TriggerEntity> triggers;
  final List<EntityRelation> edges;
  final List<SchedulerInboxRow> inbox;
  final List<Flowrun> runs;

  /// Per-run node rows — the linked pane's gantt/graph and the replay confirm's real numbers.
  /// 逐 run 节点行:联动格与 replay 真数字。
  final Map<String, List<FlowrunNode>> nodesByRun;

  /// Per-workflow active-version graph (absent = a bare entity → the honest «no graph»). 活跃版本图。
  final Map<String, Graph> graphByWorkflow;

  /// Per-run ⑤ activity rows — the flagship gantt's exec segment + the inspector's execId deep link
  /// (absent = a run that left no audit rows, the honest fallback to the row's own stamps).
  /// 逐 run 活动行(⑤);缺席=无审计行的 run,诚实回落行自身戳。
  final Map<String, List<FlowrunActivityRow>> activityByRun;

  /// Per-VERSION-id pinned graph (§5.2) — keyed by `wfv_` id, so a battery can prove the flagship
  /// asked for the RUN's version and not today's active one; an absent id 404s → the fallback banner.
  /// 按版本 id 的钉版图:证旗舰问的是 run 的版本而非当下 active;缺席即 404 → 回退横幅。
  final Map<String, Graph> pinnedGraphByVersion;

  /// The ⑧ forward schedule. Deliberately a WHOLE [TriggerSchedule] (not a bare point list) so a
  /// battery can script `truncated` — the honest-overflow sentence is only provable if the stub can
  /// say «there is more». ⑧ 前瞻调度:刻意收整个 TriggerSchedule 而非裸点列表,故电池可编 truncated
  /// ——诚实溢出句只有在 stub 能说「还有更多」时才可证。
  final TriggerSchedule schedule;

  /// The firing ledger seeds (工单⑭) — the track's past half. 过去半的 firing 种子。
  final List<Firing> firings;

  /// Per-workflow ⑩ grid. Absent = the endpoint's honest empty answer (三个空列表), NOT an error.
  /// Mutable so a battery can seed it onto a shared `_repo()` by cascade. 逐 workflow 的 ⑩ 格阵;
  /// 缺席=端点诚实的空答案(三空列表),**不是**错误;可变以便电池用级联往共享 _repo() 上种。
  final Map<String, FlowrunMatrix> matrixByWorkflow;

  /// The ⑬ machine-level retention line — the run table's tombstone reads it. ⑬ 机器级保留线。
  final RetentionConfig retentionConfig;

  final bool failWorkflows;

  /// getRunFull throws — the replay confirm must still open, with the numberless sentence.
  /// 取数失败:确认框仍开,句子不带假数。
  final bool failRunFull;

  /// listActivity throws — the flagship must degrade to the row's own stamps, never blank.
  /// 活动读失败:甘特回落行自身戳,绝不空白。
  final bool failActivity;
  final bool failSchedule;

  /// listFirings throws 422 — the board must survive a firing read failing. firing 读失败:盘面须活着。
  final bool failFirings;
  bool failMatrix;
  final bool failRetention;

  /// Stateful decide/cancel so the batteries can walk the full settle grammar. Order proves the
  /// batch dispatched SEQUENTIALLY. 有状态;decideOrder 证批量逐发。
  final Set<String> decided = {};
  final List<String> decideOrder = [];
  final Set<String> cancelled = <String>{};
  final List<String> cancelOrder = [];

  /// S3 mutations — replayed failed runs flip running; killed workflows go inactive + cancel their
  /// in-flight runs; pause/resume flip the wire trio. Orders prove sequential dispatch.
  /// S3 变更:重放翻 running / kill 翻 inactive 并取消在途 / 暂停恢复翻线缆三键;序证逐发。
  final Set<String> replayed = {};
  final List<String> replayOrder = [];
  final List<String> runNowOrder = [];
  final List<String> killOrder = [];
  final Map<String, bool> pausedById = {};
  final List<String> pauseOrder = [];

  /// Every `GET /flowruns` question this stub was asked, in order — the honest-filter probe.
  /// 每次 flowruns 提问的过滤参数(按序):过滤诚实性探针。
  final List<({String? status, String? origin, DateTime? startedAfter, String? cursor, int? limit})>
      listFilters = [];

  /// Optional decide latency — lets a widget test observe the mid-batch pending face (逐行挂账).
  /// 可选延迟:widget 测试借它观察批中挂账脸。
  Duration decideLatency = Duration.zero;

  /// Optional replay latency (the batch's per-row pending face). 重放延迟:观察批中挂账脸。
  Duration replayLatency = Duration.zero;

  @override
  Future<List<SchedulerWorkflowRow>> listWorkflows() async {
    if (failWorkflows) throw StateError('backend down');
    return workflows;
  }

  @override
  Future<SchedulerStats> stats(List<String> workflowIds,
      {int recentN = 10, String since = '168h'}) async {
    statsSinces.add(since);
    return SchedulerStats(
      totals: SchedulerTotals(
          running: totalsRunning,
          failedSince: failedBySince[_sinceKey(since)] ?? 0,
          parkedNodes: inbox.length,
          // Counted through the SAME predicate the firing page uses (the backend shares one
          // `firingQuery` between `CountFirings` and `SearchFirings`; a stub that scripted the card's
          // number independently of the rows could not catch the two drifting apart, which is the one
          // thing worth catching here).
          // 与 firing 页**同一份**谓词计数(后端 CountFirings 与 SearchFirings 共用一个 firingQuery);若 stub 把牌
          // 的数字与行**各自**编脚本,就恰好抓不到那两者漂移——而那正是此处唯一值得抓的东西。
          missed: _matchFirings(status: FiringStatus.missed, createdAfter: _sinceInstant(since))
              .length),
      byWorkflow: byWorkflow,
    );
  }

  /// The Overview sends an ABSOLUTE `since` (工单⑭ — ONE client-side anchor shared by the 「错过 N」 card
  /// and the firing list), so a script written as `{'24h': 4, '48h': 6}` is matched by how far back the
  /// window reaches rather than by the literal word. A non-absolute word passes through unchanged, so
  /// callers that still speak `'168h'` keep working.
  /// Overview 发的是**绝对** since(工单⑭:牌与 firing 列表共用的那**一个**前端锚点),故写成 `{'24h':4,'48h':6}` 的
  /// 脚本按窗**回看多远**匹配、而非按字面词;非绝对的词原样透传,故仍说 '168h' 的调用方照常。
  String _sinceKey(String since) {
    final absolute = DateTime.tryParse(since);
    if (absolute == null) return since;
    return '${DateTime.now().difference(absolute).inHours}h';
  }

  DateTime _sinceInstant(String since) =>
      DateTime.tryParse(since) ??
      DateTime.now().subtract(Duration(
          hours: int.tryParse(since.replaceAll(RegExp(r'[^0-9]'), '')) ?? 168));

  List<Firing> _matchFirings({
    String? triggerId,
    FiringStatus? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) =>
      [
        for (final f in firings)
          if (triggerId == null || f.triggerId == triggerId)
            if (status == null || f.status == status)
              if (createdAfter == null || !f.createdAt.isBefore(createdAfter))
                if (createdBefore == null || f.createdAt.isBefore(createdBefore)) f,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<contract.Page<Firing>> listFirings({
    String? triggerId,
    FiringStatus? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
    String? cursor,
    int? limit,
  }) async {
    // The exact wire question, recorded: the card's number and this page are only «the same predicate»
    // if the URLs say so, and that is provable ONLY here. 逐字记下线缆上真问出的问题:牌的数字与这一页是不是
    // 「同一份谓词」,只有 URL 说了才算,而那只有在这里可证。
    firingFilters.add({
      'triggerId': triggerId ?? '',
      'status': status?.name ?? '',
      'createdAfter': createdAfter?.toUtc().toIso8601String() ?? '',
      'createdBefore': createdBefore?.toUtc().toIso8601String() ?? '',
      'limit': '${limit ?? 0}',
    });
    if (failFirings) {
      throw const ApiException(
          code: 'TRIGGER_FIRING_INVALID_FILTER', message: 'bad window', httpStatus: 422);
    }
    final rows = _matchFirings(
        triggerId: triggerId,
        status: status,
        createdAfter: createdAfter,
        createdBefore: createdBefore);
    final cap = limit ?? 50;
    final capped = rows.length > cap;
    return contract.Page(
      items: capped ? rows.sublist(0, cap) : rows,
      hasMore: capped,
      nextCursor: capped ? 'stub-firings-1' : null,
    );
  }

  @override
  Future<List<TriggerEntity>> listTriggers() async => [for (final t in triggers) _liveTrigger(t)];

  @override
  Future<List<EntityRelation>> workflowTriggerEdges() async => edges;

  @override
  Future<List<SchedulerInboxRow>> listInbox() async => [
        for (final r in inbox)
          if (!decided.contains('${r.node.flowrunId}/${r.node.nodeId}') &&
              !cancelled.contains(r.node.flowrunId))
            r,
      ];

  @override
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
      {required String decision, String? reason}) async {
    if (decideLatency > Duration.zero) await Future<void>.delayed(decideLatency);
    final key = '$flowrunId/$nodeId';
    if (decided.contains(key)) {
      throw const ApiException(
          code: 'FLOWRUN_APPROVAL_NOT_PARKED', message: 'not parked', httpStatus: 422);
    }
    decided.add(key);
    decideOrder.add('$key:$decision${reason == null ? '' : ':$reason'}');
    return FlowrunComposite(
        flowrun: Flowrun(id: flowrunId, workflowId: 'wf_x', updatedAt: DateTime.now()));
  }

  @override
  Future<FlowrunComposite> cancelRun(String flowrunId) async {
    final run = runs.where((r) => r.id == flowrunId).firstOrNull;
    if (run == null || run.status != 'running' || cancelled.contains(flowrunId)) {
      throw const ApiException(
          code: 'FLOWRUN_NOT_CANCELLABLE', message: 'not running', httpStatus: 422);
    }
    cancelled.add(flowrunId);
    cancelOrder.add(flowrunId);
    return FlowrunComposite(
        flowrun: Flowrun(
            id: flowrunId,
            workflowId: run.workflowId,
            status: 'cancelled',
            updatedAt: DateTime.now()));
  }

  /// The run's CURRENT status under the stateful mutations. 有状态下的当前状态。
  String statusOf(Flowrun r) {
    if (cancelled.contains(r.id)) return 'cancelled';
    if (replayed.contains(r.id) && r.status == 'failed') return 'running';
    return r.status;
  }

  /// The run under the stateful mutations. Every OTHER field must ride through untouched — a stub
  /// that silently drops `pinnedRefs`/`firingId` would make the dossier's pinned-closure and the
  /// provenance line untestable and, worse, would let a real drop pass green.
  /// 有状态变更后的 run:其余字段必须原样带过——静默丢 pinnedRefs/firingId 的 stub 会让卷宗闭包与出处行
  /// 无法可测,更糟的是会让真正的丢失一路绿灯。
  Flowrun _live(Flowrun r) => r.copyWith(
        status: statusOf(r),
        error: statusOf(r) == 'failed' ? r.error : null,
        completedAt: statusOf(r) == 'running' ? null : r.completedAt,
      );

  @override
  Future<contract.Page<Flowrun>> listFlowruns(
      {required String workflowId,
      String? status,
      String? origin,
      String? triggerId,
      DateTime? startedAfter,
      DateTime? startedBefore,
      String? cursor,
      int? limit}) async {
    listFilters.add((
      status: status,
      origin: origin,
      startedAfter: startedAfter,
      cursor: cursor,
      limit: limit
    ));
    final rows = [
      for (final r in runs.map(_live))
        if (r.workflowId == workflowId &&
            (status == null || r.status == status) &&
            (origin == null || r.origin == origin) &&
            (triggerId == null || r.triggerId == triggerId) &&
            (startedAfter == null ||
                (r.startedAt != null && !r.startedAt!.isBefore(startedAfter))) &&
            (startedBefore == null ||
                (r.startedAt != null && r.startedAt!.isBefore(startedBefore))))
          r,
    ];
    // Offset cursor (the wire cursor is opaque anyway) — lets a battery walk real keyset paging.
    // 偏移游标模拟 keyset(线缆游标本就不透明)。
    final offset = cursor != null ? (int.tryParse(cursor) ?? 0) : 0;
    final cap = limit ?? 25;
    final page = rows.skip(offset).take(cap).toList();
    final more = offset + page.length < rows.length;
    return contract.Page(
        items: page, nextCursor: more ? '${offset + page.length}' : null, hasMore: more);
  }

  @override
  Future<Flowrun> getRun(String flowrunId) async {
    final r = runs.where((r) => r.id == flowrunId).firstOrNull;
    if (r == null) {
      throw const ApiException(code: 'FLOWRUN_NOT_FOUND', message: 'no run', httpStatus: 404);
    }
    return _live(r);
  }

  @override
  Future<FlowrunComposite> getRunFull(String flowrunId) async {
    if (failRunFull) throw StateError('node history unavailable');
    final run = await getRun(flowrunId);
    return FlowrunComposite(flowrun: run, nodes: nodesByRun[flowrunId] ?? const []);
  }

  @override
  Future<WorkflowEntity> getWorkflow(String id) async {
    final w = workflows.where((w) => w.id == id).firstOrNull;
    if (w == null) {
      throw const ApiException(code: 'WORKFLOW_NOT_FOUND', message: 'no workflow', httpStatus: 404);
    }
    final now = DateTime.now();
    final graph = graphByWorkflow[id];
    return WorkflowEntity(
      id: w.id,
      name: w.name,
      lifecycleState: killOrder.contains(id) ? 'inactive' : w.lifecycleState,
      needsAttention: w.needsAttention,
      createdAt: now,
      updatedAt: w.updatedAt ?? now,
      activeVersion: graph == null
          ? null
          : WorkflowVersion(
              id: 'wfv_$id',
              workflowId: id,
              version: 7,
              createdAt: now,
              updatedAt: now,
              graphParsed: graph),
    );
  }

  @override
  Future<String> runNow(String workflowId) async {
    runNowOrder.add(workflowId);
    return 'fr_new0000000000';
  }

  @override
  Future<WorkflowEntity> killWorkflow(String workflowId) async {
    killOrder.add(workflowId);
    for (final r in runs) {
      if (r.workflowId == workflowId && statusOf(r) == 'running') cancelled.add(r.id);
    }
    return getWorkflow(workflowId);
  }

  @override
  Future<FlowrunComposite> replayRun(String flowrunId) async {
    if (replayLatency > Duration.zero) await Future<void>.delayed(replayLatency);
    final r = runs.where((r) => r.id == flowrunId).firstOrNull;
    if (r == null || statusOf(r) != 'failed') {
      // Only a failed run replays — anything else (already replayed / cancelled) is the honest 422.
      // 只有 failed 可重放,其余诚实 422。
      throw const ApiException(
          code: 'FLOWRUN_NOT_REPLAYABLE', message: 'not failed', httpStatus: 422);
    }
    replayed.add(flowrunId);
    replayOrder.add(flowrunId);
    return getRunFull(flowrunId);
  }

  @override
  Future<TriggerEntity> pauseTrigger(String triggerId) => _flip(triggerId, true);

  @override
  Future<TriggerEntity> resumeTrigger(String triggerId) => _flip(triggerId, false);

  Future<TriggerEntity> _flip(String triggerId, bool paused) async {
    pausedById[triggerId] = paused;
    pauseOrder.add('$triggerId:${paused ? 'pause' : 'resume'}');
    final t = triggers.where((t) => t.id == triggerId).firstOrNull;
    if (t == null) {
      throw const ApiException(code: 'TRIGGER_NOT_FOUND', message: 'no trigger', httpStatus: 404);
    }
    return _liveTrigger(t);
  }

  @override
  Future<List<FlowrunActivityRow>> listActivity(String flowrunId) async {
    if (failActivity) throw StateError('activity unavailable');
    activityAsked.add(flowrunId);
    return activityByRun[flowrunId] ?? const [];
  }

  @override
  Future<WorkflowVersion> getWorkflowVersion(String workflowId, String versionId) async {
    versionAsked.add(versionId);
    final g = pinnedGraphByVersion[versionId];
    if (g == null) {
      throw const ApiException(
          code: 'WORKFLOW_VERSION_NOT_FOUND', message: 'no version', httpStatus: 404);
    }
    final now = DateTime.now();
    return WorkflowVersion(
        id: versionId,
        workflowId: workflowId,
        version: 7,
        createdAt: now,
        updatedAt: now,
        graphParsed: g);
  }

  @override
  Future<String> triageRun(String flowrunId) async {
    triageOrder.add(flowrunId);
    return 'cv_triage00000001';
  }

  @override
  Future<TriggerSchedule> triggerSchedule({String within = '24h', int limit = 200}) async {
    scheduleWithins.add(within);
    if (failSchedule) {
      throw const ApiException(
          code: 'TRIGGER_SCHEDULE_INVALID_QUERY', message: 'bad window', httpStatus: 422);
    }
    return schedule;
  }

  @override
  Future<FlowrunMatrix> runMatrix(String workflowId, {int recentN = 20}) async {
    matrixAsks.add((workflowId: workflowId, recentN: recentN));
    if (failMatrix) {
      throw const ApiException(code: 'INVALID_REQUEST', message: 'bad matrix', httpStatus: 400);
    }
    // An unknown workflowId is NOT an error — the endpoint answers three empty lists.
    // 未知 workflowId 不是错误——端点返三个空列表。
    return matrixByWorkflow[workflowId] ?? const FlowrunMatrix();
  }

  @override
  Future<RetentionConfig> retention() async {
    retentionAsks++;
    if (failRetention) {
      throw const ApiException(code: 'INTERNAL', message: 'boom', httpStatus: 500);
    }
    return retentionConfig;
  }

  /// S5 probes: the WINDOW each schedule fetch asked for (a track that claims «24h» must have asked
  /// for 24h), the (workflowId, recentN) each matrix fetch asked for (proves the 20 cap really
  /// reached the wire), and how often the tombstone read its line.
  /// S5 探针:每次调度取数问的**窗**(号称 24h 的轨必须真问了 24h)、每次矩阵取数问的 (workflowId, recentN)
  /// (证 20 真到了线缆)、以及墓碑读了几次线。
  final List<String> scheduleWithins = [];

  /// Every `since` the stats fetch asked, and every firing filter — the pair that proves the card and
  /// the list it opens share ONE anchor. stats 每次问的 since,与每次 firing 过滤:这一对**证明**牌与它点开的
  /// 列表共用**一个**锚点。
  final List<String> statsSinces = [];
  final List<Map<String, String>> firingFilters = [];
  final List<({String workflowId, int recentN})> matrixAsks = [];
  int retentionAsks = 0;

  /// Probes: WHICH version id the flagship asked for (§5.2 钉版而非 active), which runs it aggregated,
  /// and every `:triage` it fired. 探针:旗舰问的是哪个版本 id / 聚合了哪些 run / 发过哪些诊断。
  final List<String> versionAsked = [];
  final List<String> activityAsked = [];
  final List<String> triageOrder = [];

  /// A trigger under the pause overrides — paused reads listening=false + nextFireAt ABSENT, exactly
  /// like the wire (工单⑦). 暂停覆写后的 trigger:与线缆一致(不监听、无下次)。
  TriggerEntity _liveTrigger(TriggerEntity t) {
    final paused = pausedById[t.id] ?? t.paused;
    return t.copyWith(
        paused: paused,
        listening: !paused && t.listening,
        nextFireAt: paused ? null : t.nextFireAt);
  }
}

/// One enriched inbox row seed. 一行收件箱种子。
SchedulerInboxRow stubInboxRow(
  String frId,
  String nodeId, {
  String wfId = 'wf_a',
  String wfName = '数据清洗流水线',
  DateTime? deadline,
  Duration waited = const Duration(minutes: 18),
  bool allowReason = true,
  DateTime? now,
}) {
  final base = now ?? DateTime.now();
  return SchedulerInboxRow(
    node: FlowrunNode(
      id: 'frn_$frId',
      flowrunId: frId,
      nodeId: nodeId,
      kind: 'approval',
      status: 'parked',
      result: {'rendered': 'gate $nodeId?', 'allowReason': allowReason},
      createdAt: base.subtract(waited),
      updatedAt: base.subtract(waited),
    ),
    workflowId: wfId,
    workflowName: wfName,
    deadline: deadline,
  );
}
