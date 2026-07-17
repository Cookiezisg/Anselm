import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/features/scheduler/data/scheduler_demo_fixture.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/state/scheduler_overview_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The Scheduler demo battery's seed-correctness lock (WRK-069 §15 — fixture is pure data, the test
// pins the states the rail grammar needs; D-track tactic). demo 种子正确性锁。

void main() {
  final repo = demoSchedulerRepository();

  // The 「下次调度」 tile is clickable only when the instant it names is really a tick on the track it
  // opens (nextFireOnTrack) — so a demo whose two seams disagree about that instant can never show the
  // tile's drill-down at all: a state the demo is required to reach (D 轨:demo 全展示). This pins the
  // fixture to the property the BACKEND has for free: `cron.Next(expr, now)` is a pure function of the
  // expression, so `listTriggers` and `trigger-schedule` project the SAME instant for the same cron.
  // 「下次调度」牌只在它所念的时刻真是它要打开的那条轨上的一个刻度时才可点(nextFireOnTrack)——故两条缝对那个
  // 时刻各执一词的 demo,根本演示不出这张牌的钻取:而那是 demo 必须到达的状态(D 轨:demo 全展示)。本测把 fixture
  // 钉在**后端白送**的那条性质上:cron.Next(expr, now) 是表达式的纯函数,故 listTriggers 与 trigger-schedule
  // 为同一个 cron 投影出**同一个**时刻。
  test('the 「下次调度」 tile has a tick to open: the fixture\'s next fire IS on the fixture\'s track',
      () async {
    final container = ProviderContainer(overrides: [
      sseGatewayProvider.overrideWithValue(null),
      schedulerRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final d = await container.read(schedulerOverviewProvider.future);
    expect(d.kpi.nextFire, isNotNull, reason: 'demo 有 cron,牌得有值');
    expect(nextFireOnTrack(d.track, d.kpi.nextFire), isTrue,
        reason: '两条缝必须对同一个 cron 刻度说同一个时刻,否则 demo 演示不出这张牌可点的样子');
  });

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

  // failedSince is DERIVED from the failed run seeds through the same predicate the 「24h 失败」 zone
  // lists with (工单⑮), so the tile (`failedRuns.length`), the delta's failed24, and this count are one
  // number. The seeds tell «one night»: everything failed within the last ~30h, so the 48h window holds
  // one more than the 24h window (fr_e5f6 landed 30h ago) and the 7d window holds nothing older still.
  // failedSince 从失败 run 种子经与「24h 失败」区**同一份**谓词派生(工单⑮),故牌/delta/本计数是一个数。
  // 种子讲「一夜」:一切在近 ~30h 内失败,故 48h 窗比 24h 窗多一个(fr_e5f6 落定于 30h 前)、7d 再无更老的。
  test('failed totals are DERIVED and window-monotonic: 24h < 48h ≤ 7d, delta positive (worsening)',
      () async {
    final f24 = (await repo.stats(const [], since: '24h')).totals.failedSince;
    final f48 = (await repo.stats(const [], since: '48h')).totals.failedSince;
    final f7d = (await repo.stats(const [])).totals.failedSince;
    // The tile IS this list's length — same predicate, drained. 牌就是这份列表的长度。
    final list24 = await repo.listFailedSince(DateTime.now().subtract(const Duration(hours: 24)));
    expect(list24.length, f24, reason: '「牌上写 N、点开列表显示 N」:同谓词,构造相等');
    expect(f24, lessThan(f48), reason: 'fr_e5f6 (30h 前) 落在 24-48h 带里');
    expect(f48, lessThanOrEqualTo(f7d));
    expect(f24 - (f48 - f24), greaterThan(0), reason: 'worsening: 坏的一夜就在最近 24h');
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

  // The demo is an INTERLOCKED world (D 轨立法), and this is the interlock a real-machine walk broke:
  // wf_inventory's run rows read «cron · 01:11» while its TRIGGERS zone said «no triggers equip this
  // workflow» — a workflow with no cron, firing on cron. Stated as a general law over every seed, not
  // as a spot-check on the one row that was caught. demo=自洽互锁世界,而这正是真机走查里断掉的那道锁:
  // 库存同步的 run 行写着「cron · 01:11」、TRIGGERS 区却说「没有 trigger 装备本 workflow」。写成对全部
  // 种子的普遍律,而不是对当初被抓那一行的点检。
  test('every cron-born run has a cron BEHIND it: a live trigger, equipped to that very workflow '
      '(自洽互锁 — no run may be fired by something that does not exist)', () async {
    final triggers = {for (final t in await repo.listTriggers()) t.id: t};
    final edges = await repo.workflowTriggerEdges();
    final workflows = await repo.listWorkflows();

    var checked = 0;
    for (final w in workflows) {
      final page = await repo.listFlowruns(workflowId: w.id, origin: 'cron', limit: 100);
      for (final run in page.items) {
        checked++;
        final t = triggers[run.triggerId];
        expect(t, isNotNull,
            reason: 'run ${run.id}(origin=cron)指向的 trigger ${run.triggerId} 不存在'
                '——cron 来源的 run 必须有一个真的 cron 把它生出来');
        expect(t!.kind, TriggerSource.cron, reason: 'cron 来源的 run 只能由 cron 触发');
        final equipped = [for (final e in edges) if (e.toId == t.id) e.fromId];
        expect(equipped, contains(w.id),
            reason: '${w.id} 的 run 由 ${t.id} 触发,则该 trigger 必须装备在 ${w.id} 上'
                '(否则运营主页 TRIGGERS 区会说「没有 trigger 装备本 workflow」而大表却在显示它的 cron run)');
      }
    }
    expect(checked, greaterThan(0), reason: '前提:确实有 cron 来源的 run 可查(否则本测空过)');
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

  // ── S5 seeds ──

  test('S5 · ⑧ the forward schedule seeds a DENSE lane (bucket folding is provable on screen) '
      'and a paused trigger contributes NOTHING — exactly as the real endpoint behaves', () async {
    final sched = await repo.triggerSchedule();
    expect(sched.points, isNotEmpty);
    expect(sched.points.map((p) => p.at).toList(), orderedEquals(sched.points.map((p) => p.at)),
        reason: 'at 升序:端点契约');

    final dense = sched.points.where((p) => p.triggerId == 'tr_cron_report');
    expect(dense.length, greaterThan(50), reason: '密集泳道:不折叠就是亚像素纸屑,故必须种到能逼出折叠');

    // 判决① — the paused cron is seeded (tr_cron_archive) but emits no ticks; its lane must still
    // reach the board from the TRIGGER list. 暂停的 cron 有种子但零刻度;泳道靠 trigger 列表上板。
    expect(sched.points.where((p) => p.triggerId == 'tr_cron_archive'), isEmpty,
        reason: '端点只为监听中且未暂停的 cron 发刻度——暂停的一个都不发');
    final paused = (await repo.listTriggers()).firstWhere((t) => t.id == 'tr_cron_archive');
    expect(paused.paused, isTrue);
    expect(paused.nextFireAt, isNull, reason: '暂停即无下次:线缆三键同动');
  });

  test('S5 · ⑧ every point promises only workflows it can actually fire', () async {
    final sched = await repo.triggerSchedule();
    final edges = await repo.workflowTriggerEdges();
    for (final p in sched.points) {
      final equipped = [for (final e in edges) if (e.toId == p.triggerId) e.fromId];
      for (final wf in p.workflowIds) {
        expect(equipped, contains(wf),
            reason: '点绝不承诺一个没挂这条 trigger 的 workflow(workflowIds 取自监听表)');
      }
    }
  });

  test('S5 · ⑩ the matrix earns its zone: a failure STREAK, ×N folding, a live column with no '
      'elapsed, and SPARSE cells — asked by EXPLICIT ids (0717 拍板)', () async {
    // The window flow: page the runs, batch-fetch the grid for that page of ids. 窗流:翻页批取。
    final page = await repo.listFlowruns(workflowId: 'wf_clean', limit: 50);
    final m = await repo.runMatrix([for (final r in page.items) r.id]);
    expect(m.cols, isNotEmpty);
    expect(m.rows, isNotEmpty);
    expect(m.cols.length, lessThanOrEqualTo(50), reason: '一页一批,≤50');

    // Newest first — a column and its row in the big table are the same run at the same position.
    // 新→旧:列与大表里的行是同位同一个 run。
    for (var i = 1; i < m.cols.length; i++) {
      expect(m.cols[i].startedAt.isAfter(m.cols[i - 1].startedAt), isFalse, reason: '列序:新→旧');
    }

    final live = m.cols.where((c) => c.status == 'running');
    for (final c in live) {
      expect(c.elapsedMs, isNull, reason: '在跑的 run 无 elapsed——绝不发会被读成「瞬时」的 0');
    }
    for (final c in m.cols.where((c) => c.status == 'completed')) {
      expect(c.elapsedMs, isNotNull, reason: '落定的 run 有真墙钟');
    }

    // SPARSE by contract: a dense rows×cols matrix would be a different (and lying) shape.
    // 契约级稀疏:稠密 rows×cols 是另一种(且会撒谎的)形状。
    expect(m.cells.length, lessThan(m.rows.length * m.cols.length),
        reason: '稀疏:总有 run 没跑到某些节点——没跑到即**无格**');

    // The whole reason the face exists: a node that breaks across runs. 第三脸存在的全部理由。
    final failedCells = m.cells.where((c) => c.status == 'failed');
    expect(failedCells, isNotEmpty, reason: '得有失败格,否则横向红条无从谈起');
    expect(m.cells.where((c) => c.iterations > 1), isNotEmpty, reason: '得有 ×N 格(循环)');
  });

  test('S5 · ⑩ unknown ids are NOT an error — three empty lists, silently absent (wire law)',
      () async {
    final m = await repo.runMatrix(['fr_does_not_exist']);
    expect(m.cols, isEmpty);
    expect(m.rows, isEmpty);
    expect(m.cells, isEmpty);
  });

  test('S5 · ⑩ column order is canonical regardless of request order (行轴不许被乱序左右)',
      () async {
    final page = await repo.listFlowruns(workflowId: 'wf_clean', limit: 10);
    final ids = [for (final r in page.items) r.id];
    final shuffled = [...ids.reversed];
    final m = await repo.runMatrix(shuffled);
    for (var i = 1; i < m.cols.length; i++) {
      expect(m.cols[i].startedAt.isAfter(m.cols[i - 1].startedAt), isFalse,
          reason: '乱序请求,正典输出');
    }
  });

  test('S5 · ⑬ retention seeds the BACKEND default (90) so panel and tombstone agree out of the box',
      () async {
    expect((await repo.retention()).runRetentionDays, 90);
  });

  // ── S6 seeds · 工单⑭/判决⑥ 的 firing 账 ──

  test('S6 · ⑭ the disposition palette is complete: started / skipped / superseded / shed / missed '
      '(§15「各一」, now real rows rather than a reservation)', () async {
    final all = await repo.listFirings(limit: 500);
    final seen = all.items.map((f) => f.status).toSet();
    for (final s in [
      FiringStatus.started,
      FiringStatus.skipped,
      FiringStatus.superseded,
      FiringStatus.shed,
      FiringStatus.missed,
    ]) {
      expect(seen, contains(s), reason: '$s 无种子 → 它那张脸在 demo 里永远没人看过');
    }
    expect(seen, isNot(contains(FiringStatus.unknown)), reason: 'unknown 是入站兜底,绝不是一种种子');
  });

  test('S6 · ⑭ THE bug shape is unreachable in the demo too: the card\'s number IS the list\'s length',
      () async {
    // The very pair the ocean legislates about, asserted on data alone (D 轨:数据级电池取代真机帧).
    // 本海洋立法所指的那一对,只用数据断言。
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final card = (await repo.stats(const [], since: since.toUtc().toIso8601String())).totals.missed;
    final list =
        await repo.listFirings(status: FiringStatus.missed, createdAfter: since, limit: 500);
    expect(card, greaterThan(0), reason: '错过 KPI 必须非零,否则第五张牌在 demo 里永不出现、永不被看见');
    expect(list.items, hasLength(card),
        reason: '牌上写 $card、点开列表显示 ${list.items.length} —— 正是本项目明令的 bug 形态');
  });

  test('S6 · ⑭ every missed row obeys the backend\'s rules: the tick IS the timestamp, no run, no '
      'activation, cron only', () async {
    final missed = (await repo.listFirings(status: FiringStatus.missed, limit: 500)).items;
    final triggers = {for (final t in await repo.listTriggers()) t.id: t};
    final now = DateTime.now();
    for (final f in missed) {
      expect(f.flowrunId, isEmpty, reason: 'missed 从未建 run —— flowrunId 恒空');
      expect(f.activationId, isEmpty, reason: '记账不是一次动作 —— sweep 不为它记 activation');
      expect(f.createdAt.isBefore(now), isTrue, reason: 'createdAt 是**错过的刻度**,刻度只能在过去');
      final t = triggers[f.triggerId];
      expect(t, isNotNull, reason: 'missed 指向一个不存在的 trigger = 自相矛盾的世界');
      expect(t!.kind, TriggerSource.cron, reason: 'sweep 只看 cron —— 只有 cron 有「本该发生」的刻度');
    }
  });

  test('S6 · ⑭ self-consistency: a trigger\'s lastFiredAt can never predate a fire it produced',
      () async {
    // The same universal law the 0717 real-machine pass had to learn (a paused card claiming «last
    // fired 4 days ago» above a 26h-old run it fired). Written over ALL seeds, not the row that was
    // caught. 与 0717 真机那条同一律(它自己发出的 run 比它的「上次触发」还新);写成对**全部**种子的普遍律。
    final fired = (await repo.listFirings(limit: 500))
        .items
        .where((f) => f.status != FiringStatus.missed);
    expect(fired, isNotEmpty, reason: '反空过:得真有 fire 过的行可查');
    final triggers = {for (final t in await repo.listTriggers()) t.id: t};
    for (final f in fired) {
      final t = triggers[f.triggerId];
      expect(t, isNotNull);
      expect(t!.lastFiredAt, isNotNull, reason: '${t.id} 产出过 firing 却自称从未触发');
      expect(t.lastFiredAt!.isBefore(f.createdAt), isFalse,
          reason: '${t.id} 的「上次触发」早于它自己产出的 ${f.id} —— 旗舰 cron→firing→run 链会自相矛盾');
    }
  });

  test('S6 · ⑭ a started firing carries its run; the live run\'s row and its firing agree', () async {
    final started = (await repo.listFirings(status: FiringStatus.started, limit: 500)).items;
    final runIds = {for (final r in (await repo.listFlowruns(workflowId: 'wf_clean')).items) r.id};
    for (final f in started) {
      expect(f.flowrunId, isNotEmpty, reason: 'started = 刻度**成了** run,故必有 run id');
    }
    // The live run's row cites a firingId — that firing must exist and point back. 活 run 引用的 firing
    // 必须存在,且指回来。
    final live = (await repo.listFlowruns(workflowId: 'wf_clean')).items
        .firstWhere((r) => (r.firingId ?? '').isNotEmpty,
            orElse: () => fail('没有任何 run 引用 firing —— 出处链无从验起'));
    final cited = started.firstWhere((f) => f.id == live.firingId,
        orElse: () => fail('run ${live.id} 引用了不存在的 firing ${live.firingId}'));
    expect(cited.flowrunId, live.id, reason: '两头必须互指,否则出处链断在中间');
    expect(runIds, contains(cited.flowrunId));
  });

  test('S6 · ⑭ the window is HALF-OPEN [after, before) and filters compose with AND', () async {
    final all = (await repo.listFirings(limit: 500)).items;
    expect(all.map((f) => f.createdAt).toList(),
        orderedEquals(([...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .map((f) => f.createdAt)),
        reason: '新→旧:端点契约');

    final pivot = all.first.createdAt; // the newest row 最新那行
    final before = await repo.listFirings(createdBefore: pivot, limit: 500);
    expect(before.items.map((f) => f.id), isNot(contains(all.first.id)),
        reason: '上界**不含**:相邻窗才拼得上、不重叠');
    final after = await repo.listFirings(createdAfter: pivot, limit: 500);
    expect(after.items.map((f) => f.id), contains(all.first.id), reason: '下界**含**');

    // AND, not OR. AND 组合,不是 OR。
    final anded = await repo.listFirings(
        triggerId: 'tr_cron_inventory', status: FiringStatus.missed, limit: 500);
    expect(anded.items, isNotEmpty);
    for (final f in anded.items) {
      expect(f.triggerId, 'tr_cron_inventory');
      expect(f.status, FiringStatus.missed);
    }
  });

  test('S6 · ⑭ the page CAPS and says so — a truncated ledger is the newest slice, not the whole one',
      () async {
    final capped = await repo.listFirings(limit: 2);
    expect(capped.items, hasLength(2));
    expect(capped.hasMore, isTrue, reason: '撞帽必须自报,否则调用方把一页当整窗画');
    expect(capped.nextCursor, isNotNull);
    final whole = await repo.listFirings(limit: 500);
    expect(whole.hasMore, isFalse);
    expect(capped.items.map((f) => f.id), whole.items.take(2).map((f) => f.id),
        reason: '截断的是**最新**那片');
  });

  test('S6 · ⑭ the night the machine slept is ONE history, not three unrelated props', () async {
    // The ✕ marks, the ×4 streak and the 6h cron must be three views of the same seeded story.
    // ✕、×4 连败、6h cron 必须是同一段种子历史的三个视图。
    final missed = (await repo.listFirings(status: FiringStatus.missed, limit: 500)).items;
    expect(missed.map((f) => f.triggerId).toSet(), {'tr_cron_inventory'});
    expect(missed.map((f) => f.workflowId).toSet(), {'wf_inventory'});

    final inv = (await repo.listTriggers()).firstWhere((t) => t.id == 'tr_cron_inventory');
    expect(inv.config['cron'], '0 */6 * * *');
    final stats = await repo.stats(const ['wf_inventory']);
    expect(stats.byWorkflow.single.consecutiveFailures, 4, reason: '同一段历史的另一个视图:连败 ×4');

    // The equipped edge exists — a missed tick on a workflow that never listened is a broken world.
    // 边必须在:一个从未监听过的 workflow 上出现 missed 刻度 = 世界坏了。
    final edges = await repo.workflowTriggerEdges();
    expect(
        edges.any((e) => e.toId == 'tr_cron_inventory' && e.fromId == 'wf_inventory'), isTrue);
  });
}
