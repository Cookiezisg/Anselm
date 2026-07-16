import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/ui/an_button.dart';
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
        {DateTime? nextFireAt, bool listening = true}) =>
    TriggerEntity(
      id: id,
      name: name,
      kind: TriggerSource.cron,
      createdAt: _now,
      updatedAt: _now,
      listening: listening,
      nextFireAt: nextFireAt,
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

    test('upcomingFires: 24h window, time-ASC, listening-only, N equipped workflows → N rows, '
        'unequipped trigger excluded, name falls back to the edge', () {
      final now = DateTime(2026, 7, 16, 9);
      final fires = upcomingFires(
        triggers: [
          _trigger('tr_soon', 'soon', nextFireAt: now.add(const Duration(hours: 2))),
          _trigger('tr_now', 'now-ish', nextFireAt: now.add(const Duration(minutes: 3))),
          _trigger('tr_far', 'far', nextFireAt: now.add(const Duration(hours: 25))), // 窗外
          _trigger('tr_off', 'paused', nextFireAt: now.add(const Duration(hours: 1)), listening: false),
          _trigger('tr_orphan', 'orphan', nextFireAt: now.add(const Duration(hours: 1))), // 无边
        ],
        edges: [
          _edge('wf_1', 'tr_soon'),
          _edge('wf_2', 'tr_soon', wfName: 'edge-name'), // 一 trigger 两 workflow → 两行
          _edge('wf_1', 'tr_now'),
          _edge('wf_1', 'tr_far'),
          _edge('wf_1', 'tr_off'),
        ],
        workflowNames: const {'wf_1': '清洗'},
        now: now,
      );
      expect([for (final f in fires) f.triggerId], ['tr_now', 'tr_soon', 'tr_soon']);
      expect(fires.first.workflowName, '清洗');
      expect(fires.last.workflowName, 'edge-name', reason: 'names map 缺席回落边上的 fromName');
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

      expect(d.upcoming, hasLength(1));
      expect(d.upcoming.single.workflowName, '数据清洗流水线');

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
      expect(find.text('数据清洗流水线'), findsWidgets);
      expect(find.text('fr_live1'), findsOneWidget);

      // Upcoming row: trigger name + relative time (the KPI next-fire tile quotes the SAME earliest
      // fire → two honest occurrences). 未来行;KPI 下次调度牌同引最早 fire → 两处同现。
      expect(find.text('每日 09:00'), findsOneWidget);
      expect(find.text(ov.fireIn(d: '3m')), findsNWidgets(2));

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
}
