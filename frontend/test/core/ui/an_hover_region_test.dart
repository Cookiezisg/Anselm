import 'package:anselm/core/ui/an_hover_region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnHoverRegion = a MouseRegion that FREEZES hover transitions while the nearest ancestor Scrollable
// is in motion and flushes the resting hover on settle (0718 滚动闪烁审定). These batteries lock the
// four contract points: freeze while scrolling / passthrough when idle / flush on settle / re-bind
// when the ancestor ScrollPosition is replaced. Content-moves-under-a-parked-cursor is exactly the
// production trigger — MouseTracker re-hit-tests each frame, so a scrolled row slides past a still mouse.
// AnHoverRegion:滚动中冻结 hover、滚停 flush 的 MouseRegion。四电池锁四契约点:滚动中冻/静止直通/
// 滚停 flush/换 position 重挂。内容在静止光标下移动=生产触发条件(MouseTracker 每帧重命中)。
void main() {
  // A tall list with one AnHoverRegion target between spacers — scrolling slides the target out from
  // under a parked cursor. 高列表,目标夹在两垫之间——滚动把目标从静止光标下滑走。
  Widget harness({
    required ScrollController controller,
    required List<String> log,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 300),
            AnHoverRegion(
              onEnter: (_) => log.add('enter'),
              onExit: (_) => log.add('exit'),
              child: const SizedBox(width: 200, height: 40),
            ),
            const SizedBox(height: 1400),
          ],
        ),
      ),
    );
  }

  Future<TestGesture> scrollBy(
    WidgetTester tester,
    Offset anchor,
    int frames,
  ) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.panZoomStart(anchor);
    await tester.pump(const Duration(milliseconds: 16));
    var pan = Offset.zero;
    for (var i = 0; i < frames; i++) {
      pan += const Offset(0, -30); // content up = scroll down
      await g.panZoomUpdate(anchor, pan: pan);
      await tester.pump(const Duration(milliseconds: 16));
    }
    return g; // still active (isScrolling == true) — caller ends + settles 调用方结束并落定
  }

  testWidgets('idle: enter/exit pass straight through (no ancestor motion)', (
    tester,
  ) async {
    final log = <String>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller: controller, log: log));

    final centre = tester.getCenter(find.byType(AnHoverRegion));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: centre);
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(log, [
      'enter',
    ], reason: 'over the target, nothing scrolling → immediate enter');

    await mouse.moveTo(
      const Offset(400, 560),
    ); // off the target, over the bottom spacer
    await tester.pump();
    expect(log, [
      'enter',
      'exit',
    ], reason: 'leaving the target while idle → immediate exit');
  });

  testWidgets('scrolling: the exit is FROZEN (not dispatched mid-scroll)', (
    tester,
  ) async {
    final log = <String>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller: controller, log: log));

    final centre = tester.getCenter(find.byType(AnHoverRegion));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: centre);
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(log, ['enter']);

    // Scroll the target ~150px up and out from under the parked cursor. A plain MouseRegion WOULD
    // have exited by now; the freeze must hold the exit. 目标滑走 ~150px,普通 MouseRegion 早已 exit;冻结须扣住。
    final g = await scrollBy(tester, centre, 5);
    expect(log, [
      'enter',
    ], reason: 'exit must be deferred while the ancestor is scrolling');

    await g.panZoomEnd();
    await mouse
        .removePointer(); // avoid a settle-time flush racing the assertion above 先断指针免落定 flush 抢跑
    await tester.pumpAndSettle();
  });

  testWidgets('settle: the frozen exit FLUSHES once motion stops', (
    tester,
  ) async {
    final log = <String>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(harness(controller: controller, log: log));

    final centre = tester.getCenter(find.byType(AnHoverRegion));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: centre);
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(log, ['enter']);

    final g = await scrollBy(tester, centre, 5);
    expect(log, ['enter'], reason: 'frozen during the scroll');
    await g.panZoomEnd();
    await tester.pumpAndSettle();
    // The cursor's resting state is off the target (it scrolled away) — the deferred exit lands ONCE.
    // 光标停歇态在目标外(它已滑走)——被缓存的 exit 落定一次。
    expect(log, [
      'enter',
      'exit',
    ], reason: 'the deferred exit must flush exactly once on settle');
  });

  testWidgets(
    're-bind: a swapped ScrollPosition is tracked, so the freeze still engages',
    (tester) async {
      final log = <String>[];
      final c1 = ScrollController();
      final c2 = ScrollController();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      await tester.pumpWidget(harness(controller: c1, log: log));
      final centre = tester.getCenter(find.byType(AnHoverRegion));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: centre);
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(log, ['enter']);

      // Swap the controller → the Scrollable builds a NEW ScrollPosition. didChangeDependencies must
      // re-bind the freeze to it; otherwise it would still watch c1's (now detached, idle) notifier and
      // the exit would fire mid-scroll. 换控制器→新 position;须重挂,否则仍盯 c1 的空闲 notifier、exit 会中途发。
      await tester.pumpWidget(harness(controller: c2, log: log));
      await tester.pump();

      final g = await scrollBy(tester, centre, 5);
      expect(
        log,
        ['enter'],
        reason:
            'the freeze must follow the swapped ScrollPosition (c2), not the stale c1',
      );
      await g.panZoomEnd();
      await tester.pumpAndSettle();
      expect(log, [
        'enter',
        'exit',
      ], reason: 'and still flush on settle after the re-bind');
    },
  );
}
