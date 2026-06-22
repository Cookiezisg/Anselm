import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/syntax.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A read-only, selectable code block with lightweight syntax highlighting (comments /
/// strings / numbers / keywords / function calls), colored via [AnSyntax]. A regex
/// highlighter — good enough for display of Python/JS/JSON; the editable editor is a
/// later, feature-coupled component.
/// 只读可选代码块 + 轻量语法高亮(注释/字符串/数字/关键字/函数调用),色取自 [AnSyntax]。正则高亮,
/// 用于展示 Python/JS/JSON 足矣;可编辑编辑器是后续 feature 耦合件。
class AnCodeBlock extends StatelessWidget {
  const AnCodeBlock(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sx = context.syntax;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AnSpace.s12),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(AnRadius.button),
        border: Border.all(color: c.line, width: AnSize.hairline),
      ),
      child: SelectableText.rich(
        TextSpan(style: AnText.mono.copyWith(color: c.ink), children: _spans(code, sx)),
      ),
    );
  }
}

final RegExp _hl = RegExp(
  r'''(#[^\n]*|//[^\n]*)|("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)|(\b\d[\w.]*\b)|(\b(?:def|class|return|if|elif|else|for|while|import|from|as|in|is|not|and|or|None|True|False|async|await|with|try|except|finally|raise|lambda|yield|pass|break|continue|const|let|var|function|new|null|true|false|export|default|typeof|void)\b)|([A-Za-z_]\w*(?=\s*\())''',
  multiLine: true,
);

List<InlineSpan> _spans(String code, AnSyntax sx) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _hl.allMatches(code)) {
    if (m.start > last) spans.add(TextSpan(text: code.substring(last, m.start)));
    final Color? color = m.group(1) != null
        ? sx.comment
        : m.group(2) != null
            ? sx.string
            : m.group(3) != null
                ? sx.number
                : m.group(4) != null
                    ? sx.keyword
                    : m.group(5) != null
                        ? sx.function
                        : null;
    spans.add(TextSpan(text: m.group(0), style: color == null ? null : TextStyle(color: color)));
    last = m.end;
  }
  if (last < code.length) spans.add(TextSpan(text: code.substring(last)));
  return spans;
}
