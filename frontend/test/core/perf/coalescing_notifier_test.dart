import 'package:anselm/core/perf/coalescing_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 7 perf gate — the foundation contract the streaming UI rests on: under a firehose of N deltas,
// the value is updated synchronously + losslessly, but a widget watching it rebuilds ≤1×/frame (NOT N
// times). This is the executable proof of "an SSE frame never storms the leaf" at the primitive level;
// the page==0 / row≤1 assertions through the real gateway come with the Chat feature (4.2).
void main() {
  testWidgets('value is synchronous + lossless; listeners notified ≤1/frame', (
    tester,
  ) async {
    final n = CoalescingNotifier<String>('');
    addTearDown(n.dispose);
    var notifies = 0;
    n.addListener(() => notifies++);

    for (var i = 0; i < 100; i++) {
      n.mutate((s) => '$s$i;');
    }
    // applied immediately, every delta present (lossless)…
    expect(n.value.split(';').where((s) => s.isNotEmpty).length, 100);
    // …but NOT yet notified (coalesced)
    expect(notifies, 0);

    await tester.pump(); // one frame
    expect(notifies, 1); // exactly one notify for the 100 mutates

    // a fresh batch coalesces into the next frame's single notify
    n.mutate((s) => '${s}done;');
    await tester.pump();
    expect(notifies, 2);
  });

  testWidgets(
    'ValueListenableBuilder over it rebuilds exactly once for a 200-delta firehose',
    (tester) async {
      final n = CoalescingNotifier<int>(0);
      addTearDown(n.dispose);
      var builds = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: n,
            builder: (_, v, _) {
              builds++;
              return Text('$v');
            },
          ),
        ),
      );
      expect(builds, 1); // initial build

      for (var i = 0; i < 200; i++) {
        n.mutate((v) => v + 1);
      }
      // settle: one frame fires the coalesced postFrame notify, the next does the single rebuild.
      await tester.pumpAndSettle();

      expect(n.value, 200); // all 200 applied
      expect(builds, 2); // initial + exactly ONE coalesced rebuild (NOT 200)
      expect(find.text('200'), findsOneWidget);
    },
  );

  testWidgets('mutate after dispose is a no-op (no throw)', (tester) async {
    final n = CoalescingNotifier<int>(0);
    n.dispose();
    n.mutate((v) => v + 1);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
