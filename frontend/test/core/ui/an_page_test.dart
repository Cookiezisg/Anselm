import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnPage = one scroll region + a centered 720 content column + overlay scrollbar, top pad clearing the
// head band. AnPage 契约。
void main() {
  Widget host(Widget child, {double w = 400, double h = 300}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: Center(child: SizedBox(width: w, height: h, child: child))),
      );

  testWidgets('tall content scrolls in a single scroll region (no overflow)', (tester) async {
    await tester.pumpWidget(host(AnPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < 12; i++) const SizedBox(height: 80, child: Text('row'))],
      ),
    )));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('content column is clamped to 720 + centered in a wide ocean', (tester) async {
    await tester.pumpWidget(host(
      AnPage(child: Container(key: const Key('content'), height: 100, color: const Color(0xFF000000))),
      w: 900,
      h: 400,
    ));
    final width = tester.getSize(find.byKey(const Key('content'))).width;
    expect(width, lessThanOrEqualTo(AnSize.content + 0.5), reason: 'content clamped to the 720 max-width');
    expect(width, lessThan(900), reason: 'clamped, not the full ocean width (centered)');
  });

  testWidgets('on a desktop target only AnPage\'s RawScrollbar paints (no inherited Material Scrollbar)',
      (tester) async {
    // MaterialScrollBehavior wraps every desktop vertical scrollable in a Scrollbar; AnPage installs a
    // ScrollConfiguration(AnScrollBehavior) so only its OWN overlay RawScrollbar shows (no double thumb).
    // Reset the override in finally (a foundation debug var must be unset before the test's invariant check).
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(host(AnPage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < 12; i++) const SizedBox(height: 80, child: Text('row'))],
        ),
      )));
      await tester.pump();
      expect(find.byType(Scrollbar), findsNothing, reason: 'inherited Material Scrollbar suppressed');
      expect(find.byType(RawScrollbar), findsOneWidget, reason: 'only AnPage\'s deliberate overlay bar');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
