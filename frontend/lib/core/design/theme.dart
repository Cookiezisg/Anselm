import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Assembles [ThemeData] from the design tokens — the single bridge between our [AnColors] /
/// [AnText] and Material. Registers [AnColors] as a ThemeExtension (read via `context.colors`),
/// bakes the type scale + ink into the TextTheme, and strips Material's web-ish defaults
/// (splashes, loose density) for a crisp native desktop feel.
///
/// 由 token 装配 [ThemeData]——[AnColors]/[AnText] 与 Material 的唯一桥。注册 AnColors 扩展、
/// 把字阶+墨色烤进 TextTheme、去掉 Material 的水波/松散密度,换利落原生桌面手感。
abstract final class AnTheme {
  static ThemeData light() => _build(Brightness.light, AnColors.light, SyntaxColors.light, GraphColors.light);
  static ThemeData dark() => _build(Brightness.dark, AnColors.dark, SyntaxColors.dark, GraphColors.dark);

  static ThemeData _build(Brightness brightness, AnColors c, SyntaxColors syntax, GraphColors graph) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.canvas,
      // No Material ripples/overlays — our surfaces own their own hover/press via tokens. This
      // also stops any Material leaf (TextField, future InkWell) flashing its default gray overlay.
      // 去 Material 水波/叠加——我们的表面自管 hover/press;也杜绝 Material 叶子闪默认灰叠加。
      splashFactory: NoSplash.splashFactory,
      splashColor: const Color(0x00000000),
      highlightColor: const Color(0x00000000),
      hoverColor: const Color(0x00000000),
      focusColor: const Color(0x00000000),
      visualDensity: VisualDensity.standard,
      fontFamily: AnText.uiFamily,
      fontFamilyFallback: AnText.uiFallback,
      textTheme: AnText.textTheme(c.ink),
      extensions: <ThemeExtension<dynamic>>[c, syntax, graph],
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(surface: c.surface, onSurface: c.ink),
    );
  }
}
