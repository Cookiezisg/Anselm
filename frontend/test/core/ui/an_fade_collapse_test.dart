import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_edge_fade.dart';
import 'package:anselm/core/ui/an_fade_collapse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnFadeCollapse = max-height clamp + fade + expand toggle, where the fade/toggle only render when
// the content ACTUALLY overflows the clamp (measured, not guessed from the caller's heuristic).
// Regression: a fixed-height collapsed box under-filled by short content left a dead void with a
// stranded Expand button (用户 0719 值班手册收起态).
void main() {
  Widget host(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  Widget fc({required double childHeight, double collapsedHeight = 200}) => AnFadeCollapse(
        collapsible: true,
        collapsedHeight: collapsedHeight,
        expandLabel: 'Expand',
        collapseLabel: 'Collapse',
        child: SizedBox(height: childHeight, child: const Text('BODY')),
      );

  testWidgets('short content: sits at its own height, no fade, no toggle', (tester) async {
    await tester.pumpWidget(host(fc(childHeight: 80)));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AnFadeCollapse)).height, 80,
        reason: 'max-height clamp, not a fixed box — short content must not stretch to the clamp');
    expect(find.byType(AnEdgeFade), findsNothing);
    expect(find.text('Expand'), findsNothing, reason: 'a toggle under fully-visible content is a dead affordance');
  });

  testWidgets('tall content: clamped, fade + Expand present', (tester) async {
    await tester.pumpWidget(host(fc(childHeight: 900)));
    await tester.pumpAndSettle();
    final total = tester.getSize(find.byType(AnFadeCollapse)).height;
    expect(total, lessThan(900), reason: 'clamped to collapsedHeight + toggle row');
    expect(find.byType(AnEdgeFade), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);
  });

  testWidgets('expand shows full content + Collapse; collapse clamps back', (tester) async {
    await tester.pumpWidget(host(fc(childHeight: 900)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SizedBox).first).height, 900, reason: 'expanded → intrinsic height');
    expect(find.text('Collapse'), findsOneWidget);
    await tester.ensureVisible(find.text('Collapse'));
    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();
    expect(find.text('Expand'), findsOneWidget);
    expect(tester.getSize(find.byType(AnFadeCollapse)).height, lessThan(900));
  });

  testWidgets('collapsible=false renders the bare child', (tester) async {
    await tester.pumpWidget(host(const AnFadeCollapse(
      collapsible: false,
      expandLabel: 'Expand',
      collapseLabel: 'Collapse',
      child: Text('BODY'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Expand'), findsNothing);
    expect(find.byType(AnEdgeFade), findsNothing);
  });
}
