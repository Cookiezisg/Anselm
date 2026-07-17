import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/trigger_schedule.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_schedule_track.dart';
import 'package:anselm/core/ui/an_section.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/core/ui/an_wash_highlight.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/scheduler/scheduler_windows.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/state/scheduler_overview_provider.dart';
import 'package:anselm/features/scheduler/ui/scheduler_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'stub_scheduler_repo.dart';

// S2a · the Overview board (WRK-069 §3) — pure-derivation table + the widget battery (first-use /
// empty zones / full board / KPI delta both ways / deep links). The running dot breathes forever, so
// tests use FIXED pumps, never pumpAndSettle. Overview 看板电池;呼吸点常动,固定 pump、不 settle。

final _now = DateTime.now();

TriggerEntity _trigger(String id, String name,
        {DateTime? nextFireAt,
        bool listening = true,
        bool paused = false,
        TriggerSource kind = TriggerSource.cron}) =>
    TriggerEntity(
      id: id,
      name: name,
      kind: kind,
      createdAt: _now,
      updatedAt: _now,
      // The wire's paused trio moves together (契约,非渲染判断): paused ⇒ !listening ⇒ no nextFireAt.
      // 线缆三键同动:暂停 ⇒ 不监听 ⇒ 无 nextFireAt。
      listening: paused ? false : listening,
      paused: paused,
      nextFireAt: paused ? null : nextFireAt,
    );

EntityRelation _edge(String wf, String trigger, {String wfName = ''}) => EntityRelation(
    id: 'rel_$wf$trigger',
    kind: 'equip',
    fromKind: 'workflow',
    fromId: wf,
    fromName: wfName,
    toKind: 'trigger',
    toId: trigger);

StubSchedulerRepo _fullRepo({Map<String, int> failed = const {'24h': 4, '48h': 6}}) => StubSchedulerRepo(
      workflows: [
        SchedulerWorkflowRow(id: 'wf_a', name: '数据清洗流水线', lifecycleState: 'active', updatedAt: _now),
        SchedulerWorkflowRow(id: 'wf_b', name: '库存同步', lifecycleState: 'active', updatedAt: _now),
      ],
      byWorkflow: [
        WorkflowRunStats(
            workflowId: 'wf_a',
            running: 1,
            lastRunAt: _now.subtract(const Duration(seconds: 90)),
            recent: const ['running']),
        WorkflowRunStats(
            workflowId: 'wf_b',
            lastRunAt: _now.subtract(const Duration(hours: 1)),
            recent: const ['failed', 'failed', 'failed', 'failed'],
            consecutiveFailures: 4),
      ],
      failedBySince: failed,
      totalsRunning: 1,
      // Two inbox rows — the KPI «waiting» tile counts THESE (badge/tile/zone one truth). 牌=行数。
      inbox: [
        stubInboxRow('fr_park1', 'approve_send',
            deadline: _now.add(const Duration(hours: 2)), now: _now),
        stubInboxRow('fr_park2', 'approve_more', wfId: 'wf_b', wfName: '库存同步', now: _now),
      ],
      // 3m30s out so the render-time diff still floors to «3m» (fmtWaited minute granularity).
      // 提前 3m30s:渲染时差值仍落 3m 档。
      triggers: [
        _trigger('tr_1', '每日 09:00', nextFireAt: _now.add(const Duration(minutes: 3, seconds: 30))),
      ],
      edges: [_edge('wf_a', 'tr_1')],
      // The ⑧ schedule feeds the track's points; the lane itself comes from the trigger above.
      // ⑧ 调度喂轨道的点;泳道本身来自上面那个 trigger。
      schedule: TriggerSchedule(points: [
        SchedulePoint(
            at: _now.add(const Duration(minutes: 3, seconds: 30)),
            triggerId: 'tr_1',
            triggerName: '每日 09:00',
            workflowIds: const ['wf_a']),
      ]),
      runs: [
        Flowrun(
            id: 'fr_live1',
            workflowId: 'wf_a',
            status: 'running',
            startedAt: _now.subtract(const Duration(seconds: 90)),
            updatedAt: _now),
        // FOUR failed wf_b runs inside the 24h window — matching the streak of 4 and failedBySince[24h],
        // so the 「24h 失败」 tile (= failedRuns.length, 工单⑮) reads 4 consistently with the delta, and
        // its per-run zone shows the four rows. fr_dead1 is the newest (the 7d probe's latest-run link).
        // 四个 wf_b 失败 run 落在 24h 窗内——与连败 4 及 failedBySince[24h] 一致,故「24h 失败」牌(=failedRuns.length)
        // 读 4、与 delta 一致,且它的按 run 区显示这四行;fr_dead1 最新(7d 探针的最新 run 直通车)。
        for (var i = 1; i <= 4; i++)
          Flowrun(
              id: 'fr_dead$i',
              workflowId: 'wf_b',
              status: 'failed',
              error: 'HTTP 502 Bad Gateway: upstream did not respond\nretried 3 times',
              startedAt: _now.subtract(Duration(hours: i)),
              completedAt: _now.subtract(Duration(hours: i)),
              updatedAt: _now),
      ],
    );

