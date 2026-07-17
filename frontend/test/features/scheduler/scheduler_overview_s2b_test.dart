import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/ui/run_peek_card.dart';
import 'package:anselm/features/scheduler/ui/scheduler_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'stub_scheduler_repo.dart';

// S2b · the Overview's ACTION zones (WRK-069 §3 判决②) — «等你处理» (inbox rows + in-place gate +
// batch approve/reject) and «正在跑» grown hover-⏹ cancel + batch cancel. Batteries: full/empty inbox,
// no-deadline row, soft-deleted host fallback, single-decide slide-out, first-wins 422 honest toast,
// sequential batch with explicit per-row settling, cancel confirm + 422. The running dot breathes
// forever, so tests use FIXED pumps, never pumpAndSettle. S2b 操作区电池;固定 pump、不 settle。

final _now = DateTime.now();

StubSchedulerRepo _repo({Duration decideLatency = Duration.zero}) {
  final repo = StubSchedulerRepo(
    workflows: [
      SchedulerWorkflowRow(id: 'wf_a', name: '数据清洗流水线', lifecycleState: 'active', updatedAt: _now),
      SchedulerWorkflowRow(id: 'wf_b', name: '库存同步', lifecycleState: 'active', updatedAt: _now),
    ],
    byWorkflow: [
      WorkflowRunStats(workflowId: 'wf_a', running: 1, lastRunAt: _now),
      WorkflowRunStats(workflowId: 'wf_b', running: 1, lastRunAt: _now),
    ],
    totalsRunning: 2,
    runs: [
      Flowrun(
          id: 'fr_live1',
          workflowId: 'wf_a',
          status: 'running',
          startedAt: _now.subtract(const Duration(seconds: 90)),
          updatedAt: _now),
      Flowrun(
          id: 'fr_live2',
          workflowId: 'wf_b',
          status: 'running',
          startedAt: _now.subtract(const Duration(minutes: 3)),
          updatedAt: _now),
    ],
    // Three inbox forms: deadline soon (+2h, reason allowed) / no deadline (reason forbidden) /
    // soft-deleted host (bare-id name, overdue). 三形种子。
    inbox: [
      stubInboxRow('fr_park1', 'approve_send',
          wfId: 'wf_report',
          wfName: '周报生成',
          deadline: _now.add(const Duration(hours: 2)),
          now: _now),
      stubInboxRow('fr_park2', 'approve_deploy',
          wfId: 'wf_deploy',
          wfName: '发布上线',
          allowReason: false,
          waited: const Duration(minutes: 5),
          now: _now),
      stubInboxRow('fr_ghost7', 'approve_cleanup',
          wfId: 'wf_ghost',
          wfName: 'wf_ghost',
          deadline: _now.subtract(const Duration(minutes: 30)),
          waited: const Duration(days: 2),
          now: _now),
    ],
  );
  repo.decideLatency = decideLatency;
  return repo;
}

Widget _host(StubSchedulerRepo repo) => ProviderScope(
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
            home: const Scaffold(
                body: SingleChildScrollView(child: SchedulerOverviewView())),
          );
        }),
      ),
    );

Future<void> _pumpBoard(WidgetTester tester, StubSchedulerRepo repo) async {
  await tester.pumpWidget(_host(repo));
  await tester.pump(); // providers resolve
  await tester.pump(const Duration(seconds: 1)); // count-ups settle; breath keeps looping
}

/// Hover a point with a persistent mouse (scrolling it into the viewport first — an off-screen
/// MouseRegion never hears enter events). 常驻鼠标悬停(先滚进视口,折叠线下的 MouseRegion 听不到)。
Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  await tester.pump();
  await g.moveTo(tester.getCenter(target));
  await tester.pump();
  return g;
}

/// The selection checkbox inside the approval CARD whose title is [name] (B13 卡片化). 按卡题定位选择框。
Finder _cardCheck(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(AnCard)),
    matching: find.byType(AnBatchCheck));

