import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/announce_probe.dart';

void main() {
  Widget host(Widget child, {double width = 300, bool reduced = false}) =>
      TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (ctx) {
                    return reduced
                        ? MediaQuery(
                            data: MediaQuery.of(
                              ctx,
                            ).copyWith(disableAnimations: true),
                            child: child,
                          )
                        : child;
                  },
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets(
    'shimmers (ShaderMask) normally; static (no ShaderMask) under reduced-motion + settles',
    (tester) async {
      await tester.pumpWidget(host(const AnSkeleton.text()));
      await tester.pump();
      expect(find.byType(ShaderMask), findsOneWidget); // animated sweep present

      await tester.pumpWidget(host(const AnSkeleton.text(), reduced: true));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(
        tester.takeException(),
        isNull,
      ); // no ticker left running under reduced
      expect(find.byType(ShaderMask), findsNothing); // froze to flat bones
    },
  );

  testWidgets(
    'a11y: labelled "loading" and FINDABLE — but deliberately never announced',
    (tester) async {
      final handle = tester.ensureSemantics();
      final said = probeAnnouncements(tester);
      await tester.pumpWidget(host(const AnSkeleton.card()));
      // NOT pumpAndSettle — the shimmer is an infinite .repeat(). Two pumps cover mount + the post-frame
      // callback an announcement would ride on. 不用 pumpAndSettle(扫光是无限循环);两 pump 覆盖挂载 + post-frame。
      await tester.pump();
      await tester.pump();
      expect(tester.getSemantics(find.byType(AnSkeleton)).label, 'Loading');
      // A skeleton is a SHAPE, and callers render many at once (AnRailSkeleton lays 5 rows; the scheduler
      // pages pair a .card() with a .lines(6)) — pushing on mount would shout "loading" 5–7 times for ONE
      // screen. The news a reader wants is the CONTENT, which announces itself. 骨架是形状、且一次渲很多个;
      // 挂载即推=一屏喊 5–7 声。**滥播报比不播报更糟**。
      expect(said, isEmpty, reason: '骨架刻意不播报——一屏多个,喊起来是噪声');
      handle.dispose();
    },
  );

  testWidgets(
    'a rail of 5 skeleton rows still says nothing (the over-announce case, measured)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final said = probeAnnouncements(tester);
      await tester.pumpWidget(host(const AnRailSkeleton()));
      await tester.pump();
      await tester.pump();
      expect(said, isEmpty, reason: '5 行骨架 = 5 声「加载中」,正是本裁定要挡的');
      handle.dispose();
    },
  );

  testWidgets('all variants build with no overflow in a narrow box', (
    tester,
  ) async {
    for (final v in [
      const AnSkeleton.text(),
      const AnSkeleton.lines(4),
      const AnSkeleton.row(),
      const AnSkeleton.card(),
    ]) {
      await tester.pumpWidget(
        host(v, width: 180, reduced: true),
      ); // reduced so pumpAndSettle terminates
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'variant overflowed or hung',
      );
    }
  });
}