Widget _host(SchedulerRepository repo, {GoRouter? router}) => ProviderScope(
      overrides: [
        sseGatewayProvider.overrideWithValue(null),
        schedulerRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: router != null
            ? MaterialApp.router(theme: AnTheme.light(), routerConfig: router)
            : MaterialApp(
                theme: AnTheme.light(),
                home: const Scaffold(body: SchedulerOverviewView())),
      ),
    );

Future<void> _pumpBoard(WidgetTester tester, Widget host) async {
  await tester.pumpWidget(host);
  await tester.pump(); // providers resolve
  await tester.pump(const Duration(seconds: 1)); // count-ups settle (≤900ms); breath keeps looping
}

void main() {
  group('pure derivations 纯派生', () {
    test('kpiFailedDelta: worsening / improving / flat', () {
      expect(kpiFailedDelta(failed24: 4, failed48: 6), 2); // ▲2
      expect(kpiFailedDelta(failed24: 1, failed48: 4), -2); // ▼2
      expect(kpiFailedDelta(failed24: 3, failed48: 6), 0); // hidden
    });

    test('earliestNextFire: earliest FUTURE wins, past ignored, none → null', () {
      final now = DateTime(2026, 7, 16, 9);
      expect(
        earliestNextFire([
          now.add(const Duration(hours: 2)),
          now.add(const Duration(minutes: 3)),
          now.subtract(const Duration(minutes: 1)),
        ], now),
        now.add(const Duration(minutes: 3)),
      );
      expect(earliestNextFire([now.subtract(const Duration(days: 1))], now), isNull);
      expect(earliestNextFire(const [], now), isNull);
    });

    test('scheduleLanes: the lane set comes from the TRIGGER LIST — a PAUSED trigger keeps its lane '
        '(判决①), a non-cron never gets one, and points hang onto lanes by (trigger, workflow)', () {
      final now = DateTime(2026, 7, 16, 9);
      final lanes = scheduleLanes(
        triggers: [
          _trigger('tr_soon', 'soon'),
          _trigger('tr_now', 'now-ish'),
          // Paused: the endpoint emits NO points for it — the lane must survive on trigger data alone.
          // 暂停:端点为它一个点都不发——泳道必须仅靠 trigger 数据存活。
          _trigger('tr_off', 'paused', paused: true),
          _trigger('tr_hook', 'webhook', kind: TriggerSource.webhook),
          _trigger('tr_orphan', 'orphan'), // 无边 → 不产 run → 无泳道
        ],
        edges: [
          _edge('wf_1', 'tr_soon'),
          _edge('wf_2', 'tr_soon', wfName: 'edge-name'), // 一 trigger 两 workflow → 两泳道
          _edge('wf_1', 'tr_now'),
          _edge('wf_1', 'tr_off'),
          _edge('wf_1', 'tr_hook'),
        ],
        workflowNames: const {'wf_1': '清洗'},
        schedule: TriggerSchedule(points: [
          SchedulePoint(
              at: now.add(const Duration(hours: 2)),
              triggerId: 'tr_soon',
              workflowIds: const ['wf_1', 'wf_2']),
          SchedulePoint(
              at: now.add(const Duration(minutes: 3)),
              triggerId: 'tr_now',
              workflowIds: const ['wf_1']),
          // Outside the 24h window — unplaceable, so unshown. 窗外:放不下即不渲。
          SchedulePoint(
              at: now.add(const Duration(hours: 25)),
              triggerId: 'tr_soon',
              workflowIds: const ['wf_1']),
        ]),
        now: now,
      );

      expect([for (final l in lanes) l.triggerId], ['tr_now', 'tr_soon', 'tr_soon', 'tr_off'],
          reason: '最近的在前;没有将至之事的泳道(暂停)沉底——**沉底不是消失**');
      expect(lanes.where((l) => l.triggerId == 'tr_hook'), isEmpty,
          reason: 'webhook 下次 fire 不可知,如实缺席而非在场且空');
      expect(lanes.where((l) => l.triggerId == 'tr_orphan'), isEmpty, reason: '无边=不产 run,无泳道');

      final paused = lanes.singleWhere((l) => l.triggerId == 'tr_off');
      expect(paused.paused, isTrue);
      expect(paused.futureAt, isEmpty,
          reason: '判决①:暂停泳道零未来点却**仍在**——它靠 trigger 列表活着,不靠调度点');

      expect(lanes.first.futureAt, [now.add(const Duration(minutes: 3))]);
      expect(lanes[1].futureAt, [now.add(const Duration(hours: 2))],
          reason: '窗外的点被丢弃,窗内的留下');
      expect(lanes.first.workflowName, '清洗');
      expect(lanes.firstWhere((l) => l.workflowId == 'wf_2').workflowName, 'edge-name',
          reason: 'names map 缺席回落边上的 fromName');
    });

    test('scheduleLanes: a point never lights a workflow the listener table did not resolve', () {
      final now = DateTime(2026, 7, 16, 9);
      final lanes = scheduleLanes(
        triggers: [_trigger('tr_1', 'cron')],
        edges: [_edge('wf_1', 'tr_1'), _edge('wf_2', 'tr_1')],
        workflowNames: const {'wf_1': 'A', 'wf_2': 'B'},
        // The point resolves to wf_1 ONLY — wf_2's lane must stay empty. 点只反查出 wf_1。
        schedule: TriggerSchedule(points: [
          SchedulePoint(
              at: now.add(const Duration(hours: 1)),
              triggerId: 'tr_1',
              workflowIds: const ['wf_1']),
        ]),
        now: now,
      );
      expect(lanes.firstWhere((l) => l.workflowId == 'wf_1').futureAt, hasLength(1));
      expect(lanes.firstWhere((l) => l.workflowId == 'wf_2').futureAt, isEmpty,
          reason: '点绝不点亮它承诺不了的泳道(workflowIds 取自内存监听表,是承诺的边界)');
    });

    test('topFailing: streak-DESC, zero excluded, capped at 5', () {
      final stats = [
        for (var i = 0; i < 8; i++) WorkflowRunStats(workflowId: 'wf_$i', consecutiveFailures: i),
      ];
      final top = topFailing(stats);
      expect([for (final s in top) s.consecutiveFailures], [7, 6, 5, 4, 3]);
    });

    test('errorFirstLine: first non-empty line; null-safe', () {
      expect(errorFirstLine('boom\nstack'), 'boom');
      expect(errorFirstLine('\n  \n  real cause  \nrest'), 'real cause');
      expect(errorFirstLine(null), isNull);
      expect(errorFirstLine('  \n '), isNull);
    });
  });

  group('provider 组装', () {
    test('the board derives every zone from the rail truth + probes', () async {
      final container = ProviderContainer(overrides: [
        sseGatewayProvider.overrideWithValue(null),
        schedulerRepositoryProvider.overrideWithValue(_fullRepo()),
      ]);
      addTearDown(container.dispose);

      final d = await container.read(schedulerOverviewProvider.future);
      expect(d.firstUse, isFalse);
      expect(d.kpi.running, 1);
      expect(d.kpi.waiting, 2);
      // The tile IS the length of its per-run failed list (工单⑮), not a second count. 牌就是列表长度。
      expect(d.failedRuns, hasLength(4));
      expect(d.kpi.failed24h, d.failedRuns.length);
      expect(d.kpi.failedDelta, 2);
      expect(d.kpi.nextFire, isNotNull);

      expect(d.runningRuns, hasLength(1));
      expect(d.runningRuns.single.workflowName, '数据清洗流水线');
      expect(d.runningRuns.single.run.id, 'fr_live1');

      expect(d.track.lanes, hasLength(1));
      expect(d.track.lanes.single.workflowName, '数据清洗流水线');
      expect(d.track.lanes.single.futureAt, hasLength(1), reason: '⑧ 的点挂到了它的泳道上');
      expect(d.track.truncated, isFalse);

      expect(d.failures, hasLength(1));
      expect(d.failures.single.streak, 4);
      expect(d.failures.single.error, 'HTTP 502 Bad Gateway: upstream did not respond',
          reason: '错误只取首句');
      expect(d.failures.single.latestRunId, 'fr_dead1');
    });

    test('zero workflows → firstUse, no probes fired', () async {
      final container = ProviderContainer(overrides: [
        sseGatewayProvider.overrideWithValue(null),
        schedulerRepositoryProvider.overrideWithValue(StubSchedulerRepo()),
      ]);
      addTearDown(container.dispose);
      final d = await container.read(schedulerOverviewProvider.future);
      expect(d.firstUse, isTrue);
    });
  });

  group('widget battery 电池', () {
    testWidgets('full board: KPI strip + running row + upcoming row + failure row', (tester) async {
      await _pumpBoard(tester, _host(_fullRepo()));
      final ov = t.scheduler.overview;

      // KPI labels + the delta arrow (red ▲2). KPI 牌与红 ▲2。
      expect(find.text(ov.kpiRunning), findsOneWidget);
      expect(find.text(ov.kpiWaiting), findsOneWidget);
      expect(find.text(ov.kpiFailed24h), findsOneWidget);
      expect(find.text(ov.kpiNextFire), findsOneWidget);
      expect(find.text(ov.deltaUp(n: '2')), findsOneWidget);

      // Zone heads (caption labels render uppercased). 区头(大写渲染)。
      expect(find.text(ov.runningHead(n: '1').toUpperCase()), findsOneWidget);
      expect(find.text(ov.scheduleHead.toUpperCase()), findsOneWidget);
      expect(find.text(ov.failed24hHead(n: '4').toUpperCase()), findsOneWidget,
          reason: '24h 失败区(工单⑮):牌点开的四行');
      expect(find.text(ov.failuresHead.toUpperCase()), findsOneWidget);

      // Running row: name + fr_ chip; elapsed rides the measure slot. 正在跑行。
      
      expect(find.text('fr_live1'), findsOneWidget);

      // The schedule TRACK (S5): a lane per (workflow × cron trigger), labelled by the WORKFLOW —
      // this ocean's axis is the workflow (§1/§3.4), and the trigger's name rides the dot's tooltip.
      // So the workflow name now appears twice (running row + its lane), and the KPI next-fire tile
      // is the only place quoting the relative time.
      // 调度**轨道**(S5):逐 (workflow×cron) 一泳道,标签是 **workflow** 名——本海洋的轴是 workflow
      // (§1/§3.4),trigger 名在点的 tooltip 里。故 workflow 名现两次(正在跑行 + 它的泳道),而相对时间
      // 只剩 KPI 下次调度牌一处在引。
      expect(find.byType(AnScheduleTrack), findsOneWidget);
      expect(find.text('数据清洗流水线'), findsNWidgets(3),
          reason: '同一个 workflow 在三个区各现一次:等你处理行 + 正在跑行 + 轨道泳道');
      expect(find.text(ov.fireIn(d: '3m')), findsOneWidget, reason: 'KPI 下次调度牌');

      // Failure row: streak chip + error FIRST line + through-train. 失败行。
      expect(find.text(ov.streak(n: '4')), findsOneWidget);
      // The 502 error first-line renders in EACH 24h-failed run row (4) AND the 7d aggregation row (1)
      // — one projection, five surfaces; the finding here is that both failure views show it honestly.
      // 502 错误首句在每个 24h 失败 run 行(4)与 7d 聚合行(1)各现——一份投影五处;两种失败视图都诚实地显示它。
      expect(find.text('HTTP 502 Bad Gateway: upstream did not respond'), findsNWidgets(5));
      expect(find.text(ov.latestRun), findsOneWidget);

      // No empty sentences on a full board. 满态无空句。
      expect(find.text(ov.runningEmpty), findsNothing);
      expect(find.text(ov.scheduleEmpty), findsNothing);
      expect(find.text(ov.failuresEmpty), findsNothing);
    });

    testWidgets('quiet workspace: three honest empty sentences, KPI dashes', (tester) async {
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '安静', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
      );
      await _pumpBoard(tester, _host(repo));
      final ov = t.scheduler.overview;
      expect(find.text(ov.runningEmpty), findsOneWidget);
      expect(find.text(ov.scheduleEmpty), findsOneWidget);
      expect(find.text(ov.failuresEmpty), findsOneWidget);
      expect(find.text(ov.kpiNone), findsOneWidget, reason: '无未来 fire → 下次调度牌 —');
      expect(find.text(ov.deltaUp(n: '0')), findsNothing);
      expect(find.text(ov.deltaDown(n: '0')), findsNothing);
    });

    testWidgets('KPI delta both ways: improving reads ▼ green; flat hides the arrow', (tester) async {
      await _pumpBoard(tester, _host(_fullRepo(failed: const {'24h': 1, '48h': 4})));
      final ov = t.scheduler.overview;
      expect(find.text(ov.deltaDown(n: '2')), findsOneWidget);
      expect(find.textContaining('▲'), findsNothing);

      // A fresh tree — overrideWithValue on a live ProviderScope updates the VALUE but the rail
      // never re-reads the repo without a durable event, so the old board would linger. 换库先拆树。
      await tester.pumpWidget(const SizedBox());
      await _pumpBoard(tester, _host(_fullRepo(failed: const {'24h': 3, '48h': 6})));
      expect(find.textContaining('▲'), findsNothing);
      expect(find.textContaining('▼'), findsNothing);
    });

    testWidgets('zero data: the whole page is ONE education card with both deep links',
        (tester) async {
      await _pumpBoard(tester, _host(StubSchedulerRepo()));
      final ov = t.scheduler.overview;
      expect(find.text(ov.firstUseTitle), findsOneWidget);
      expect(find.text(ov.firstUseEntities), findsOneWidget);
      expect(find.text(ov.firstUseChat), findsOneWidget);
      expect(find.byType(AnSection), findsNothing, reason: '教育卡替代全部区块,不渲空框废墟');
      expect(find.byType(AnButton), findsNWidgets(2));
    });

    testWidgets('a running row deep-links into the run flagship', (tester) async {
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SchedulerOverviewView())),
        GoRoute(
            path: '/scheduler/w/:id/runs/:frId',
            builder: (_, _) => const Scaffold(body: SizedBox())),
      ]);
      addTearDown(router.dispose);
      await _pumpBoard(tester, _host(_fullRepo(), router: router));

      await tester.tap(find.text('fr_live1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/scheduler/w/wf_a/runs/fr_live1');
    });

    testWidgets('a 24h-failed row deep-links into its run flagship (工单⑮)', (tester) async {
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SchedulerOverviewView())),
        GoRoute(
            path: '/scheduler/w/:id/runs/:frId',
            builder: (_, _) => const Scaffold(body: SizedBox())),
      ]);
      addTearDown(router.dispose);
      await _pumpBoard(tester, _host(_fullRepo(), router: router));

      // The newest failed wf_b run (fr_dead1) sits in the 24h-failed zone below the fold; scroll it in,
      // then tapping it opens its detail. 最新的 wf_b 失败 run(fr_dead1)在折叠下的 24h 失败区里;滚进来再点。
      await tester.ensureVisible(find.text('fr_dead1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('fr_dead1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/scheduler/w/wf_b/runs/fr_dead1');
    });

    testWidgets('first-load failure: the error state with a retry', (tester) async {
      await _pumpBoard(tester, _host(StubSchedulerRepo(failWorkflows: true)));
      expect(find.byType(AnState), findsOneWidget);
      expect(find.text(t.scheduler.overview.errorTitle), findsOneWidget);
      expect(find.text(t.scheduler.retry), findsOneWidget);
    });
  });

  group('S5 · 调度时间轴', () {
    testWidgets('the track replaces the row list: a lane per (workflow × cron), points from ⑧',
        (tester) async {
      final repo = _fullRepo();
      await _pumpBoard(tester, _host(repo));
      expect(find.byType(AnScheduleTrack), findsOneWidget);
      expect(repo.scheduleWithins, ['24h'],
          reason: '区头承诺 24h,就必须真的问 24h(窗口走 SchedulerWindows.trackWithin)');
    });

    testWidgets('a PAUSED trigger keeps a greyed lane with «已暂停» — 判决①', (tester) async {
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '邮件归档', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
        triggers: [_trigger('tr_off', '每晚归档', paused: true)],
        edges: [_edge('wf_a', 'tr_off')],
        // The endpoint emits NOTHING for a paused trigger — the lane must live on trigger data alone.
        // 端点为暂停的 trigger 一个点都不发——泳道必须仅靠 trigger 数据活着。
        schedule: const TriggerSchedule(),
      );
      await _pumpBoard(tester, _host(repo));
      expect(find.byType(AnScheduleTrack), findsOneWidget);
      expect(find.text('邮件归档'), findsWidgets, reason: '判决①:暂停泳道**不消失**');
      expect(find.text(t.scheduler.home.paused), findsOneWidget, reason: '灰显必须配词:色不独行');
    });

    // NOTE these are two SEPARATE tests, not one with two pumps: re-pumping an identical tree reuses
    // the ProviderScope element, and the controllers `ref.read` their repo — so a swapped override
    // would NOT re-run them and the second half would silently assert against the FIRST repo's data.
    // 注意这是**两个独立测试**而非一个测两次 pump:重 pump 同构树会复用 ProviderScope 元素,而控制器是
    // `ref.read` 取 repo 的——换 override 不会让它们重跑,后半段会静默地对着**前一个** repo 的数据断言。
    testWidgets('an uncapped window says nothing about truncation', (tester) async {
      await _pumpBoard(tester, _host(_fullRepo()));
      expect(find.text(t.scheduler.overview.trackTruncated), findsNothing);
    });

    testWidgets('truncated says so out loud — a capped window must not read as the whole truth',
        (tester) async {
      final full = _fullRepo();
      await _pumpBoard(
          tester,
          _host(StubSchedulerRepo(
            workflows: full.workflows,
            byWorkflow: full.byWorkflow,
            triggers: full.triggers,
            edges: full.edges,
            schedule: TriggerSchedule(points: full.schedule.points, truncated: true),
          )));
      expect(find.text(t.scheduler.overview.trackTruncated), findsOneWidget,
          reason: '端点截断了窗就必须明说,否则轨道会被读成全部真相');
    });

    testWidgets('no cron lanes at all → the honest empty sentence, not an empty axis', (tester) async {
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '手动流程', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
      );
      await _pumpBoard(tester, _host(repo));
      expect(find.text(t.scheduler.overview.scheduleEmpty), findsOneWidget);
      expect(find.byType(AnScheduleTrack), findsNothing, reason: '零泳道不画一条指着空无的轴');
    });
  });

  // ─────────────────────────── 判决⑥ · 过去的点 / 错过的 ✕ / 错过 KPI 牌 ───────────────────────────
  // 工单⑭ closed the contract gap S5 recorded (a workspace-level, time-windowed firing query), so the
  // track finally carries BOTH halves of one timeline and the fifth KPI card can exist. The batteries
  // below guard the one thing that makes the card legitimate rather than decorative: 「牌上写 3、点开
  // 列表显示 4」 must be UNREACHABLE — not unlikely, unreachable — because the number and the marks it
  // opens are the same predicate on the same anchor.
  group('判决⑥ 过去的点与错过的 ✕', () {
    Firing f(String id, String trigger, String wf, FiringStatus status, Duration ago,
            {String flowrunId = ''}) =>
        Firing(
          id: id,
          triggerId: trigger,
          workflowId: wf,
          status: status,
          flowrunId: flowrunId,
          createdAt: _now.subtract(ago),
          updatedAt: _now.subtract(ago),
        );

    group('scheduleLanes 纯派生', () {
      test('past firings hang on their (trigger × workflow) lane; missed keeps its own identity', () {
        final lanes = scheduleLanes(
          triggers: [_trigger('tr_1', '每 6 小时')],
          edges: [_edge('wf_a', 'tr_1')],
          workflowNames: const {'wf_a': '库存同步'},
          schedule: const TriggerSchedule(),
          firings: [
            f('trf_1', 'tr_1', 'wf_a', FiringStatus.started, const Duration(hours: 1)),
            f('trf_2', 'tr_1', 'wf_a', FiringStatus.missed, const Duration(hours: 13)),
          ],
          now: _now,
        );
        expect(lanes, hasLength(1));
        expect(lanes.single.firings.map((e) => e.id), ['trf_2', 'trf_1'],
            reason: '旧→新:轴从左往右读');
        expect(lanes.single.firings.map((e) => e.status),
            [FiringStatus.missed, FiringStatus.started]);
      });

      test('a firing older than the past window is off the axis and dropped', () {
        final lanes = scheduleLanes(
          triggers: [_trigger('tr_1', '每日')],
          edges: [_edge('wf_a', 'tr_1')],
          workflowNames: const {'wf_a': 'A'},
          schedule: const TriggerSchedule(),
          firings: [f('trf_old', 'tr_1', 'wf_a', FiringStatus.started, const Duration(hours: 25))],
          now: _now,
        );
        expect(lanes.single.firings, isEmpty, reason: '25h 前 > 24h 过去窗:轴上无处可站');
      });

      // THE bug shape, guarded. A missed tick whose lane is gone (the workflow stopped listening, or
      // the trigger was deleted, since it came due) is still counted by the card — so it must still be
      // shown. 那个 bug 形态的守卫:泳道已消失的 missed 刻度**仍被牌数着**,故仍须显示。
      test('an ORPHANED missed tick still gets a lane — the card counts it, so it must be shown', () {
        final lanes = scheduleLanes(
          triggers: const [],
          edges: const [],
          workflowNames: const {'wf_gone': '已解绑的流程'},
          schedule: const TriggerSchedule(),
          firings: [f('trf_m', 'tr_gone', 'wf_gone', FiringStatus.missed, const Duration(hours: 5))],
          now: _now,
        );
        expect(lanes, hasLength(1));
        expect(lanes.single.workflowName, '已解绑的流程');
        expect(lanes.single.firings.single.id, 'trf_m');
        expect(lanes.single.futureAt, isEmpty, reason: '它没有未来——只有一个发生过的事实');
      });

      test('an orphaned NON-missed firing is dropped — nothing counts it, so it is only context', () {
        final lanes = scheduleLanes(
          triggers: const [],
          edges: const [],
          workflowNames: const {'wf_gone': '幽灵'},
          schedule: const TriggerSchedule(),
          firings: [f('trf_s', 'tr_gone', 'wf_gone', FiringStatus.shed, const Duration(hours: 5))],
          now: _now,
        );
        expect(lanes, isEmpty, reason: 'shed 孤儿无人数它,故它不配为自己造一条泳道');
      });

      test('a PAUSED lane still carries the fires it made before it was paused (判决①)', () {
        final lanes = scheduleLanes(
          triggers: [_trigger('tr_1', '每晚归档', paused: true)],
          edges: [_edge('wf_a', 'tr_1')],
          workflowNames: const {'wf_a': '归档'},
          schedule: const TriggerSchedule(),
          firings: [f('trf_1', 'tr_1', 'wf_a', FiringStatus.started, const Duration(hours: 2))],
          now: _now,
        );
        expect(lanes.single.paused, isTrue);
        expect(lanes.single.futureAt, isEmpty, reason: '暂停的 cron 不获未来刻度');
        expect(lanes.single.firings, hasLength(1), reason: '但它暂停之前开过的火仍是历史');
      });

      test('the missed window floor is the KPI window — equal by construction, not by coincidence', () {
        expect(SchedulerWindows.trackPastWindow, SchedulerWindows.kpiWindow);
      });
    });

    group('错过 KPI 牌', () {
      StubSchedulerRepo missedRepo({int missedCount = 2}) {
        final repo = _fullRepo();
        return StubSchedulerRepo(
          workflows: repo.workflows,
          byWorkflow: repo.byWorkflow,
          failedBySince: const {'24h': 4, '48h': 6},
          totalsRunning: 1,
          inbox: repo.inbox,
          triggers: repo.triggers,
          edges: repo.edges,
          schedule: repo.schedule,
          runs: repo.runs,
          firings: [
            for (var i = 0; i < missedCount; i++)
              f('trf_m$i', 'tr_1', 'wf_a', FiringStatus.missed, Duration(hours: 3 + i * 4)),
            f('trf_ok', 'tr_1', 'wf_a', FiringStatus.started, const Duration(hours: 2)),
          ],
        );
      }

      testWidgets('「错过 0」 is NOT a tile — the absence of the card IS the good news', (tester) async {
        await _pumpBoard(tester, _host(missedRepo(missedCount: 0)));
        expect(find.text(t.scheduler.overview.kpiMissed), findsNothing,
            reason: '禁虚荣数字:天天读 0 的牌是装饰,还要吃掉另外四张的宽');
        // The other four are unaffected. 另外四张不受影响。
        expect(find.text(t.scheduler.overview.kpiRunning), findsOneWidget);
      });

      testWidgets('missed > 0 → the fifth tile appears carrying the backend count', (tester) async {
        await _pumpBoard(tester, _host(missedRepo()));
        expect(find.text(t.scheduler.overview.kpiMissed), findsOneWidget);
        expect(find.text('2'), findsWidgets);
      });

      // 宪法: a KPI must open the list it counts. 宪法:KPI 必须点开它数的那个列表。
      testWidgets('the tile OPENS its evidence — the schedule track washes on tap', (tester) async {
        await _pumpBoard(tester, _host(missedRepo()));
        expect(find.byType(AnWashHighlight), findsNothing, reason: '未点击前不洗:注意力只随用户动作而动');
        await tester.tap(find.text(t.scheduler.overview.kpiMissed));
        await tester.pump();
        expect(find.byType(AnWashHighlight), findsOneWidget,
            reason: '点击 → 它数的那些刻度所在的区被洗亮');
        expect(find.descendant(of: find.byType(AnWashHighlight), matching: find.byType(AnScheduleTrack)),
            findsOneWidget);
      });

      // The whole point, in one assertion. 全部要害,一条断言。
      testWidgets('SAME PREDICATE: the missed page asks the byte-identical instant the card counted from',
          (tester) async {
        final repo = missedRepo();
        await _pumpBoard(tester, _host(repo));
        // The rail reads stats too (168h, a relative word) — the card's read is the ABSOLUTE 24h one.
        // Picked by its window rather than by call order, so this stays true if the batch is reordered.
        // rail 也读 stats(168h 相对词)——牌读的是那次**绝对** 24h。按**窗口**挑而非按调用序,故批次重排它仍成立。
        final absolutes = repo.statsSinces.where((s) => DateTime.tryParse(s) != null).toList();
        expect(absolutes, hasLength(2), reason: 'Overview 发两次绝对窗:24h(牌)+ 48h(delta 探针)');
        final cardSince = absolutes.firstWhere(
            (s) => DateTime.now().difference(DateTime.parse(s)).inHours == 24,
            orElse: () => fail('没有一次 stats 读用的是 24h 绝对窗——牌的数从哪来的?'));

        final missedFilter =
            repo.firingFilters.firstWhere((q) => q['status'] == FiringStatus.missed.name);
        expect(missedFilter['createdAfter'], cardSince,
            reason: '牌的 since 与 ✕ 的 createdAfter 必须**逐字节**相同——两个「差不多」的锚点就是「牌写 3、列表显示 4」');
        expect(missedFilter['createdBefore'], '',
            reason: '牌的窗是 [since, ∞)、无上界;给列表加一个上界就是第二份谓词');
      });

      testWidgets('the marks land on the track: a ✕ per missed tick, solid dots for real fires',
          (tester) async {
        await _pumpBoard(tester, _host(missedRepo()));
        expect(find.descendant(
                of: find.byType(AnScheduleTrack), matching: find.byIcon(AnIcons.close)),
            findsNWidgets(2),
            reason: '两个 missed → 两个 ✕(桶不同故不折叠)');
      });

      testWidgets('a capped firing page SAYS the older end is unknown — never a silent hole',
          (tester) async {
        final base = missedRepo();
        final repo = StubSchedulerRepo(
          workflows: base.workflows,
          byWorkflow: base.byWorkflow,
          failedBySince: const {'24h': 4, '48h': 6},
          triggers: base.triggers,
          edges: base.edges,
          schedule: base.schedule,
          // 400 rows > the 200 cap → the page is the NEWEST slice. 400 行 > 200 帽 → 只拿到最新那片。
          firings: [
            for (var i = 0; i < 400; i++)
              f('trf_$i', 'tr_1', 'wf_a', FiringStatus.started, Duration(minutes: i * 3)),
          ],
        );
        await _pumpBoard(tester, _host(repo));
        expect(find.textContaining(RegExp('未显示|not shown')), findsOneWidget,
            reason: '撞帽 = 更老那端是**未知**而非**空**;不说就是画一条藏着洞、看起来完整的轨');
      });

      testWidgets('a firing read that FAILS never becomes a reassuring zero', (tester) async {
        final base = missedRepo();
        final repo = StubSchedulerRepo(
          workflows: base.workflows,
          byWorkflow: base.byWorkflow,
          failedBySince: const {'24h': 4, '48h': 6},
          triggers: base.triggers,
          edges: base.edges,
          schedule: base.schedule,
          firings: base.firings,
          failFirings: true,
        );
        await _pumpBoard(tester, _host(repo));
        expect(find.text(t.scheduler.overview.errorTitle), findsOneWidget,
            reason: '「你什么都没错过」与「我查不出来」是两句话,只有一句可以渲成让人放心的空牌');
        expect(find.text(t.scheduler.overview.kpiMissed), findsNothing);
      });
    });
  });
}
