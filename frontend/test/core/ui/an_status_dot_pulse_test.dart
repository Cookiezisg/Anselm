import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/perf/pulse_clock.dart';
import 'package:anselm/core/ui/an_status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// T1 (WRK-070): AnStatusDot's self-owned `.repeat()` kept the whole app at 120fps while any run dot
/// was visible — 24.92% CPU idle heat, the one user-feelable burn. The cure is the clock STOPPING:
/// static faces never touch the clock at all, and a live run dot only breathes while activity
/// (arrival / rebuilds) keeps poking the shared PulseClock — past idleAfter it rests to the solid
/// pose and requests NOTHING. These tests pin that contract.
/// T1:自持 .repeat() 曾烧 24.92% CPU。救命的是钟会停:静态点根本不碰钟;活 run 点只在活动(到场/
/// rebuild)持续 poke 时呼吸,超 idleAfter 归实心静息、零请求。本文件锁死该契约。
void main() {
  Widget host(Widget child, {bool reduced = false, bool tickerOn = true}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(disableAnimations: reduced),
                child: TickerMode(enabled: tickerOn, child: child),
              ),
            ),
          ),
        ),
      );

  testWidgets('a static dot does ZERO animation work: clock never starts, no frames requested',
      (tester) async {
    final clock = PulseClock();
    await tester.pumpWidget(host(AnStatusDot(AnStatus.done, clock: clock)));
    await tester.pump(const Duration(seconds: 1));
    expect(clock.idle, isTrue); // never poked, never started 从未起搏
    expect(find.descendant(of: find.byType(AnStatusDot), matching: find.byType(AnimatedBuilder)),
        findsNothing); // never subscribes 根本不订阅
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'a static dot must keep the engine fully asleep');
    clock.dispose();
  });

  testWidgets('a run dot breathes on arrival, then degrades past idleAfter and goes fully silent',
      (tester) async {
    final clock = PulseClock(
        period: const Duration(milliseconds: 100), idleAfter: const Duration(milliseconds: 300));
    await tester.pumpWidget(host(AnStatusDot(AnStatus.run, clock: clock)));
    await tester.pump(const Duration(milliseconds: 40)); // one cadence 一个节拍
    expect(clock.idle, isFalse); // arrival poked the clock — breathing 出现即起搏,在呼吸
    // No further activity — sail past the idle deadline. 无新活动,越过静息线。
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(clock.idle, isTrue);
    expect(clock.value, 0); // frozen at the solid pose 冻回实心姿态
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'past idleAfter a lone run dot must request nothing — the T1 cure IS the stop');
  });

  testWidgets('a rebuild reaching a live run dot re-arms the idle window (stream heartbeat)',
      (tester) async {
    final clock = PulseClock(
        period: const Duration(milliseconds: 100), idleAfter: const Duration(milliseconds: 300));
    await tester.pumpWidget(host(AnStatusDot(AnStatus.run, clock: clock)));
    await tester.pump(const Duration(milliseconds: 200));
    // A stream frame rebuilds the row → didUpdateWidget pokes → deadline pushed back. 流帧重建行→顺延。
    await tester.pumpWidget(host(AnStatusDot(AnStatus.run, clock: clock)));
    await tester.pump(const Duration(milliseconds: 250)); // t=450 > original deadline 300 原线已过
    expect(clock.idle, isFalse, reason: 'activity must sustain the breath');
    await tester.pump(const Duration(seconds: 1)); // quiet — now it rests 安静后归息
    expect(clock.idle, isTrue);
  });

  testWidgets('reduced motion: a run dot neither subscribes nor pokes (double gate)', (tester) async {
    final clock = PulseClock();
    await tester.pumpWidget(host(AnStatusDot(AnStatus.run, clock: clock), reduced: true));
    await tester.pump(const Duration(seconds: 1));
    expect(clock.idle, isTrue); // no poke 不起搏
    expect(find.descendant(of: find.byType(AnStatusDot), matching: find.byType(AnimatedBuilder)),
        findsNothing); // no subscription 不订阅
    clock.dispose();
  });

  testWidgets('off-stage (TickerMode off): a run dot stays static — no poke, no subscription',
      (tester) async {
    final clock = PulseClock();
    await tester.pumpWidget(host(AnStatusDot(AnStatus.run, clock: clock), tickerOn: false));
    await tester.pump(const Duration(seconds: 1));
    expect(clock.idle, isTrue);
    expect(find.descendant(of: find.byType(AnStatusDot), matching: find.byType(AnimatedBuilder)),
        findsNothing);
    clock.dispose();
  });
}
