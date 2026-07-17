import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/trigger_schedule.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/ui/an_wash_highlight.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/scheduler_windows.dart';
import 'package:anselm/features/scheduler/state/scheduler_overview_provider.dart';
import 'package:anselm/features/scheduler/ui/overview_zones.dart';
import 'package:anselm/features/scheduler/ui/scheduler_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stub_scheduler_repo.dart';

// The other four KPI tiles (WRK-069 §3.1) — 「错过 N」 shipped its drill-down with 判决⑥; this is the
// rest of the strip settling the same debt, and the ONE law they are all measured against:
//
//   **a tile opens the list it counts, or it opens nothing.**
//
// So every tile below carries a 口径同源 guard proving its number and the surface its click reveals are
// the SAME predicate — and each guard is written so that re-pointing the tile at the plausible second
// source (`totals.running` / `totals.parkedNodes` / an ungated next-fire) turns it RED. 「24h 失败」 has
// no guard because it has no click: its predicate is provably inexpressible here, and the test that
// says so is the one showing the nearby zone answering a different question.
//
// 另外四张 KPI 牌:「错过 N」随判决⑥ 已还了它的钻取债,这里是其余几张还同一笔债,以及衡量它们的**唯一**一条法:
// **牌要么点开它数的那个列表,要么什么都不点开**。故下面每张牌都带一条口径同源守卫,证明它的数字与它点击所揭示的
// 面是**同一份谓词**——且每条守卫都写成:一旦把牌重新指向那个貌似合理的第二源(totals.running / totals.parkedNodes /
// 无门的下次调度),它就**变红**。「24h 失败」没有守卫,因为它没有点击:它的谓词在此**可证**地表达不出来,而说明这一点的
// 那个测试,正是展示「旁边那个区答的是另一个问题」的那一个。

final _now = DateTime.now();

SchedulerWorkflowRow _wf(String id, String name) =>
    SchedulerWorkflowRow(id: id, name: name, lifecycleState: 'active', updatedAt: _now);

Flowrun _run(String id, String wfId, {String status = 'running', Duration ago = const Duration(seconds: 90)}) =>
    Flowrun(
        id: id,
        workflowId: wfId,
        status: status,
        startedAt: _now.subtract(ago),
        updatedAt: _now);

TriggerEntity _cron(String id, {DateTime? nextFireAt}) => TriggerEntity(
    id: id,
    name: '每日 09:00',
    kind: TriggerSource.cron,
    createdAt: _now,
    updatedAt: _now,
    listening: true,
    nextFireAt: nextFireAt);

EntityRelation _edge(String wf, String trigger) => EntityRelation(
    id: 'rel_$wf$trigger',
    kind: 'equip',
    fromKind: 'workflow',
    fromId: wf,
    fromName: '',
    toKind: 'trigger',
    toId: trigger);

Widget _host(SchedulerRepository repo) => ProviderScope(
      overrides: [
        sseGatewayProvider.overrideWithValue(null),
        schedulerRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
            theme: AnTheme.light(), home: const Scaffold(body: SchedulerOverviewView())),
      ),
    );

Future<void> _pumpBoard(WidgetTester tester, Widget host) async {
  await tester.pumpWidget(host);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1)); // count-ups settle; the breath keeps looping
}

