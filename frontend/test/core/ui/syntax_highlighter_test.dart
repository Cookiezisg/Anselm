import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/ui/syntax_highlighter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// highlightCode = the ONE syntax tokenizer (WRK-040 G5.0). Pure-function tests: the lossless invariant
// (no glyph dropped/dup'd) + per-token-group colouring + CEL interpolation. 唯一 tokenizer 的纯函数测。
void main() {
  const c = SyntaxColors.light;
  String joined(List<TextSpan> s) => s.map((e) => e.text ?? '').join();
  TextSpan spanFor(List<TextSpan> s, String text) =>
      s.firstWhere((e) => e.text == text);
  Color? colorOf(List<TextSpan> s, String text) =>
      spanFor(s, text).style?.color;

  test('empty input → no spans', () {
    expect(highlightCode('', colors: c), isEmpty);
  });

  test(
    'LOSSLESS: concatenated span text equals the input (no glyph dropped or duplicated)',
    () {
      for (final src in <String>[
        'plain text no tokens',
        'def f(x):\n    return x + 1  # add one',
        'a = "str" + `tpl` + \'q\'',
        'has(input.x) ? input.x : "fallback"',
        '{{ user.name }} / \${env} / \$1',
        'x\n\n\ny', // blank lines
        '日本語 + 中文 // comment', // non-ASCII passes through
      ]) {
        expect(
          joined(highlightCode(src, colors: c)),
          src,
          reason: 'must round-trip: $src',
        );
      }
    },
  );

  test('keyword → keyword colour', () {
    final s = highlightCode('return', colors: c);
    expect(colorOf(s, 'return'), c.keyword);
  });

  test('identifier followed by ( → function colour; otherwise plain', () {
    final fn = highlightCode('foo(1)', colors: c);
    expect(colorOf(fn, 'foo'), c.function);
    final plain = highlightCode('foo bar', colors: c);
    expect(
      spanFor(plain, 'foo').style?.color,
      isNull,
      reason: 'not a call → plain, inherits ambient',
    );
  });

  test('function detection skips whitespace before the paren', () {
    final s = highlightCode('foo  (1)', colors: c);
    expect(colorOf(s, 'foo'), c.function);
  });

  test('string literal → string colour (double / single / backtick)', () {
    expect(colorOf(highlightCode('"hi"', colors: c), '"hi"'), c.string);
    expect(colorOf(highlightCode("'hi'", colors: c), "'hi'"), c.string);
    expect(colorOf(highlightCode('`hi`', colors: c), '`hi`'), c.string);
  });

  test('comment → comment colour + italic (# line, // line, /* block */)', () {
    final hash = highlightCode('# c', colors: c);
    expect(colorOf(hash, '# c'), c.comment);
    expect(spanFor(hash, '# c').style?.fontStyle, FontStyle.italic);
    expect(colorOf(highlightCode('// c', colors: c), '// c'), c.comment);
    expect(colorOf(highlightCode('/* c */', colors: c), '/* c */'), c.comment);
  });

  test('number → number colour (int + decimal)', () {
    expect(colorOf(highlightCode('42', colors: c), '42'), c.number);
    expect(colorOf(highlightCode('3.14', colors: c), '3.14'), c.number);
  });

  test(
    'CEL / interpolation → arg colour + bold ({{ }} / \${ } / \$n) [decision 4]',
    () {
      final tpl = highlightCode('{{ user.name }}', colors: c);
      expect(colorOf(tpl, '{{ user.name }}'), c.arg);
      // Two-weight law (批8 普查): emphasis is w400, never a heavier third tier. 两档字重铁律。
      expect(
        spanFor(tpl, '{{ user.name }}').style?.fontWeight,
        FontWeight.w400,
      );
      expect(colorOf(highlightCode('\${env}', colors: c), '\${env}'), c.arg);
      expect(colorOf(highlightCode('\$1', colors: c), '\$1'), c.arg);
    },
  );

  test(
    'CEL expression colours keyword + function + string together (unified tokenizer covers CEL)',
    () {
      // control when: `has(input.flag) ? input.x : "d"` — `has` is a call, `"d"` a string, `input` plain.
      final s = highlightCode('has(input.flag) ? "d" : "e"', colors: c);
      expect(colorOf(s, 'has'), c.function);
      expect(colorOf(s, '"d"'), c.string);
      expect(joined(s), 'has(input.flag) ? "d" : "e"');
    },
  );

  test(
    'lang param is accepted and does not change v1 tokenization (unified)',
    () {
      final withLang = highlightCode('def f()', lang: 'python', colors: c);
      final without = highlightCode('def f()', colors: c);
      expect(joined(withLang), joined(without));
      expect(colorOf(withLang, 'def'), c.keyword);
    },
  );
}
