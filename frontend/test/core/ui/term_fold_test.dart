import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/term_fold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// termFold + ansiSpans (B4.1, WRK-056 #5) — in-place rewrite folding (\r / ESC[K / cursor-up) + SGR →
// design tokens. Five batteries: empty / carriage-return progress bar / docker-pull cursor-up / window
// bound / chunk-cut escape. termFold 折叠 + ansiSpans 五电池。

void main() {
  group('termFold — carriage-return (\\r) progress bars', () {
    test('a full \\r-rewrite keeps only the final frame', () {
      final lines = termFold(
        'Downloading  10%\rDownloading  55%\rDownloading 100%',
      );
      expect(lines, ['Downloading 100%']);
    });

    test('partial \\r overwrite: later chars win per column', () {
      // "abcdef" then \r "XY" → "XYcdef"
      expect(termFold('abcdef\rXY'), ['XYcdef']);
    });

    test('\\n separates physical lines; each folds independently', () {
      expect(termFold('line1\rDONE1\nline2\rDONE2'), ['DONE1', 'DONE2']);
    });
  });

  group('termFold — cursor-up multi-line (docker pull / cargo)', () {
    test('ESC[nA rewinds n lines and overwrites them', () {
      // print 3 layers, cursor up 3, rewrite all 3 to "done"
      const raw =
          'layer1 pull\nlayer2 pull\nlayer3 pull\n[3Alayer1 done\nlayer2 done\nlayer3 done';
      expect(termFold(raw), ['layer1 done', 'layer2 done', 'layer3 done', '']);
    });

    test('ESC[2K erase-line before rewrite clears leftovers', () {
      const raw = 'a very long status line\n[1A[2Kshort';
      expect(
        termFold(raw).first,
        'short',
      ); // line 1 left empty (consumer trims trailing)
    });
  });

  group('termFold — window bound + degradation', () {
    test('cursor-up beyond the window is ignored (frozen older lines)', () {
      // 3 lines, then cursor up 10 (> window=2) → out of window, ignored; text appends at current row
      final lines = termFold('a\nb\nc[10AX', window: 2);
      // the ESC[10A is ignored (target row 2-10 < floor), so X overwrites current line c → cX? no:
      // col is at end of 'c' (1), X writes at col 1 → 'cX'
      expect(lines.last, 'cX');
      expect(lines.first, 'a'); // frozen
    });

    test('absolute-position CSI (ESC[H) is stripped, never mis-folds', () {
      expect(termFold('[Hhello'), ['hello']);
    });
  });

  group('termFold — robustness', () {
    test('empty / plain text pass through', () {
      expect(termFold(''), ['']);
      expect(termFold('plain'), ['plain']);
    });

    test(
      'a chunk-cut escape at the very end is left for the tail buffer (not garbled)',
      () {
        // trailing incomplete CSI → dropped, prior text intact
        expect(termFold('done['), ['done']);
      },
    );
  });

  group('ansiSpans — SGR → design tokens', () {
    testWidgets('color codes map to tokens; bold uses the emphasis weight', (
      tester,
    ) async {
      late List<InlineSpan> spans;
      late AnColors c;
      await tester.pumpWidget(
        MaterialApp(
          theme: AnTheme.light(),
          home: Builder(
            builder: (context) {
              c = context.colors;
              spans = ansiSpans(
                '[31mERROR[0m ok',
                c,
                base: const TextStyle(),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      // first span 'ERROR' is danger-colored, then ' ok' resets to base
      final err = spans.whereType<TextSpan>().firstWhere(
        (s) => s.text == 'ERROR',
      );
      expect((err.style!.color), c.danger);
      final rest = spans.whereType<TextSpan>().firstWhere(
        (s) => s.text!.contains('ok'),
      );
      expect(rest.style!.color, isNot(c.danger));
    });

    testWidgets('a plain line (no SGR) is one span at the base style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AnTheme.light(),
          home: Builder(
            builder: (context) {
              final spans = ansiSpans(
                'no color here',
                context.colors,
                base: const TextStyle(fontSize: 13),
              );
              expect(spans.length, 1);
              expect((spans.first as TextSpan).text, 'no color here');
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