/// The selection checkbox inside the ledger ROW whose primary CONTAINS [name] (running/failed zones
/// are AnLedgerRows; the B10 primary is «workflow · source phrase», so match by containment). 按行主文定位。
Finder _rowCheck(String name) => find.descendant(
    of: find.ancestor(of: find.textContaining(name), matching: find.byType(AnLedgerRow)),
    matching: find.byType(AnBatchCheck));

/// The persistent verb button (⏹ Stop / ↻ Retry) inside the ledger ROW whose primary contains [name]
/// (B10 大表行文法:动词常驻,非 hover 行尾). 行内常驻动词按钮。
Finder _rowVerb(String name, String label) => find.descendant(
    of: find.ancestor(of: find.textContaining(name), matching: find.byType(AnLedgerRow)),
    matching: find.widgetWithText(AnButton, label));

/// The row's primary text — the tap target that toggles the inline peek (never the verb button).
/// 行主文=开合速览的点击靶(不碰动词钮)。
Finder _rowPrimary(String name) => find.textContaining(name);

/// Settle a decide/cancel: slide-out (240ms) + settleRefetch delay (300ms) + refetch rebuild.
/// 落定节拍:滑出+延迟对账+重建。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 100));
}

/// N completed + M failed node rows for a run — feeds the replay confirm's REAL numbers (记忆化承诺).
/// 一个 run 的 N completed + M failed 节点行:喂 replay 确认的真数字。
List<FlowrunNode> _nodes(String frId, {int completed = 0, int failed = 0}) => [
      for (var i = 0; i < completed; i++)
        FlowrunNode(
            id: 'frn_${frId}_c$i',
            flowrunId: frId,
            nodeId: 'c$i',
            kind: 'function',
            status: 'completed',
            createdAt: _now,
            updatedAt: _now),
      for (var i = 0; i < failed; i++)
        FlowrunNode(
            id: 'frn_${frId}_f$i',
            flowrunId: frId,
            nodeId: 'f$i',
            kind: 'function',
            status: 'failed',
            createdAt: _now,
            updatedAt: _now),
    ];

/// Two failed runs landed inside the 24h window (工单⑮), one per workflow, each with node rows so the
/// replay confirm shows real «re-run N · reuse M» numbers. 两个 24h 窗内失败 run,带节点行喂 replay 真数字。
StubSchedulerRepo _failedRepo() => StubSchedulerRepo(
      workflows: [
        SchedulerWorkflowRow(id: 'wf_a', name: '数据清洗流水线', lifecycleState: 'active', updatedAt: _now),
        SchedulerWorkflowRow(id: 'wf_b', name: '库存同步', lifecycleState: 'active', updatedAt: _now),
      ],
      byWorkflow: [
        WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now),
        WorkflowRunStats(workflowId: 'wf_b', lastRunAt: _now),
      ],
      runs: [
        Flowrun(
            id: 'fr_bad1',
            workflowId: 'wf_a',
            status: 'failed',
            origin: 'cron',
            startedAt: _now.subtract(const Duration(minutes: 10)),
            completedAt: _now.subtract(const Duration(minutes: 8)),
            error: 'HTTP 502 Bad Gateway: upstream did not respond\nstack trace...',
            updatedAt: _now),
        Flowrun(
            id: 'fr_bad2',
            workflowId: 'wf_b',
            status: 'failed',
            origin: 'manual',
            startedAt: _now.subtract(const Duration(minutes: 30)),
            completedAt: _now.subtract(const Duration(minutes: 25)),
            error: 'connection refused',
            updatedAt: _now),
      ],
      nodesByRun: {
        'fr_bad1': _nodes('fr_bad1', completed: 2, failed: 1),
        'fr_bad2': _nodes('fr_bad2', completed: 1, failed: 1),
      },
    );

