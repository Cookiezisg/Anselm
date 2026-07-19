import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/chat/ui/tool_card_fs_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Grep parsers + GrepContentView (B4 F02.2) — three output modes + inline match highlight. Grep 三模式。
void main() {
  group('parseGrepContent', () {
    test('multi-file: path:line:text (match) + path-line-text (context), grouped', () {
      const out = 'a.py:8:  hit one\na.py-9-  ctx after\nb.py:2:  hit two';
      final g = parseGrepContent(out, '/ws');
      expect(g.length, 2); // two files
      expect(g[0].path, 'a.py');
      expect(g[0].lines[0].isMatch, isTrue);
      expect(g[0].lines[0].line, 8);
      expect(g[0].lines[1].isMatch, isFalse); // context line
    });
    test('single-file: bare line:text (no path prefix)', () {
      const out = '8:  hit\n9-  ctx';
      final g = parseGrepContent(out, '/ws/a.py');
      expect(g.length, 1);
      expect(g[0].path, '/ws/a.py'); // path from the arg
      expect(g[0].lines[0].line, 8);
    });
    test('noise lines (-- separator / truncation / No matches) are dropped', () {
      const out = 'a.py:1:x\n--\na.py:5:y\n... [truncated at 200 lines; …]';
      final g = parseGrepContent(out, '/ws');
      expect(g[0].lines.length, 2);
    });
  });

  group('parseGrepCount', () {
    test('path:N (stdlib) + bare N (rg single-file)', () {
      expect(parseGrepCount('a.py:5\nb.py:12', '/ws').length, 2);
      final bare = parseGrepCount('7', '/ws/a.py');
      expect(bare.single.path, '/ws/a.py');
      expect(bare.single.count, 7);
    });
  });

  group('parseGrepFiles', () {
    test('one path per line, noise dropped', () {
      expect(parseGrepFiles('a.py\nb.py\n... [truncated at 100 files; …]'), ['a.py', 'b.py']);
    });
  });

  testWidgets('highlightMatches: the pattern is highlighted; an uncompilable pattern degrades to plain',
      (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AnTheme.light(), home: Builder(builder: (context) {
      final c = context.colors;
      final spans = highlightMatches('the amount and amounts', 'amount', c, base: const TextStyle());
      // 'amount' appears twice → at least 2 highlighted spans among the parts. 至少两处点亮。
      expect(spans.length, greaterThan(1));
      // an uncompilable regex → a single plain span (never a crash). 编译失败→单纯 span。
      final bad = highlightMatches('a(b', 'a(', c, base: const TextStyle());
      expect(bad.length, 1);
      return const SizedBox();
    })));
  });
}
