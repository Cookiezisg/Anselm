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
  // WRK-083 L12 — the tail lives inside a CompositedTransformFollower, and a Flutter [Tooltip] cannot
  // compute its position there.
  //
  // The band's design is deliberate (app_shell `_BandNoticeHost`): the current card is a paint target
  // centred on its own, and the candidate tail FOLLOWS its right edge through a LayerLink WITHOUT
  // participating in layout — that is what guarantees «1 / 2 / +N can never nudge the card left». But a
  // FollowerLayer establishes its paint transform only AFTER layout, and Tooltip's overlay asks for that
  // transform DURING layout. Real machine: hovering `+N` threw
  // «The paint transform cannot be reliably computed because of RenderFollowerLayer(s)» — and **no
  // tooltip appeared at all**. So it was not a mispositioned label, it was a dead affordance that cost a
  // rendering assertion on every hover. The accessible name never depended on it (the Semantics label
  // right below is what a screen reader reads), and the glyph already says the thing: `+N` → `✕`.
  //
  // The guard hosts the tail the way the app does — INSIDE a follower — because a bare tail cannot
  // reproduce this at all: every existing test in this file renders it in a plain Center and is green.
  //
  // WRK-083 L12——尾巴住在 CompositedTransformFollower 里,而 Flutter 的 [Tooltip] 在那里算不出自己的位置。
  //
  // 顶带的设计是刻意的(app_shell 的 `_BandNoticeHost`):当前卡是自己居中的 paint target,候场尾经 LayerLink
  // **跟随它的右缘且不参与布局**——这正是「1/2/+N 永不把卡往左挤」的保证。但 FollowerLayer 的 paint transform
  // 要**布局之后**才确立,而 Tooltip 的 overlay 在**布局期**就来要这个 transform。真机:hover `+N` 抛出
  // 「The paint transform cannot be reliably computed because of RenderFollowerLayer(s)」,且**根本没有任何
  // tooltip 出现**。所以它不是「标签位置错了」,是一个**死的**示能,代价是每次 hover 抛一次渲染断言。可访问名
  // 从来不靠它(下面那个 Semantics label 才是屏幕阅读器读的),而字形本身已经把话说清:`+N` → `✕`。
  //
  // 守卫必须**按 app 的样子**把尾巴装进 follower——裸着的尾巴根本复现不了:本文件既有的每一条都把它渲在一个
  // 普通 Center 里,故全是绿的。
  testWidgets(
    'hovering the clear affordance inside a FOLLOWER throws nothing (L12)',
    (tester) async {
      final link = LayerLink();
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 400,
            height: 80,
            child: Stack(
              children: [
                CompositedTransformTarget(
                  link: link,
                  child: const SizedBox(width: 40, height: 36),
                ),
                Positioned.fill(
                  child: CompositedTransformFollower(
                    link: link,
                    targetAnchor: Alignment.topRight,
                    followerAnchor: Alignment.topLeft,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: AnNoticeQueueTail(
                        cues: cues,
                        overflowCount: 3,
                        clearLabel: 'clear 5',
                        onClear: () {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('+3')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2)); // past the dwell 越过驻留
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'a hover on the tail must not throw — a Tooltip inside a CompositedTransformFollower '
            'asserts during layout and shows nothing (WRK-083 L12)',
      );
    },
  );
}
