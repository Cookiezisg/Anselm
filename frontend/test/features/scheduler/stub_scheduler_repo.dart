import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/contract/page.dart' as contract;
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
    this.failWorkflows = false,
    this.failRunFull = false,
  });

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

  final bool failWorkflows;

  /// getRunFull throws — the replay confirm must still open, with the numberless sentence.
  /// 取数失败:确认框仍开,句子不带假数。
  final bool failRunFull;

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
          {int recentN = 10, String since = '168h'}) async =>
      SchedulerStats(
        totals: SchedulerTotals(
            running: totalsRunning,
            failedSince: failedBySince[since] ?? 0,
            parkedNodes: inbox.length),
        byWorkflow: byWorkflow,
      );

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

  Flowrun _live(Flowrun r) => Flowrun(
        id: r.id,
        workflowId: r.workflowId,
        versionId: r.versionId,
        triggerId: r.triggerId,
        origin: r.origin,
        conversationId: r.conversationId,
        status: statusOf(r),
        replayCount: r.replayCount,
        error: statusOf(r) == 'failed' ? r.error : null,
        startedAt: r.startedAt,
        completedAt: statusOf(r) == 'running' ? null : r.completedAt,
        updatedAt: r.updatedAt,
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
