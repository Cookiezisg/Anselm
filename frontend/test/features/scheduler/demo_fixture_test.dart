import 'package:anselm/core/contract/api_error.dart';
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

  test('inbox seeds all three enrich forms (S2b 工单④): deadline soon / no deadline / '
      'soft-deleted host name fallen back to the bare id (overdue)', () async {
    final rows = await repo.listInbox();
    expect(rows.length, greaterThanOrEqualTo(3), reason: '≥3 收件箱行');

    final now = DateTime.now();
    final soon = rows.where((r) =>
        r.deadline != null &&
        r.deadline!.isAfter(now.add(const Duration(hours: 1))) &&
        r.deadline!.isBefore(now.add(const Duration(hours: 3))));
    expect(soon, isNotEmpty, reason: '带 deadline 将超时(剩~2h)形');

    expect(rows.where((r) => r.deadline == null), isNotEmpty, reason: '无 deadline 形(不渲倒计时)');

    final ghost = rows.where((r) => r.workflowName == r.workflowId);
    expect(ghost, isNotEmpty, reason: '宿主软删名回落裸 id 形');
    expect(ghost.first.deadline!.isBefore(now), isTrue, reason: '软删形种已超时(danger 脸)');

    for (final r in rows) {
      expect(r.node.status, 'parked');
      expect(r.node.result['rendered'], isNotEmpty, reason: '审批门要渲 prompt');
      expect(r.workflowName, isNotEmpty);
    }
    expect(rows.where((r) => r.node.result['allowReason'] == true), isNotEmpty,
        reason: '至少一行长理由输入');
    expect(rows.where((r) => r.node.result['allowReason'] == false), isNotEmpty,
        reason: '至少一行不长理由输入');
  });

  test('decide is stateful: the row leaves the inbox; a second decide loses first-wins (422)',
      () async {
    final fresh = demoSchedulerRepository();
    final before = await fresh.listInbox();
    final target = before.first;
    await fresh.decideApproval(target.node.flowrunId, target.node.nodeId, decision: 'yes');
    final after = await fresh.listInbox();
    expect(after.length, before.length - 1, reason: '决了行消失');
    expect(after.where((r) => r.node.flowrunId == target.node.flowrunId), isEmpty);

    await expectLater(
      fresh.decideApproval(target.node.flowrunId, target.node.nodeId, decision: 'no'),
      throwsA(isA<ApiException>()
          .having((e) => e.httpStatus, 'httpStatus', 422)
          .having((e) => e.code, 'code', 'FLOWRUN_APPROVAL_NOT_PARKED')),
    );
  });

  test('cancel is stateful: the running row leaves; its parked inbox row is withdrawn; '
      'a second cancel (and a non-running cancel) earn 422', () async {
    final fresh = demoSchedulerRepository();
    // Cancel the parked wf_report run — running zone loses it AND its inbox row goes (CancelParkedNodes).
    // 取消 parked run:正在跑除名 + 收件箱行一并收回。
    const frId = 'fr_9a12b34c56d78e90';
    await fresh.cancelRun(frId);
    final running = await fresh.listFlowruns(workflowId: 'wf_report', status: 'running');
    expect(running.items, isEmpty, reason: '取消后 running 行消失');
    final inbox = await fresh.listInbox();
    expect(inbox.where((r) => r.node.flowrunId == frId), isEmpty, reason: '收件箱不留死项');

    await expectLater(
        fresh.cancelRun(frId),
        throwsA(isA<ApiException>()
            .having((e) => e.httpStatus, 'httpStatus', 422)
            .having((e) => e.code, 'code', 'FLOWRUN_NOT_CANCELLABLE')));
    await expectLater(fresh.cancelRun('fr_c3d4e5f607182930'),
        throwsA(isA<ApiException>().having((e) => e.httpStatus, 'httpStatus', 422)),
        reason: 'failed run 不可取消');
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
