import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_deferred_loading.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// AnDeferredLoading — the anti-flash primitive: nothing until [delay], then the child. A load that
// resolves first (parent leaves the loading branch → this disposes) never flashes the indicator.

void main() {
  testWidgets('shows nothing before delay, child after', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: AnDeferredLoading(child: Text('SKELETON')),
    ));
    expect(find.text('SKELETON'), findsNothing); // within the delay

    await tester.pump(AnMotion.loaderDelay + const Duration(milliseconds: 20));
    expect(find.text('SKELETON'), findsOneWidget); // after the delay
  });

  testWidgets('a fast load (disposed before delay) never shows the indicator — no flash', (tester) async {
    // Mount the deferred loader, then replace it BEFORE the delay (the data arrived) → no pending timer,
    // skeleton never appeared. (A leftover Timer would fail the test as a pending timer.)
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: AnDeferredLoading(child: Text('SKELETON')),
    ));
    await tester.pump(const Duration(milliseconds: 40)); // still within delay
    expect(find.text('SKELETON'), findsNothing);

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Text('CONTENT'),
    ));
    expect(find.text('CONTENT'), findsOneWidget);
    expect(find.text('SKELETON'), findsNothing);
  });
}
