import 'package:anselm/features/scheduler/data/scheduler_demo_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

// The Scheduler demo battery's seed-correctness lock (WRK-069 §15 — fixture is pure data, the test
// pins the states the rail grammar needs; D-track tactic). demo 种子正确性锁。

void main() {
  final repo = demoSchedulerRepository();

  test('every rail state is seeded: running / waiting / failing / healed / never-ran / inactive', () async {
    final wfs = await repo.listWorkflows();
    final stats = await repo.stats(const []);
    final byId = {for (final s in stats.byWorkflow) s.workflowId: s};

    expect(wfs.where((w) => w.lifecycleState == 'inactive'), isNotEmpty, reason: '停用段种子');
    final neverRan = wfs.where((w) => w.lifecycleState != 'inactive' && !byId.containsKey(w.id));
    expect(neverRan.length, greaterThanOrEqualTo(2), reason: '未运行段种子(≥2 供排序)');

    expect(byId.values.where((s) => s.running > 0 && s.parkedNodes == 0), isNotEmpty, reason: '在跑(蓝)');
    expect(byId.values.where((s) => s.parkedNodes > 0), isNotEmpty, reason: '等人(琥珀)');
    expect(byId.values.where((s) => s.consecutiveFailures >= 4), isNotEmpty, reason: '连败×4(红)');
    expect(
      byId.values.where((s) =>
          s.consecutiveFailures == 0 && s.recent.contains('failed') && s.recent.first == 'completed'),
      isNotEmpty,
      reason: '自愈(曾败,最新成)',
    );
  });

  test('stats honours the requested-id filter; totals stay workspace-wide', () async {
    final one = await repo.stats(const ['wf_clean']);
    expect(one.byWorkflow.map((s) => s.workflowId), ['wf_clean']);
    expect(one.totals.running, greaterThan(0), reason: 'totals 不随 ids 过滤');
  });

  test('run rows: every running workflow has a running run; the streak workflow has a failed run '
      'with a wire error (the Overview zones all render real data)', () async {
    final stats = await repo.stats(const []);
    for (final s in stats.byWorkflow.where((s) => s.running > 0)) {
      final page = await repo.listFlowruns(workflowId: s.workflowId, status: 'running');
      expect(page.items, isNotEmpty, reason: '正在跑区种子:${s.workflowId}');
      expect(page.items.every((r) => r.status == 'running' && r.startedAt != null), isTrue,
          reason: '活耗时需要 startedAt');
    }
    final streak = stats.byWorkflow.firstWhere((s) => s.consecutiveFailures > 0);
    final failed = await repo.listFlowruns(workflowId: streak.workflowId, status: 'failed', limit: 1);
    expect(failed.items, hasLength(1), reason: 'limit=1 探针');
    expect(failed.items.first.error, isNotEmpty, reason: '失败聚合错误首句来源');
    expect(failed.hasMore, isTrue, reason: '连败 workflow 有多条失败,limit 截断诚实');
  });

  test('failed totals are window-aware: 24h < 48h < 7d, and the KPI delta reads positive (+2)',
      () async {
    final f24 = (await repo.stats(const [], since: '24h')).totals.failedSince;
    final f48 = (await repo.stats(const [], since: '48h')).totals.failedSince;
    final f7d = (await repo.stats(const [])).totals.failedSince;
    expect(f24, lessThan(f48));
    expect(f48, lessThan(f7d));
    expect(f24 - (f48 - f24), 2, reason: '§3 示意「24h失败 4 ▲2」');
  });

  test('a listening cron trigger fires WITHIN the next 24h (the upcoming zone has a row)', () async {
    final triggers = await repo.listTriggers();
    final edges = await repo.workflowTriggerEdges();
    final now = DateTime.now();
    final soon = triggers.where((t) =>
        t.listening &&
        t.nextFireAt != null &&
        t.nextFireAt!.isAfter(now) &&
        t.nextFireAt!.isBefore(now.add(const Duration(hours: 24))));
    expect(soon, isNotEmpty, reason: '未来 24h 区种子');
    expect(edges.map((e) => e.toId), containsAll(soon.map((t) => t.id)),
        reason: '未来行需要 workflow 边 join');
  });

  test('cron triggers carry a FUTURE nextFireAt and an equip edge to their workflow', () async {
    final triggers = await repo.listTriggers();
    final edges = await repo.workflowTriggerEdges();
    expect(triggers.where((t) => t.nextFireAt != null && t.nextFireAt!.isAfter(DateTime.now())),
        isNotEmpty, reason: '⏱ meta 需要未来 fire');
    for (final e in edges) {
      expect(e.fromKind, 'workflow');
      expect(e.toKind, 'trigger');
      expect(triggers.map((t) => t.id), contains(e.toId), reason: '边指向存在的 trigger');
    }
    expect(edges, isNotEmpty);
  });
}
