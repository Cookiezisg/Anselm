import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/contract/page.dart' as contract;
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';

// The ONE scriptable Scheduler seam for the test batteries (S2a board + S2b action zones) — every
// zone's inputs are injectable, and decide/cancel are STATEFUL (decided rows leave the inbox, a
// second decide loses first-wins with 422, cancelled runs leave the running filter) so widget tests
// can walk the full settle grammar. 全可编脚本的数据缝:decide/cancel 有状态,widget 测试走全程。

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
    this.failWorkflows = false,
  });

  final List<SchedulerWorkflowRow> workflows;
  final List<WorkflowRunStats> byWorkflow;
  final Map<String, int> failedBySince;
  final int totalsRunning;
  final List<TriggerEntity> triggers;
  final List<EntityRelation> edges;
  final List<SchedulerInboxRow> inbox;
  final List<Flowrun> runs;
  final bool failWorkflows;

  /// Stateful decide/cancel so the batteries can walk the full settle grammar. Order proves the
  /// batch dispatched SEQUENTIALLY. 有状态;decideOrder 证批量逐发。
  final Set<String> decided = {};
  final List<String> decideOrder = [];
  final Set<String> cancelled = <String>{};
  final List<String> cancelOrder = [];

  /// Optional decide latency — lets a widget test observe the mid-batch pending face (逐行挂账).
  /// 可选延迟:widget 测试借它观察批中挂账脸。
  Duration decideLatency = Duration.zero;

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
  Future<List<TriggerEntity>> listTriggers() async => triggers;

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

  @override
  Future<contract.Page<Flowrun>> listFlowruns(
      {required String workflowId, String? status, String? cursor, int? limit}) async {
    final rows = [
      for (final r in runs)
        if (r.workflowId == workflowId &&
            (status == null || (cancelled.contains(r.id) ? 'cancelled' : r.status) == status))
          r,
    ];
    final capped = limit != null && limit < rows.length ? rows.sublist(0, limit) : rows;
    return contract.Page(items: capped, hasMore: capped.length < rows.length);
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