/// 12 failed runs (one workflow) — pushes the failed zone past one 10-row front-end page (B10 pager).
/// 12 个失败 run(一 workflow):把失败区推过一页(前端 10/页翻页器)。
StubSchedulerRepo _manyFailedRepo() => StubSchedulerRepo(
      workflows: [
        SchedulerWorkflowRow(id: 'wf_a', name: '数据清洗流水线', lifecycleState: 'active', updatedAt: _now),
      ],
      byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
      runs: [
        for (var i = 0; i < 12; i++)
          Flowrun(
              id: 'fr_f$i',
              workflowId: 'wf_a',
              status: 'failed',
              origin: 'cron',
              startedAt: _now.subtract(Duration(minutes: 60 + i)),
              completedAt: _now.subtract(Duration(minutes: 30 + i)),
              error: 'boom $i',
              updatedAt: _now),
      ],
    );

/// A router that hosts the board at `/` and a marker page at the run flagship path — the peek's
/// «Open →» and the row's double-tap both navigate there. 路由:board 在 /,run 子页占位;Open→ 与双击去它。
GoRouter _makeRouter() => GoRouter(initialLocation: '/', routes: [
      GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: SingleChildScrollView(child: SchedulerOverviewView()))),
      GoRoute(
          path: '/scheduler/w/:id/runs/:frId',
          builder: (_, _) => const Scaffold(body: SizedBox())),
    ]);

