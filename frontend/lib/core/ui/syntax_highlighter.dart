/// The ONE syntax tokenizer (WRK-040 G5.0 铁律·唯一高亮源) — a port of the demo's regex highlighter
/// (`code-editor.js`). AnCodeEditor renders it; AnVersionDiff colours each diff line through it;
/// AnJsonTree leans on it for value tinting. NEVER write a second tokenizer — colour code only here.
///
/// Design (per WRK-040 decision 1 = port the demo regex; decision 4 = CEL coloured here):
/// - SYNCHRONOUS + pure → returns `List<TextSpan>` immediately, so streaming `.value` repaints and
///   per-line diff tinting need no async preload (async-init packages were vetoed, §4 铁律·同步).
/// - LANGUAGE-AGNOSTIC: one regex + one keyword set covers Python / JS / Markdown / JSON. CEL needs
///   NO separate tokenizer — its interpolation `{{ }}` / `${ }` is captured natively as the [arg]
///   group, satisfying decision 4 inside this single entry point. [lang] is accepted for API
///   stability + the caller's language label; v1 does not branch on it.
/// - Colours come from [SyntaxColors] (passed in, since a pure fn can't read context). Untokenized
///   gaps are emitted as plain unstyled spans so they inherit the widget's code text colour.
///
/// 唯一语法 tokenizer(移植 demo code-editor.js)。同步纯函数(流式/逐行 diff 免异步)、语言无关(单正则+单 KW 集
/// 覆盖 py/js/md/json;CEL 插值经 arg 组天然覆盖、无须第二套)。色吃 SyntaxColors,未着色间隙留白继承代码色。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../design/colors.dart';

// Keyword set — verbatim from the demo (mixed Python/JS/etc; one set for all langs). 关键字集(移植 demo,语言混合)。
const Set<String> _keywords = {
  'const',
  'let',
  'var',
  'function',
  'def',
  'class',
  'return',
  'if',
  'elif',
  'else',
  'for',
  'while',
  'do',
  'in',
  'of',
  'import',
  'from',
  'export',
  'default',
  'new',
  'await',
  'async',
  'try',
  'except',
  'catch',
  'finally',
  'raise',
  'throw',
  'with',
  'as',
  'lambda',
  'yield',
  'and',
  'or',
  'not',
  'is',
  'None',
  'True',
  'False',
  'true',
  'false',
  'null',
  'undefined',
  'self',
  'this',
  'match',
  'case',
  'pass',
  'break',
  'continue',
};

// Tokenizer — verbatim port of the demo's TOK. Five ordered groups:
//   1 comment  (# line / // line / /* block */)
//   2 string   (backtick / "double" / 'single', with escapes)
//   3 arg      (${...} / $n / {{...}} — interpolation, incl. CEL)
//   4 number   (\d+(.\d+)?)
//   5 ident    ([A-Za-z_$][\w$]*) → keyword | function (followed by '(') | plain
// Triple-quoted raw so the embedded ' and " in the string group need no escaping.
// 五组有序 tokenizer(逐字移植 demo);三引号 raw 串容纳内嵌的 ' 与 "。
final RegExp _tok = RegExp(
  r'''(#[^\n]*|//[^\n]*|/\*[\s\S]*?\*/)|(`(?:\\.|[^`\\])*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(\$\{[^}]*\}|\$\d+|\{\{[^}]*\}\})|(\b\d+(?:\.\d+)?\b)|([A-Za-z_$][\w$]*)''',
);

/// Tokenize [code] into coloured [TextSpan]s using [colors]. [lang] is accepted for API/label
/// stability (v1 uses the unified tokenizer for every language). Wrap the result in a parent span:
/// `Text.rich(TextSpan(children: highlightCode(code, colors: context.syntax)))`.
/// 把 code 切成着色 TextSpan(lang 仅为 API/标签稳定,v1 统一 tokenizer)。
/// The number of full tokenizer passes run — a perf probe for the memoization guards (C-012/013/014):
/// tests assert this does NOT climb when a code widget rebuilds with unchanged code / on a caret move.
/// 全量分词次数探针:测试断言无变化重建/移光标时不增。
@visibleForTesting
int highlightCodePasses = 0;

List<TextSpan> highlightCode(
  String code, {
  String? lang,
  required SyntaxColors colors,
}) {
  highlightCodePasses++;
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in _tok.allMatches(code)) {
    if (m.start > last) {
      spans.add(TextSpan(text: code.substring(last, m.start)));
    }
    final comment = m.group(1);
    final string = m.group(2);
    final arg = m.group(3);
    final number = m.group(4);
    if (comment != null) {
      spans.add(
        TextSpan(
          text: comment,
          style: TextStyle(color: colors.comment, fontStyle: FontStyle.italic),
        ),
      );
    } else if (string != null) {
      spans.add(
        TextSpan(
          text: string,
          style: TextStyle(color: colors.string),
        ),
      );
    } else if (arg != null) {
      spans.add(
        TextSpan(
          text: arg,
          style: TextStyle(color: colors.arg, fontWeight: FontWeight.w400),
        ),
      );
    } else if (number != null) {
      spans.add(
        TextSpan(
          text: number,
          style: TextStyle(color: colors.number),
        ),
      );
    } else {
      final word = m.group(5)!;
      if (_keywords.contains(word)) {
        spans.add(
          TextSpan(
            text: word,
            style: TextStyle(color: colors.keyword),
          ),
        );
      } else if (_followedByParen(code, m.end)) {
        spans.add(
          TextSpan(
            text: word,
            style: TextStyle(color: colors.function),
          ),
        );
      } else {
        spans.add(
          TextSpan(text: word),
        ); // plain → inherits ambient code colour 留白继承代码色
      }
    }
    last = m.end;
  }
  if (last < code.length) spans.add(TextSpan(text: code.substring(last)));
  return spans;
}

// An identifier is a function name if the next non-whitespace char is '(' (demo /^\s*\(/). Scans code
// units (NOT `code.substring(from)` + a RegExp) so a file of N identifiers stays O(N), not O(N²) from
// copying the tail each time. ASCII whitespace only (space/tab/newline/CR/FF/VT) — INTENTIONALLY narrower
// than JS `\s` (which also matches U+00A0/U+2000–200A/…): a Unicode space between an identifier and its
// call paren does not occur in real source, and matching it isn't worth a per-identifier Unicode scan.
// 标识符后跟 ( 视为函数名。按 code unit 扫(非 substring+正则)保 O(N);只认 ASCII 空白(有意窄于 JS \s——代码里
// 标识符与调用括号间不会有 Unicode 空白,不值得逐标识符做 Unicode 扫描)。
bool _followedByParen(String code, int from) {
  for (var i = from; i < code.length; i++) {
    final ch = code.codeUnitAt(i);
    if (ch == 0x20 || (ch >= 0x09 && ch <= 0x0D)) {
      continue; // ASCII whitespace 空白
    }
    return ch == 0x28; // '('
  }
  return false;
}
