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

  group('AnZonedPage — prose zones keep 720, a full-bleed zone breaks out (WRK-069 判决③ 豁免)', () {
    testWidgets('a prose zone is clamped + centered exactly like AnPage\'s body', (tester) async {
      await tester.pumpWidget(host(
        AnZonedPage(zones: [
          AnPageZone(Container(key: const Key('prose'), height: 100, color: const Color(0xFF000000))),
        ]),
        w: 1200,
        h: 400,
      ));
      final w = tester.getSize(find.byKey(const Key('prose'))).width;
      expect(w, lessThanOrEqualTo(AnSize.content + 0.5), reason: '散文区守 720 阅读列');
      expect(w, lessThan(1200));
    });

    testWidgets('a full-bleed zone spans the ocean width (minus the page inset)', (tester) async {
      await tester.pumpWidget(host(
        AnZonedPage(zones: [
          AnPageZone(Container(key: const Key('wide'), height: 100, color: const Color(0xFF000000)),
              fullBleed: true),
        ]),
        w: 1200,
        h: 400,
      ));
      final w = tester.getSize(find.byKey(const Key('wide'))).width;
      // Measured against the page's OWN width (the test surface bounds the host box). 对页实测宽断言。
      final pageW = tester.getSize(find.byType(AnZonedPage)).width;
      expect(w, greaterThan(AnSize.content), reason: '全宽区破 720 列(时间轴/矩阵横向密度)');
      expect(w, pageW - AnInset.pageX * 2, reason: '占满海洋宽,只留页 inset');
    });

    testWidgets('the two zone kinds coexist in ONE scroll region', (tester) async {
      await tester.pumpWidget(host(
        AnZonedPage(zones: [
          AnPageZone(Container(key: const Key('a'), height: 100, color: const Color(0xFF000000))),
          AnPageZone(Container(key: const Key('b'), height: 100, color: const Color(0xFF000000)),
              fullBleed: true),
          AnPageZone(Container(key: const Key('c'), height: 100, color: const Color(0xFF000000))),
        ]),
        w: 1200,
        h: 400,
      ));
      expect(find.byType(SingleChildScrollView), findsOneWidget, reason: '唯一滚动区');
      expect(tester.getSize(find.byKey(const Key('a'))).width, lessThanOrEqualTo(AnSize.content + 0.5));
      expect(tester.getSize(find.byKey(const Key('b'))).width, greaterThan(AnSize.content));
      expect(tester.getSize(find.byKey(const Key('c'))).width, lessThanOrEqualTo(AnSize.content + 0.5),
          reason: '全宽区之后仍回 720 列');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow ocean never overflows (the 720 clamp is a MAX, not a floor)',
        (tester) async {
      await tester.pumpWidget(host(
        AnZonedPage(zones: [
          AnPageZone(Container(key: const Key('p'), height: 60, color: const Color(0xFF000000))),
          AnPageZone(Container(key: const Key('w'), height: 60, color: const Color(0xFF000000)),
              fullBleed: true),
        ]),
        w: 320,
        h: 300,
      ));
      expect(tester.getSize(find.byKey(const Key('p'))).width, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
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
