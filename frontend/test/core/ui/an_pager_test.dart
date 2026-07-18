import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnPager (WRK-070 B4) — the standard page-number pager. Pins: single page renders nothing;
// windowed number strip; ‹/› step + clamp; jump field commits a clamped page.
// 翻页器契约:单页不渲/开窗带/步进钳制/跳页钳制。

void main() {
  final s = AnPagerStrings(
    prevLabel: 'prev',
    nextLabel: 'next',
    jumpHint: 'page',
    pageLabel: (n) => 'page $n',
  );

  Widget host(int page, int count, void Function(int) onPage) => MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: Center(
            child: AnPager(page: page, pageCount: count, onPage: onPage, strings: s),
          ),
        ),
      );

  testWidgets('a single page renders NOTHING (拍板:没有多页就不显示)', (tester) async {
    await tester.pumpWidget(host(1, 1, (_) {}));
    expect(find.byType(AnPager), findsOneWidget);
    expect(find.text('1'), findsNothing, reason: '单页=空白');
  });

  testWidgets('windowed strip folds the middle to a … sentinel', (tester) async {
    await tester.pumpWidget(host(6, 12, (_) {}));
    // 1 … 5 6 7 … 12 — first, last, current±1, two ellipses. 首末+当前±1+双 …。
    for (final n in ['1', '5', '6', '7', '12']) {
      expect(find.text(n), findsOneWidget, reason: '窗内应含 $n');
    }
    expect(find.text('…'), findsNWidgets(2));
    expect(find.text('3'), findsNothing, reason: '窗外页折进 …');
  });

  testWidgets('‹ is disabled on page 1; › on the last page', (tester) async {
    var got = -1;
    await tester.pumpWidget(host(1, 3, (p) => got = p));
    await tester.tap(find.bySemanticsLabel('prev'));
    await tester.pump();
    expect(got, -1, reason: '首页 ‹ 压灰不派发');
    await tester.tap(find.bySemanticsLabel('next'));
    await tester.pump();
    expect(got, 2);
  });

  testWidgets('tapping a number navigates; the current number is inert', (tester) async {
    var got = -1;
    await tester.pumpWidget(host(2, 5, (p) => got = p));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(got, 3);
    got = -1;
    await tester.tap(find.text('2')); // current — inert 当前页惰性
    await tester.pump();
    expect(got, -1);
  });

  testWidgets('few pages (≤7): ALL numbers, NO jump field (Ant 定式:很少就不需要跳转)',
      (tester) async {
    await tester.pumpWidget(host(2, 7, (_) {}));
    for (var p = 1; p <= 7; p++) {
      expect(find.text('$p'), findsOneWidget, reason: '≤7 页全列');
    }
    expect(find.text('…'), findsNothing);
    expect(find.byType(EditableText), findsNothing, reason: '少页无跳转输入');
  });

  testWidgets('the jump field appears when folded and commits a CLAMPED page on submit',
      (tester) async {
    var got = -1;
    await tester.pumpWidget(host(1, 12, (p) => got = p));
    expect(find.byType(EditableText), findsOneWidget, reason: '折叠(>7)才有跳页');
    await tester.enterText(find.byType(EditableText), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(got, 12, reason: '越界跳页钳到末页');
  });
}
