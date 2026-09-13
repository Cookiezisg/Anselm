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
  test(
    'the 「下次调度」 tile has a tick to open: the fixture\'s next fire IS on the fixture\'s track',
    () async {
      final container = ProviderContainer(
        overrides: [
          sseGatewayProvider.overrideWithValue(null),
          schedulerRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final d = await container.read(schedulerOverviewProvider.future);
      expect(d.kpi.nextFire, isNotNull, reason: 'demo 有 cron,牌得有值');
      expect(
        nextFireOnTrack(d.track, d.kpi.nextFire),
        isTrue,
        reason: '两条缝必须对同一个 cron 刻度说同一个时刻,否则 demo 演示不出这张牌可点的样子',
      );
    },
  );

  test(
    'every rail state is seeded: running / waiting / failing / healed / never-ran / inactive',
    () async {
      final wfs = await repo.listWorkflows();
      final stats = await repo.stats(const []);
      final byId = {for (final s in stats.byWorkflow) s.workflowId: s};

      expect(
        wfs.where((w) => w.lifecycleState == 'inactive'),
        isNotEmpty,
        reason: '停用段种子',
      );
      final neverRan = wfs.where(
        (w) => w.lifecycleState != 'inactive' && !byId.containsKey(w.id),
      );
      expect(
        neverRan.length,
        greaterThanOrEqualTo(2),
        reason: '未运行段种子(≥2 供排序)',
      );

      expect(
        byId.values.where((s) => s.running > 0 && s.parkedNodes == 0),
        isNotEmpty,
        reason: '在跑(蓝)',
      );
      expect(
        byId.values.where((s) => s.parkedNodes > 0),
        isNotEmpty,
        reason: '等人(琥珀)',
      );
      expect(
        byId.values.where((s) => s.consecutiveFailures >= 4),
        isNotEmpty,
        reason: '连败×4(红)',
      );
      expect(
        byId.values.where(
          (s) =>
              s.consecutiveFailures == 0 &&
              s.recent.contains('failed') &&
              s.recent.first == 'completed',
        ),
        isNotEmpty,
        reason: '自愈(曾败,最新成)',
      );
    },
  );

  test(
    'inbox seeds all three enrich forms (S2b 工单④): deadline soon / no deadline / '
    'soft-deleted host name fallen back to the bare id (overdue)',
    () async {
      final rows = await repo.listInbox();
      expect(rows.length, greaterThanOrEqualTo(3), reason: '≥3 收件箱行');

      final now = DateTime.now();
      final soon = rows.where(
        (r) =>
            r.deadline != null &&
            r.deadline!.isAfter(now.add(const Duration(hours: 1))) &&
            r.deadline!.isBefore(now.add(const Duration(hours: 3))),
      );
      expect(soon, isNotEmpty, reason: '带 deadline 将超时(剩~2h)形');

      expect(
        rows.where((r) => r.deadline == null),
        isNotEmpty,
        reason: '无 deadline 形(不渲倒计时)',
      );

      final ghost = rows.where((r) => r.workflowName == r.workflowId);
      expect(ghost, isNotEmpty, reason: '宿主软删名回落裸 id 形');
      expect(
        ghost.first.deadline!.isBefore(now),
        isTrue,
        reason: '软删形种已超时(danger 脸)',
      );

      for (final r in rows) {
        expect(r.node.status, 'parked');
        expect(r.node.result['rendered'], isNotEmpty, reason: '审批门要渲 prompt');
        expect(r.workflowName, isNotEmpty);
      }
      expect(
        rows.where((r) => r.node.result['allowReason'] == true),
        isNotEmpty,
        reason: '至少一行长理由输入',
      );
      expect(
        rows.where((r) => r.node.result['allowReason'] == false),
        isNotEmpty,
        reason: '至少一行不长理由输入',
      );
    },
  );

  // The demo is an INTERLOCKED world (D 轨立法), and this is the interlock a real-machine walk broke:
  // wf_inventory's run rows read «cron · 01:11» while its TRIGGERS zone said «no triggers equip this
  // workflow» — a workflow with no cron, firing on cron. Stated as a general law over every seed, not
  // as a spot-check on the one row that was caught. demo=自洽互锁世界,而这正是真机走查里断掉的那道锁:
  // 库存同步的 run 行写着「cron · 01:11」、TRIGGERS 区却说「没有 trigger 装备本 workflow」。写成对全部
  // 种子的普遍律,而不是对当初被抓那一行的点检。
  test(
    'every cron-born run has a cron BEHIND it: a live trigger, equipped to that very workflow '
    '(自洽互锁 — no run may be fired by something that does not exist)',
    () async {
      final triggers = {for (final t in await repo.listTriggers()) t.id: t};
      final edges = await repo.workflowTriggerEdges();
      final workflows = await repo.listWorkflows();

      var checked = 0;
      for (final w in workflows) {
        final page = await repo.listFlowruns(
          workflowId: w.id,
          origin: 'cron',
          limit: 100,
        );
        for (final run in page.items) {
          checked++;
          final t = triggers[run.triggerId];
          expect(
            t,
            isNotNull,
            reason:
                'run ${run.id}(origin=cron)指向的 trigger ${run.triggerId} 不存在'
                '——cron 来源的 run 必须有一个真的 cron 把它生出来',
          );
          expect(
            t!.kind,
            TriggerSource.cron,
            reason: 'cron 来源的 run 只能由 cron 触发',
          );
          final equipped = [
            for (final e in edges)
              if (e.toId == t.id) e.fromId,
          ];
          expect(
            equipped,
            contains(w.id),
            reason:
                '${w.id} 的 run 由 ${t.id} 触发,则该 trigger 必须装备在 ${w.id} 上'
                '(否则运营主页 TRIGGERS 区会说「没有 trigger 装备本 workflow」而大表却在显示它的 cron run)',
          );
        }
      }
      expect(checked, greaterThan(0), reason: '前提:确实有 cron 来源的 run 可查(否则本测空过)');
    },
  );

  // ─────────────────────────── S3 · 运营主页种子 ───────────────────────────

  // ── S4 · the run flagship's seeds (WRK-069 §15) ──────────────────────────────
  // The flagship's whole grammar has to be reachable with zero backend, so the seeds carry the four
  // shapes that are hard to produce on demand: a ×N loop, a 650KB result, an orphan (host deleted)
  // and a genuinely mid-flight run with no rows yet. 旗舰全文法必须零后端可达:四种难造的形态在此。

  test(
    'S4 · the loop run folds ×3 and its last turn holds the 650KB monster (§15 大 I/O 注入)',
    () async {
      final comp = await repo.getRunFull('fr_loop00000000d1');
      final analyze = [
        for (final n in comp.nodes)
          if (n.nodeId == 'analyze') n,
      ];
      expect(analyze, hasLength(3), reason: '×N 折叠的成员');
      expect(analyze.map((n) => n.iteration), [0, 1, 2], reason: '逐轮升序,供迭代切换器');
      final payload = analyze.last.result['payload'] as String;
      expect(payload.length, 650000, reason: '650KB 物理隔离于右岛 JSON 树的注入');
      expect(
        analyze.first.result['payload'],
        isNull,
        reason: '只有末轮是巨物(其余轮不该被撑大)',
      );
      expect(
        comp.flowrun.versionId,
        'wfv_clean00000007',
        reason: '钉版 id 在场,旗舰据它取图',
      );
    },
  );

  test(
    'S4 · the ORPHAN run stays reachable while its host 404s (§5.7 墓碑)',
    () async {
      final comp = await repo.getRunFull('fr_gh05t16273a4b5c6');
      expect(comp.flowrun.workflowId, 'wf_ghost');
      // The host is gone from the rail AND from getWorkflow — that pair IS the tombstone condition.
      // 宿主在 rail 与 getWorkflow 双双消失——这一对就是墓碑的成立条件。
      expect(
        (await repo.listWorkflows()).where((w) => w.id == 'wf_ghost'),
        isEmpty,
      );
      await expectLater(
        repo.getWorkflow('wf_ghost'),
        throwsA(
          isA<ApiException>().having((e) => e.httpStatus, 'httpStatus', 404),
        ),
      );
      // Its pinned version is gone too → the flagship falls back to «no graph», honestly.
      // 它的钉版也没了 → 旗舰诚实回退。
      await expectLater(
        repo.getWorkflowVersion('wf_ghost', 'wfv_ghost000000001'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  // ── S5 seeds ──

  test(
    'S5 · ⑧ every point promises only workflows it can actually fire',
    () async {
      final sched = await repo.triggerSchedule();
      final edges = await repo.workflowTriggerEdges();
      for (final p in sched.points) {
        final equipped = [
          for (final e in edges)
            if (e.toId == p.triggerId) e.fromId,
        ];
        for (final wf in p.workflowIds) {
          expect(
            equipped,
            contains(wf),
            reason: '点绝不承诺一个没挂这条 trigger 的 workflow(workflowIds 取自监听表)',
          );
        }
      }
    },
  );

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
      expect(
        m.cols[i].startedAt.isAfter(m.cols[i - 1].startedAt),
        isFalse,
        reason: '列序:新→旧',
      );
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
    expect(
      m.cells.length,
      lessThan(m.rows.length * m.cols.length),
      reason: '稀疏:总有 run 没跑到某些节点——没跑到即**无格**',
    );

    // The whole reason the face exists: a node that breaks across runs. 第三脸存在的全部理由。
    final failedCells = m.cells.where((c) => c.status == 'failed');
    expect(failedCells, isNotEmpty, reason: '得有失败格,否则横向红条无从谈起');
    expect(
      m.cells.where((c) => c.iterations > 1),
      isNotEmpty,
      reason: '得有 ×N 格(循环)',
    );
  });

  // ── S6 seeds · 工单⑭/判决⑥ 的 firing 账 ──

  test(
    'S6 · ⑭ the disposition palette is complete: started / skipped / superseded / shed / missed '
    '(§15「各一」, now real rows rather than a reservation)',
    () async {
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
      expect(
        seen,
        isNot(contains(FiringStatus.unknown)),
        reason: 'unknown 是入站兜底,绝不是一种种子',
      );
    },
  );

  test(
    'S6 · ⑭ THE bug shape is unreachable in the demo too: the card\'s number IS the list\'s length',
    () async {
      // The very pair the ocean legislates about, asserted on data alone (D 轨:数据级电池取代真机帧).
      // 本海洋立法所指的那一对,只用数据断言。
      final since = DateTime.now().subtract(const Duration(hours: 24));
      final card = (await repo.stats(
        const [],
        since: since.toUtc().toIso8601String(),
      )).totals.missed;
      final list = await repo.listFirings(
        status: FiringStatus.missed,
        createdAfter: since,
        limit: 500,
      );
      expect(
        card,
        greaterThan(0),
        reason: '错过 KPI 必须非零,否则第五张牌在 demo 里永不出现、永不被看见',
      );
      expect(
        list.items,
        hasLength(card),
        reason: '牌上写 $card、点开列表显示 ${list.items.length} —— 正是本项目明令的 bug 形态',
      );
    },
  );

  test(
    'S6 · ⑭ self-consistency: a trigger\'s lastFiredAt can never predate a fire it produced',
    () async {
      // The same universal law the 0717 real-machine pass had to learn (a paused card claiming «last
      // fired 4 days ago» above a 26h-old run it fired). Written over ALL seeds, not the row that was
      // caught. 与 0717 真机那条同一律(它自己发出的 run 比它的「上次触发」还新);写成对**全部**种子的普遍律。
      final fired = (await repo.listFirings(
        limit: 500,
      )).items.where((f) => f.status != FiringStatus.missed);
      expect(fired, isNotEmpty, reason: '反空过:得真有 fire 过的行可查');
      final triggers = {for (final t in await repo.listTriggers()) t.id: t};
      for (final f in fired) {
        final t = triggers[f.triggerId];
        expect(t, isNotNull);
        expect(t!.lastFiredAt, isNotNull, reason: '${t.id} 产出过 firing 却自称从未触发');
        expect(
          t.lastFiredAt!.isBefore(f.createdAt),
          isFalse,
          reason:
              '${t.id} 的「上次触发」早于它自己产出的 ${f.id} —— 旗舰 cron→firing→run 链会自相矛盾',
        );
      }
    },
  );

  test(
    'S6 · ⑭ the night the machine slept is ONE history, not three unrelated props',
    () async {
      // The ✕ marks, the ×4 streak and the 6h cron must be three views of the same seeded story.
      // ✕、×4 连败、6h cron 必须是同一段种子历史的三个视图。
      final missed = (await repo.listFirings(
        status: FiringStatus.missed,
        limit: 500,
      )).items;
      expect(missed.map((f) => f.triggerId).toSet(), {'tr_cron_inventory'});
      expect(missed.map((f) => f.workflowId).toSet(), {'wf_inventory'});

      final inv = (await repo.listTriggers()).firstWhere(
        (t) => t.id == 'tr_cron_inventory',
      );
      expect(inv.config['cron'], '0 */6 * * *');
      final stats = await repo.stats(const ['wf_inventory']);
      expect(
        stats.byWorkflow.single.consecutiveFailures,
        4,
        reason: '同一段历史的另一个视图:连败 ×4',
      );

      // The equipped edge exists — a missed tick on a workflow that never listened is a broken world.
      // 边必须在:一个从未监听过的 workflow 上出现 missed 刻度 = 世界坏了。
      final edges = await repo.workflowTriggerEdges();
      expect(
        edges.any(
          (e) => e.toId == 'tr_cron_inventory' && e.fromId == 'wf_inventory',
        ),
        isTrue,
      );
    },
  );
}
