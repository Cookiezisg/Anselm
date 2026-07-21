import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnHoverCard — the non-interactive hover detail card. THE regression this file exists for: the card's
// overlay child was a bare Positioned, which the Overlay theatre FORCES to the full stage with TIGHT
// constraints (tight beats the Container's maxWidth) — the card rendered as a screen-sized white slab
// covering half the app (用户 0718 真机撞上). The size lock below makes that shape unrepresentable.
// 大白片回归锁:裸 Positioned 被 Overlay 剧场强制铺满(tight 碾过 maxWidth),卡曾渲成挡半个 app 的全屏白板。

void main() {
  Widget host() => MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: Center(
        child: AnHoverCard(
          cardBuilder: (_) => const Text('card body'),
          child: const SizedBox(
            width: 24,
            height: 24,
            child: ColoredBox(color: Color(0xFFEEEEEE)),
          ),
        ),
      ),
    ),
  );

  Future<TestGesture> hover(WidgetTester tester) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byType(AnHoverCard)));
    addTearDown(g.removePointer);
    await tester.pump();
    return g;
  }

  testWidgets(
    'the card sizes to its CONTENT — never the full stage (0718 大白片回归锁)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      await hover(tester);
      await tester.pump(AnMotion.dwell);
      await tester.pump();
      final card = find
          .ancestor(
            of: find.text('card body'),
            matching: find.byType(Container),
          )
          .first;
      final rect = tester.getRect(card);
      expect(
        rect.width,
        lessThanOrEqualTo(AnSize.menuMaxWidth),
        reason: '卡宽 ≤ maxWidth token(绝不铺满舞台)',
      );
      expect(rect.height, lessThan(200), reason: '卡高按内容(一行文字),绝非全屏白板');
    },
  );

  testWidgets(
    'dwell manners: no card before the dwell elapses; exit hides it',
    (tester) async {
      await tester.pumpWidget(host());
      final g = await hover(tester);
      expect(find.text('card body'), findsNothing, reason: '驻留未满不现(划过不闪卡)');
      await tester.pump(AnMotion.dwell);
      await tester.pump();
      expect(find.text('card body'), findsOneWidget, reason: '驻留满即现');
      await g.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(find.text('card body'), findsNothing, reason: '离开即收');
    },
  );

  testWidgets(
    'the card is pure display: IgnorePointer + ExcludeSemantics (不可交互、不重复朗读)',
    (tester) async {
      await tester.pumpWidget(host());
      await hover(tester);
      await tester.pump(AnMotion.dwell);
      await tester.pump();
      expect(
        find.ancestor(
          of: find.text('card body'),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
        reason: '整卡 IgnorePointer(光标进不了卡,不与格争 hover)',
      );
      expect(
        find.ancestor(
          of: find.text('card body'),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
        reason: '整卡 ExcludeSemantics(读屏听格自己的句子)',
      );
    },
  );
}
