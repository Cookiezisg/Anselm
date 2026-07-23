import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_content_in.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// AnContentIn — the one-shot content-surface fade (S5): plays once on mount, in-place rebuilds
// never replay, static under reduced motion.

void main() {
  testWidgets('fades in on mount: starts transparent, settles opaque', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AnContentIn(child: Text('CONTENT')),
      ),
    );
    final early = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(early, lessThan(0.5)); // just mounted — still surfacing

    await tester.pump(AnMotion.contentIn);
    final settled = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(settled, 1.0);
    expect(find.text('CONTENT'), findsOneWidget);
  });

  testWidgets('an in-place rebuild does NOT replay the fade', (tester) async {
    Widget host(String label) => Directionality(
      textDirection: TextDirection.ltr,
      child: AnContentIn(child: Text(label)),
    );
    await tester.pumpWidget(host('a'));
    await tester.pumpAndSettle();

    // Same element position, new data — content must swap at full opacity (fast beats fancy).
    await tester.pumpWidget(host('b'));
    final opacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(opacity, 1.0);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets(
    'reduced motion renders the child statically — no Opacity layer',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AnContentIn(child: Text('CONTENT')),
          ),
        ),
      );
      expect(find.text('CONTENT'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
    },
  );
}
