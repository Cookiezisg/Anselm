import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/scheduler_matrix.dart';
import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/contract/retention.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/run/run_ledger.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/state/scheduler_home_provider.dart';
import 'package:anselm/features/scheduler/ui/scheduler_home.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'stub_scheduler_repo.dart';

// S3 · the workflow operations home (WRK-069 §4) — four segments: health head (bead strip + 7d
// stats + Run now + ⋯/:kill TypeToConfirm) · the run big table (source-phrase identity, TRUE count
// strip, origin/window filters that really reach the wire, keyset paging, the follow pill that never
// inserts a row, batch replay/cancel with merged real numbers) · the linked pane (gantt ⇄ graph,
// full-bleed) · the triggers exhibit (cron mono + the pause/resume switch). The running dot breathes
// forever → FIXED pumps, never pumpAndSettle. S3 电池;固定 pump、不 settle。

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

StubSchedulerRepo _repo(
    {bool failRunFull = false,
    RetentionConfig retention = const RetentionConfig(runRetentionDays: 90)}) {
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
    retentionConfig: retention,
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
    testWidgets('name + lifecycle chip + bead strip + 7d stats sentence + Run now', (tester) async {
      await _pump(tester, _repo());
      expect(find.text('数据清洗流水线'), findsOneWidget);
      expect(find.text(t.scheduler.status.active), findsOneWidget);
      expect(find.byType(RunBeadStrip), findsOneWidget, reason: '近 10 珠串在场');
      expect(find.text(h.statsLine(window: h.windowWord, rate: '80%', avg: '42.0s')), findsOneWidget);
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
      expect(find.text(h.statsLine(window: h.windowWord, rate: '—', avg: '—')), findsOneWidget);
      expect(find.textContaining('0%'), findsNothing);
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
    testWidgets('rows ARE their source phrase; the mono fr_ id demotes to a chip', (tester) async {
      await _pump(tester, _repo());
      // cron · HH:mm from each run's own start stamp. cron 带本次时刻。
      final cronAt = _now.subtract(const Duration(minutes: 3)).toLocal();
      final hhmm =
          '${cronAt.hour.toString().padLeft(2, '0')}:${cronAt.minute.toString().padLeft(2, '0')}';
      expect(find.text(h.srcCron(at: hhmm)), findsOneWidget);
      expect(find.text(h.srcWithName(kind: h.srcWebhookBare, name: '/invoice')), findsOneWidget,
          reason: 'webhook 摘要=path(config 胜过名)');
      expect(find.text(h.srcChat), findsOneWidget);
      expect(find.text(h.srcUnknown), findsOneWidget, reason: '旧行诚实 unknown,不装 manual');
      // The id is demoted to a chip — it is never the row's identity. id 降 chip,绝不是行身份。
      expect(
          find.descendant(of: find.byType(AnChip), matching: find.text('fr_live1')), findsOneWidget);
      expect(
          find.descendant(of: find.byType(AnLedgerRow), matching: find.text('fr_live1')).evaluate(),
          hasLength(1));
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
      expect(find.text(h.srcChat), findsNothing, reason: '过滤后 completed 行退场');
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

    testWidgets('the window dropdown really moves startedAfter (工单⑥)', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      repo.listFilters.clear();
      await tester.tap(find.text(h.window7d).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(h.window24h).last);
      await tester.pump();
      await _settle(tester);
      final asked = repo.listFilters.where((f) => f.startedAfter != null).toList();
      expect(asked, isNotEmpty);
      final span = _now.difference(asked.last.startedAfter!);
      expect(span.inHours, closeTo(24, 1));
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

    testWidgets('keyset paging: load more appends the next page', (tester) async {
      final runs = [
        for (var i = 0; i < 30; i++)
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
      expect(find.byType(AnLedgerRow), findsNWidgets(SchedulerRunTableController.pageSize));

      await tester.ensureVisible(find.text(h.loadMore));
      await tester.tap(find.text(h.loadMore));
      await tester.pump();
      await _settle(tester);
      expect(find.byType(AnLedgerRow), findsNWidgets(30));
      expect(find.text(h.loadMore), findsNothing, reason: '末页收哨兵');
    });

    testWidgets('hover ⏹ on running / ↻ on failed — a reserved cell, zero layout shift',
        (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      final cronAt = _now.subtract(const Duration(minutes: 3)).toLocal();
      final hhmm =
          '${cronAt.hour.toString().padLeft(2, '0')}:${cronAt.minute.toString().padLeft(2, '0')}';
      final g = await _hover(tester, find.text(h.srcCron(at: hhmm)));
      expect(find.byIcon(AnIcons.stop), findsOneWidget, reason: '在跑行 hover 出 ⏹');
      await g.removePointer();
    });

    testWidgets('single replay: the confirm carries the REAL memoization numbers', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);

      final g = await _hover(tester, find.text('HTTP 502 Bad Gateway: upstream did not respond'),
          reveal: find.ancestor(
              of: find.text('HTTP 502 Bad Gateway: upstream did not respond'),
              matching: find.byType(AnLedgerRow)));
      // Target the ↻ of the row we hovered, by its per-row semantic label — NOT «the first history
      // icon on the page». A page-order finder silently aims at another row the moment the page grows
      // tall enough for ensureVisible to scroll (the reserved hover cell stays in the tree but
      // un-hittable), which is a test that breaks on unrelated layout, not on the behaviour it names.
      // 按**行自己**的语义标签取该行的 ↻,而不是「页面上第一个 history 图标」:一旦页面高到 ensureVisible
      // 需要滚动,页序 finder 就会静默瞄向另一行(定宽格里的 ↻ 仍在树上但不可命中)——那是一个会被无关布局
      // 改动搞坏的测试,而非它所声称的行为的测试。
      await tester.tap(find.bySemanticsLabel(h.replayA11y(id: 'fr_fail1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // fr_fail1 nodes: 1 completed + 1 failed. 真数字。
      expect(find.text(h.replayBody(failed: '1', completed: '1')), findsOneWidget);

      await tester.tap(find.text(h.replayAction));
      await tester.pump();
      await _settle(tester);
      expect(repo.replayOrder, ['fr_fail1']);
      await g.removePointer();
    });

    testWidgets('replay when the node history is unavailable → the numberless honest sentence',
        (tester) async {
      final repo = _repo(failRunFull: true);
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);

      final g = await _hover(tester, find.text('HTTP 502 Bad Gateway: upstream did not respond'),
          reveal: find.ancestor(
              of: find.text('HTTP 502 Bad Gateway: upstream did not respond'),
              matching: find.byType(AnLedgerRow)));
      // The hovered row's own ↻ (per-row semantic label) — see the note on the single-replay test.
      // 该行自己的 ↻(逐行语义标签),理由见单条 replay 测试的注。
      await tester.tap(find.bySemanticsLabel(h.replayA11y(id: 'fr_fail1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(h.replayBodyUnknown), findsOneWidget, reason: '取不到数字也不假造');
      await g.removePointer();
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

  group('④ 联动格', () {
    testWidgets('absent without ?run=; present with it (gantt default, graph on toggle)',
        (tester) async {
      await _pump(tester, _repo());
      expect(find.text(h.linkedTitle), findsNothing);

      await _pump(tester, _repo(), runId: 'fr_fail1');
      expect(find.text(h.linkedTitle), findsOneWidget);
      expect(find.byType(AnNodeGantt), findsOneWidget, reason: '默认甘特');
      expect(find.byType(AnGraphCanvas), findsNothing);

      // The pane sits below the big table, so on a taller page the face toggle is under the fold —
      // scroll it in before tapping (a tap that misses reports «found but not hit», not a real
      // regression). 联动格在大表之下,页一长切脸器就沉到折线下——先滚入再点(点空报的是「找到却没点中」,
      // 不是真回归)。
      await tester.ensureVisible(find.text(h.faceGraph));
      await tester.pump();
      await tester.tap(find.text(h.faceGraph));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnGraphCanvas), findsOneWidget, reason: '切图脸');
      expect(find.byType(AnNodeGantt), findsNothing);
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
      // The pane sits below the big table, so on a taller page the face toggle is under the fold —
      // scroll it in before tapping (a tap that misses reports «found but not hit», not a real
      // regression). 联动格在大表之下,页一长切脸器就沉到折线下——先滚入再点(点空报的是「找到却没点中」,
      // 不是真回归)。
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
      expect(find.text(h.triggersEditHint), findsOneWidget, reason: '编辑归 Entities');
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

  // ── S5:矩阵第三脸(判决③/工单⑩) + 保留墓碑(判决④/工单⑬) ──
  group('⑤ 矩阵第三脸', () {
    FlowrunMatrix grid() => FlowrunMatrix(
          cols: [
            // Newest LEFT; the live one carries NO elapsed. 新在左;在跑的无 elapsed。
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

    testWidgets('the matrix face is LAZY — picking it is what asks the wire (recentN=20 reaches it)',
        (tester) async {
      final repo = _repo();
      await _pump(tester, repo, runId: 'fr_fail1');
      expect(repo.matrixAsks, isEmpty, reason: '不点矩阵脸就一个字节都不取——天生惰性');

      await tester.ensureVisible(find.text(h.faceMatrix));
      await tester.pump();
      await tester.tap(find.text(h.faceMatrix));
      await tester.pump();
      await _settle(tester);
      expect(repo.matrixAsks, [(workflowId: 'wf_a', recentN: 20)],
          reason: '20 是 SchedulerWindows.matrixRecentN,且必须真到线缆(不是渲染时才裁)');
    });

    testWidgets('the grid renders: ×N in the cell, «未及» for a sparse one, and the pane retitles',
        (tester) async {
      final repo = _repo()..matrixByWorkflow['wf_a'] = grid();
      await _pump(tester, repo, runId: 'fr_fail1');
      await tester.ensureVisible(find.text(h.faceMatrix));
      await tester.pump();
      await tester.tap(find.text(h.faceMatrix));
      await tester.pump();
      await _settle(tester);

      expect(find.byType(AnRunMatrix), findsOneWidget);
      expect(find.text(h.matrixTitle), findsOneWidget, reason: '矩阵脸有自己的标题(跨 run,不是「本次运行」)');
      expect(find.text(h.linkedTitle), findsNothing);
      expect(find.byType(AnNodeGantt), findsNothing, reason: '三脸互斥');
      expect(find.text('3'), findsOneWidget, reason: 'iterations=3 → ×N 在格里');
      expect(find.byTooltip(h.matrixNotReached), findsOneWidget,
          reason: '稀疏格说「未及」——空格是真答案,不是缺答案');
    });

    testWidgets('an empty grid says so; a failed read offers retry — neither blanks the pane',
        (tester) async {
      await _pump(tester, _repo(), runId: 'fr_fail1');
      await tester.ensureVisible(find.text(h.faceMatrix));
      await tester.pump();
      await tester.tap(find.text(h.faceMatrix));
      await tester.pump();
      await _settle(tester);
      expect(find.text(h.matrixEmpty), findsOneWidget, reason: '未知/无 run 的 workflow 返三空列表,不是错误');

      await _pump(tester, _repo()..failMatrix = true, runId: 'fr_fail1');
      await tester.ensureVisible(find.text(h.faceMatrix));
      await tester.pump();
      await tester.tap(find.text(h.faceMatrix));
      await tester.pump();
      await _settle(tester);
      expect(find.text(h.paneError), findsOneWidget, reason: '取数失败诚实报错 + 重试,绝不空白');
    });

    testWidgets('picking a COLUMN routes the run into the URL (the other two faces follow it)',
        (tester) async {
      final repo = _repo()..matrixByWorkflow['wf_a'] = grid();
      String? routed;
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: SchedulerHomeView(workflowId: 'wf_a', linkedRunId: 'fr_fail1'))),
        GoRoute(
            path: '/scheduler/w/:id',
            builder: (_, st) {
              routed = st.uri.toString();
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
      await tester.ensureVisible(find.text(h.faceMatrix));
      await tester.pump();
      await tester.tap(find.text(h.faceMatrix));
      await tester.pump();
      await _settle(tester);

      // The LEFT column is the newest run (fr_live1) — picking it must land in the URL, because the
      // run grain is shareable state. Scope the finder INSIDE the grid: the run table above also
      // prints «fr_live1», so a page-wide finder would tap a chip in the table instead of a column
      // head. 最左列=最新 run;点它必须落 URL(run 粒度是可分享的状态)。finder 必须**限定在格阵内**:
      // 上面的大表也印着 fr_live1,页级 finder 会点到表里的 chip 而不是列头。
      final colHead = find.descendant(
          of: find.byType(AnRunMatrix), matching: find.bySemanticsLabel(RegExp('fr_live1')));
      await tester.ensureVisible(colHead.first);
      await tester.pump();
      await tester.tap(colHead.first);
      await tester.pump();
      await _settle(tester);
      expect(routed, contains('run=fr_live1'), reason: '点列=选中该 run,且落在 URL 里');
    });
  });

  group('⑥ 保留墓碑', () {
    testWidgets('at the true end of the history the tombstone says WHY it ends', (tester) async {
      final repo = _repo();
      await _pump(tester, repo);
      // Filter to failed → 2 rows, no more pages → the true bottom. 过滤到失败=到底。
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);
      expect(find.text(h.tombstone(d: '90')), findsOneWidget,
          reason: '没有解释的末行会静默暗示「在那之前从没跑过」——那是假的');
      expect(repo.retentionAsks, greaterThan(0), reason: '墓碑读的是真 GET /retention,不是硬编的 90');
    });

    testWidgets('«forever» (0) renders NO tombstone — nothing was cleared, so nothing to explain',
        (tester) async {
      final repo = _repo(retention: const RetentionConfig(runRetentionDays: 0));
      await _pump(tester, repo);
      await tester.tap(find.text(h.filterFailed(n: '2')));
      await tester.pump();
      await _settle(tester);
      expect(find.textContaining('保留策略'), findsNothing);
      expect(find.text(h.tombstone(d: '0')), findsNothing, reason: '永久=不清理=无墓碑');
    });

    testWidgets('a tombstone never appears while more pages remain (the end is not yet the end)',
        (tester) async {
      // 30 runs > one 25-row page → hasMore → the loadMore sentinel owns the tail, not a tombstone.
      // 30 条 run > 一页 25 行 → 还有下一页 → 尾巴归 loadMore 哨兵,不归墓碑。
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '多页', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
        runs: [
          for (var i = 0; i < 30; i++)
            Flowrun(
                id: 'fr_h${i.toString().padLeft(3, '0')}',
                workflowId: 'wf_a',
                origin: 'cron',
                status: 'completed',
                startedAt: _now.subtract(Duration(hours: i + 1)),
                completedAt: _now.subtract(Duration(hours: i + 1)),
                updatedAt: _now),
        ],
      );
      await _pump(tester, repo);
      expect(find.text(h.loadMore), findsOneWidget);
      expect(find.text(h.tombstone(d: '90')), findsNothing, reason: '还有下一页时说「更早的已清理」就是撒谎');
    });
  });
}
