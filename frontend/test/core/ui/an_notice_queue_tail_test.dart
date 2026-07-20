import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/ui/an_notice_queue_tail.dart';
import 'package:anselm/core/ui/an_status_dot.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cues = <NoticeCue>[
    NoticeCue(id: 'a', tone: AnTone.warn, kind: NoticeKind.approval),
    NoticeCue(id: 'b', tone: AnTone.danger, kind: NoticeKind.pill),
  ];

  Widget host(Widget child, {bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets(
    'one / two / overflow render at most two dots and +N excludes them',
    (tester) async {
      await tester.pumpWidget(
        host(
          AnNoticeQueueTail(
            cues: cues.take(1).toList(),
            overflowCount: 0,
            clearLabel: 'clear 2',
            onClear: () {},
          ),
        ),
      );
      expect(find.byType(AnStatusDot), findsOneWidget);

      await tester.pumpWidget(
        host(
          AnNoticeQueueTail(
            cues: cues,
            overflowCount: 0,
            clearLabel: 'clear 3',
            onClear: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnStatusDot), findsNWidgets(2));
      expect(find.text('+1'), findsNothing);

      await tester.pumpWidget(
        host(
          AnNoticeQueueTail(
            cues: cues,
            overflowCount: 18,
            clearLabel: 'clear 21',
            onClear: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnStatusDot), findsNWidgets(2));
      expect(find.text('+18'), findsOneWidget);
    },
  );

  testWidgets(
    '+N hover swaps to a tile-less X on the same fixed centre and clears',
    (tester) async {
      var clears = 0;
      await tester.pumpWidget(
        host(
          AnNoticeQueueTail(
            cues: cues,
            overflowCount: 18,
            clearLabel: 'clear 21',
            onClear: () => clears++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final countRect = tester.getRect(find.text('+18'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(countRect.center);
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.close), findsOneWidget);
      final clearButtonRect = tester.getRect(
        find.byKey(const ValueKey<String>('clear')),
      );
      final clearIconRect = tester.getRect(find.byIcon(AnIcons.close));
      expect(clearButtonRect.size, const Size.square(28));
      expect(
        clearButtonRect.center,
        countRect.center,
        reason:
            'the transparent 28px hit target stays centred in the 32px slot',
      );
      expect(
        clearIconRect.center,
        countRect.center,
        reason: '+N/X content swaps without moving the visual centre',
      );
      final face = find.descendant(
        of: find.byKey(const ValueKey<String>('clear')),
        matching: find.byType(AnimatedContainer),
      );
      expect(
        tester.widget<AnimatedContainer>(face).decoration,
        isA<BoxDecoration>()
            .having((d) => d.color, 'fill', isNull)
            .having((d) => d.shape, 'halo shape', BoxShape.circle),
        reason: '28px 是命中面，不是一个可见的圆角方块',
      );
      await tester.tap(find.byIcon(AnIcons.close));
      expect(clears, 1);
    },
  );

  testWidgets(
    'keyboard focus also reveals X; Enter clears; semantics carries exact total',
    (tester) async {
      var clears = 0;
      await tester.pumpWidget(
        host(
          AnNoticeQueueTail(
            cues: cues,
            overflowCount: 1,
            clearLabel: 'clear all 4 top notices',
            onClear: () => clears++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.close), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(clears, 1);
      expect(find.bySemanticsLabel('clear all 4 top notices'), findsOneWidget);
    },
  );

  testWidgets(
    'visual count caps at 999+ while exact count remains accessible',
    (tester) async {
      await tester.pumpWidget(
        host(
          AnNoticeQueueTail(
            cues: cues,
            overflowCount: 12000,
            clearLabel: 'clear all 12003 top notices',
            onClear: () {},
          ),
        ),
      );
      expect(find.text('999+'), findsOneWidget);
      expect(
        find.bySemanticsLabel('clear all 12003 top notices'),
        findsOneWidget,
      );
    },
  );
}