Future<SchedulerOverviewData> _board(StubSchedulerRepo repo) async {
  final container = ProviderContainer(overrides: [
    sseGatewayProvider.overrideWithValue(null),
    schedulerRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container.read(schedulerOverviewProvider.future);
}

/// Did tapping [label] reveal [zone]? The wash IS the reveal — an inert tile leaves the board alone.
/// 点 label 有没有揭示 zone?洗亮**就是**揭示——惰性的牌什么都不动。
Future<bool> _tapReveals(WidgetTester tester, String label, Type zone) async {
  await tester.tap(find.text(label));
  await tester.pump();
  return find
      .descendant(of: find.byType(AnWashHighlight), matching: find.byType(zone))
      .evaluate()
      .isNotEmpty;
}

void main() {
  final ov = t.scheduler.overview;

  // ───────────────────────────────── 在跑 N → 「正在跑」 ─────────────────────────────────
  group('在跑 N', () {
    StubSchedulerRepo repo({
      List<Flowrun> runs = const [],
      int totalsRunning = 0,
      List<SchedulerWorkflowRow>? workflows,
      bool failRunningRuns = false,
    }) =>
        StubSchedulerRepo(
          workflows: workflows ?? [_wf('wf_a', '数据清洗流水线')],
          byWorkflow: const [WorkflowRunStats(workflowId: 'wf_a')],
          failedBySince: const {'24h': 0, '48h': 0},
          totalsRunning: totalsRunning,
          runs: runs,
          failRunningRuns: failRunningRuns,
        );

    // THE guard. 口径同源守卫。
    test('口径同源: the tile IS its zone\'s list length — the wire\'s own count cannot reach it',
        () async {
      // The wire insists on 99. The zone holds one row. A tile sourced from `totals.running` would say
      // 99 and open a list of 1 — «牌上写 3、点开的列表显示 4», the shape this ocean is legislated against.
      // 线缆咬定 99,区里只有一行。若牌取自 totals.running,它会写 99 并打开一个只有 1 行的列表。
      final d = await _board(repo(runs: [_run('fr_1', 'wf_a')], totalsRunning: 99));
      expect(d.kpi.running, 1);
      expect(d.kpi.running, d.runningRuns.length,
          reason: '牌 = 它点开的那份列表的 length,别无来源');
    });

    // The bug the old per-workflow probe loop could not even see. 旧的逐 workflow 探针循环连看都看不见的 bug。
    test('口径同源: an ORPHAN\'s run is BOTH counted and shown — one workspace-wide question, not a loop',
        () async {
      // wf_gone was soft-deleted while its run kept running (孤儿 run 一等公民). Anything counting the
      // flowruns table counts it; a loop driven by the workflow list can never visit it.
      // wf_gone 在它的 run 还跑着的时候被软删了(孤儿 run 一等公民):凡数 flowruns 表的都数着它,而由 workflow
      // 列表驱动的循环永远走不到它。
      final d = await _board(repo(
        runs: [_run('fr_live', 'wf_a'), _run('fr_orphan', 'wf_gone')],
        totalsRunning: 2,
      ));
      expect(d.runningRuns, hasLength(2), reason: '孤儿的 run 在跑,牌数着它,故区必须显示它');
      expect(d.kpi.running, d.runningRuns.length);
      final orphan = d.runningRuns.firstWhere((r) => r.run.id == 'fr_orphan');
      expect(orphan.workflowName, 'wf_gone',
          reason: '宿主已软删 → 名字 join 不到 → 回落裸 id(relation-Namer 先例),而不是把行丢掉');
    });

    testWidgets('the tile OPENS the rows it counts', (tester) async {
      await _pumpBoard(tester, _host(repo(runs: [_run('fr_1', 'wf_a')], totalsRunning: 1)));
      expect(find.byType(AnWashHighlight), findsNothing, reason: '未点击前不洗');
      expect(await _tapReveals(tester, ov.kpiRunning, SchedulerRunningZone), isTrue);
    });

    testWidgets('电池·空: 「在跑 0」 opens nothing — there is no list to open', (tester) async {
      await _pumpBoard(tester, _host(repo()));
      expect(find.text(ov.kpiRunning), findsOneWidget, reason: '牌还在(四张固定牌),只是不可点');
      expect(await _tapReveals(tester, ov.kpiRunning, SchedulerRunningZone), isFalse,
          reason: '零行 = 没有列表 = 没有可供性;死可供性是谎');
    });

    List<Flowrun> manyRuns() =>
        [for (var i = 0; i < 200; i++) _run('fr_$i', 'wf_a', ago: Duration(seconds: i))];

    test('电池·海量: 200 running runs — the tile and the zone stay one number', () async {
      final d = await _board(repo(runs: manyRuns(), totalsRunning: 200));
      expect(d.kpi.running, 200);
      expect(d.runningRuns, hasLength(200));
    });

    testWidgets('电池·海量: 200 rows render and the tile still opens them', (tester) async {
      await _pumpBoard(tester, _host(repo(runs: manyRuns(), totalsRunning: 200)));
      expect(tester.takeException(), isNull);
      expect(await _tapReveals(tester, ov.kpiRunning, SchedulerRunningZone), isTrue);
    });

    testWidgets('电池·超长: an absurd workflow name never breaks the row or the tile', (tester) async {
      final long = '数据清洗流水线' * 60;
      await _pumpBoard(
          tester,
          _host(repo(
              runs: [_run('fr_1', 'wf_long')],
              totalsRunning: 1,
              workflows: [_wf('wf_long', long)])));
      expect(tester.takeException(), isNull);
      expect(await _tapReveals(tester, ov.kpiRunning, SchedulerRunningZone), isTrue);
    });

    testWidgets('电池·注入: a failed running read is an ERROR, never a reassuring 0', (tester) async {
      await _pumpBoard(tester, _host(repo(runs: [_run('fr_1', 'wf_a')], failRunningRuns: true)));
      expect(find.text(ov.errorTitle), findsOneWidget,
          reason: '「没有东西在跑」与「我查不出来」是两句话;一张因为取数死了而读 0 的 KPI 是最危险的谎');
    });
  });

  // ───────────────────────────────── 等你 N → 「等你处理」 ─────────────────────────────────
  group('等你 N', () {
    StubSchedulerRepo repo({List<SchedulerInboxRow> inbox = const []}) => StubSchedulerRepo(
          workflows: [_wf('wf_a', '数据清洗流水线')],
          byWorkflow: const [WorkflowRunStats(workflowId: 'wf_a')],
          failedBySince: const {'24h': 0, '48h': 0},
          inbox: inbox,
        );

    // THE guard — and the one place the two candidate sources genuinely disagree.
    test('口径同源: the tile IS the inbox\'s ROW count — `totals.parkedNodes` counts RUNS', () async {
      // One run parked on TWO approvals: two decisions for the human, one run for the wire's parked
      // total. The zone renders two rows, so the tile must say two. A tile on `totals.parkedNodes`
      // would say 1 and open a list of 2.
      // 一个 run park 在**两个**审批上:对人是两个决策,对线缆的 parked 总数是**一个 run**。区渲两行,故牌必须说 2。
      // 取自 totals.parkedNodes 的牌会写 1、点开一个 2 行的列表。
      final r = repo(inbox: [
        stubInboxRow('fr_park1', 'approve_send', now: _now),
        stubInboxRow('fr_park1', 'approve_more', now: _now),
      ]);
      final wire = await r.stats(const [], since: SchedulerWindows.statsSince);
      expect(wire.totals.parkedNodes, 1, reason: '线缆:一个 run(契约,不管这个键叫什么名字)');

      final d = await _board(r);
      expect(d.kpi.waiting, 2, reason: '人要做两个决策,区渲两行');
      expect(d.kpi.waiting, d.waiting.length, reason: '牌 = 它点开的那份列表的 length');
    });

    testWidgets('the tile OPENS the rows it counts', (tester) async {
      await _pumpBoard(tester, _host(repo(inbox: [stubInboxRow('fr_p1', 'gate', now: _now)])));
      expect(await _tapReveals(tester, ov.kpiWaiting, SchedulerWaitingZone), isTrue);
    });

    testWidgets('电池·空: 「等你 0」 opens nothing', (tester) async {
      await _pumpBoard(tester, _host(repo()));
      expect(await _tapReveals(tester, ov.kpiWaiting, SchedulerWaitingZone), isFalse);
    });
  });

  // ───────────────────────────── 下次调度 → 调度轨上那个刻度 ─────────────────────────────
  group('下次调度', () {
    ScheduleTrackData track(List<DateTime> futureAt) => ScheduleTrackData(lanes: [
          ScheduleLane(
              triggerId: 'tr_1',
              triggerName: 'cron',
              workflowId: 'wf_a',
              workflowName: 'A',
              paused: false,
              futureAt: futureAt),
        ]);

    test('nextFireOnTrack: the tick is on the axis, or the card does not click', () {
      final at = _now.add(const Duration(minutes: 3));
      expect(nextFireOnTrack(track([at]), at), isTrue);
      expect(nextFireOnTrack(track([at]), at.add(const Duration(minutes: 1))), isFalse,
          reason: '两个投影跨过了 cron 的边界 → 差一整个周期 → 所念的不是轴上那个');
      expect(nextFireOnTrack(track(const []), at), isFalse, reason: '泳道在、点不在(监听表没解出它)');
      expect(nextFireOnTrack(const ScheduleTrackData(), at), isFalse);
      expect(nextFireOnTrack(track([at]), null), isFalse);
      // Same instant, different UTC-ness: `DateTime ==` would say no, and it would be wrong — the two
      // projections of one cron expression are one absolute moment. 同一瞬间、UTC 旗标不同:DateTime ==
      // 会说「不是」,而那是错的——一条 cron 表达式的两次投影是同一个绝对时刻。
      expect(nextFireOnTrack(track([at.toUtc()]), at), isTrue);
    });

    StubSchedulerRepo repo({required DateTime? nextFireAt, List<SchedulePoint> points = const []}) =>
        StubSchedulerRepo(
          workflows: [_wf('wf_a', '数据清洗流水线')],
          byWorkflow: const [WorkflowRunStats(workflowId: 'wf_a')],
          failedBySince: const {'24h': 0, '48h': 0},
          triggers: [_cron('tr_1', nextFireAt: nextFireAt)],
          edges: [_edge('wf_a', 'tr_1')],
          schedule: TriggerSchedule(points: points),
        );

    testWidgets('on the axis → the tile OPENS the tick it names', (tester) async {
      final at = _now.add(const Duration(minutes: 3, seconds: 30));
      await _pumpBoard(
          tester,
          _host(repo(nextFireAt: at, points: [
            SchedulePoint(at: at, triggerId: 'tr_1', triggerName: 'cron', workflowIds: const ['wf_a']),
          ])));
      expect(await _tapReveals(tester, ov.kpiNextFire, SchedulerScheduleZone), isTrue);
    });

    // 宁可不可点。The three ways the named instant can be off the axis, all real, all inert.
    testWidgets('beyond the 24h horizon → the tile still SAYS it, and still does not click',
        (tester) async {
      // A weekly cron. The value is honest news; the track simply does not draw that far.
      // 周 cron:这个值是诚实的消息,而轨道根本画不到那么远。
      await _pumpBoard(tester, _host(repo(nextFireAt: _now.add(const Duration(hours: 30)))));
      expect(find.text(ov.fireIn(d: '1d')), findsOneWidget, reason: '牌照说真话,它只是没有去处');
      expect(await _tapReveals(tester, ov.kpiNextFire, SchedulerScheduleZone), isFalse,
          reason: '滚到一条「所念刻度不在其上」的轴,比不可点更糟');
    });

    testWidgets('a lane the listen registry never resolved → no tick, no click', (tester) async {
      final at = _now.add(const Duration(minutes: 3, seconds: 30));
      await _pumpBoard(
          tester,
          _host(repo(nextFireAt: at, points: [
            // The point promises nothing to wf_a — equipped (edge) but not listening for it.
            // 这个点对 wf_a 什么都不承诺:装备了(边在)、却没为它监听。
            SchedulePoint(at: at, triggerId: 'tr_1', triggerName: 'cron', workflowIds: const []),
          ])));
      expect(await _tapReveals(tester, ov.kpiNextFire, SchedulerScheduleZone), isFalse);
    });

    testWidgets('电池·极值: a tick exactly ON the horizon is still on the axis', (tester) async {
      final at = _now.add(SchedulerWindows.trackWindow);
      await _pumpBoard(
          tester,
          _host(repo(nextFireAt: at, points: [
            SchedulePoint(at: at, triggerId: 'tr_1', triggerName: 'cron', workflowIds: const ['wf_a']),
          ])));
      expect(await _tapReveals(tester, ov.kpiNextFire, SchedulerScheduleZone), isTrue,
          reason: '视野是闭区间(scheduleLanes 的 !isAfter(horizon));边界上的刻度画得出,故点得开');
    });

    testWidgets('电池·空: no schedule at all → 「—」, and nothing to open', (tester) async {
      await _pumpBoard(tester, _host(repo(nextFireAt: null)));
      expect(find.text(ov.kpiNone), findsOneWidget);
      expect(await _tapReveals(tester, ov.kpiNextFire, SchedulerScheduleZone), isFalse);
    });
  });

  // ─────────────────────── 24h 失败 → 没有去处(且这是个结论,不是遗漏) ───────────────────────
  group('24h 失败', () {
    // The evidence that «Failures · 7d» is the nearby-but-different list the 宪法 names. It is not a
    // matter of taste: the two answer different questions, in different units, over different windows,
    // and here they disagree completely.
    // 「失败聚合 7d」正是宪法点名的那个**相近但不同**的列表的证据。这不是口味问题:两者答的是不同的问题、
    // 用不同的单位、跨不同的窗口——而在这里,它们完全不一致。
    // Failed four times overnight, then SUCCEEDED. The streak self-healed to 0 → absent from the 7d
    // roll-up, by design (自愈=证明跑通). The four failures are still inside the 24h window.
    // 整夜失败四次,然后**跑通了**:连败自愈归 0 → 按设计不在 7d 榜上。而那四次失败仍在 24h 窗口里。
    StubSchedulerRepo repo() => StubSchedulerRepo(
          workflows: [_wf('wf_a', '数据清洗流水线')],
          byWorkflow: const [WorkflowRunStats(workflowId: 'wf_a', recent: ['completed'])],
          failedBySince: const {'24h': 4, '48h': 4},
        );

    test('the tile says 4 while the 7d zone is legitimately EMPTY', () async {
      final d = await _board(repo());
      expect(d.kpi.failed24h, 4);
      expect(d.failures, isEmpty, reason: '连败已自愈 → 7d 榜上没有它');
    });

    testWidgets('…so the tile grows NO click — linking it to the 7d zone would open an empty list',
        (tester) async {
      await _pumpBoard(tester, _host(repo()));
      expect(find.text(ov.failuresEmpty), findsOneWidget);
      expect(await _tapReveals(tester, ov.kpiFailed24h, SchedulerScheduleZone), isFalse);
      expect(find.byType(AnWashHighlight), findsNothing,
          reason: '这张牌一个点击都不长:把它接到 7d 榜上,就会让它写着 4、点开一个空区');
    });
  });

  // ───────────────────────────────────────── a11y ─────────────────────────────────────────
  group('a11y', () {
    testWidgets('a tile that became a control announces as one — label + button + the TAP ACTION',
        (tester) async {
      final handle = tester.ensureSemantics();
      final at = _now.add(const Duration(minutes: 3, seconds: 30));
      await _pumpBoard(
          tester,
          _host(StubSchedulerRepo(
            workflows: [_wf('wf_a', 'A')],
            byWorkflow: const [WorkflowRunStats(workflowId: 'wf_a')],
            failedBySince: const {'24h': 4, '48h': 4},
            inbox: [stubInboxRow('fr_p1', 'gate', now: _now)],
            runs: [_run('fr_1', 'wf_a')],
            triggers: [_cron('tr_1', nextFireAt: at)],
            edges: [_edge('wf_a', 'tr_1')],
            schedule: TriggerSchedule(points: [
              SchedulePoint(
                  at: at, triggerId: 'tr_1', triggerName: 'cron', workflowIds: const ['wf_a']),
            ]),
          )));

      // The sentence exists IFF the tile is a control — and it says what the click does, because a
      // desktop screen reader gets `label` and the action and almost nothing else (design-system §2).
      // 句子在场 **当且仅当** 牌是控件——且它说清这一下会做什么:桌面读屏拿得到的几乎只有 label 与动作(§2)。
      for (final sentence in [
        ov.kpiRunningA11y(n: '1'),
        ov.kpiWaitingA11y(n: '1'),
        ov.kpiNextFireA11y(d: '3m'),
      ]) {
        final node = tester.getSemantics(find.bySemanticsLabel(sentence));
        final data = node.getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue, reason: '$sentence:变成按钮就要念成按钮');
        expect(data.hasAction(SemanticsAction.tap), isTrue,
            reason: '$sentence:动作是少数真到得了桌面读屏的东西之一——标 button 却不给它 = 按不动的按钮');
      }

      // The inert tile stays furniture: no sentence, no button. 惰性的牌仍是家具:无句子、无按钮。
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(ov.kpiFailed24h) + r'.*Show')), findsNothing);
      handle.dispose();
    });
  });
}
