import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnVersionDiff = the unified version-diff (lineDiff + inline highlightCode). LCS correctness is the
// code_diff unit test; here: rendering, +N/−N counts, range/note, earliest-version, new-file line
// numbers (deleted lines have none), bare, a11y. AnVersionDiff 渲染/计数/范围/最早版本/行号/bare/a11y。
void main() {
  Widget host(Widget child, {double width = 460, double height = 360}) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: width, height: height, child: child))),
        ),
      );

  testWidgets('renders context / deleted / added lines', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(before: 'alpha\nbeta', after: 'alpha\ngamma', lang: 'py')));
    await tester.pumpAndSettle();
    expect(find.textContaining('alpha'), findsOneWidget); // context
    expect(find.textContaining('beta'), findsOneWidget); // deleted
    expect(find.textContaining('gamma'), findsOneWidget); // added
  });

  testWidgets('+N / −N counts in the bar', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(before: 'alpha\nbeta', after: 'alpha\ngamma', range: 'v1 → v2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('+1'), findsOneWidget); // one add
    expect(find.textContaining('−1'), findsOneWidget); // one del (U+2212)
    expect(find.text('v1 → v2'), findsOneWidget); // range label
  });

  testWidgets('note renders (ellipsized single line)', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(before: 'a', after: 'b', note: 'tweaked the thing')));
    await tester.pumpAndSettle();
    expect(find.text('tweaked the thing'), findsOneWidget);
  });

  testWidgets('earliest version (before null) → all context, no +/− counts', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(before: null, after: 'one\ntwo\nthree', lang: 'py', range: 'v1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('one'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing); // no add count
    expect(find.text('1\n2\n3'), findsNothing); // numbers are per-row (separate widgets), not a block
  });

  testWidgets('new-file line numbers: context/added increment, deleted has none', (tester) async {
    // alpha(ctx,1) beta(del,—) gamma(add,2) → numbers 1 and 2 present, del row blank. 删行无号。
    await tester.pumpWidget(host(const AnVersionDiff(before: 'alpha\nbeta', after: 'alpha\ngamma')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget); // alpha
    expect(find.text('2'), findsOneWidget); // gamma (NOT 3 — deleted beta took no number) 删行不占号
    expect(find.text('3'), findsNothing);
  });

  testWidgets('bare drops the frame + bar (inline diff)', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(before: 'a = 1', after: 'a = 2', bare: true, range: 'v1 → v2')));
    await tester.pumpAndSettle();
    expect(find.byType(AnCodeSurface), findsOneWidget); // surface present...
    expect(find.text('v1 → v2'), findsNothing); // ...but bare → no bar/range
  });

  testWidgets('all-replace (no common lines): every old line del, every new line add', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(before: 'x1\nx2', after: 'y1\ny2', range: 'v1 → v2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('+2'), findsOneWidget);
    expect(find.textContaining('−2'), findsOneWidget);
  });

  testWidgets('special characters render as plain text (no injection)', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(before: '<b>old</b>', after: '<b>new</b> & x', lang: 'md')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('<b>new</b> & x'), findsOneWidget);
  });

  testWidgets('a11y: container labelled with counts; rows merge with an Added/Removed prefix', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnVersionDiff(before: 'alpha\nbeta', after: 'alpha\ngamma')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Diff, 1 added, 1 removed')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Added: gamma')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Removed: beta')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('long line scrolls horizontally without overflow', (tester) async {
    await tester.pumpWidget(host(const AnVersionDiff(
      before: 'short',
      after: 'a really long replacement line that exceeds the diff viewport width and must scroll',
      lang: 'py',
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
