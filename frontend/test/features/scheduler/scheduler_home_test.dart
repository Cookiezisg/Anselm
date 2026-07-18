import 'dart:async';

import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_matrix.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/model/time_range.dart';
import 'package:anselm/core/run/run_ledger.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/state/scheduler_home_provider.dart';
import 'package:anselm/features/scheduler/ui/scheduler_home_model.dart';
import 'package:anselm/features/scheduler/ui/scheduler_home.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'stub_scheduler_repo.dart';

// S3 · the workflow operations home (WRK-069 §4, 主页重建拍板 0717) — four segments: health head
// (7d stat numbers + Run now + ⋯/:kill; the bead strip is GONE — the matrix's column heads carry
// the same news) · the MATRIX zone (page-level time-range capsule + the chronological grid; column/
// cell clicks NAVIGATE to the flagship) · the run big table (source-phrase identity, TRUE count
// strip, origin filter, keyset paging, follow pill, batch ops; a row tap expands the INLINE peek
// card — `?run=` is the one expanded row) · the triggers exhibit. The running dot breathes forever
// → FIXED pumps, never pumpAndSettle. S3 电池;固定 pump、不 settle。

final _now = DateTime.now();

Graph get _graph => const Graph(
      nodes: [
        Node(id: 'fetch', kind: NodeKind.action, ref: 'fn_fetch'),
        Node(id: 'analyze', kind: NodeKind.agent, ref: 'ag_analyze'),
        Node(id: 'notify', kind: NodeKind.action, ref: 'fn_notify'),
      ],
      edges: [Edge(id: 'e1', from: 'fetch', to: 'analyze'), Edge(id: 'e2', from: 'analyze', to: 'notify')],
    );

List<FlowrunNode> _nodes(String frId, {bool failed = false}) => [
      FlowrunNode(
          id: 'frn_${frId}_1',
          flowrunId: frId,
          nodeId: 'fetch',
          kind: 'action',
          status: 'completed',
          createdAt: _now.subtract(const Duration(minutes: 2)),
          completedAt: _now.subtract(const Duration(minutes: 2)),
          updatedAt: _now),
      FlowrunNode(
          id: 'frn_${frId}_2',
          flowrunId: frId,
          nodeId: 'analyze',
          kind: 'agent',
          status: failed ? 'failed' : 'completed',
          error: failed ? 'timeout: LLM 30s' : null,
          createdAt: _now.subtract(const Duration(minutes: 1)),
          completedAt: _now.subtract(const Duration(seconds: 40)),
          updatedAt: _now),
    ];

StubSchedulerRepo _repo({bool failRunFull = false}) {
  final runs = <Flowrun>[
    Flowrun(
        id: 'fr_live1',
        workflowId: 'wf_a',
        origin: 'cron',
        triggerId: 'tr_cron',
        status: 'running',
        startedAt: _now.subtract(const Duration(minutes: 3)),
        updatedAt: _now),
    Flowrun(
        id: 'fr_fail1',
        workflowId: 'wf_a',
        origin: 'webhook',
        triggerId: 'tr_hook',
        status: 'failed',
        error: 'HTTP 502 Bad Gateway: upstream did not respond\nretried 3 times',
        replayCount: 1,
        startedAt: _now.subtract(const Duration(hours: 1)),
        completedAt: _now.subtract(const Duration(hours: 1)),
        updatedAt: _now),
    Flowrun(
        id: 'fr_fail2',
        workflowId: 'wf_a',
        origin: 'cron',
        triggerId: 'tr_cron',
        status: 'failed',
        error: 'timeout: LLM 30s no answer',
        startedAt: _now.subtract(const Duration(hours: 2)),
        completedAt: _now.subtract(const Duration(hours: 2)),
        updatedAt: _now),
    Flowrun(
        id: 'fr_chat1',
        workflowId: 'wf_a',
        origin: 'chat',
        conversationId: 'cv_demo0000000001',
        status: 'completed',
        startedAt: _now.subtract(const Duration(hours: 3)),
        completedAt: _now.subtract(const Duration(hours: 3)).add(const Duration(seconds: 12)),
        updatedAt: _now),
    // A pre-provenance row — origin absent on the wire. 旧行(无 origin)。
    Flowrun(
        id: 'fr_legacy1',
        workflowId: 'wf_a',
        status: 'completed',
        startedAt: _now.subtract(const Duration(days: 3)),
        completedAt: _now.subtract(const Duration(days: 3)).add(const Duration(seconds: 30)),
        updatedAt: _now),
  ];
  return StubSchedulerRepo(
    workflows: [
      SchedulerWorkflowRow(
          id: 'wf_a', name: '数据清洗流水线', lifecycleState: 'active', updatedAt: _now),
    ],
    byWorkflow: [
      WorkflowRunStats(
        workflowId: 'wf_a',
        running: 1,
        lastRunAt: _now.subtract(const Duration(minutes: 3)),
        recent: const ['running', 'failed', 'completed', 'completed'],
        successRate: 0.8,
        avgElapsedMs: 42000,
      ),
    ],
    totalsRunning: 1,
    triggers: [
      TriggerEntity(
          id: 'tr_cron',
          name: '每日 09:00',
          kind: TriggerSource.cron,
          config: const {'cron': '0 9 * * *'},
          createdAt: _now,
          updatedAt: _now,
          listening: true,
          lastFiredAt: _now.subtract(const Duration(minutes: 2)),
          nextFireAt: _now.add(const Duration(minutes: 3))),
      TriggerEntity(
          id: 'tr_hook',
          name: '发票回调',
          kind: TriggerSource.webhook,
          config: const {'path': '/invoice'},
          createdAt: _now,
          updatedAt: _now,
          listening: true,
          lastFiredAt: _now.subtract(const Duration(hours: 1))),
      TriggerEntity(
          id: 'tr_paused',
          name: '每晚归档',
          kind: TriggerSource.cron,
          config: const {'cron': '0 1 * * *'},
          createdAt: _now,
          updatedAt: _now,
          paused: true,
          lastFiredAt: _now.subtract(const Duration(days: 4))),
    ],
    edges: const [
      EntityRelation(
          id: 'rel_1',
          kind: 'equip',
          fromKind: 'workflow',
          fromId: 'wf_a',
          fromName: '数据清洗流水线',
          toKind: 'trigger',
          toId: 'tr_cron',
          toName: '每日 09:00'),
      EntityRelation(
          id: 'rel_hook',
          kind: 'equip',
          fromKind: 'workflow',
          fromId: 'wf_a',
          fromName: '数据清洗流水线',
          toKind: 'trigger',
          toId: 'tr_hook',
          toName: '发票回调'),
      EntityRelation(
          id: 'rel_2',
          kind: 'equip',
          fromKind: 'workflow',
          fromId: 'wf_a',
          fromName: '数据清洗流水线',
          toKind: 'trigger',
          toId: 'tr_paused',
          toName: '每晚归档'),
    ],
    inbox: [stubInboxRow('fr_live1', 'approve_send', wfId: 'wf_a', now: _now)],
    runs: runs,
    nodesByRun: {
      'fr_live1': _nodes('fr_live1'),
      'fr_fail1': _nodes('fr_fail1', failed: true),
      'fr_fail2': _nodes('fr_fail2', failed: true),
    },
    graphByWorkflow: {'wf_a': _graph},
    failRunFull: failRunFull,
  );
}