Future<void> _pumpRouter(WidgetTester tester, StubSchedulerRepo repo, GoRouter router) async {
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
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  final ov = t.scheduler.overview;

  group('等你处理 waiting zone', () {
    testWidgets('full inbox: head count, amber rows, countdown ONLY where a deadline exists, '
        'waited measure, per-row gate, reason input only where allowed, bare-id tombstone name',
        (tester) async {
      await _pumpBoard(tester, _repo());

      expect(find.text(ov.waitingHead(n: '3').toUpperCase()), findsOneWidget);
      expect(find.text('周报生成'), findsOneWidget);
      expect(find.text('发布上线'), findsOneWidget);
      // Soft-deleted host: the name fell back to the bare id — rendered as-is, still decidable.
      // 软删宿主名回落裸 id,行仍可决。
      expect(find.text('wf_ghost'), findsOneWidget);

      // node chips + prompts. 节点 chip 与 prompt。
      expect(find.text('approve_send'), findsOneWidget);
      expect(find.text('gate approve_send?'), findsOneWidget);

      // Two deadline rows → two countdowns (the no-deadline row renders none); the overdue row
      // speaks the overdue word. 两期限行=两倒计时;无期限行不渲;超时行渲已超时。
      expect(find.byType(AnCountdown), findsNWidgets(2));
      expect(find.text(t.run.countdownOverdue), findsOneWidget);

      // Waited-for measures (minute-granular). 等待时长。
      expect(find.text(ov.waitedFor(d: '18m')), findsOneWidget);
      expect(find.text(ov.waitedFor(d: '2d')), findsOneWidget);

      // One gate per CARD; at rest the reason is a «+ 理由» PILL on allowReason cards only —
      // NO resident input anywhere (B13 用户裁「常驻输入框怪恶心」). 门逐卡;静息=药丸仅 2 卡,零常驻输入。
      expect(find.text(t.run.approve), findsNWidgets(3));
      expect(find.text(t.run.reject), findsNWidgets(3));
      expect(find.text(t.run.addReason), findsNWidgets(2));
      expect(find.byType(AnInput), findsNothing, reason: '理由输入按需长出,静息零输入框');
      // Every approval sits in a BORDERED card (KPI 牌也是 AnCard,按卡题定位); raw fr_ pill gone (B1).
      // 逐卡有边框壳;裸 id 药丸绝迹。
      for (final name in ['周报生成', '发布上线', 'wf_ghost']) {
        expect(find.ancestor(of: find.text(name), matching: find.byType(AnCard)), findsWidgets,
            reason: '审批卡带边框($name)');
      }
      expect(find.textContaining('fr_park'), findsNothing, reason: '裸 id 清除(B1)');

      // No batch bar without a selection. 无选无条。
      expect(find.byType(AnBatchBar), findsNothing);
      expect(find.text(ov.waitingEmpty), findsNothing);
    });

    testWidgets('empty inbox: the honest empty sentence', (tester) async {
      final repo = StubSchedulerRepo(
        workflows: [
          SchedulerWorkflowRow(id: 'wf_a', name: '安静', lifecycleState: 'active', updatedAt: _now),
        ],
        byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: _now)],
      );
      await _pumpBoard(tester, repo);
      expect(find.text(ov.waitingEmpty), findsOneWidget);
      expect(find.byType(AnCountdown), findsNothing);
    });

    testWidgets('a single decision settles: verdict + trimmed reason ride :decide, the row slides '
        'out and the refetch removes it', (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      // Open the first card's «+ 理由» pill, type, then approve (B13 按需长出). 点药丸长输入,再批准。
      await tester.tap(find.text(t.run.addReason).first);
      await tester.pump();
      await tester.enterText(find.byType(AnInput).first, '  周报没问题  ');
      await tester.tap(find.text(t.run.approve).first);
      await tester.pump();
      await _settle(tester);

      expect(repo.decideOrder, ['fr_park1/approve_send:yes:周报没问题']);
      expect(find.text('周报生成'), findsNothing, reason: '决了行消失(refetch 收行)');
      expect(find.text(ov.waitingHead(n: '2').toUpperCase()), findsOneWidget);
    });

    testWidgets('losing first-wins (422) earns the honest toast and the row reconciles away',
        (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      // Someone else decides fr_park1 behind our back. 别处先决。
      repo.decided.add('fr_park1/approve_send');
      await tester.tap(find.text(t.run.approve).first);
      await tester.pump();
      await _settle(tester);

      expect(find.text(ov.alreadyHandled), findsOneWidget, reason: '诚实 toast「已被处理」');
      expect(find.text('周报生成'), findsNothing, reason: 'refetch 对账,行随真相消失');
      expect(repo.decideOrder, isEmpty, reason: '输家没有写入');
    });

    testWidgets('batch approve: hover checkbox selection → bar at ≥2 → SEQUENTIAL dispatch with '
        'per-row pending → summary toast → rows settle', (tester) async {
      final repo = _repo(decideLatency: const Duration(milliseconds: 120));
      await _pumpBoard(tester, repo);

      // Hover row 1 → its checkbox replaces the amber dot → select. hover 换框、选中。
      final g = await _hover(tester, find.text('周报生成'));
      expect(find.byType(AnBatchCheck), findsOneWidget, reason: 'hover 才浮出选择框');
      await tester.tap(_cardCheck('周报生成'));
      await tester.pump();

      // Selection mode: every row shows its checkbox; one selected → still no bar. 选择模式全行出框。
      expect(find.byType(AnBatchCheck), findsWidgets);
      expect(find.byType(AnBatchBar), findsNothing, reason: '选中 1 不出条');

      await tester.tap(_cardCheck('发布上线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // bar reveal
      expect(find.byType(AnBatchBar), findsOneWidget, reason: '选中≥2 浮出批量条');
      expect(find.text(t.feedback.batch.selected(n: '2')), findsOneWidget);

      await tester.ensureVisible(find.text(ov.batchApprove));
      await tester.tap(find.text(ov.batchApprove));
      await tester.pump();
      // Mid-batch: queued rows wear the pending spinner (explicit per-row book-keeping, never a
      // fake atomic flash). 批中挂账:排队行戴 spinner。
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AnSpinner), findsWidgets);
      expect(repo.decideOrder, hasLength(lessThan(2)), reason: '逐发:第二行尚未发出');

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      await _settle(tester);

      expect(repo.decideOrder,
          ['fr_park1/approve_send:yes', 'fr_park2/approve_deploy:yes'],
          reason: '按行序逐发');
      expect(find.text(ov.sumApproved(n: '2')), findsOneWidget, reason: '汇总 toast');
      expect(find.text('周报生成'), findsNothing);
      expect(find.text('发布上线'), findsNothing);
      await g.removePointer();
    });

    testWidgets('batch approve over a half-lost race: «1 approved · 1 already handled»',
        (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      final g = await _hover(tester, find.text('周报生成'));
      await tester.tap(_cardCheck('周报生成'));
      await tester.pump();
      await tester.tap(_cardCheck('发布上线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The second target is decided elsewhere mid-selection. 第二行被别处先决。
      repo.decided.add('fr_park2/approve_deploy');
      await tester.ensureVisible(find.text(ov.batchApprove));
      await tester.tap(find.text(ov.batchApprove));
      await tester.pump();
      await _settle(tester);

      expect(
          find.text('${ov.sumApproved(n: '1')} · ${ov.sumLost(n: '1')}'), findsOneWidget,
          reason: '汇总 toast「已批准 1 · 1 条已被别处处理」');
      await g.removePointer();
    });

    testWidgets('batch reject: the shared-reason strip; the reason rides ONLY allowReason rows',
        (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      final g = await _hover(tester, find.text('周报生成'));
      await tester.tap(_cardCheck('周报生成'));
      await tester.pump();
      await tester.tap(_cardCheck('发布上线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text(ov.batchReject));
      await tester.tap(find.text(ov.batchReject));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // strip reveal
      expect(find.text(ov.batchRejectConfirm(n: '2')), findsOneWidget);

      // The strip's input is the LAST AnInput (row gates come first in the tree… the strip lives
      // above the rows, so target by hint instead). 共用理由输入按占位词定位。
      final strip = find.widgetWithText(AnInput, t.run.reasonHint).first;
      await tester.enterText(strip, '本周不发');
      await tester.ensureVisible(find.text(ov.batchRejectConfirm(n: '2')));
      await tester.tap(find.text(ov.batchRejectConfirm(n: '2')));
      await tester.pump();
      await _settle(tester);

      expect(repo.decideOrder, [
        'fr_park1/approve_send:no:本周不发', // allowReason → 理由随行
        'fr_park2/approve_deploy:no', // 不接受理由的行绝不带
      ]);
      expect(find.text(ov.sumRejected(n: '2')), findsOneWidget);
      await g.removePointer();
    });
  });

  group('正在跑 running zone (B10 大表行文法)', () {
    testWidgets('the PERSISTENT ⏹ Stop verb opens the danger confirm; cancel settles the row away',
        (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      expect(find.text(ov.runningHead(n: '2').toUpperCase()), findsOneWidget);
      // The verb is PERSISTENT now (B10 — no hover-only far-edge ⏹): one Stop per running row.
      // 动词常驻(B10:无 hover 行尾 ⏹):每行一枚 ⏹。
      expect(find.text(t.scheduler.home.rowCancel), findsNWidgets(2), reason: '常驻 ⏹ 每行一枚');
      expect(find.byWidgetPredicate((w) => w is Visibility && w.visible), findsNothing,
          reason: 'hover 行尾 ⏹ 已退役,不再有 Visibility 门');

      await tester.ensureVisible(_rowVerb('数据清洗流水线', t.scheduler.home.rowCancel));
      await tester.pump();
      await tester.tap(_rowVerb('数据清洗流水线', t.scheduler.home.rowCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog transition
      expect(find.text(ov.cancelConfirmTitle), findsOneWidget);
      expect(find.textContaining('fr_live1'), findsWidgets, reason: '弹窗点名将取消的 run');

      await tester.tap(find.text(ov.cancelConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog pops
      await _settle(tester);

      expect(repo.cancelOrder, ['fr_live1']);
      expect(find.textContaining('数据清洗流水线'), findsNothing, reason: '取消后 running 行消失');
      expect(find.text(ov.runningHead(n: '1').toUpperCase()), findsOneWidget);
    });

    testWidgets('dismissing the dialog cancels nothing', (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);
      await tester.ensureVisible(_rowVerb('库存同步', t.scheduler.home.rowCancel));
      await tester.pump();
      await tester.tap(_rowVerb('库存同步', t.scheduler.home.rowCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(ov.cancelKeep));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.cancelOrder, isEmpty);
      expect(find.textContaining('库存同步'), findsOneWidget);
    });

    testWidgets('a run that already ended (422) earns the honest toast + reconcile', (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);
      // It ends elsewhere after the board loaded. 加载后 run 已自行结束。
      repo.cancelled.add('fr_live1');

      await tester.ensureVisible(_rowVerb('数据清洗流水线', t.scheduler.home.rowCancel));
      await tester.pump();
      await tester.tap(_rowVerb('数据清洗流水线', t.scheduler.home.rowCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(ov.cancelConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      expect(find.text(ov.alreadyFinished), findsOneWidget, reason: '诚实 toast');
      expect(find.textContaining('数据清洗流水线'), findsNothing, reason: '对账后行随真相消失');
    });

    testWidgets('batch cancel: ≥2 selected → danger dialog with the victim LIST → sequential '
        'cancel → summary toast', (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      final g = await _hover(tester, _rowPrimary('数据清洗流水线'));
      await tester.tap(_rowCheck('数据清洗流水线'));
      await tester.pump();
      await tester.ensureVisible(_rowPrimary('库存同步'));
      await tester.tap(_rowCheck('库存同步'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnBatchBar), findsOneWidget);

      await tester.ensureVisible(find.text(ov.batchCancel));
      await tester.tap(find.text(ov.batchCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(ov.batchCancelTitle(n: '2')), findsOneWidget);
      expect(find.textContaining('数据清洗流水线 · fr_live1'), findsOneWidget, reason: '弹窗带行清单');
      expect(find.textContaining('库存同步 · fr_live2'), findsOneWidget);

      await tester.tap(find.text(ov.cancelConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      expect(repo.cancelOrder, ['fr_live1', 'fr_live2'], reason: '按行序逐发');
      expect(find.text(ov.sumCancelled(n: '2')), findsOneWidget);
      expect(find.text(ov.runningEmpty), findsOneWidget, reason: '两行皆去,诚实空句');
      await g.removePointer();
    });

    testWidgets('a single tap EXPANDS the inline peek in place (never navigates)', (tester) async {
      await _pumpBoard(tester, _repo());
      expect(find.byType(RunPeekCard), findsNothing, reason: '未点开=不建卡(C-006)');

      await tester.ensureVisible(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.tap(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // reveal
      // In-place expansion, not a navigation — the peek grows UNDER the row it was tapped on.
      // 就地展开、非跳转:卡长在被点的那一行底下。
      expect(find.byType(RunPeekCard), findsOneWidget, reason: '单击=行内展开速览卡(不跳转)');
      expect(find.text(t.scheduler.home.openRun), findsOneWidget, reason: '旗舰门在卡上');
      // The board is still here — an expand, not a navigation. 盘面还在:展开、非跳转。
      expect(find.text(ov.runningHead(n: '2').toUpperCase()), findsOneWidget);
    });
  });

  group('24h 失败 failed zone (B10 补齐)', () {
    testWidgets('each row carries the persistent ↻ Retry verb; a single replay confirms with REAL '
        'numbers and settles the row away', (tester) async {
      final repo = _failedRepo();
      await _pumpBoard(tester, repo);

      expect(find.text(ov.failed24hHead(n: '2').toUpperCase()), findsOneWidget);
      // The verb the failed zone was MISSING before B10 — persistent, one per row. B10 前缺失的动词。
      expect(find.text(t.scheduler.home.rowRetry), findsNWidgets(2), reason: '常驻 ↻ 每行一枚');
      // The error first line still rides the danger sub. 错误首句仍在 danger 副行。
      expect(find.textContaining('HTTP 502 Bad Gateway'), findsOneWidget);

      await tester.ensureVisible(_rowVerb('数据清洗流水线', t.scheduler.home.rowRetry));
      await tester.pump();
      await tester.tap(_rowVerb('数据清洗流水线', t.scheduler.home.rowRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // getRunFull + confirm
      // The confirm carries the REAL numbers off the node rows (2 completed reused · 1 failed re-run).
      // 确认框带真数字(2 复用·1 重跑)。
      expect(find.text(t.scheduler.home.replayTitle), findsOneWidget);
      expect(find.text(t.scheduler.home.replayBody(failed: '1', completed: '2')), findsOneWidget);

      await tester.tap(find.text(t.scheduler.home.replayAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      expect(repo.replayOrder, ['fr_bad1'], reason: '重放已派发');
      expect(find.text(ov.failed24hHead(n: '1').toUpperCase()), findsOneWidget,
          reason: '重放后离开 24h 失败窗');
    });

    testWidgets('multi-select batch replay: hover checkbox → bar at ≥2 → SEQUENTIAL dispatch → '
        'summary toast', (tester) async {
      final repo = _failedRepo();
      await _pumpBoard(tester, repo);

      final g = await _hover(tester, _rowPrimary('数据清洗流水线'));
      expect(find.byType(AnBatchCheck), findsOneWidget, reason: 'hover 才浮出选择框');
      await tester.tap(_rowCheck('数据清洗流水线'));
      await tester.pump();
      expect(find.byType(AnBatchBar), findsNothing, reason: '选中 1 不出条');

      await tester.ensureVisible(_rowPrimary('库存同步'));
      await tester.tap(_rowCheck('库存同步'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnBatchBar), findsOneWidget, reason: '选中≥2 浮出批量条');

      await tester.ensureVisible(find.text(t.scheduler.home.batchReplay));
      await tester.tap(find.text(t.scheduler.home.batchReplay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // getRunFull ×2 + confirm
      expect(find.text(t.scheduler.home.batchReplayTitle(n: '2')), findsOneWidget);

      await tester.tap(find.text(t.scheduler.home.replayAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      expect(repo.replayOrder, ['fr_bad1', 'fr_bad2'], reason: '按行序逐发');
      expect(find.text(t.scheduler.home.sumReplayed(n: '2')), findsOneWidget, reason: '汇总 toast');
      await g.removePointer();
    });

    testWidgets('a single tap EXPANDS the inline peek in place (never navigates)', (tester) async {
      await _pumpBoard(tester, _failedRepo());
      expect(find.byType(RunPeekCard), findsNothing);

      await tester.ensureVisible(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.tap(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RunPeekCard), findsOneWidget, reason: '单击=行内展开速览卡(不跳转)');
      expect(find.text(t.scheduler.home.openRun), findsOneWidget, reason: '旗舰门在卡上');
    });

    testWidgets('the peek card «Open →» routes to the run subpage', (tester) async {
      final router = _makeRouter();
      addTearDown(router.dispose);
      await _pumpRouter(tester, _failedRepo(), router);

      await tester.ensureVisible(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.tap(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text(t.scheduler.home.openRun));
      await tester.pump();
      await tester.tap(find.text(t.scheduler.home.openRun));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/scheduler/w/wf_a/runs/fr_bad1');
    });

    testWidgets('a fast double-tap on the row goes straight to the flagship', (tester) async {
      final router = _makeRouter();
      addTearDown(router.dispose);
      await _pumpRouter(tester, _failedRepo(), router);

      await tester.ensureVisible(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      // Two quick taps → the double-tap window (judged on REAL wall time in onPeekTap) → the flagship.
      // 连点两下 → 双击窗(onPeekTap 按真墙钟判)→ 旗舰。
      await tester.tap(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.tap(_rowPrimary('数据清洗流水线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/scheduler/w/wf_a/runs/fr_bad1');
    });

    testWidgets('front-end pager: 12 failed runs → 10 on page 1, 2 on page 2 (drained list sliced '
        'client-side — no backend)', (tester) async {
      await _pumpBoard(tester, _manyFailedRepo());
      expect(find.text(ov.failed24hHead(n: '12').toUpperCase()), findsOneWidget);
      // Page 1: 10 rows → 10 persistent Retry verbs; the pager is present (>10 rows). 首页 10 行。
      expect(find.text(t.scheduler.home.rowRetry), findsNWidgets(10), reason: '首页 10 行');
      expect(find.byType(AnPager), findsOneWidget, reason: '>10 行出翻页器');

      // Jump to page 2 → the remaining 2 rows (pure client slice, never a fetch). 跳第 2 页=剩 2 行。
      await tester.ensureVisible(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(t.scheduler.home.rowRetry), findsNWidgets(2), reason: '第 2 页 2 行');
    });
  });
}
