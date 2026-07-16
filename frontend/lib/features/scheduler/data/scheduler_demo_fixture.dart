import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import 'scheduler_repository.dart';

// The Scheduler demo battery (WRK-069 §15) — PURE DATA seeds covering every rail/overview state so
// `make demo` shows the whole grammar with zero backend: running / waiting-on-human / consecutive
// failures / self-healed / cron-scheduled / never-ran / inactive. Deterministic relative to [_now]
// (fixed seed times; the repo shifts them against the real clock at read so «2h ago» stays honest).
// demo 电池:纯数据种子铺全态;种子时刻相对固定锚,读时对真钟平移,相对时间永远诚实。
final _anchor = DateTime.utc(2026, 7, 16, 9);

DateTime _shift(DateTime seed) {
  // Seeds are authored against _anchor; at read we re-base them onto the real now so relative
  // labels («2h ago» / «in 3m») render as designed regardless of when the demo runs.
  // 以锚点写种子,读时重定基到真实 now。
  final offset = seed.difference(_anchor);
  return DateTime.now().add(offset);
}

class FixtureSchedulerRepository implements SchedulerRepository {
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
        running: 1,
        lastRunAt: _shift(_anchor.subtract(const Duration(seconds: 90))),
        recent: const ['running', 'completed', 'completed', 'failed', 'completed'],
        successRate: 0.8,
        avgElapsedMs: 42000,
      ),
      // Waiting on a human (amber; a parked approval 18m old). 等人。
      WorkflowRunStats(
        workflowId: 'wf_report',
        running: 1,
        parkedNodes: 1,
        lastRunAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
        recent: const ['running', 'completed', 'completed'],
        successRate: 1.0,
        avgElapsedMs: 8000,
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
    return SchedulerStats(
      totals: const SchedulerTotals(running: 2, completedSince: 23, failedSince: 4, parkedNodes: 1),
      byWorkflow: workflowIds.isEmpty
          ? all
          : [for (final s in all) if (workflowIds.contains(s.workflowId)) s],
    );
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
  Future<int> waitingCount() async => 1; // wf_report 的 parked 审批。

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