Widget _host(StubSchedulerRepo repo, {String? runId}) => ProviderScope(
      overrides: [
        sseGatewayProvider.overrideWithValue(null),
        schedulerRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: Builder(builder: (context) {
          final navKey = GlobalKey<NavigatorState>();
          return MaterialApp(
            theme: AnTheme.light(),
            navigatorKey: navKey,
            builder: (context, child) => AnOverlayHost(navigatorKey: navKey, child: child!),
            home: Scaffold(
                body: SchedulerHomeView(workflowId: 'wf_a', linkedRunId: runId)),
          );
        }),
      ),
    );

Future<void> _pump(WidgetTester tester, StubSchedulerRepo repo, {String? runId}) async {
  await tester.pumpWidget(_host(repo, runId: runId));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

/// Hover [target]. [reveal] (default [target]) is what gets scrolled into view first: a row's ERROR
/// SUB-LINE is the natural hover handle but it is the row's BOTTOM line, so scrolling *it* to the
/// viewport's top edge pushes the row's own hover action (vertically centred, i.e. higher) off-screen
/// — the action is then found but un-hittable. Reveal the ROW, hover the line.
/// 悬停 target;reveal(默认同 target)是先被滚入视口的那个:行的**错误副行**是天然的悬停把手,但它是行的
/// **底**行——把**它**滚到视口顶缘会把该行自己的悬停动作(垂直居中、即更高)顶出屏幕,动作于是「找得到却
/// 点不中」。故:滚**行**、悬停**行内那一句**。
Future<TestGesture> _hover(WidgetTester tester, Finder target, {Finder? reveal}) async {
  await tester.ensureVisible(reveal ?? target);
  await tester.pump();
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  await tester.pump();
  await g.moveTo(tester.getCenter(target));
  await tester.pump();
  return g;
}

Finder _rowCheck(String primary) => find.descendant(
    of: find.ancestor(of: find.text(primary), matching: find.byType(AnLedgerRow)),
    matching: find.byType(AnBatchCheck));

/// A control inside the trigger card whose name is [name] — three cards share the same button
/// labels, so every tap must name its card. 按卡定位控件(三卡共享同款按钮标签)。
Finder _inCard(String name, String label) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(AnCard)),
    matching: find.text(label));

