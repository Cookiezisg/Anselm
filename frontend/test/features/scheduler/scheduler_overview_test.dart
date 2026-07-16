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
        Flowrun(
            id: 'fr_dead1',
            workflowId: 'wf_b',
            status: 'failed',
            error: 'HTTP 502 Bad Gateway: upstream did not respond\nretried 3 times',
            startedAt: _now.subtract(const Duration(hours: 1)),
            completedAt: _now.subtract(const Duration(hours: 1)),
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
      expect(d.kpi.failed24h, 4);
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
      expect(find.text(ov.upcomingHead.toUpperCase()), findsOneWidget);
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
      expect(find.text('HTTP 502 Bad Gateway: upstream did not respond'), findsOneWidget);
      expect(find.text(ov.latestRun), findsOneWidget);

      // No empty sentences on a full board. 满态无空句。
      expect(find.text(ov.runningEmpty), findsNothing);
      expect(find.text(ov.upcomingEmpty), findsNothing);
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
      expect(find.text(ov.upcomingEmpty), findsOneWidget);
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
      expect(find.text(t.scheduler.overview.upcomingEmpty), findsOneWidget);
      expect(find.byType(AnScheduleTrack), findsNothing, reason: '零泳道不画一条指着空无的轴');
    });
  });
}
