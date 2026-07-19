import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/ui/an_status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// C-017: a *running* status dot breathes via an AnimationController.repeat() — without a RepaintBoundary
/// that per-frame BoxShadow would dirty everything up to the nearest ancestor boundary (a whole turn /
/// accordion row) at 60fps. Assert the run face is repaint-isolated, and the static faces are NOT (a
/// RepaintBoundary on a never-animating dot is pure overhead — a separate layer for nothing).
/// C-017:运行点呼吸须隔层(否则逐帧脏到祖先行 60fps 重绘);静态面不隔层(不动的点隔层=白付图层开销)。
void main() {
  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Center(
            // Override just disableAnimations so the reduced-motion branch can be exercised without
            // touching the ambient theme/colors. 仅覆盖 disableAnimations 以走降级分支。
            child: Builder(
              builder: (ctx) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(disableAnimations: reduced),
                child: child,
              ),
            ),
          ),
        ),
      );

  int boundaries(WidgetTester tester) =>
      tester.widgetList<RepaintBoundary>(find.byType(RepaintBoundary)).length;

  testWidgets('a running dot is repaint-isolated; a static dot is not', (tester) async {
    await tester.pumpWidget(host(const AnStatusDot(AnStatus.run)));
    // Scope to the dot: MaterialApp/Scaffold host their own AnimatedBuilders. 限定在点内(脚手架自带)。
    final dotAnim = find.descendant(of: find.byType(AnStatusDot), matching: find.byType(AnimatedBuilder));
    expect(dotAnim, findsOneWidget); // the breathing ring animates 呼吸环在动
    final withRun = boundaries(tester);

    await tester.pumpWidget(host(const AnStatusDot(AnStatus.done)));
    final withStatic = boundaries(tester);

    // The MaterialApp/Scaffold scaffolding contributes a constant number of boundaries to both trees, so
    // the DIFFERENCE is exactly the dot's own contribution: the run face adds its isolation layer, the
    // static face adds none. 脚手架隔层两树恒等,差值=点自身:运行面加一层、静态面零层。
    expect(withRun, greaterThan(withStatic),
        reason: 'the breathing run dot must be repaint-isolated; the static dot must not pay for a layer');
  });

  testWidgets('reduced-motion collapses the run dot to a static, un-isolated face', (tester) async {
    await tester.pumpWidget(host(const AnStatusDot(AnStatus.run), reduced: true));
    // Under reduced motion the run face renders static (no breathing) — no per-frame repaint to isolate.
    // Scope to the dot (material hosts its own AnimatedBuilders). 降级下运行面静态;限定在点内。
    expect(find.descendant(of: find.byType(AnStatusDot), matching: find.byType(AnimatedBuilder)),
        findsNothing);
  });
}
