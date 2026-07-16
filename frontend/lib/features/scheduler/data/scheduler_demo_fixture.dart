import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import 'scheduler_repository.dart';

// The Scheduler demo battery (WRK-069 §15) — PURE DATA seeds covering every rail/overview state so
// `make demo` shows the whole grammar with zero backend: running / waiting-on-human (deadline soon ·
// no deadline · soft-deleted host) / consecutive failures / self-healed / cron-scheduled / never-ran
// / inactive. Deterministic relative to [_now] (fixed seed times; the repo shifts them against the
// real clock at read so «2h ago» stays honest). S2b: decide/cancel are STATEFUL (a decided row
// leaves the inbox; a cancelled run leaves the running zone; a second attempt earns the honest 422)
// so the demo walks the full first-wins / cancel grammar without a backend.
// demo 电池:纯数据种子铺全态;种子时刻相对固定锚,读时对真钟平移,相对时间永远诚实。S2b:decide/cancel
// 有状态(决了行消失/取消后 running 行消失/二次操作得诚实 422),demo 免后端走全程。
final _anchor = DateTime.utc(2026, 7, 16, 9);

DateTime _shift(DateTime seed) {
  // Seeds are authored against _anchor; at read we re-base them onto the real now so relative
  // labels («2h ago» / «in 3m») render as designed regardless of when the demo runs.
  // 以锚点写种子,读时重定基到真实 now。
  final offset = seed.difference(_anchor);
  return DateTime.now().add(offset);
}

class FixtureSchedulerRepository implements SchedulerRepository {
  /// Decided approvals ('$flowrunId/$nodeId') — gone from the inbox; deciding twice loses the
  /// first-wins race (422). 已决集合:收件箱除名,二决 422。
  final Set<String> _decided = {};

  /// Cancelled run ids — gone from the running zone (and their parked rows from the inbox, the
  /// backend's CancelParkedNodes); cancelling a non-running run earns 422. 已取消集合。
  final Set<String> _cancelled = {};

