import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_expand_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnExpandReveal = the kit's shared collapse/expand reveal (ClipRect + Align heightFactor, nestable).
// Open shows the child + animates; closed removes it from the tree (collapsed rows aren't focusable).
void main() {
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('open shows the child; closed removes it from the tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AnExpandReveal(open: true, child: Text('PANEL'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('PANEL'), findsOneWidget);

    await tester.pumpWidget(
      host(const AnExpandReveal(open: false, child: Text('PANEL'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('PANEL'),
      findsNothing,
      reason: 'fully collapsed → dropped from the tree (not just clipped)',
    );
  });

  testWidgets(
    'toggling open animates the height (intermediate frame between 0 and full)',
    (tester) async {
      var open = false;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (ctx, ss) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => ss(() => open = true),
                  child: const Text('go'),
                ),
                AnExpandReveal(
                  open: open,
                  child: const SizedBox(height: 100, child: Text('PANEL')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(); // start the tween
      await tester.pump(const Duration(milliseconds: 120)); // mid-flight
      final mid = tester
          .getSize(find.text('PANEL'))
          .height; // Align clips via heightFactor < 1
      // the panel's own text height is stable; the REVEALED height is what we assert via the ClipRect/Align —
      // measure the Align's box instead
      final alignH = tester.getSize(find.byType(Align).last).height;
      expect(alignH, greaterThan(0));
      expect(
        alignH,
        lessThan(100),
        reason:
            'mid-tween: revealed height between 0 and full (animating, not instant)',
      );
      expect(mid, greaterThan(0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(Align).last).height,
        100,
        reason: 'settles to full height',
      );
    },
  );

  testWidgets('reduced motion → instant (no intermediate frame)', (
    tester,
  ) async {
    var open = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AnTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, ss) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => ss(() => open = true),
                    child: const Text('go'),
                  ),
                  AnExpandReveal(
                    open: open,
                    child: const SizedBox(height: 80, child: Text('P')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(); // single frame
    expect(
      tester.getSize(find.byType(Align).last).height,
      80,
      reason: 'reduced motion snaps to full in one frame',
    );
  });

  // keepMounted — the opt-out for a body whose live state a fold must not destroy (the skill property
  // form's debounced autosave + edit buffers). The subtree survives the collapse, the reveal still
  // animates, and at zero height the subtree reads as absent to a11y.
  // keepMounted:收起不摧毁体的活状态(skill 表单在途保存);子树活过折叠、动效照旧、零高时对 a11y 读作不存在。
  group('keepMounted', () {
    testWidgets('collapsed subtree stays mounted and KEEPS its State', (
      tester,
    ) async {
      Widget build(bool open) => host(
        AnExpandReveal(open: open, keepMounted: true, child: const _Counter()),
      );
      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      // Mutate the child's State, then fold.
      await tester.tap(find.text('n=0'));
      await tester.pumpAndSettle();
      expect(find.text('n=1'), findsOneWidget);

      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      // Still in the tree (unlike the default form, which drops it) …
      expect(
        find.text('n=1', skipOffstage: false),
        findsOneWidget,
        reason: 'keepMounted must NOT drop the subtree when fully collapsed',
      );

      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      // … and its State survived the fold (a fresh mount would read n=0).
      expect(
        find.text('n=1'),
        findsOneWidget,
        reason: 'State must survive the collapse (no remount)',
      );
    });

    testWidgets('collapsed keepMounted body takes zero height and is inert', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AnExpandReveal(
            open: false,
            keepMounted: true,
            child: SizedBox(height: 120, child: Text('BODY')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnExpandReveal)).height, 0);
      // Inert: excluded from semantics exactly like the dropped-subtree default. 语义排除,等同已出树。
      expect(
        find.bySemanticsLabel('BODY'),
        findsNothing,
        reason: 'a zero-height kept subtree must not be announced',
      );
    });

    testWidgets('default (keepMounted:false) still drops the subtree', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AnExpandReveal(open: false, child: Text('PANEL'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('PANEL', skipOffstage: false), findsNothing);
    });
  });
}

/// A tiny stateful child whose State is observable via its label — proves mount/remount. 可观测状态的小子件。
class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: () => setState(() => n++), child: Text('n=$n'));
}
