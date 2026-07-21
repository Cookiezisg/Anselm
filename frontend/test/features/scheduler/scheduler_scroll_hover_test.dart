import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/ui/scheduler_home.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stub_scheduler_repo.dart';

// The scroll-flicker regression lock (0718 滚动闪烁审定 — the promoted transplant of the one-shot
// zz_scroll_probe侦查). The disease: on the scheduler home, a trackpad overscroll rubber-band moves
// the run rows UNDER a parked cursor; a hovered row that SWAPS a child (disclosure chevron / lead
// spinner — a relayout, not a repaint) feeds the in-flight drag a reverse delta, the overscroll
// clamps to 0, the content springs back, hover flips again — a self-sustaining flicker (measured:
// the offset traced 30→0→0→30→0→0 instead of a monotone rubber-band). The cure = [AnHoverRegion] /
// AnInteractive freeze hover while the ancestor Scrollable is in motion. These locks prove the cured
// track is INDISTINGUISHABLE from a scroll where the cursor never sat on a row.
// 滚动闪烁回归锁(0718 审定,一次性侦查探针转正)。病:主页触控板 overscroll 橡皮筋把 run 行拖过静止
// 光标,悬停行换件(披露箭头/lead 转圈=relayout)喂回进行中 drag 反向增量 → 掐回 0 → 弹回 → hover 又翻
// → 自激闪烁(实测 offset 走 30→0→0→30→0→0 而非单调橡皮筋)。药=AnHoverRegion/AnInteractive 滚动中冻
// hover。三锁证:治后轨迹与「光标从未落在行上」的滚动逐帧不可区分。
void main() {
  final now = DateTime.now();

  StubSchedulerRepo repo() => StubSchedulerRepo(
    workflows: [
      SchedulerWorkflowRow(
        id: 'wf_a',
        name: '数据清洗流水线',
        lifecycleState: 'active',
        updatedAt: now,
      ),
    ],
    byWorkflow: [WorkflowRunStats(workflowId: 'wf_a', lastRunAt: now)],
    runs: [
      for (var i = 0; i < 24; i++)
        Flowrun(
          id: 'fr_p$i',
          workflowId: 'wf_a',
          origin: 'cron',
          status: 'completed',
          startedAt: now.subtract(Duration(hours: i + 1)),
          completedAt: now.subtract(Duration(hours: i + 1)),
          updatedAt: now,
        ),
    ],
  );

  Widget host(StubSchedulerRepo r) => ProviderScope(
    overrides: [
      sseGatewayProvider.overrideWithValue(null),
      schedulerRepositoryProvider.overrideWithValue(r),
    ],
    child: TranslationProvider(
      child: Builder(
        builder: (context) {
          final navKey = GlobalKey<NavigatorState>();
          return MaterialApp(
            theme: AnTheme.light(),
            navigatorKey: navKey,
            builder: (context, child) =>
                AnOverlayHost(navigatorKey: navKey, child: child!),
            home: Scaffold(body: SchedulerHomeView(workflowId: 'wf_a')),
          );
        },
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  // Drive an at-the-bottom overscroll: pan the content down for [panFrames] frames past the extent,
  // release, then observe [reboundFrames] of rubber-band recovery. The pan ALWAYS lands on a content
  // row (identical physics input); only the parked hover pointer's location varies. Returns the
  // overscroll offset (pixels − maxScrollExtent) per frame across pan + rebound.
  // 触底 overscroll:pan 落点恒在内容行(物理输入一致),只变 hover 光标停放处;返回逐帧 overscroll offset。
  Future<List<double>> overscrollTrack(
    WidgetTester tester, {
    required bool hoverAtEdge,
    int panFrames = 20,
    int reboundFrames = 30,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(repo()));
    await settle(tester);

    final pos = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();

    // Pan on the LAST run row's centre; the hover pointer parks either there or out at the left edge
    // whitespace (720 reading column outside). pan 恒在末行中心;hover 停在行上或左侧白边。
    final rowCentre = tester.getCenter(find.byType(AnLedgerRow).last);
    final hoverP = hoverAtEdge ? Offset(30, rowCentre.dy) : rowCentre;

    final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await hover.addPointer(location: hoverP);
    await tester.pump();

    final track = <double>[];
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.panZoomStart(rowCentre);
    await tester.pump(const Duration(milliseconds: 16));
    var pan = Offset.zero;
    for (var i = 0; i < panFrames; i++) {
      pan += const Offset(
        0,
        -30,
      ); // negative dy = content up = scroll toward bottom overscroll
      await g.panZoomUpdate(rowCentre, pan: pan);
      await tester.pump(const Duration(milliseconds: 16));
      track.add(pos.pixels - pos.maxScrollExtent);
    }
    await g.panZoomEnd();
    for (var i = 0; i < reboundFrames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      track.add(pos.pixels - pos.maxScrollExtent);
    }
    // Clean up THIS call's hover pointer so a second call in the same test can add its own without a
    // duplicate-device MouseTracker assert. 收本次 hover 指针,同测第二次调用可再添不撞设备断言。
    await hover.removePointer();
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
    return track;
  }

  testWidgets(
    'hover over a content row leaves the overscroll IDENTICAL to hovering the edge',
    (tester) async {
      // Lock #1: same pan, cursor on the row vs cursor on the whitespace — after the freeze the two
      // tracks are frame-for-frame the same (before the cure the on-row track self-oscillated).
      // 锁①:同 pan,光标在行上 vs 在白边——冻结后两轨逐帧一致(治前在行上轨自激振荡)。
      final onRow = await overscrollTrack(tester, hoverAtEdge: false);
      final onEdge = await overscrollTrack(tester, hoverAtEdge: true);
      expect(onRow.length, onEdge.length);
      for (var i = 0; i < onRow.length; i++) {
        expect(
          (onRow[i] - onEdge[i]).abs(),
          lessThan(0.1),
          reason:
              'frame $i diverged: onRow=${onRow[i]} onEdge=${onEdge[i]} '
              '(a divergence here means a hovered row relaid out mid-scroll)',
        );
      }
    },
  );

  testWidgets('overscroll is a single clean rise-then-decay (no self-oscillation)', (
    tester,
  ) async {
    // Lock #2: with the cursor on a row, the overscroll must build up monotonically and relax back
    // monotonically — one smooth rubber-band, never the bug's 30→0→0→30 saw-tooth. The saw-tooth
    // lived in the BUILD-UP (the clamp-back fired every hover flip), so both halves are asserted.
    // 锁②:光标在行上,overscroll 单调涨、单调回弹——一条平滑橡皮筋,绝无 30→0→0→30 锯齿(锯齿在涨程,
    // 每次 hover 翻转都掐回),故涨程与回程都断言。
    const panFrames = 20;
    final track = await overscrollTrack(
      tester,
      hoverAtEdge: false,
      panFrames: panFrames,
      reboundFrames: 30,
    );
    final buildUp = track.sublist(0, panFrames);
    final rebound = track.sublist(panFrames);
    for (var i = 1; i < buildUp.length; i++) {
      expect(
        buildUp[i],
        greaterThanOrEqualTo(buildUp[i - 1] - 0.1),
        reason:
            'overscroll DROPPED at build-up frame $i (${buildUp[i - 1]} → ${buildUp[i]}) — the '
            'self-exciting clamp-back is exactly this reversal (bug traced 30→0→0→30)',
      );
    }
    for (var i = 1; i < rebound.length; i++) {
      expect(
        rebound[i],
        lessThanOrEqualTo(rebound[i - 1] + 0.1),
        reason:
            'rebound ROSE at frame $i (${rebound[i - 1]} → ${rebound[i]}) — a clean decay never does',
      );
    }
    expect(
      buildUp.last,
      greaterThan(100.0),
      reason: 'the overscroll must reach a real peak',
    );
    expect(
      rebound.last,
      lessThan(buildUp.last * 0.2),
      reason: 'the rubber-band must relax substantially back toward the extent',
    );
  });

  testWidgets('once the scroll settles, the cursor\'s row shows its disclosure hand', (
    tester,
  ) async {
    // Lock #3: freezing hover DURING the scroll must not lose it — when motion stops, the row under
    // the parked cursor gets its hover (the AnLedgerRow disclose chevron = an AnimatedRotation).
    // 锁③:滚动中冻 hover 不得丢——滚停后光标下的行落定 hover(披露箭头=AnimatedRotation)。
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(repo()));
    await settle(tester);

    final pos = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pump();

    final row = find.byType(AnLedgerRow).last;
    final centre = tester.getCenter(row);
    // No chevron before any hover (the run filter is «all» → the row discloses on hover only).
    // hover 前无箭头(过滤=all,行仅 hover 才披露)。
    expect(
      find.descendant(of: row, matching: find.byType(AnimatedRotation)),
      findsNothing,
    );

    final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await hover.addPointer(location: centre);
    addTearDown(hover.removePointer);
    await tester.pump();
    // Hover registered before scrolling → the row shows its chevron. 滚动前 hover 生效,行现箭头。
    expect(
      find.descendant(
        of: find.byType(AnLedgerRow),
        matching: find.byType(AnimatedRotation),
      ),
      findsWidgets,
    );

    // A short overscroll, release, then let the rubber-band play out FRAME BY FRAME (as the real app
    // does — the row slides away and returns under the cursor over several frames). 逐帧回弹(同真机)。
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.panZoomStart(centre);
    var pan = Offset.zero;
    for (var i = 0; i < 6; i++) {
      pan += const Offset(0, -30);
      await g.panZoomUpdate(centre, pan: pan);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.panZoomEnd();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The frozen hover has landed on the cursor's resting row — its disclosure chevron is present.
    // 冻结的 hover 已落定在光标停歇的行上——披露箭头在场。
    expect(
      find.descendant(
        of: find.byType(AnLedgerRow),
        matching: find.byType(AnimatedRotation),
      ),
      findsWidgets,
      reason:
          'a row under the settled cursor must carry its hover disclosure hand',
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
