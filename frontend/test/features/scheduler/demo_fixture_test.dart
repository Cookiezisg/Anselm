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
