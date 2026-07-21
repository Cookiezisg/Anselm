import 'package:anselm/core/perf/pulse_clock.dart';
import 'package:flutter_test/flutter_test.dart';

// PulseClock — the shared phase source with idle degrade (WRK-061 W0 §5-6): activity-gated (runs only
// with listeners + a recent poke), ONE low-rate timer for all pulses (T1/WRK-070: never a vsync
// ticker — that forces display-rate frames), freezes at the static pose past idleAfter.
// 共享脉冲时钟:活动门控(有听众+近期 poke 才转)、全体共用一只低频 timer(T1:绝不用 vsync ticker——
// 那会逼出屏幕刷新率整帧)、超时冻回静态姿态。

void main() {
  testWidgets(
    'never starts without a poke (activity-gated, not free-running)',
    (tester) async {
      final clock = PulseClock(
        period: const Duration(milliseconds: 100),
        idleAfter: const Duration(milliseconds: 500),
      );
      var notified = 0;
      clock.addListener(() => notified++);
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.idle, isTrue);
      expect(clock.value, 0);
      expect(notified, 0);
      clock.dispose();
    },
  );

  testWidgets('poke starts the loop; phase advances and listeners hear ticks', (
    tester,
  ) async {
    final clock = PulseClock(
      period: const Duration(milliseconds: 100),
      idleAfter: const Duration(milliseconds: 500),
    );
    var notified = 0;
    clock.addListener(() => notified++);
    clock.poke();
    // Past one cadence interval (33ms) — the first timer fire. 越过一个节拍(33ms)=第一次触发。
    await tester.pump(const Duration(milliseconds: 40));
    expect(clock.idle, isFalse);
    expect(clock.value, greaterThan(0));
    expect(notified, greaterThan(0));
    clock.dispose();
  });

  testWidgets(
    'idle degrade: past idleAfter with no poke → stops, freezes at 0, one final notify',
    (tester) async {
      final clock = PulseClock(
        period: const Duration(milliseconds: 100),
        idleAfter: const Duration(milliseconds: 200),
      );
      clock.addListener(() {});
      clock.poke();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(clock.idle, isFalse);
      // No further pokes — sail past the idle deadline. 不再 poke,越过静息期限。
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 16));
      expect(clock.idle, isTrue);
      expect(clock.value, 0); // frozen at the static pose 冻回静态姿态
      // And it STAYS down (no zombie frames). 停后不再来帧。
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.idle, isTrue);
      clock.dispose();
    },
  );

  testWidgets('a poke after degrade restarts from rest', (tester) async {
    final clock = PulseClock(
      period: const Duration(milliseconds: 100),
      idleAfter: const Duration(milliseconds: 200),
    );
    clock.addListener(() {});
    clock.poke();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.idle, isTrue);
    clock.poke(); // new activity 新活动
    await tester.pump(const Duration(milliseconds: 40)); // one cadence 一个节拍
    expect(clock.idle, isFalse);
    expect(clock.value, greaterThan(0));
    clock.dispose();
  });

  testWidgets(
    'notifies at the pulse cadence (~30fps), never at vsync rate (T1 guard)',
    (tester) async {
      final clock = PulseClock(
        period: const Duration(seconds: 1),
        idleAfter: const Duration(seconds: 5),
      );
      var notified = 0;
      clock.addListener(() => notified++);
      clock.poke();
      await tester.pump(const Duration(seconds: 1));
      // 1s at 33ms cadence = 30 fires; a vsync ticker would have delivered 60–120. The A/B standard is
      // WRK-070's 476×: the cure is a LOW-RATE, stoppable clock. 1s@33ms=30 拍;vsync 会是 60–120。
      expect(notified, inInclusiveRange(25, 35));
      clock.dispose();
    },
  );

  testWidgets(
    'losing the last listener stops the clock (nobody watching = no work)',
    (tester) async {
      final clock = PulseClock(
        period: const Duration(milliseconds: 100),
        idleAfter: const Duration(milliseconds: 500),
      );
      void listener() {}
      clock.addListener(listener);
      clock.poke();
      await tester.pump();
      expect(clock.idle, isFalse);
      clock.removeListener(listener);
      expect(clock.idle, isTrue);
      clock.dispose();
    },
  );
}