Future<void> _settle(WidgetTester tester) async {
  for (final ms in [300, 200, 200, 100]) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  final h = t.scheduler.home;

  group('① 健康头', () {
    testWidgets('the documentary head: crumb + big title + range-scoped stats sentence + capsule '
        '+ Run now — and NO bead strip (需求②③ 0717-晚)', (tester) async {
      await _pump(tester, _repo());
      expect(find.byType(AnOceanHeader), findsOneWidget, reason: '文档化页头(entities 同文法)');
      expect(find.text('数据清洗流水线'), findsOneWidget);
      expect(find.text(t.scheduler.status.active), findsOneWidget);
      expect(find.byType(RunBeadStrip), findsNothing, reason: '珠串已删——矩阵列头就是同一排珠子');
      // The sentence's window word IS the capsule's word (需求②:成功率跟随选择器,默认近 7 天).
      // 句子窗口词=胶囊之词。
      expect(find.text(h.statsLine(rate: '80%', avg: '42.0s')),
          findsOneWidget);
      expect(find.byType(AnTimeRangePicker), findsOneWidget, reason: '胶囊坐在页头 meta 行');
      expect(find.text(h.runNow), findsOneWidget);
    });

    testWidgets('null stats read «—», NEVER 0% (缺席≠零)', (tester) async {
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '安静', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
      );
      await _pump(tester, repo);
      expect(find.text(h.statsLine(rate: '—', avg: '—')),
          findsOneWidget);
      expect(find.textContaining('0%'), findsNothing);
    });

    testWidgets('the stats sentence FOLLOWS the capsule: picking 24h re-asks stats with since=24h '
        '(需求②:一颗胶囊、句子同窗)', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      repo.statsWindows.clear();
      await tester.tap(find.byType(AnTimeRangePicker));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(t.scheduler.range.h24).last);
      await tester.pump();
      await _settle(tester);
      expect(repo.statsWindows.any((w) => w.since == '24h' && w.until == null), isTrue,
          reason: '句子的统计真按新窗重取(预设走时长文法)');
      expect(find.textContaining(t.scheduler.range.h24), findsWidgets,
          reason: '窗口词换成 24h——句囊永不打架');
    });

    testWidgets('an ABSOLUTE range sends `until` on the stats wire — the app\'s ONE non-null-until '
        'emitter reaches the repo (需求②/后端 089060f2 的整个前端理由)', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      repo.statsWindows.clear();
      final container =
          ProviderScope.containerOf(tester.element(find.byType(AnOceanHeader)));
      final from = DateTime(2026, 7, 1, 9, 0);
      final to = DateTime(2026, 7, 2, 18, 30);
      container
          .read(schedulerTimeRangeProvider.notifier)
          .set(AnAbsoluteRange(from: from, to: to));
      await tester.pump();
      await _settle(tester);
      expect(
          repo.statsWindows.any((w) =>
              w.since == from.toUtc().toIso8601String() &&
              w.until == to.add(const Duration(minutes: 1)).toUtc().toIso8601String()),
          isTrue,
          reason: '绝对对上线缆:since/until 皆 RFC3339,until=闭分钟端后推一分钟');
    });

    testWidgets('a range switch renders «—» while the new window\'s numbers are IN FLIGHT — the '
        'sentence never pairs the new word with the old range\'s numbers (范围章,复审 0717-晚)',
        (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      expect(find.text(h.statsLine(rate: '80%', avg: '42.0s')),
          findsOneWidget);
      repo.statsLatency = const Duration(milliseconds: 300);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(AnOceanHeader)));
      container
          .read(schedulerTimeRangeProvider.notifier)
          .set(const AnPresetRange(AnTimePreset.h24));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // In flight: the NEW word with honest dashes — never the old 7d numbers under a 24h label.
      // 在飞:新窗口词配诚实「—」——绝不让 24h 的帽子戴在 7d 的数字上。
      expect(find.text(h.statsLine(rate: '—', avg: '—')),
          findsOneWidget, reason: '范围章不符=只render词不render数');
      expect(find.text(h.statsLine(rate: '80%', avg: '42.0s')),
          findsNothing, reason: '新词配旧数=句子撒谎');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      expect(find.text(h.statsLine(rate: '80%', avg: '42.0s')),
          findsOneWidget, reason: '新窗数字落地,句子完整');
    });

    testWidgets('Run now hits :trigger and reports the new run', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.tap(find.text(h.runNow));
      await tester.pump();
      await _settle(tester);
      expect(repo.runNowOrder, ['wf_a']);
      expect(find.textContaining(h.runNowStarted(id: 'fr_new0000000…').split('·').first.trim()),
          findsWidgets);
    });

    testWidgets(':kill lives behind ⋯ + AnTypeToConfirm with the REAL blast radius', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      expect(find.byType(AnTypeToConfirm), findsNothing, reason: '危险区默认不在场');

      await tester.tap(find.byIcon(AnIcons.more));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(h.menuKill));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AnTypeToConfirm), findsOneWidget);
      expect(find.text(h.killWarning(n: '1')), findsOneWidget, reason: '影响面=真在途 run 数');

      // The gate holds until the exact name is typed. 输对名前闸不开。
      await tester.enterText(find.descendant(
          of: find.byType(AnTypeToConfirm), matching: find.byType(AnInput)), '错的名');
      await tester.pump();
      await tester.tap(find.text(h.killConfirm));
      await tester.pump();
      expect(repo.killOrder, isEmpty, reason: '名字不对,绝不执行');

      await tester.enterText(find.descendant(
          of: find.byType(AnTypeToConfirm), matching: find.byType(AnInput)), '数据清洗流水线');
      await tester.pump();
      await tester.tap(find.text(h.killConfirm));
      await tester.pump();
      await _settle(tester);
      expect(repo.killOrder, ['wf_a']);
    });
  });

  group('② run 大表', () {
    testWidgets('rows speak «source · start instant»; NO bare id anywhere in a row (需求⑤⑦)',
        (tester) async {
      await _pump(tester, _repo());
      // Every origin now carries its start instant (the one phrase grammar). 每来源都带开始时刻。
      final cronAt = _now.subtract(const Duration(minutes: 3)).toLocal();
      final hhmm =
          '${cronAt.hour.toString().padLeft(2, '0')}:${cronAt.minute.toString().padLeft(2, '0')}';
      expect(find.text('${h.srcCronBare} · $hhmm'), findsOneWidget);
      expect(
          find.textContaining(h.srcWithName(kind: h.srcWebhookBare, name: '/invoice')),
          findsOneWidget,
          reason: 'webhook 摘要=path(config 胜过名),后接时刻');
      expect(find.textContaining(h.srcChat), findsWidgets);
      // The fr_ id is GONE from rows (需求⑤:人看不懂 id) — it lives in the peek card + tooltips.
      // 行内无裸 id——完整 id 收进速览卡与 tooltip。
      expect(find.textContaining('fr_live1'), findsNothing,
          reason: '行内不再渲 run id 药丸——身份=来源短语+时刻');
    });

    testWidgets('failed rows carry the error FIRST LINE in the danger sub', (tester) async {
      await _pump(tester, _repo());
      expect(find.text('HTTP 502 Bad Gateway: upstream did not respond'), findsOneWidget);
      expect(find.textContaining('retried 3 times'), findsNothing, reason: '只取首句');
    });

    testWidgets('the count strip carries TRUE numbers and each click IS the wire filter',
        (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      expect(find.text(h.filterRunning(n: '1')), findsOneWidget, reason: '在跑数来自 stats');
      expect(find.text(h.filterFailed(n: '2')), findsOneWidget, reason: '失败数来自同文法探针');
      expect(find.text(h.filterWaiting(n: '1')), findsOneWidget, reason: '等人数来自 inbox 派生');

      repo.listFilters.clear();
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);
      expect(repo.listFilters.any((f) => f.status == 'failed'), isTrue);
      expect(find.textContaining(h.srcChat), findsNothing, reason: '过滤后 completed 行退场');
    });

    testWidgets('«等人» intersects the inbox and NEVER sends ?status=parked', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      repo.listFilters.clear();
      await tester.tap(find.text(h.filterWaiting(n: '1')));
      await tester.pump();
      await _settle(tester);
      expect(repo.listFilters.every((f) => f.status != 'parked'), isTrue,
          reason: 'parked 不在 run 状态封闭集,发上去就是 422');
      expect(repo.listFilters.any((f) => f.status == 'running'), isTrue);
    });

    testWidgets('«等人» filter is UNPAGED: the pager never renders even with >10 matches '
        '(复审 [1]/[5] 死钮修)', (tester) async {
      // 12 running runs each parked on an approval → 12 waiting rows (running∩inbox). 12 等人行。
      final runs = [
        for (var i = 0; i < 12; i++)
          Flowrun(
              id: 'fr_wait${i.toString().padLeft(2, '0')}',
              workflowId: 'wf_a',
              origin: 'cron',
              status: 'running',
              startedAt: _now.subtract(Duration(minutes: i + 1)),
              updatedAt: _now),
      ];
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '多等', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', running: 12, lastRunAt: _now)],
        runs: runs,
        inbox: [
          for (var i = 0; i < 12; i++)
            stubInboxRow('fr_wait${i.toString().padLeft(2, '0')}', 'gate', now: _now),
        ],
      );
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterWaiting(n: '12')));
      await tester.pump();
      await _settle(tester);
      expect(find.byType(AnLedgerRow), findsNWidgets(12), reason: '等人全展(不分页)');
      expect(find.byType(AnPager), findsNothing,
          reason: '等人不分页:全在一屏,翻页器不渲免死钮(复审 [1]/[5])');
    });

    testWidgets('the page-level time-range capsule governs the TABLE too (0717 拍板:一颗胶囊治两区)',
        (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      repo.listFilters.clear();
      repo.matrixAsks.clear();
      // Open the capsule (default «Last 7 days») and pick the 24h preset — click applies instantly.
      // 打开胶囊(默认近 7 天)点 24h 预设——点即生效。
      final r = t.scheduler.range;
      await tester.ensureVisible(find.byType(AnTimeRangePicker));
      await tester.pump();
      await tester.tap(find.byType(AnTimeRangePicker));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(r.h24).last);
      await tester.pump();
      await _settle(tester);
      final asked = repo.listFilters.where((f) => f.startedAfter != null).toList();
      expect(asked, isNotEmpty, reason: '表随胶囊重取');
      final span = DateTime.now().difference(asked.last.startedAfter!);
      expect(span.inHours, closeTo(24, 1));
      expect(repo.matrixAsks, isNotEmpty, reason: '矩阵窗同随胶囊重建——一颗镜头两个区');
    });

    testWidgets('a stale in-flight page fetch NEVER clobbers a newer filter pick (复审 [2] 请求代号)',
        (tester) async {
      final runs = [
        for (var i = 0; i < 24; i++)
          Flowrun(
              id: 'fr_g${i.toString().padLeft(2, '0')}',
              workflowId: 'wf_a',
              origin: 'cron',
              status: i < 3 ? 'failed' : 'completed',
              error: i < 3 ? 'boom' : null,
              startedAt: _now.subtract(Duration(minutes: i + 1)),
              completedAt: _now.subtract(Duration(minutes: i + 1)),
              updatedAt: _now),
      ];
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '竞态', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
        runs: runs,
      );
      await _pump(tester, repo);
      final ctrl = ProviderScope.containerOf(tester.element(find.byType(AnPager)))
          .read(schedulerRunTableProvider('wf_a').notifier);

      // Now gate every page fetch so we can resolve them OUT OF ORDER. 从此闸住每次取数,乱序放行。
      repo.gatePages = true;
      unawaited(ctrl.setPage(3)); // stale request A (all·page3) 过时请求 A
      await tester.pump();
      unawaited(ctrl.refetchTop(filter: RunStatusFilter.failed)); // newer request B (failed·page1) 更新请求 B
      await tester.pump();
      expect(repo.pageGates.length, 2, reason: '两次取数都停在闸上');

      // Resolve B (newer) FIRST, then A (stale). B 先放行、A 后放行。
      repo.pageGates[1].complete();
      await _settle(tester);
      repo.pageGates[0].complete();
      await _settle(tester);

      // The stale A must NOT have overwritten B: filter stays failed, page stays 1. 过时 A 绝不覆盖 B。
      final s = ProviderScope.containerOf(tester.element(find.byType(SchedulerHomeView)))
          .read(schedulerRunTableProvider('wf_a'))
          .value!;
      expect(s.filter, RunStatusFilter.failed, reason: '更新的失败过滤存活');
      expect(s.page, 1, reason: '页码是 B 的 1,不是 A 的 3');
    });

    testWidgets('the origin dropdown really reaches the wire', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      repo.listFilters.clear();
      await tester.tap(find.text(h.originAll));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(h.originChat).last);
      await tester.pump();
      await _settle(tester);
      expect(repo.listFilters.any((f) => f.origin == 'chat'), isTrue);
    });

    testWidgets('page-number pager: 10/page, ‹/›/number/jump navigate, single page hides '
        '(WRK-070 B4)', (tester) async {
      final runs = [
        for (var i = 0; i < 24; i++)
          Flowrun(
              id: 'fr_h${i.toString().padLeft(3, '0')}',
              workflowId: 'wf_a',
              origin: 'cron',
              status: 'completed',
              startedAt: _now.subtract(Duration(hours: i + 1)),
              completedAt: _now.subtract(Duration(hours: i + 1)),
              updatedAt: _now),
      ];
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '多页', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
        runs: runs,
      );
      await _pump(tester, repo);
      // 24 runs / 10 per page → 3 pages, page 1 shows 10 rows. 24/10=3 页,首页 10 行。
      expect(find.byType(AnLedgerRow), findsNWidgets(10));
      expect(find.byType(AnPager), findsOneWidget, reason: '多页出翻页器');
      expect(repo.pageAsks.last, (offset: 0, limit: 10, status: null, origin: null));

      // The pager never self-margins: AnSection's 12 IS the gap above it (0718 对齐审计 — the old
      // Padding(top) doubled it to 24 while rows sit 12 apart). 翻页器不自夹:行→翻页器=12。
      final lastRow = tester.getRect(find.byType(AnLedgerRow).last);
      final pagerRect = tester.getRect(find.byType(AnPager));
      expect(pagerRect.top - lastRow.bottom, moreOrLessEquals(12, epsilon: 0.6),
          reason: '行→翻页器 12(无自夹双倍)');

      // Jump to page 3 (the last, 4 rows). 跳到第 3 页(末页 4 行)。
      await tester.ensureVisible(find.byType(AnPager));
      await tester.tap(find.descendant(of: find.byType(AnPager), matching: find.text('3')));
      await tester.pump();
      await _settle(tester);
      expect(find.byType(AnLedgerRow), findsNWidgets(4), reason: '第 3 页 4 行');
      expect(repo.pageAsks.last, (offset: 20, limit: 10, status: null, origin: null),
          reason: 'offset=(3-1)*10 上线缆');

      // Filtering to a single page hides the pager entirely. 过滤到单页则翻页器整消失。
      await tester.tap(find.text(h.filterFailed(n: '0')));
      await tester.pump();
      await _settle(tester);
      expect(find.byType(AnPager), findsNothing, reason: '单页不渲');
    });

    testWidgets('zone seams stack FLUSH — each AnSection carries its own 24 bottom, no doubled '
        'wrapper (0718 全模块对齐审计:段缝曾 48)', (tester) async {
      await _pump(tester, _repo());
      Rect zoneOf(String label) => tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(AnSection)).first);
      final matrix = zoneOf(h.matrixView);
      final runs = zoneOf(h.runsHead);
      final trig = zoneOf(h.triggersHead);
      expect(runs.top - matrix.bottom, moreOrLessEquals(0, epsilon: 0.6),
          reason: '矩阵→运行贴合(24 在段自身底距,外无 top 垫)');
      expect(trig.top - runs.bottom, moreOrLessEquals(0, epsilon: 0.6), reason: '运行→触发器贴合');
    });

    testWidgets('the verb is PERSISTENT, inline after the phrase — no hover needed (需求⑦)',
        (tester) async {
      await _pump(tester, _repo());
      // No pointer anywhere: running rows already wear ⏹ Stop, failed rows ↻ Retry. 零悬停即见。
      expect(find.text(h.rowCancel), findsOneWidget, reason: '在跑行常驻 ⏹ 终止(种子恰一条在跑)');
      expect(find.text(h.rowRetry), findsNWidgets(2), reason: '两条失败行常驻 ↻ 重试');
      // The verb sits INSIDE the row (right after the phrase), not in a far-edge reserved cell.
      // 动词在行内紧随短语,不在行尾预留格。
      expect(
          find.descendant(of: find.byType(AnLedgerRow), matching: find.text(h.rowCancel)),
          findsOneWidget);
    });

    testWidgets('single replay: the confirm carries the REAL memoization numbers', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);

      // The verb is persistent and lives IN the row — address THAT row's Retry by ancestry off its
      // error line (需求⑦:常驻内联,无需悬停;寻址走行自己的错误副行,绝不「页面上第一个 Retry」).
      // 动词常驻行内——按该行错误副行做祖先寻址,绝不拿页序第一个。
      final failRow = find.ancestor(
          of: find.text('HTTP 502 Bad Gateway: upstream did not respond'),
          matching: find.byType(AnLedgerRow));
      await tester.ensureVisible(failRow.first);
      await tester.pump();
      await tester.tap(
          find.descendant(of: failRow, matching: find.text(h.rowRetry)).first,
          warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // fr_fail1 nodes: 1 completed + 1 failed. 真数字。
      expect(find.text(h.replayBody(failed: '1', completed: '1')), findsOneWidget);

      await tester.tap(find.text(h.replayAction));
      await tester.pump();
      await _settle(tester);
      expect(repo.replayOrder, ['fr_fail1']);
    });

    testWidgets('replay when the node history is unavailable → the numberless honest sentence',
        (tester) async {
      final repo = _repo(failRunFull: true);
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);

      final failRow = find.ancestor(
          of: find.text('HTTP 502 Bad Gateway: upstream did not respond'),
          matching: find.byType(AnLedgerRow));
      await tester.ensureVisible(failRow.first);
      await tester.pump();
      await tester.tap(
          find.descendant(of: failRow, matching: find.text(h.rowRetry)).first,
          warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(h.replayBodyUnknown), findsOneWidget, reason: '取不到数字也不假造');
    });

    testWidgets('batch replay: ≥2 selected → merged real numbers → SEQUENTIAL dispatch',
        (tester) async {
      final repo = _repo();
      repo.replayLatency = const Duration(milliseconds: 100);
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);

      final g = await _hover(tester, find.text('HTTP 502 Bad Gateway: upstream did not respond'),
          reveal: find.ancestor(
              of: find.text('HTTP 502 Bad Gateway: upstream did not respond'),
              matching: find.byType(AnLedgerRow)));
      await tester.tap(_rowCheck('HTTP 502 Bad Gateway: upstream did not respond'));
      await tester.pump();
      expect(find.byType(AnBatchBar), findsNothing, reason: '选中 1 不出条');
      await tester.tap(_rowCheck('timeout: LLM 30s no answer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnBatchBar), findsOneWidget);

      await tester.ensureVisible(find.text(h.batchReplay));
      await tester.tap(find.text(h.batchReplay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Two runs × (1 failed + 1 completed) = merged 2 / 2. 合并真数字。
      expect(find.text(h.batchReplayBody(failed: '2', completed: '2')), findsOneWidget);

      await tester.tap(find.text(h.replayAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(repo.replayOrder.length, lessThan(2), reason: '逐发:第二个尚未发出');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      await _settle(tester);
      expect(repo.replayOrder, ['fr_fail1', 'fr_fail2'], reason: '按行序逐发');
      expect(find.text(h.sumReplayed(n: '2')), findsOneWidget);
      await g.removePointer();
    });

    testWidgets('batch cancel lives in the RUNNING face and lists its victims', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);
      expect(find.text(t.scheduler.overview.batchCancel), findsNothing,
          reason: '失败态没有取消语义');
    });
  });

  group('③ 新 run 不插行(活性军规)', () {
    // The three fold rules are PURE state — a plain test() (a ProviderContainer inside
    // testWidgets' fake_async trips riverpod's dispose-scheduler timer). 三条折叠规则是纯状态,
    // 走 plain test(容器在 testWidgets 的 fake_async 里会绊住 riverpod dispose 定时器)。
    ({ProviderContainer container, SchedulerRunTableController ctl}) live(StubSchedulerRepo repo) {
      final container = ProviderContainer(overrides: [
        sseGatewayProvider.overrideWithValue(null),
        schedulerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      return (container: container, ctl: container.read(schedulerRunTableProvider('wf_a').notifier));
    }

    StreamEnvelope frame({required int seq, String wf = 'wf_a', String type = 'run_started'}) =>
        StreamEnvelope(
          seq: seq,
          scope: StreamScope(kind: 'workflow', id: wf),
          id: 'n1',
          // The frame the backend really sends (工单①:durable signal, workflow scope). 真帧形。
          frame: FrameSignal(
              node: StreamNode(type: type, content: const {'flowrunId': 'fr_new', 'origin': 'cron'})),
        );

    test('a durable run_started bumps the PILL — never a row', () async {
      final (:container, :ctl) = live(_repo());
      await container.read(schedulerRunTableProvider('wf_a').future);
      final before = container.read(schedulerRunTableProvider('wf_a')).value!.rows.length;

      ctl.onFrameForTest(frame(seq: 7));
      final s = container.read(schedulerRunTableProvider('wf_a')).value!;
      expect(s.newRuns, 1, reason: 'pill +1');
      expect(s.rows.length, before, reason: '几何不动:绝不插行');
    });

    test('an ephemeral tick (seq=0) never touches the table', () async {
      final (:container, :ctl) = live(_repo());
      await container.read(schedulerRunTableProvider('wf_a').future);
      ctl.onFrameForTest(frame(seq: 0));
      expect(container.read(schedulerRunTableProvider('wf_a')).value!.newRuns, 0,
          reason: 'tick 永不达(活性军规)');
    });

    test("another workflow's ledger is not ours", () async {
      final (:container, :ctl) = live(_repo());
      await container.read(schedulerRunTableProvider('wf_a').future);
      ctl.onFrameForTest(frame(seq: 9, wf: 'wf_other'));
      expect(container.read(schedulerRunTableProvider('wf_a')).value!.newRuns, 0);
    });

    testWidgets('the pill renders its count and the tap pulls the new runs in', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      expect(find.text(h.newRuns(n: '2')), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.byType(SchedulerHomeView)));
      final ctl = container.read(schedulerRunTableProvider('wf_a').notifier);
      for (var i = 0; i < 2; i++) {
        ctl.onFrameForTest(StreamEnvelope(
          seq: 7 + i,
          scope: const StreamScope(kind: 'workflow', id: 'wf_a'),
          id: 'n$i',
          frame: FrameSignal(node: StreamNode(type: 'run_started', content: {'flowrunId': 'fr_n$i'})),
        ));
      }
      await tester.pump();
      expect(find.text(h.newRuns(n: '2')), findsOneWidget);

      await tester.tap(find.text(h.newRuns(n: '2')));
      await tester.pump();
      await _settle(tester);
      expect(find.text(h.newRuns(n: '2')), findsNothing, reason: '归位后 pill 清零');
    });
  });

  group('④ 行内速览卡 (0717 拍板:?run= 即展开行)', () {
    testWidgets('the card is an ordinary 720 section — no face may widen the page (用户 0717 判决)',
        (tester) async {
      await _pump(tester, _repo(), runId: 'fr_fail1');
      final reading = AnSize.content - AnInset.pageX * 2;

      Future<void> expectWithinColumn(Finder face, String who) async {
        expect(face, findsOneWidget, reason: '$who 在场');
        expect(tester.getSize(face).width, lessThanOrEqualTo(reading + 0.5),
            reason: '$who 不得破 720 阅读列——宽度归它自己解决(甘特分数轨缩放 / 图 InteractiveViewer)');
        expect(tester.takeException(), isNull, reason: '$who 在 720 内不溢出');
      }

      // ① gantt (the default face) — a [0,1] fraction track, so it just rescales. 甘特=分数轨,直接缩放。
      await expectWithinColumn(find.byType(AnNodeGantt), '甘特');

      Future<void> switchTo(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // ② graph — pans/zooms inside its own InteractiveViewer. 图=在自己的 InteractiveViewer 里平移缩放。
      await switchTo(h.faceGraph);
      await expectWithinColumn(find.byType(AnGraphCanvas), '图');
    });

    testWidgets('collapsed without ?run=; expanded IN PLACE with it (gantt default, graph on '
        'toggle, the flagship door on board)', (tester) async {
      await _pump(tester, _repo());
      expect(find.byType(AnNodeGantt), findsNothing, reason: '无 ?run= 即无展开行——收起的行绝不建卡(C-006)');

      await _pump(tester, _repo(), runId: 'fr_fail1');
      // The card grows UNDER its own row (inside the ledger row's disclosure lane), not somewhere
      // below the fold. 卡长在自己那一行底下(台账行披露车道内),不在折线下某处。
      final row = find.ancestor(of: find.byType(AnNodeGantt), matching: find.byType(AnLedgerRow));
      expect(row, findsOneWidget, reason: '速览卡住在展开行的披露体里');
      expect(find.text(h.openRun), findsOneWidget, reason: '旗舰门在卡上');
      expect(find.byType(AnGraphCanvas), findsNothing);

      await tester.ensureVisible(find.text(h.faceGraph));
      await tester.pump();
      await tester.tap(find.text(h.faceGraph));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnGraphCanvas), findsOneWidget, reason: '切图脸');
      expect(find.byType(AnNodeGantt), findsNothing);
    });

    testWidgets('a row tap TOGGLES ?run= in the URL — expand, and tap again to collapse',
        (tester) async {
      final repo = _repo();
      final routed = <String>[];
      // A LIVE route (the home rebuilds with each navigation's ?run=) so both toggle branches are
      // exercised for real — a dead-end capture route can only ever see the first tap (复审 [9]).
      // 活路由(每次导航后主页按新 ?run= 重建),两个开合分支都真跑——死胡同捕获路由只见得到第一击。
      final router = GoRouter(initialLocation: '/scheduler/w/wf_a?run=fr_fail1', routes: [
        GoRoute(
            path: '/scheduler/w/:id',
            builder: (_, st) {
              routed.add(st.uri.toString());
              return Scaffold(
                  body: SchedulerHomeView(
                      workflowId: 'wf_a', linkedRunId: st.uri.queryParameters['run']));
            }),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sseGatewayProvider.overrideWithValue(null),
          schedulerRepositoryProvider.overrideWithValue(repo),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(theme: AnTheme.light(), routerConfig: router),
        ),
      ));
      await tester.pump();
      await _settle(tester);

      Future<void> tapChatRow() async {
        await tester.ensureVisible(find.textContaining(h.srcChat).first);
        await tester.pump();
        await tester.tap(find.textContaining(h.srcChat).first, warnIfMissed: false);
        // The double-tap window is judged on REAL wall time (DateTime.now() in _onRowTap), which
        // fake pumps do not advance — sleep real 350ms or two quick test taps read as a double.
        // 双击窗按真墙钟判(假 pump 不走真钟)——真睡 350ms,否则连点被判双击直进旗舰。
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 350)));
        await _settle(tester);
      }

      // Tap a DIFFERENT row than the expanded one → the URL carries its id (expand). 点另一行=展开。
      await tapChatRow();
      expect(routed, isNotEmpty, reason: '行点击必须走 URL——选区单向派生自 URL');
      expect(routed.last, contains('run=fr_chat1'), reason: '点行=展开该行(URL 真相)');

      // Tap the SAME (now expanded) row → the URL drops ?run= (collapse). 同行再点=收起去参。
      await tapChatRow();
      expect(routed.last.contains('run='), isFalse,
          reason: '再点已展开行=URL 去 ?run=——开合是同一只手,不是两套手势');
    });

    testWidgets('no active-version graph → the honest sentence, never an empty frame',
        (tester) async {
      final repo = _repo();
      final noGraph = StubSchedulerRepo(
        workflows: repo.workflows,
        byWorkflow: repo.byWorkflow,
        runs: repo.runs,
        nodesByRun: repo.nodesByRun,
        // graphByWorkflow deliberately empty. 刻意无图。
      );
      await _pump(tester, noGraph, runId: 'fr_fail1');
      await tester.ensureVisible(find.text(h.faceGraph));
      await tester.pump();
      await tester.tap(find.text(h.faceGraph));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(h.noGraph), findsOneWidget);
    });
  });

  group('⑤ triggers 陈列', () {
    testWidgets('cron mono + schedule sentence + the paused card wears its chip', (tester) async {
      await _pump(tester, _repo());
      expect(find.text('每日 09:00'), findsOneWidget);
      expect(find.text('0 9 * * *'), findsOneWidget, reason: 'cron 表达式 mono 在场');
      expect(find.text(h.paused), findsOneWidget, reason: '暂停卡带「已暂停」徽');
      // The «Editing belongs to Entities ↗» hint is GONE (B3) and cards flow as a grid (B9).
      expect(find.textContaining('Entities'), findsNothing, reason: '编辑归属提示已删(B3)');
      expect(find.byType(AnAutoGrid), findsOneWidget, reason: 'trigger 卡双列网格(B9)');
    });

    testWidgets('pause: the dialog states the exact semantics, then the switch flips', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.ensureVisible(_inCard('每日 09:00', h.pause));
      await tester.tap(_inCard('每日 09:00', h.pause));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(h.pauseTitle(name: '每日 09:00')), findsOneWidget);
      expect(find.text(h.pauseBody), findsOneWidget, reason: '「不再产生新 firing,在途 run 不受影响」');

      await tester.tap(find.text(h.pauseAction).last);
      await tester.pump();
      await _settle(tester);
      expect(repo.pauseOrder, ['tr_cron:pause']);
      expect(find.text(h.paused), findsNWidgets(2), reason: '暂停后两卡皆带徽');
    });

    testWidgets('dismissing the pause dialog flips nothing', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.ensureVisible(_inCard('每日 09:00', h.pause));
      await tester.tap(_inCard('每日 09:00', h.pause));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(t.action.cancel).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.pauseOrder, isEmpty);
    });

    testWidgets('resume is idempotent + dialog-free (harmless) and un-greys the card',
        (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.ensureVisible(_inCard('每晚归档', h.resume));
      await tester.tap(_inCard('每晚归档', h.resume));
      await tester.pump();
      await _settle(tester);
      expect(repo.pauseOrder, ['tr_paused:resume'], reason: '恢复无害幂等,不弹确认');
      expect(find.text(h.paused), findsNothing);
    });
  });

  group('⑥ 边角', () {
    testWidgets('a deleted / unknown workflow deep link is an honest not-found', (tester) async {
      final repo = StubSchedulerRepo(workflows: [
        SchedulerWorkflowRow(id: 'wf_other', name: '别的', lifecycleState: 'active', updatedAt: _now),
      ]);
      await _pump(tester, repo);
      expect(find.text(h.notFoundTitle), findsOneWidget);
    });
  });

  // ── 页顶矩阵区(0717 拍板:常驻+时序+导航点击) + 保留墓碑(判决④/工单⑬) ──
  group('⑤ 页顶矩阵区', () {
    FlowrunMatrix grid() => FlowrunMatrix(
          cols: [
            // Wire canonical: newest first; the live one carries NO elapsed. 线缆正典新→旧;在跑无 elapsed。
            MatrixCol(flowrunId: 'fr_live1', startedAt: _now, status: 'running'),
            MatrixCol(
                flowrunId: 'fr_fail1',
                startedAt: _now.subtract(const Duration(hours: 1)),
                status: 'failed',
                elapsedMs: 8000),
          ],
          rows: const [
            MatrixRow(nodeId: 'fetch', kind: 'action'),
            MatrixRow(nodeId: 'analyze', kind: 'agent'),
          ],
          // SPARSE: fr_live1 never reached analyze → no cell. 稀疏:fr_live1 没跑到 analyze。
          cells: const [
            MatrixCell(flowrunId: 'fr_live1', nodeId: 'fetch', status: 'completed'),
            MatrixCell(flowrunId: 'fr_fail1', nodeId: 'fetch', status: 'completed'),
            MatrixCell(flowrunId: 'fr_fail1', nodeId: 'analyze', status: 'failed', iterations: 3),
          ],
        );

    testWidgets('the matrix is RESIDENT: opening the page pages the runs and batch-fetches the grid '
        'by EXPLICIT ids (惰性律反转,0717 拍板)', (tester) async {
      final repo = _repo()..matrixGrid = grid();
      await _pump(tester, repo);
      expect(repo.matrixAsks, isNotEmpty, reason: '矩阵常驻页顶——开页即取,不再等谁点脸');
      // The batch is the ids of the window page — the flowrunIds wire law. 批=窗页的 id 集。
      expect(repo.matrixAsks.first, containsAll(['fr_live1', 'fr_fail1']),
          reason: '按显式 flowrunIds 批查,不再有 recentN');
      expect(find.byType(AnRunMatrix), findsOneWidget);
    });

    testWidgets('the grid renders: ×N in the cell, «未及» for a sparse one, CHRONOLOGICAL display '
        '(旧在左)', (tester) async {
      final repo = _repo()..matrixGrid = grid();
      await _pump(tester, repo);

      expect(find.byType(AnRunMatrix), findsOneWidget);
      // The «Matrix View» section title (WRK-070 B3 方案 A) — a titleless grid read as「给标题留位」;
      // the old NODE × RUN title stays gone. 段题=矩阵视图;旧 NODE × RUN 仍删。
      expect(find.text(h.matrixView), findsOneWidget, reason: '段题=矩阵视图(B3 方案 A)');
      expect(find.text(h.matrixTitle.toUpperCase()), findsNothing,
          reason: '旧 NODE × RUN 段标题仍删(需求②)');
      expect(find.text('3'), findsOneWidget, reason: 'iterations=3 → ×N 在格里');
      expect(find.byTooltip(h.matrixNotReached), findsOneWidget,
          reason: '稀疏格说「未及」——空格是真答案,不是缺答案');
      // Display order is CHRONOLOGICAL: the older fr_fail1 column sits LEFT of fr_live1 (wire is
      // newest-first; the zone reverses for the timeline). 呈现时序:旧列在左。
      final grid_ = find.byType(AnRunMatrix);
      // Column semantics speak the SOURCE PHRASE now (需求⑤) — address the two cols by their
      // distinguishing words (running vs failed). 列语义念来源短语——按状态词寻址两列。
      final older = tester.getTopLeft(find
          .descendant(of: grid_, matching: find.bySemanticsLabel(RegExp('failed')))
          .first);
      final newer = tester.getTopLeft(find
          .descendant(of: grid_, matching: find.bySemanticsLabel(RegExp('running|在跑|Running')))
          .first);
      expect(older.dx, lessThan(newer.dx), reason: '时间轴:旧在左、新在右(锚最新端)');
    });

    testWidgets('the grid takes its width from ITSELF, never from the page (用户 0717 判决)',
        (tester) async {
      final repo = _repo()..matrixGrid = grid();
      await _pump(tester, repo);

      expect(tester.getSize(find.byType(AnRunMatrix)).width,
          lessThanOrEqualTo(AnSize.content - AnInset.pageX * 2 + 0.5),
          reason: '矩阵不得破 720 阅读列——宽度归它自己解决');
      final sv = tester.widget<SingleChildScrollView>(find.descendant(
          of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView)));
      expect(sv.scrollDirection, Axis.horizontal, reason: '矩阵的宽在它自己肚子里滚');
      expect(sv.reverse, isTrue, reason: '锚最新端(offset 0=最新缘)');
      expect(tester.takeException(), isNull, reason: '720 内不溢出');
    });

    testWidgets('an empty window says so; a failed read offers retry — neither blanks the zone',
        (tester) async {
      // The default stub grid is EMPTY → the zone answers with the honest sentence, never a bare
      // frame. 默认剧本格阵空 → 空窗句,绝不空框。
      await _pump(tester, _repo());
      expect(find.text(h.matrixEmpty), findsOneWidget, reason: '空窗是答案(这段时间没有运行)');

      // A fresh container (the second pump would otherwise keep the previous ProviderScope state,
      // and the zone honestly prefers stale truth over an error face). 清树取新容器——否则留旧真相。
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _repo()..failMatrix = true);
      await _settle(tester);
      expect(find.text(h.paneError), findsWidgets, reason: '取数失败诚实报错 + 重试,绝不空白');
    });

    testWidgets('a COLUMN head click NAVIGATES to the flagship; a CELL click preselects the node '
        '(0717 拍板:格阵是发射台)', (tester) async {
      final repo = _repo()..matrixGrid = grid();
      final routed = <String>[];
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: SchedulerHomeView(workflowId: 'wf_a'))),
        GoRoute(
            path: '/scheduler/w/:id/runs/:frId',
            builder: (_, st) {
              routed.add(st.uri.toString());
              return const SizedBox.shrink();
            }),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sseGatewayProvider.overrideWithValue(null),
          schedulerRepositoryProvider.overrideWithValue(repo),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(theme: AnTheme.light(), routerConfig: router),
        ),
      ));
      await tester.pump();
      await _settle(tester);

      // Scope INSIDE the grid: the run table below also prints the id. finder 限定格阵内。
      final colHead = find.descendant(
          of: find.byType(AnRunMatrix),
          matching: find.bySemanticsLabel(RegExp('running|在跑|Running')));
      await tester.ensureVisible(colHead.first);
      await tester.pump();
      await tester.tap(colHead.first, warnIfMissed: false);
      await tester.pump();
      await _settle(tester);
      expect(routed, isNotEmpty, reason: '点列=直进该 run 的旗舰页');
      expect(routed.last, contains('/runs/fr_live1'));

      // A CELL lands there with ?node= — the flagship's own selection grammar. Addressed by its
      // ValueKey: non-cursor cells are ExcludeSemantics by design, so a semantics finder would be
      // permanently empty and the assertion vacuous (复审 [7] 抓获的空转守卫). The col click above
      // NAVIGATED AWAY — come home first, or the grid is no longer in the tree.
      // 格带节点预选。按 ValueKey 寻址:非光标格刻意无语义节点,语义 finder 恒空=断言空转。上面点列已
      // 导航离页——先回主页,否则格阵不在树里。
      router.go('/');
      await tester.pump();
      await _settle(tester);
      routed.clear();
      final cell = find.descendant(
          of: find.byType(AnRunMatrix),
          matching: find.byKey(const ValueKey(('analyze', 'fr_fail1'))));
      expect(cell, findsOneWidget, reason: '失败格必须真实在场——找不到就该炸,绝不静默跳过');
      await tester.ensureVisible(cell);
      await tester.pump();
      await tester.tap(cell, warnIfMissed: false);
      await tester.pump();
      await _settle(tester);
      expect(routed, isNotEmpty, reason: '点格必须导航');
      expect(routed.last, contains('/runs/fr_fail1'));
      expect(routed.last, contains('node=analyze'), reason: '点格=旗舰 + ?node= 预选');
    });
  });

  group('⑥ 墓碑句已删(WRK-070 B3)', () {
    testWidgets('the end of the history carries NO retention tombstone sentence', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);
      // 用户裁「没用+占位怪异」——历史尽头干净结束;保留线只在设置存储面板陈述。
      expect(find.textContaining('保留策略'), findsNothing);
      expect(find.textContaining('retention policy'), findsNothing);
    });
  });
}
