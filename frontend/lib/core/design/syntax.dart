import 'package:flutter/material.dart';

/// Code syntax-highlight colors as their own [ThemeExtension] (`context.syntax`). Code is
/// the one place dense color genuinely aids reading, so it is kept even in an otherwise
/// monochrome UI. Values are the One Light / One Dark families. Kept separate from
/// [AnColors] so the chrome palette stays small and syntax can evolve independently.
///
/// 代码高亮色,独立 [ThemeExtension](`context.syntax`)。代码是密集配色真正助读之处,故单色 UI 里仍保留。
/// 取 One Light / One Dark 系。与 [AnColors] 分开,使 chrome 调色板精简、语法配色独立演进。
@immutable
class AnSyntax extends ThemeExtension<AnSyntax> {
  const AnSyntax({
    required this.comment,
    required this.keyword,
    required this.string,
    required this.number,
    required this.function,
  });

  final Color comment;
  final Color keyword;
  final Color string;
  final Color number;
  final Color function;

  static const AnSyntax light = AnSyntax(
    comment: Color(0xFFA0A1A7),
    keyword: Color(0xFFA626A4),
    string: Color(0xFF50A14F),
    number: Color(0xFF986801),
    function: Color(0xFF4078F2),
  );

  static const AnSyntax dark = AnSyntax(
    comment: Color(0xFF7F848E),
    keyword: Color(0xFFC678DD),
    string: Color(0xFF98C379),
    number: Color(0xFFD19A66),
    function: Color(0xFF61AFEF),
  );

  @override
  AnSyntax copyWith({
    Color? comment,
    Color? keyword,
    Color? string,
    Color? number,
    Color? function,
  }) {
    return AnSyntax(
      comment: comment ?? this.comment,
      keyword: keyword ?? this.keyword,
      string: string ?? this.string,
      number: number ?? this.number,
      function: function ?? this.function,
    );
  }

  @override
  AnSyntax lerp(ThemeExtension<AnSyntax>? other, double t) {
    if (other is! AnSyntax) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AnSyntax(
      comment: c(comment, other.comment),
      keyword: c(keyword, other.keyword),
      string: c(string, other.string),
      number: c(number, other.number),
      function: c(function, other.function),
    );
  }
}

extension AnSyntaxContext on BuildContext {
  AnSyntax get syntax => Theme.of(this).extension<AnSyntax>()!;
}
