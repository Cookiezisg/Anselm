import 'package:anselm/core/model/code_diff.dart';
import 'package:flutter_test/flutter_test.dart';

// lineDiff = the pure LCS line diff behind AnVersionDiff. Framework-free golden tests: op sequence
// correctness on the cases that matter (identical / pure add / pure del / mid change / repeated lines
// / empty before / degrade gate). 纯 LCS diff 的 golden 单测。
void main() {
  List<DiffOp> ops(List<DiffLine> d) => [for (final l in d) l.op];
  List<String> texts(List<DiffLine> d) => [for (final l in d) l.text];
  int count(List<DiffLine> d, DiffOp op) => d.where((l) => l.op == op).length;

  test('identical text → all context, lines preserved in order', () {
    final d = lineDiff('a\nb\nc', 'a\nb\nc');
    expect(ops(d), [DiffOp.context, DiffOp.context, DiffOp.context]);
    expect(texts(d), ['a', 'b', 'c']);
  });

  test('pure addition → trailing adds after shared context', () {
    final d = lineDiff('a\nb', 'a\nb\nc');
    expect(ops(d), [DiffOp.context, DiffOp.context, DiffOp.add]);
    expect(texts(d), ['a', 'b', 'c']);
  });

  test('pure deletion → del between context', () {
    final d = lineDiff('a\nb\nc', 'a\nc');
    expect(ops(d), [DiffOp.context, DiffOp.del, DiffOp.context]);
    expect(texts(d), ['a', 'b', 'c']);
  });

  test('mid-line change → del (old) then add (new), del wins the tie', () {
    final d = lineDiff('a\nX\nc', 'a\nY\nc');
    expect(ops(d), [DiffOp.context, DiffOp.del, DiffOp.add, DiffOp.context]);
    expect(texts(d), ['a', 'X', 'Y', 'c']);
  });

  test('whole replace (no common lines) → all del then all add', () {
    final d = lineDiff('a\nb', 'c\nd');
    expect(count(d, DiffOp.context), 0);
    expect(count(d, DiffOp.del), 2);
    expect(count(d, DiffOp.add), 2);
    // dels come before adds (backtrack drains a, then b). 删在增前。
    expect(ops(d), [DiffOp.del, DiffOp.del, DiffOp.add, DiffOp.add]);
  });

  test(
    'repeated identical lines → keeps the LCS, removes the surplus copy',
    () {
      final d = lineDiff('x\nx\nx', 'x\nx');
      expect(count(d, DiffOp.context), 2);
      expect(count(d, DiffOp.del), 1);
      expect(count(d, DiffOp.add), 0);
      expect(texts(d).every((t) => t == 'x'), isTrue);
    },
  );

  test('blank lines participate as real (empty) lines', () {
    // trailing newline → a real trailing empty line; a blank line inserted in the middle is an add.
    final d = lineDiff('a\n\nb', 'a\n\n\nb');
    expect(count(d, DiffOp.add), 1); // one extra blank line added 多一空行
    expect(count(d, DiffOp.del), 0);
    expect(count(d, DiffOp.context), 3); // a, blank, b 共有
  });

  test(
    'empty before is NOT special-cased here (caller renders all-context) — split yields one empty line',
    () {
      final d = lineDiff('', 'a\nb');
      // "" splits to [""] so it diffs as: del the empty line, add a, add b. AnVersionDiff gates the
      // earliest-version case upstream (renders absent before as all-context). 空 before 由调用方上游处理。
      expect(ops(d), [DiffOp.del, DiffOp.add, DiffOp.add]);
      expect(texts(d), ['', 'a', 'b']);
    },
  );

  test(
    'degrade gate: beyond the cell cap → whole-segment replace (no LCS)',
    () {
      final before = List.generate(3000, (i) => 'b$i').join('\n'); // 3000 lines
      final after = List.generate(
        3000,
        (i) => 'a$i',
      ).join('\n'); // (3001)² ≈ 9M cells > 4M
      final d = lineDiff(before, after);
      expect(d.length, 6000);
      expect(count(d, DiffOp.context), 0, reason: 'degraded path runs no LCS');
      expect(count(d, DiffOp.del), 3000);
      expect(count(d, DiffOp.add), 3000);
      // all dels first, then all adds. 全删在前、全增在后。
      expect(d.take(3000).every((l) => l.op == DiffOp.del), isTrue);
      expect(d.skip(3000).every((l) => l.op == DiffOp.add), isTrue);
    },
  );

  test(
    'degrade gate: BALANCED diff trips the cell cap a total-line cap would miss (G5.0 review HIGH)',
    () {
      // m=n=2500 is only 5000 total lines but (2501)² ≈ 6.25M cells > 4M → must degrade (else a ~50MB
      // matrix). This is exactly the case an m+n line cap let through — pinned so it can't regress.
      // 平衡型 m=n=2500 仅 5000 行却 6.25M cell → 必退化;行数闸会漏、cell 闸封住。
      final before = List.generate(2500, (i) => 'b$i').join('\n');
      final after = List.generate(2500, (i) => 'a$i').join('\n');
      final d = lineDiff(before, after);
      expect(
        count(d, DiffOp.context),
        0,
        reason: 'the cell cap degrades the balanced case',
      );
      expect(count(d, DiffOp.del), 2500);
      expect(count(d, DiffOp.add), 2500);
    },
  );

  test(
    'under the cell cap → real LCS runs (large but identical → all context, not over-degraded)',
    () {
      // 1000 identical lines: (1001)² ≈ 1M cells < 4M → real LCS finds the full match (the degraded path
      // would have emitted del+add). Guards the gate against over-degrading legitimate medium files.
      // 1000 行恒等:~1M cell < 4M → 真跑 LCS 出全 ctx;防闸把正常中等文件误退化。
      final text = List.generate(1000, (i) => 'line$i').join('\n');
      final d = lineDiff(text, text);
      expect(
        count(d, DiffOp.context),
        1000,
        reason: 'below the cap LCS runs and finds the full match',
      );
      expect(count(d, DiffOp.del), 0);
      expect(count(d, DiffOp.add), 0);
    },
  );
}
