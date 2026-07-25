import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/code_diff.dart';
import 'package:anselm/core/ui/an_version_diff.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WRK-077 VT — the two numbers the ticket demanded be MEASURED, not guessed.
///
/// (1) `lineDiff`'s real degrade point: the LCS DP matrix is capped by CELL COUNT
/// ([lineDiffMaxCells]); this pins where the cap trips and what the worst legal (just-under-cap) run
/// costs, so «should we swap in Myers?» is answered by a stopwatch. (2) The virtualized diff's per-frame
/// build cost: with the rows as slivers, a bounded viewport must only ever build its visible window —
/// the structural fact behind «show all on a huge file doesn't drop frames» (a widget test has no frame
/// timeline, so the invariant is asserted as «rows built», which is what a frame pays for).
///
/// CAVEAT — `flutter test` is debug-JIT, ~2–5× slower than the release-AOT the user ships, so the
/// printed milliseconds are a PESSIMISTIC upper bound. Assertions are deliberately loose ceilings (a
/// regression detector, not a benchmark): the PRINTED numbers are the deliverable.
///
/// WRK-077 VT——工单要求「先测再改」的两个数:①`lineDiff` 真实降级点(cell 闸在哪翻、闸下最坏一档多贵),
/// 于是「要不要换 Myers」由秒表回答;②虚拟化后有界视口每帧只建可见窗(「大文件展开全部不掉帧」背后的结构事实;
/// widget 测拿不到帧时间线,故断言落在「建了几行」——那正是一帧要付的钱)。注:debug JIT 比 release 慢 2–5×,
/// 打印的毫秒是上界;断言是宽松天花板(防回归、非基准),真正的交付物是打印出来的数。
void main() {
  String body(int n, {String prefix = 'line'}) =>
      [for (var i = 0; i < n; i++) '    $prefix$i = compute($i)'].join('\n');

  test('lineDiff: where the cell cap trips, and what the worst legal run costs', () {
    final rows = <String>[];
    int? lastUnderCapMs;
    for (final n in [500, 1000, 1500, 1997, 2000, 3000]) {
      final a = body(n);
      final b = body(n, prefix: 'val');
      final cells = (a.split('\n').length + 1) * (b.split('\n').length + 1);
      final degraded = cells > lineDiffMaxCells;
      final sw = Stopwatch()..start();
      final out = lineDiff(a, b);
      sw.stop();
      rows.add(
        '$n lines · $cells cells · ${degraded ? 'DEGRADED' : 'real LCS'} · '
        '${sw.elapsedMilliseconds}ms · ${out.length} ops',
      );
      if (!degraded) lastUnderCapMs = sw.elapsedMilliseconds;
      // The cap's contract: past it there is NO context line (whole-segment replace). 闸上零上下文。
      if (degraded) {
        expect(out.every((l) => l.op != DiffOp.context), isTrue);
      }
    }
    // ignore: avoid_print
    print(
      'lineDiff degrade curve (cap=$lineDiffMaxCells cells):\n  ${rows.join('\n  ')}',
    );
    // 1997×1997 is the worst run the cap still allows. A loose ceiling: if this ever needs seconds, the
    // «keep LCS, don't reach for Myers» verdict has to be revisited. 闸下最坏一档的宽松天花板。
    expect(
      lastUnderCapMs,
      lessThan(2000),
      reason:
          'the worst under-cap LCS must stay in the tens of ms, not seconds',
    );
  });

  testWidgets('a 6002-row diff in a bounded card builds only its visible window', (
    tester,
  ) async {
    // 3000 vs 3000 lines with nothing in common → past the cap → all-del + all-add = 6002 rows and NOT
    // ONE context line, so hunk folding cannot help: virtualization is the only thing left.
    // 3000 vs 3000 全不相同→过闸→全删+全增=6002 行且零上下文,hunk 无可折,只剩虚拟化。
    final before = [for (var i = 0; i < 3000; i++) 'old_$i'].join('\n');
    final after = [for (var i = 0; i < 3000; i++) 'new_$i'].join('\n');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 480,
              child: AnVersionDiff(
                before: before,
                after: after,
                reading: true,
                hunks: true,
                maxHeight: 320,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byWidgetPredicate(
      (w) => w is Container && w.padding == const EdgeInsets.only(right: 12),
    );
    final first = rowFinder.evaluate().length;
    var worst = first;
    final sw = Stopwatch()..start();
    final scroller = find
        .descendant(
          of: find.byType(AnVersionDiff),
          matching: find.byType(Scrollable),
        )
        .last;
    for (var i = 0; i < 20; i++) {
      await tester.drag(scroller, const Offset(0, -280));
      await tester.pump();
      final n = rowFinder.evaluate().length;
      if (n > worst) worst = n;
    }
    sw.stop();
    // ignore: avoid_print
    print(
      'bounded 6002-row diff: $first rows on first paint, worst $worst rows mounted, '
      '20 scroll steps in ${sw.elapsedMilliseconds}ms (debug JIT)',
    );
    expect(
      worst,
      lessThan(120),
      reason: 'a 320px viewport must never mount thousands of rows',
    );
  });
}
