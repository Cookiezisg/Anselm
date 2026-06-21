import 'package:flutter/material.dart';

/// Typography — a modular scale anchored on a 13px UI body (not a power of two: it is the
/// reading-comfort anchor, everything else is derived). Styles are defined COLORLESS on
/// purpose: color is applied once by the theme (`buildTextTheme(ink)`) and inherited via
/// DefaultTextStyle, so text adapts to light/dark without any widget restating a color.
/// Tight negative tracking on large headings gives the crisp, high-end feel; line-heights
/// are always explicit.
///
/// 字体——模数阶梯,锚在 13px UI 正文(非 2 的幂:它是阅读舒适锚,其余由它派生)。样式刻意不带色:
/// 色由主题统一施加(`buildTextTheme(ink)`)、经 DefaultTextStyle 继承,故文本自适应明暗、无需 widget
/// 复述颜色。大标题用紧凑负字距获得高级利落感;行高永远显式。
abstract final class AnText {
  static const String _mono = 'monospace';
  static const List<String> _monoFallback = [
    'SF Mono',
    'Menlo',
    'JetBrains Mono',
    'Consolas',
  ];

  static const TextStyle h1 = TextStyle(
    fontSize: 32, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 24, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.3,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.2,
  );
  static const TextStyle strong = TextStyle(
    fontSize: 16, height: 1.4, fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, // the UI anchor 正文锚
  );
  static const TextStyle bodyProse = TextStyle(
    fontSize: 13, height: 1.6, fontWeight: FontWeight.w400, // long-form reading 长文阅读
  );
  static const TextStyle label = TextStyle(
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w500, letterSpacing: 0.1,
  );
  static const TextStyle meta = TextStyle(
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w400, // muted secondary 次级
  );
  static const TextStyle mono = TextStyle(
    fontSize: 13, height: 1.5, fontWeight: FontWeight.w400,
    fontFamily: _mono, fontFamilyFallback: _monoFallback,
  );

  /// Map the scale onto Material's [TextTheme] and bake the ink color in once, so any
  /// Material widget (and `Theme.of(context).textTheme`) inherits the same typography.
  /// 把字阶映射到 Material 的 [TextTheme] 并一次性注入墨色,使所有 Material widget 继承同一字体。
  static TextTheme textTheme(Color ink) => TextTheme(
        displayLarge: h1,
        displayMedium: h1,
        headlineLarge: h2,
        headlineMedium: h2,
        headlineSmall: h3,
        titleLarge: strong,
        titleMedium: strong,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: meta,
        labelLarge: label,
        labelMedium: label,
        labelSmall: meta,
      ).apply(bodyColor: ink, displayColor: ink);
}
