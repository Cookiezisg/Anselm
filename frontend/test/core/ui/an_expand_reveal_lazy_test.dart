import 'package:anselm/core/ui/an_expand_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// C-006 — AnExpandReveal.builder must NOT call its childBuilder while fully collapsed, so a collapsed
// tool card never runs its expensive family body (jsonDecode / regex) on every parent rebuild during
// streaming. The eager `child:` form can't do this (the child is built before the widget). 收起态零建体。
void main() {
  testWidgets('a COLLAPSED lazy reveal never builds its child', (tester) async {
    var built = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AnExpandReveal.builder(
          open: false,
          childBuilder: (context) {
            built++;
            return const Text('body');
          },
        ),
      ),
    );
    expect(built, 0, reason: '收起态→builder 零调用');
    expect(find.text('body'), findsNothing);
  });

  testWidgets('an OPEN lazy reveal builds its child once', (tester) async {
    var built = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AnExpandReveal.builder(
          open: true,
          childBuilder: (context) {
            built++;
            return const Text('body');
          },
        ),
      ),
    );
    expect(built, 1, reason: '展开态→建体一次(非逐动画帧)');
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets(
    'collapsing settles back to zero builds (no per-rebuild body cost)',
    (tester) async {
      var built = 0;
      Widget host(bool open) => MaterialApp(
        home: AnExpandReveal.builder(
          open: open,
          duration:
              Duration.zero, // instant → no lingering animation frames 即时收
          childBuilder: (context) {
            built++;
            return const Text('body');
          },
        ),
      );
      await tester.pumpWidget(host(true));
      expect(built, 1);
      await tester.pumpWidget(host(false)); // collapse
      await tester.pump();
      final afterCollapse = built;
      // Further parent rebuilds while collapsed must NOT re-run the body. 收起后父重建不再建体。
      await tester.pumpWidget(host(false));
      await tester.pumpWidget(host(false));
      expect(built, afterCollapse, reason: '收起态重建→builder 不再调用');
    },
  );
}
