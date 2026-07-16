import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
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

  // ─────────────────────────── S3 · 运营主页种子 ───────────────────────────

  test('the home\'s run history pages (25+ rows over every origin, failures carry wire errors)',
      () async {
    final first = await repo.listFlowruns(workflowId: 'wf_clean', limit: 25);
    expect(first.items, hasLength(25), reason: '首页满 25');
    expect(first.hasMore, isTrue, reason: '25+ 条史 → 必翻页(哨兵有活干)');
    expect(first.nextCursor, isNotNull);

    final second = await repo.listFlowruns(workflowId: 'wf_clean', cursor: first.nextCursor, limit: 25);
    expect(second.items, isNotEmpty, reason: '第二页有行');
    final ids = {for (final r in [...first.items, ...second.items]) r.id};
    expect(ids.length, first.items.length + second.items.length, reason: '两页不重不漏');

    // Newest-first, the backend's keyset order. 新→旧。
    final stamps = [for (final r in first.items) r.startedAt!];
    for (var i = 1; i < stamps.length; i++) {
      expect(stamps[i].isAfter(stamps[i - 1]), isFalse, reason: '新→旧');
    }

    final all = [...first.items, ...second.items];
    final origins = {for (final r in all) r.origin};
    expect(origins, containsAll(<String?>['cron', 'chat', 'webhook', 'manual']), reason: '全来源种齐');
    expect(origins, contains(null), reason: '旧行(origin 缺席)种子 → unknown 脸');

    final chat = all.firstWhere((r) => r.origin == 'chat');
    expect(chat.conversationId, isNotNull, reason: 'chat 行带对话坐标(工单①)');

    final failed = all.where((r) => r.status == 'failed');
    expect(failed, isNotEmpty);
    expect(failed.every((r) => (r.error ?? '').isNotEmpty), isTrue, reason: '失败行带错误(渲 danger 副行)');
    expect(failed.any((r) => r.error!.contains('\n')), isTrue, reason: '多行错误 → 行只取首句');
  });

  test('the wire filters really narrow: status / origin / startedAfter (工单⑥)', () async {
    final failed = await repo.listFlowruns(workflowId: 'wf_clean', status: 'failed', limit: 50);
    expect(failed.items, isNotEmpty);
    expect(failed.items.every((r) => r.status == 'failed'), isTrue);

    final cron = await repo.listFlowruns(workflowId: 'wf_clean', origin: 'cron', limit: 50);
    expect(cron.items.every((r) => r.origin == 'cron'), isTrue);

    final since = DateTime.now().subtract(const Duration(hours: 24));
    final win = await repo.listFlowruns(workflowId: 'wf_clean', startedAfter: since, limit: 50);
    expect(win.items.every((r) => !r.startedAt!.isBefore(since)), isTrue);
    expect(win.items.length, lessThan((await repo.listFlowruns(workflowId: 'wf_clean', limit: 50)).items.length),
        reason: '24h 窗真的收窄了(全部时间更多)');
  });

  test('run nodes seed the linked pane: failures stop at analyze (notify 未及), completions walk all',
      () async {
    final failed = await repo.getRunFull('fr_hook0000000fa1');
    expect(failed.nodes.map((n) => n.nodeId), ['fetch', 'gate', 'analyze']);
    expect(failed.nodes.last.status, 'failed');
    expect(failed.nodes.last.error, isNotEmpty, reason: '甘特红条与台账同句同源');
    expect(failed.nodes.map((n) => n.nodeId), isNot(contains('notify')), reason: 'notify 未及(灰弱)');

    final done = await repo.getRunFull('fr_chat00000000a1');
    expect(done.nodes.map((n) => n.nodeId), ['fetch', 'gate', 'analyze', 'notify']);
    expect(done.nodes.every((n) => n.status == 'completed'), isTrue);
    // Spans must be real (the gantt falls back to equal slots only when the span collapses) — and
    // the span lives in the ⑫ STAMPS (startedAt→completedAt), never in createdAt, which is the row's
    // WRITE time and therefore lands ON the terminal. Asserting a createdAt-based span would be
    // asserting the pre-⑫ fiction the engine surgery removed.
    // 跨度真实,且跨度住在 ⑫ 两戳里(startedAt→completedAt),绝不在 createdAt——那是行的写入时刻、恰落在
    // 终态上。拿 createdAt 断言跨度,就是在断言引擎手术已经消灭的那个假象。
    expect(done.nodes.every((n) => n.readyAt != null && n.startedAt != null), isTrue,
        reason: '⑫ 排队戳:甘特三段条的数据源');
    expect(done.nodes.every((n) => !n.startedAt!.isBefore(n.readyAt!)), isTrue,
        reason: '因果序 readyAt ≤ startedAt(与后端 timing_test 同一不变式)');
    expect(done.nodes.any((n) => n.completedAt!.difference(n.startedAt!).inMilliseconds > 0), isTrue);
    // createdAt IS the terminal write — it must NOT be usable as a start stamp. createdAt=终态写入时刻。
    expect(done.nodes.every((n) => n.completedAt == n.createdAt), isTrue,
        reason: 'createdAt=行写入时刻=终态,绝非节点起点');
  });

  test('wf_clean carries the active-version graph the pane\'s graph face renders', () async {
    final wf = await repo.getWorkflow('wf_clean');
    final graph = wf.activeVersion?.graphParsed;
    expect(graph, isNotNull, reason: '图脸种子');
    expect(graph!.nodes.map((n) => n.id), ['fetch', 'gate', 'analyze', 'notify']);
    expect(graph.edges, isNotEmpty);
    // The run's node rows must exist IN the graph (else the gantt reads as orphan rows).
    // run 的节点行须在图内(否则甘特读作孤儿行)。
    final comp = await repo.getRunFull('fr_chat00000000a1');
    expect(graph.nodes.map((n) => n.id), containsAll(comp.nodes.map((n) => n.nodeId)));
  });

  test('a PAUSED trigger is seeded and reads the wire truth: no nextFireAt, not listening (工单⑦)',
      () async {
    final triggers = await repo.listTriggers();
    final paused = triggers.where((t) => t.paused);
    expect(paused, isNotEmpty, reason: '暂停态卡种子');
    expect(paused.every((t) => t.nextFireAt == null), isTrue, reason: '暂停时 nextFireAt 缺席');
    expect(paused.every((t) => !t.listening), isTrue, reason: '暂停时监听器冷');
    expect(triggers.where((t) => t.kind == TriggerSource.webhook), isNotEmpty,
        reason: 'webhook 卡种子(path 摘要)');
  });

  test('pause / resume are stateful + idempotent, and flip the whole wire trio', () async {
    final fresh = demoSchedulerRepository();
    await fresh.pauseTrigger('tr_cron_clean');
    var t = (await fresh.listTriggers()).firstWhere((t) => t.id == 'tr_cron_clean');
    expect(t.paused, isTrue);
    expect(t.nextFireAt, isNull, reason: '暂停后不再有下次');
    expect(t.listening, isFalse);

    await fresh.pauseTrigger('tr_cron_clean'); // idempotent 幂等
    t = (await fresh.listTriggers()).firstWhere((t) => t.id == 'tr_cron_clean');
    expect(t.paused, isTrue, reason: '重复暂停无害');

    await fresh.resumeTrigger('tr_cron_clean');
    t = (await fresh.listTriggers()).firstWhere((t) => t.id == 'tr_cron_clean');
    expect(t.paused, isFalse);
    expect(t.nextFireAt, isNotNull, reason: '恢复后下次调度回来');
    expect(t.listening, isTrue);
  });

  test('replay is stateful: a failed run flips running; only failed replays (422 otherwise)',
      () async {
    final fresh = demoSchedulerRepository();
    const frId = 'fr_hook0000000fa1';
    final before = await fresh.getRun(frId);
    expect(before.status, 'failed');

    await fresh.replayRun(frId);
    expect((await fresh.getRun(frId)).status, 'running', reason: 'replay 后翻 running');
    expect((await fresh.getRun(frId)).error, isNull, reason: '重放后不再挂旧错误');

    await expectLater(
        fresh.replayRun(frId),
        throwsA(isA<ApiException>()
            .having((e) => e.httpStatus, 'httpStatus', 422)
            .having((e) => e.code, 'code', 'FLOWRUN_NOT_REPLAYABLE')),
        reason: '已在跑的 run 不可再重放');
    await expectLater(fresh.replayRun('fr_chat00000000a1'),
        throwsA(isA<ApiException>().having((e) => e.httpStatus, 'httpStatus', 422)),
        reason: 'completed run 不可重放');
  });

  test('Run now births a running manual run; :kill flips inactive and cancels the in-flight',
      () async {
    final fresh = demoSchedulerRepository();
    final id = await fresh.runNow('wf_clean');
    final born = await fresh.getRun(id);
    expect(born.status, 'running');
    expect(born.origin, 'manual', reason: '手动来源盖章');

    final killed = await fresh.killWorkflow('wf_clean');
    expect(killed.lifecycleState, 'inactive');
    final running = await fresh.listFlowruns(workflowId: 'wf_clean', status: 'running');
    expect(running.items, isEmpty, reason: ':kill 取消所有在途 run');
    expect((await fresh.listWorkflows()).firstWhere((w) => w.id == 'wf_clean').lifecycleState,
        'inactive', reason: 'rail 行随之停用(左岛沉底段)');
  });

  // ── S4 · the run flagship's seeds (WRK-069 §15) ──────────────────────────────
  // The flagship's whole grammar has to be reachable with zero backend, so the seeds carry the four
  // shapes that are hard to produce on demand: a ×N loop, a 650KB result, an orphan (host deleted)
  // and a genuinely mid-flight run with no rows yet. 旗舰全文法必须零后端可达:四种难造的形态在此。

  test('S4 · the loop run folds ×3 and its last turn holds the 650KB monster (§15 大 I/O 注入)',
      () async {
    final comp = await repo.getRunFull('fr_loop00000000d1');
    final analyze = [for (final n in comp.nodes) if (n.nodeId == 'analyze') n];
    expect(analyze, hasLength(3), reason: '×N 折叠的成员');
    expect(analyze.map((n) => n.iteration), [0, 1, 2], reason: '逐轮升序,供迭代切换器');
    final payload = analyze.last.result['payload'] as String;
    expect(payload.length, 650000, reason: '650KB 物理隔离于右岛 JSON 树的注入');
    expect(analyze.first.result['payload'], isNull, reason: '只有末轮是巨物(其余轮不该被撑大)');
    expect(comp.flowrun.versionId, 'wfv_clean00000007', reason: '钉版 id 在场,旗舰据它取图');
  });

  test('S4 · the ORPHAN run stays reachable while its host 404s (§5.7 墓碑)', () async {
    final comp = await repo.getRunFull('fr_gh05t16273a4b5c6');
    expect(comp.flowrun.workflowId, 'wf_ghost');
    // The host is gone from the rail AND from getWorkflow — that pair IS the tombstone condition.
    // 宿主在 rail 与 getWorkflow 双双消失——这一对就是墓碑的成立条件。
    expect((await repo.listWorkflows()).where((w) => w.id == 'wf_ghost'), isEmpty);
    await expectLater(repo.getWorkflow('wf_ghost'),
        throwsA(isA<ApiException>().having((e) => e.httpStatus, 'httpStatus', 404)));
    // Its pinned version is gone too → the flagship falls back to «no graph», honestly.
    // 它的钉版也没了 → 旗舰诚实回退。
    await expectLater(repo.getWorkflowVersion('wf_ghost', 'wfv_ghost000000001'),
        throwsA(isA<ApiException>()));
  });

  test('S4 · the COLD-OPEN run is live with NO rows — the page must not blank (§5.5)', () async {
    final comp = await repo.getRunFull('fr_cold00000000e1');
    expect(comp.flowrun.status, 'running');
    expect(comp.nodes, isEmpty, reason: '真在飞但引擎还没落定任何行');
    expect(comp.flowrun.versionId, isNotEmpty, reason: '钉版图仍可取 → 渲占位而非空白');
  });

  test('S4 · activity (⑤) is derived from the SAME rows, so gantt and ledger cannot disagree',
      () async {
    final rows = await repo.listActivity('fr_loop00000000d1');
    expect(rows, isNotEmpty);
    // startedAt ASC — the wire's order (api.md ⑤ 行序). 线缆行序。
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].startedAt.isBefore(rows[i - 1].startedAt), isFalse);
    }
    // control/approval evaluate INLINE and leave no audit row — their absence is correct, not a gap.
    // control/approval 内联求值、不留审计行:它们的缺席是正确的,不是缺口。
    expect(rows.map((r) => r.nodeId), isNot(contains('gate')));
    final analyze = [for (final r in rows) if (r.nodeId == 'analyze') r];
    expect(analyze, hasLength(3), reason: '逐迭代各一行审计');
    expect(analyze.every((r) => r.execId.startsWith('agx_')), isTrue, reason: 'agent 族审计 id');
    expect(analyze.every((r) => r.elapsedMs > 0), isTrue);
    // The queue stamp joins through from the truth row (⑫) — the grey segment's data source.
    // 排队戳自真相行 join 过来(⑫):灰段的数据源。
    expect(analyze.every((r) => r.readyAt != null), isTrue);
  });

  test('S4 · the legacy run carries NO queue stamps — the two-part degradation is on screen too',
      () async {
    final comp = await repo.getRunFull('fr_legacy000000c3');
    expect(comp.nodes.every((n) => n.readyAt == null && n.startedAt == null), isTrue,
        reason: '旧行无戳:甘特必须诚实回退,而不是编一段排队出来');
  });

  test('S4 · :triage hands back a conversation id the caller can deep-link into chat', () async {
    expect(await repo.triageRun('fr_hook0000000fa1'), startsWith('cv_'));
  });
}