  @override
  Future<List<SchedulerWorkflowRow>> listWorkflows() async => [
        SchedulerWorkflowRow(
            id: 'wf_clean', name: '数据清洗流水线', lifecycleState: 'active', updatedAt: _shift(_anchor)),
        SchedulerWorkflowRow(
            id: 'wf_report',
            name: '周报生成',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(days: 1)))),
        SchedulerWorkflowRow(
            id: 'wf_deploy',
            name: '发布上线',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(minutes: 5)))),
        SchedulerWorkflowRow(
            id: 'wf_inventory',
            name: '库存同步',
            lifecycleState: 'active',
            needsAttention: true,
            updatedAt: _shift(_anchor.subtract(const Duration(days: 2)))),
        SchedulerWorkflowRow(
            id: 'wf_archive',
            name: '邮件归档',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(days: 3)))),
        SchedulerWorkflowRow(
            id: 'wf_new', name: '发票对账(新)', lifecycleState: 'active', updatedAt: _shift(_anchor)),
        SchedulerWorkflowRow(
            id: 'wf_draft',
            name: '草稿清理(新)',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(hours: 5)))),
        SchedulerWorkflowRow(
            id: 'wf_retired',
            name: '旧版同步(停用)',
            lifecycleState: 'inactive',
            updatedAt: _shift(_anchor.subtract(const Duration(days: 30)))),
      ];

  @override
  Future<SchedulerStats> stats(List<String> workflowIds, {int recentN = 10, String since = '168h'}) async {
    final all = <WorkflowRunStats>[
      // Running now (blue dot; started 90s ago). 在跑。
      WorkflowRunStats(
        workflowId: 'wf_clean',
        running: _cancelled.contains('fr_0a1b2c3d4e5f6071') ? 0 : 1,
        lastRunAt: _shift(_anchor.subtract(const Duration(seconds: 90))),
        recent: const ['running', 'completed', 'completed', 'failed', 'completed'],
        successRate: 0.8,
        avgElapsedMs: 42000,
      ),
      // Waiting on a human (amber; a parked approval 18m old, deadline ~2h out). 等人(带期限)。
      WorkflowRunStats(
        workflowId: 'wf_report',
        running: _cancelled.contains('fr_9a12b34c56d78e90') ? 0 : 1,
        parkedNodes: _parkedCount('fr_9a12b34c56d78e90'),
        lastRunAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
        recent: const ['running', 'completed', 'completed'],
        successRate: 1.0,
        avgElapsedMs: 8000,
      ),
      // Waiting on a human, NO deadline (the approval never times out). 等人(无期限)。
      WorkflowRunStats(
        workflowId: 'wf_deploy',
        running: _cancelled.contains('fr_de91f20a3b4c5d6e') ? 0 : 1,
        parkedNodes: _parkedCount('fr_de91f20a3b4c5d6e'),
        lastRunAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
        recent: const ['running', 'completed'],
        successRate: 1.0,
        avgElapsedMs: 15000,
      ),
      // Consecutive failures ×4 (red dot; last failed 1h ago). 连败。
      WorkflowRunStats(
        workflowId: 'wf_inventory',
        lastRunAt: _shift(_anchor.subtract(const Duration(hours: 1))),
        recent: const ['failed', 'failed', 'failed', 'failed', 'completed'],
        successRate: 0.2,
        avgElapsedMs: 12000,
        consecutiveFailures: 4,
      ),
      // Self-healed (had failures, latest completed — no dot). 自愈。
      WorkflowRunStats(
        workflowId: 'wf_archive',
        lastRunAt: _shift(_anchor.subtract(const Duration(hours: 26))),
        recent: const ['completed', 'failed', 'failed', 'completed'],
        successRate: 0.5,
        avgElapsedMs: 60000,
      ),
      // wf_new / wf_draft: never ran (no stats row). wf_retired: inactive (no stats row).
    ];
    // Window-aware failed totals — the Overview KPI's delta needs 24h vs 48h to differ:
    // failed24=4, failed48=6 → prior-24h window = 2 → delta = +2 (▲2, §3 mock). 7d holds the rest.
    // 窗口感知失败数:24h=4 / 48h=6 → 前一个 24h 窗=2 → delta=+2(对齐 §3 示意)。
    final failedSince = switch (since) { '24h' => 4, '48h' => 6, _ => 9 };
    // Live totals track the stateful cancels/decides (the demo stays honest after an action).
    // totals 跟随有状态操作(动作之后 demo 不撒谎)。
    final running = [for (final s in all) s.running].fold(0, (a, b) => a + b);
    final parked = [for (final s in all) s.parkedNodes].fold(0, (a, b) => a + b);
    return SchedulerStats(
      totals: SchedulerTotals(
          running: running, completedSince: 23, failedSince: failedSince, parkedNodes: parked),
      byWorkflow: workflowIds.isEmpty
          ? all
          : [for (final s in all) if (workflowIds.contains(s.workflowId)) s],
    );
  }

  int _parkedCount(String flowrunId) {
    if (_cancelled.contains(flowrunId)) return 0;
    return _inboxSeeds().where((r) => r.node.flowrunId == flowrunId && !_decided.contains('${r.node.flowrunId}/${r.node.nodeId}')).length;
  }

  /// The seeded run rows (newest first, mirroring the backend's keyset order) — the Overview's
  /// running rows + the failure aggregation's latest-failed probe read THESE, so every zone renders
  /// real data in `make demo`. A cancelled run flips to `cancelled` (out of the running filter).
  /// 种子 run 行(新→旧):正在跑区与失败聚合探针的数据源;取消后翻 cancelled、退出 running 过滤。
  List<Flowrun> _runs() => [
        // wf_clean: the live run (blue, started 90s ago). 在跑。
        Flowrun(
          id: 'fr_0a1b2c3d4e5f6071',
          workflowId: 'wf_clean',
          status: _cancelled.contains('fr_0a1b2c3d4e5f6071') ? 'cancelled' : 'running',
          startedAt: _shift(_anchor.subtract(const Duration(seconds: 90))),
          updatedAt: _shift(_anchor),
        ),
        // wf_deploy: running but parked on a no-deadline approval. 等人(running∧parked,无期限)。
        Flowrun(
          id: 'fr_de91f20a3b4c5d6e',
          workflowId: 'wf_deploy',
          status: _cancelled.contains('fr_de91f20a3b4c5d6e') ? 'cancelled' : 'running',
          startedAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
          updatedAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
        ),
        // wf_report: running but parked on an approval (the waiting-on-human run). 等人(running∧parked)。
        Flowrun(
          id: 'fr_9a12b34c56d78e90',
          workflowId: 'wf_report',
          status: _cancelled.contains('fr_9a12b34c56d78e90') ? 'cancelled' : 'running',
          startedAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
          updatedAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
        ),
        // wf_inventory: the ×4 streak — latest failed run carries the error the aggregation quotes.
        // 连败最新失败 run(错误首句来源)。
        Flowrun(
          id: 'fr_c3d4e5f607182930',
          workflowId: 'wf_inventory',
          status: 'failed',
          error: 'HTTP 502 Bad Gateway: upstream inventory API did not respond\nretried 3 times',
          replayCount: 1,
          startedAt: _shift(_anchor.subtract(const Duration(hours: 1, seconds: 12))),
          completedAt: _shift(_anchor.subtract(const Duration(hours: 1))),
          updatedAt: _shift(_anchor.subtract(const Duration(hours: 1))),
        ),
        Flowrun(
          id: 'fr_b2c3d4e5f6071829',
          workflowId: 'wf_inventory',
          status: 'failed',
          error: 'HTTP 502 Bad Gateway: upstream inventory API did not respond',
          startedAt: _shift(_anchor.subtract(const Duration(hours: 7))),
          completedAt: _shift(_anchor.subtract(const Duration(hours: 7))),
          updatedAt: _shift(_anchor.subtract(const Duration(hours: 7))),
        ),
        // wf_archive: self-healed — latest completed over an older failure. 自愈。
        Flowrun(
          id: 'fr_d4e5f60718293a4b',
          workflowId: 'wf_archive',
          status: 'completed',
          startedAt: _shift(_anchor.subtract(const Duration(hours: 26))),
          completedAt: _shift(_anchor.subtract(const Duration(hours: 26))),
          updatedAt: _shift(_anchor.subtract(const Duration(hours: 26))),
        ),
        Flowrun(
          id: 'fr_e5f60718293a4b5c',
          workflowId: 'wf_archive',
          status: 'failed',
          error: 'disk full: /var/anselm/archive',
          startedAt: _shift(_anchor.subtract(const Duration(hours: 30))),
          completedAt: _shift(_anchor.subtract(const Duration(hours: 30))),
          updatedAt: _shift(_anchor.subtract(const Duration(hours: 30))),
        ),
      ];

  @override
  Future<Page<Flowrun>> listFlowruns(
      {required String workflowId, String? status, String? cursor, int? limit}) async {
    final rows = [
      for (final r in _runs())
        if (r.workflowId == workflowId && (status == null || r.status == status)) r,
    ];
    final capped = limit != null && limit < rows.length ? rows.sublist(0, limit) : rows;
    return Page(items: capped, hasMore: capped.length < rows.length);
  }

  /// The three inbox seed FORMS (工单④): deadline soon (~2h, amber countdown) / no deadline (no
  /// countdown) / soft-deleted host (name fell back to the bare id on the backend join; overdue
  /// deadline shows the danger face). 收件箱三形种子:将超时/无期限/宿主软删名回落(且已超时)。
  List<SchedulerInboxRow> _inboxSeeds() => [
        SchedulerInboxRow(
          node: FlowrunNode(
            id: 'frn_report_approve',
            flowrunId: 'fr_9a12b34c56d78e90',
            nodeId: 'approve_send',
            kind: 'approval',
            status: 'parked',
            result: const {'rendered': '本周报可以发出吗?', 'allowReason': true},
            createdAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
            updatedAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
          ),
          workflowId: 'wf_report',
          workflowName: '周报生成',
          deadline: _shift(_anchor.add(const Duration(hours: 2))),
        ),
        SchedulerInboxRow(
          node: FlowrunNode(
            id: 'frn_deploy_approve',
            flowrunId: 'fr_de91f20a3b4c5d6e',
            nodeId: 'approve_deploy',
            kind: 'approval',
            status: 'parked',
            result: const {'rendered': '可以发布 v2.4.1 到生产吗?', 'allowReason': false},
            createdAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
            updatedAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
          ),
          workflowId: 'wf_deploy',
          workflowName: '发布上线',
          // No deadline: the approval never times out → no countdown. 无期限,不渲倒计时。
        ),
        SchedulerInboxRow(
          node: FlowrunNode(
            id: 'frn_ghost_approve',
            flowrunId: 'fr_gh05t16273a4b5c6',
            nodeId: 'approve_cleanup',
            kind: 'approval',
            status: 'parked',
            result: const {'rendered': '继续清理 2019 年之前的归档?', 'allowReason': true},
            createdAt: _shift(_anchor.subtract(const Duration(days: 2))),
            updatedAt: _shift(_anchor.subtract(const Duration(days: 2))),
          ),
          // The host workflow was soft-deleted — the backend's name join fell back to the bare id.
          // 宿主软删,名回落裸 id。
          workflowId: 'wf_ghost',
          workflowName: 'wf_ghost',
          deadline: _shift(_anchor.subtract(const Duration(minutes: 30))),
        ),
      ];

  @override
  Future<List<SchedulerInboxRow>> listInbox() async => [
        for (final r in _inboxSeeds())
          if (!_decided.contains('${r.node.flowrunId}/${r.node.nodeId}') &&
              !_cancelled.contains(r.node.flowrunId))
            r,
      ];

  @override
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
      {required String decision, String? reason}) async {
    final key = '$flowrunId/$nodeId';
    final live = await listInbox();
    if (!live.any((r) => r.node.flowrunId == flowrunId && r.node.nodeId == nodeId)) {
      // Lost the first-wins race (or the node never parked) — the honest 422. 输家诚实 422。
      throw const ApiException(
          code: 'FLOWRUN_APPROVAL_NOT_PARKED',
          message: 'approval is not parked',
          httpStatus: 422);
    }
    _decided.add(key);
    final run = _runs().firstWhere((r) => r.id == flowrunId);
    return FlowrunComposite(flowrun: run);
  }

  @override
  Future<FlowrunComposite> cancelRun(String flowrunId) async {
    final run = _runs().where((r) => r.id == flowrunId).firstOrNull;
    if (run == null || run.status != 'running') {
      throw const ApiException(
          code: 'FLOWRUN_NOT_CANCELLABLE',
          message: 'only a running flowrun can be cancelled',
          httpStatus: 422);
    }
    _cancelled.add(flowrunId);
    return FlowrunComposite(
        flowrun: Flowrun(
            id: run.id, workflowId: run.workflowId, status: 'cancelled', updatedAt: DateTime.now()));
  }

  @override
  Future<List<TriggerEntity>> listTriggers() async => [
        TriggerEntity(
          id: 'tr_cron_clean',
          name: '每日 09:00',
          kind: TriggerSource.cron,
          config: const {'cron': '0 9 * * *'},
          createdAt: _shift(_anchor.subtract(const Duration(days: 30))),
          updatedAt: _shift(_anchor.subtract(const Duration(days: 30))),
          refCount: 1,
          listening: true,
          lastFiredAt: _shift(_anchor.subtract(const Duration(minutes: 2))),
          nextFireAt: _shift(_anchor.add(const Duration(minutes: 3))),
        ),
        TriggerEntity(
          id: 'tr_cron_report',
          name: '每周一 08:00',
          kind: TriggerSource.cron,
          config: const {'cron': '0 8 * * 1'},
          createdAt: _shift(_anchor.subtract(const Duration(days: 60))),
          updatedAt: _shift(_anchor.subtract(const Duration(days: 60))),
          refCount: 1,
          listening: true,
          lastFiredAt: _shift(_anchor.subtract(const Duration(days: 2))),
          nextFireAt: _shift(_anchor.add(const Duration(days: 5))),
        ),
      ];

  @override
  Future<List<EntityRelation>> workflowTriggerEdges() async => const [
        EntityRelation(
            id: 'rel_1',
            kind: 'equip',
            fromKind: 'workflow',
            fromId: 'wf_clean',
            fromName: '数据清洗流水线',
            toKind: 'trigger',
            toId: 'tr_cron_clean',
            toName: '每日 09:00'),
        EntityRelation(
            id: 'rel_2',
            kind: 'equip',
            fromKind: 'workflow',
            fromId: 'wf_report',
            fromName: '周报生成',
            toKind: 'trigger',
            toId: 'tr_cron_report',
            toName: '每周一 08:00'),
      ];
}

SchedulerRepository demoSchedulerRepository() => FixtureSchedulerRepository();
