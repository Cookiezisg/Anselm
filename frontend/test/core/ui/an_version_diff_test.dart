import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnVersionDiff = the unified version-diff (lineDiff + inline highlightCode). LCS correctness is the
// code_diff unit test; here: rendering, +N/−N counts, range/note, earliest-version, new-file line
// numbers (deleted lines have none), bare, a11y — plus (WRK-077 VT) hunk mode, the whole-file escape,
// the wrap seed and the sliver virtualization.
// AnVersionDiff 渲染/计数/范围/最早版本/行号/bare/a11y + (VT)hunk 模式/整份逃生口/wrap 种子/sliver 虚拟化。
void main() {
  // Every diff ROW (and every gap marker) is the one Container carrying the row's right inset — the
  // cheapest honest way to COUNT what was actually built (the point of virtualization).
  // 每条 diff 行(含 gap 标记)都是那唯一带右内距的 Container——数「真建了几行」最诚实的便宜办法。
  final rowFinder = find.byWidgetPredicate(
    (w) => w is Container && w.padding == const EdgeInsets.only(right: 12),
  );
  String lines(int n, {int? changeAt}) => [
    for (var i = 0; i < n; i++)
      i == changeAt ? 'CHANGED_$i' : 'line_$i = compute($i)',
  ].join('\n');

  Widget host(Widget child, {double width = 460, double height = 360}) =>
      TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, height: height, child: child),
            ),
          ),
        ),
      );

  testWidgets('renders context / deleted / added lines', (tester) async {
    await tester.pumpWidget(
      host(
        const AnVersionDiff(
          before: 'alpha\nbeta',
          after: 'alpha\ngamma',
          lang: 'py',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('alpha'), findsOneWidget); // context
    expect(find.textContaining('beta'), findsOneWidget); // deleted
    expect(find.textContaining('gamma'), findsOneWidget); // added
  });

  testWidgets('+N / −N counts in the bar', (tester) async {
    await tester.pumpWidget(
      host(
        const AnVersionDiff(
          before: 'alpha\nbeta',
          after: 'alpha\ngamma',
          range: 'v1 → v2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('+1'), findsOneWidget); // one add
    expect(find.textContaining('−1'), findsOneWidget); // one del (U+2212)
    expect(find.text('v1 → v2'), findsOneWidget); // range label
  });

  testWidgets(
    'counts are pinned to the top-right edge even with a range + note present',
    (tester) async {
      // Regression (user-reported): a Flexible note + a Spacer (two flex children) split the slack and
      // left +N/−N short of the right edge; one filler pins it right. 回归:双 flex 致计数不贴右,单填充修。
      await tester.pumpWidget(
        host(
          const AnVersionDiff(
            before: 'a\nb',
            after: 'a\nc',
            range: 'v3 → v4',
            note: 'rename + add param',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final countsRight = tester.getRect(find.textContaining('+1')).right;
      final diffRight = tester.getRect(find.byType(AnVersionDiff)).right;
      expect(
        diffRight - countsRight,
        lessThan(AnSpace.s16),
        reason: 'counts hug the right edge (only the cap padding between)',
      );
    },
  );

  testWidgets('note renders (ellipsized single line)', (tester) async {
    await tester.pumpWidget(
      host(
        const AnVersionDiff(before: 'a', after: 'b', note: 'tweaked the thing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('tweaked the thing'), findsOneWidget);
  });

  testWidgets('earliest version (before null) → all context, no +/− counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnVersionDiff(
          before: null,
          after: 'one\ntwo\nthree',
          lang: 'py',
          range: 'v1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('one'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing); // no add count
    expect(
      find.text('1\n2\n3'),
      findsNothing,
    ); // numbers are per-row (separate widgets), not a block
  });

  testWidgets(
    'new-file line numbers: context/added increment, deleted has none',
    (tester) async {
      // alpha(ctx,1) beta(del,—) gamma(add,2) → numbers 1 and 2 present, del row blank. 删行无号。
      await tester.pumpWidget(
        host(const AnVersionDiff(before: 'alpha\nbeta', after: 'alpha\ngamma')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget); // alpha
      expect(
        find.text('2'),
        findsOneWidget,
      ); // gamma (NOT 3 — deleted beta took no number) 删行不占号
      expect(find.text('3'), findsNothing);
    },
  );

  testWidgets('bare drops the frame + bar (inline diff)', (tester) async {
    await tester.pumpWidget(
      host(
        const AnVersionDiff(
          before: 'a = 1',
          after: 'a = 2',
          bare: true,
          range: 'v1 → v2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnCodeSurface), findsOneWidget); // surface present...
    expect(find.text('v1 → v2'), findsNothing); // ...but bare → no bar/range
  });

  testWidgets(
    'all-replace (no common lines): every old line del, every new line add',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AnVersionDiff(
            before: 'x1\nx2',
            after: 'y1\ny2',
            range: 'v1 → v2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('+2'), findsOneWidget);
      expect(find.textContaining('−2'), findsOneWidget);
    },
  );

  testWidgets('special characters render as plain text (no injection)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnVersionDiff(
          before: '<b>old</b>',
          after: '<b>new</b> & x',
          lang: 'md',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('<b>new</b> & x'), findsOneWidget);
  });

  testWidgets(
    'a11y: container labelled with counts; rows merge with an Added/Removed prefix',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const AnVersionDiff(before: 'alpha\nbeta', after: 'alpha\ngamma')),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('Diff, 1 added, 1 removed')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Added: gamma')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Removed: beta')), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('long line scrolls horizontally without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnVersionDiff(
          before: 'short',
          after:
              'a really long replacement line that exceeds the diff viewport width and must scroll',
          lang: 'py',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('hunk mode (WRK-077 VT)', () {
    testWidgets('folds the unchanged stretches, keeps 3 lines each side', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            before: lines(30),
            after: lines(30, changeAt: 15),
            hunks: true,
          ),
          height: 900,
        ),
      );
      await tester.pumpAndSettle();
      // The change + its 3-line context bands are rendered… 变更与其上下 3 行在场。
      expect(find.textContaining('CHANGED_15'), findsOneWidget);
      expect(find.textContaining('line_12'), findsOneWidget);
      expect(find.textContaining('line_18'), findsOneWidget);
      // …the far reaches are NOT — they are behind the two fold markers. 远处不在场,藏在两条折叠标记后。
      expect(find.textContaining('line_0 '), findsNothing);
      expect(find.textContaining('line_29'), findsNothing);
      expect(find.textContaining('unchanged lines'), findsNWidgets(2));
    });

    testWidgets('tapping a fold marker reveals exactly that run', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            before: lines(30),
            after: lines(30, changeAt: 15),
            hunks: true,
          ),
          height: 900,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('unchanged lines').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('line_0 '), findsOneWidget); // head revealed
      expect(
        find.textContaining('unchanged lines'),
        findsOneWidget,
      ); // the tail run stays folded 尾段仍折
      expect(find.textContaining('line_29'), findsNothing);
    });

    testWidgets('no changes at all → nothing folds (earliest version)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnVersionDiff(before: null, after: lines(30), hunks: true),
          height: 900,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('unchanged lines'), findsNothing);
      expect(find.textContaining('line_0 '), findsOneWidget);
    });

    testWidgets(
      'the whole-file escape renders only when wired, and hands the mode back',
      (tester) async {
        bool? got;
        await tester.pumpWidget(
          host(
            AnVersionDiff(
              before: lines(30),
              after: lines(30, changeAt: 15),
              hunks: true,
              onHunksChanged: (v) => got = v,
            ),
            height: 900,
          ),
        );
        await tester.pumpAndSettle();
        // 31 after-lines → the label counts the file, not the hunk. 标签数的是整份行数。
        expect(find.text('Show all (31 lines)'), findsOneWidget);
        await tester.tap(find.text('Show all (31 lines)'));
        await tester.pumpAndSettle();
        expect(got, isFalse, reason: 'the caller owns the mode');
      },
    );

    testWidgets('no callback → no escape row (a consumer that never leaves)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            before: lines(30),
            after: lines(30, changeAt: 15),
            hunks: true,
          ),
          height: 900,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Show all'), findsNothing);
    });

    testWidgets('hunks:false with the callback offers the fold-back label', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            before: lines(30),
            after: lines(30, changeAt: 15),
            onHunksChanged: (_) {},
          ),
          height: 900,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Only changes'), findsOneWidget);
      expect(find.textContaining('unchanged lines'), findsNothing);
    });
  });

  group('virtualization + width (WRK-077 VT)', () {
    testWidgets('bounded host builds only the visible window of a big diff', (
      tester,
    ) async {
      // 400 lines, one changed, WHOLE text (hunks off) — the shape «show all» produces. 展开全部的形状。
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            before: lines(400),
            after: lines(400, changeAt: 200),
            maxHeight: 320,
          ),
          height: 400,
        ),
      );
      await tester.pumpAndSettle();
      final built = rowFinder.evaluate().length;
      expect(built, greaterThan(5), reason: 'the visible window IS built');
      expect(
        built,
        lessThan(80),
        reason: '401 rows must NOT all be built in a 320px viewport',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('unbounded host lays out every row (no viewport, no laziness)', (
      tester,
    ) async {
      // The version page's shape: the HOST owns the document scroll, so the diff has no viewport of its
      // own and can only shrink-wrap. 版本页的形状:滚动权在宿主,diff 无自己的视口,只能 shrinkWrap。
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: AnVersionDiff(
                    before: lines(40),
                    after: lines(40, changeAt: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 40 after-lines + 1 del = 41 rows, all built because the host owns the scroll. 全建(滚动权在宿主)。
      expect(rowFinder.evaluate().length, 41);
    });

    testWidgets('non-wrap uses the fixed-extent tier; wrap uses SliverList', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AnVersionDiff(before: lines(8), after: lines(8, changeAt: 4))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SliverFixedExtentList), findsOneWidget);
      expect(find.byType(SliverList), findsNothing);

      // A DIFFERENT key so the State is rebuilt: `wrap` seeds the initial face (AnCodeEditor's own
      // contract) — re-pumping the same element keeps the toggle the reader last set.
      // 换 key 才重建 State:wrap 只是初始脸(与 AnCodeEditor 同契约),同元素重 pump 保留读者上次的开关。
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            key: const ValueKey('wrapped'),
            before: lines(8),
            after: lines(8, changeAt: 4),
            wrap: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverFixedExtentList), findsNothing);
    });

    testWidgets('wrap seeds the soft-wrap face: nothing to scroll sideways', (
      tester,
    ) async {
      final long = 'x' * 400;
      await tester.pumpWidget(
        host(AnVersionDiff(before: 'a', after: long, wrap: true)),
      );
      await tester.pumpAndSettle();
      final pos = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(AnVersionDiff),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(
        pos.maxScrollExtent,
        0,
        reason: 'wrapped rows fit the viewport — no horizontal extent',
      );

      // Non-wrap on the same content DOES have somewhere to scroll (fresh key = fresh face).
      // 非 wrap 则真有横向可滚(换 key 取新脸)。
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            key: const ValueKey('nonwrapped'),
            before: 'a',
            after: long,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pos2 = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(AnVersionDiff),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(pos2.maxScrollExtent, greaterThan(0));
    });

    testWidgets('a 5000-char space-less line renders without hanging', (
      tester,
    ) async {
      final wall = 'y' * 5000;
      await tester.pumpWidget(
        host(AnVersionDiff(before: 'a', after: wall, wrap: true, hunks: true)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a revealed gap survives scrolling the virtualized rows', (
      tester,
    ) async {
      // Three changes far apart → two folds, and enough rows to scroll a 320 viewport. 三处变更→两条折叠。
      final before = lines(200);
      final after = [
        for (var i = 0; i < 200; i++)
          (i == 10 || i == 100 || i == 190)
              ? 'CHANGED_$i'
              : 'line_$i = compute($i)',
      ].join('\n');
      await tester.pumpWidget(
        host(
          AnVersionDiff(
            before: before,
            after: after,
            hunks: true,
            maxHeight: 320,
          ),
          height: 400,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('unchanged lines'), findsNWidgets(2));
      await tester.tap(find.textContaining('unchanged lines').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('line_0 '), findsOneWidget);

      final vertical = find
          .descendant(
            of: find.byType(AnVersionDiff),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.drag(vertical, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.drag(vertical, const Offset(0, 400));
      await tester.pumpAndSettle();
      // Still revealed after the rows were disposed + rebuilt. 行被销毁重建后仍是展开态。
      expect(find.textContaining('line_0 '), findsOneWidget);
      expect(find.textContaining('unchanged lines'), findsOneWidget);
    });
  });
}
