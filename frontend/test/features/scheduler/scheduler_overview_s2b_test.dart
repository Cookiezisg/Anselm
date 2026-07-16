import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/ui/scheduler_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The row-selection checkbox inside the ledger row whose primary is [name]. 按主文定位行选择框。
Finder _rowCheck(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(AnLedgerRow)),
    matching: find.byType(AnBatchCheck));

/// Settle a decide/cancel: slide-out (240ms) + settleRefetch delay (300ms) + refetch rebuild.
/// 落定节拍:滑出+延迟对账+重建。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 100));
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

      // One gate per row; the reason input grows only on allowReason rows (2 of 3). 门逐行;理由输入仅 2 行。
      expect(find.text(t.run.approve), findsNWidgets(3));
      expect(find.text(t.run.reject), findsNWidgets(3));
      expect(find.byType(AnInput), findsNWidgets(2));

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

      // Type a reason into the first (allowReason) row's gate, then approve. 首行门带理由批准。
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
      await tester.tap(_rowCheck('周报生成'));
      await tester.pump();

      // Selection mode: every row shows its checkbox; one selected → still no bar. 选择模式全行出框。
      expect(find.byType(AnBatchCheck), findsWidgets);
      expect(find.byType(AnBatchBar), findsNothing, reason: '选中 1 不出条');

      await tester.tap(_rowCheck('发布上线'));
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
      await tester.tap(_rowCheck('周报生成'));
      await tester.pump();
      await tester.tap(_rowCheck('发布上线'));
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
      await tester.tap(_rowCheck('周报生成'));
      await tester.pump();
      await tester.tap(_rowCheck('发布上线'));
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

  group('正在跑 running zone', () {
    testWidgets('hover reveals ⏹; the danger dialog confirms; cancel settles the row away',
        (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      expect(find.text(ov.runningHead(n: '2').toUpperCase()), findsOneWidget);
      final visibleStop = find.byWidgetPredicate((w) => w is Visibility && w.visible);
      expect(visibleStop, findsNothing, reason: '未 hover 无 ⏹');

      final g = await _hover(tester, find.text('数据清洗流水线'));
      expect(visibleStop, findsOneWidget, reason: 'hover 行尾浮出 ⏹');

      await tester.tap(visibleStop);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog transition
      expect(find.text(ov.cancelConfirmTitle), findsOneWidget);
      expect(find.textContaining('fr_live1'), findsWidgets, reason: '弹窗点名将取消的 run');

      await tester.tap(find.text(ov.cancelConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog pops
      await _settle(tester);

      expect(repo.cancelOrder, ['fr_live1']);
      expect(find.text('数据清洗流水线'), findsNothing, reason: '取消后 running 行消失');
      expect(find.text(ov.runningHead(n: '1').toUpperCase()), findsOneWidget);
      await g.removePointer();
    });

    testWidgets('dismissing the dialog cancels nothing', (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);
      final g = await _hover(tester, find.text('库存同步'));
      await tester.tap(find.byWidgetPredicate((w) => w is Visibility && w.visible));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(ov.cancelKeep));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.cancelOrder, isEmpty);
      expect(find.text('库存同步'), findsOneWidget);
      await g.removePointer();
    });

    testWidgets('a run that already ended (422) earns the honest toast + reconcile',
        (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);
      // It ends elsewhere after the board loaded. 加载后 run 已自行结束。
      repo.cancelled.add('fr_live1');

      final g = await _hover(tester, find.text('数据清洗流水线'));
      await tester.tap(find.byWidgetPredicate((w) => w is Visibility && w.visible));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(ov.cancelConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      expect(find.text(ov.alreadyFinished), findsOneWidget, reason: '诚实 toast');
      expect(find.text('数据清洗流水线'), findsNothing, reason: '对账后行随真相消失');
      await g.removePointer();
    });

    testWidgets('batch cancel: ≥2 selected → danger dialog with the victim LIST → sequential '
        'cancel → summary toast', (tester) async {
      final repo = _repo();
      await _pumpBoard(tester, repo);

      final g = await _hover(tester, find.text('数据清洗流水线'));
      await tester.tap(_rowCheck('数据清洗流水线'));
      await tester.pump();
      await tester.ensureVisible(find.text('库存同步'));
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
  });
}
