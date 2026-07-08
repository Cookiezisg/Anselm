import 'package:anselm/core/perf/pulse_clock.dart';
import 'package:flutter_test/flutter_test.dart';

// PulseClock — the shared phase source with idle degrade (WRK-061 W0 §5-6): activity-gated (runs only
// with listeners + a recent poke), one ticker for all pulses, freezes at the static pose past idleAfter.
// 共享脉冲时钟:活动门控(有听众+近期 poke 才转)、超时冻回静态姿态。

void main() {
  testWidgets('never starts without a poke (activity-gated, not free-running)', (tester) async {
    final clock = PulseClock(period: const Duration(milliseconds: 100), idleAfter: const Duration(milliseconds: 500));
    var notified = 0;
    clock.addListener(() => notified++);
    await tester.pump(const Duration(milliseconds: 300));
    expect(clock.idle, isTrue);
    expect(clock.value, 0);
    expect(notified, 0);
    clock.dispose();
  });

  testWidgets('poke starts the loop; phase advances and listeners hear ticks', (tester) async {
    final clock = PulseClock(period: const Duration(milliseconds: 100), idleAfter: const Duration(milliseconds: 500));
    var notified = 0;
    clock.addListener(() => notified++);
    clock.poke();
    await tester.pump(); // ticker's zero tick 起搏帧
    await tester.pump(const Duration(milliseconds: 30));
    expect(clock.idle, isFalse);
    expect(clock.value, greaterThan(0));
    expect(notified, greaterThan(0));
    clock.dispose();
  });

  testWidgets('idle degrade: past idleAfter with no poke → stops, freezes at 0, one final notify', (tester) async {
    final clock = PulseClock(period: const Duration(milliseconds: 100), idleAfter: const Duration(milliseconds: 200));
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
  });

  testWidgets('a poke after degrade restarts from rest', (tester) async {
    final clock = PulseClock(period: const Duration(milliseconds: 100), idleAfter: const Duration(milliseconds: 200));
    clock.addListener(() {});
    clock.poke();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.idle, isTrue);
    clock.poke(); // new activity 新活动
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(clock.idle, isFalse);
    expect(clock.value, greaterThan(0));
    clock.dispose();
  });

  testWidgets('losing the last listener stops the ticker (nobody watching = no work)', (tester) async {
    final clock = PulseClock(period: const Duration(milliseconds: 100), idleAfter: const Duration(milliseconds: 500));
    void listener() {}
    clock.addListener(listener);
    clock.poke();
    await tester.pump();
    expect(clock.idle, isFalse);
    clock.removeListener(listener);
    expect(clock.idle, isTrue);
    clock.dispose();
  });
}
