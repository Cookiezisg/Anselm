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
  static ThemeData light() => _build(
    Brightness.light,
    AnColors.light,
    SyntaxColors.light,
    GraphColors.light,
  );
  static ThemeData dark() => _build(
    Brightness.dark,
    AnColors.dark,
    SyntaxColors.dark,
    GraphColors.dark,
  );

  static ThemeData _build(
    Brightness brightness,
    AnColors c,
    SyntaxColors syntax,
    GraphColors graph,
  ) {
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
      // The caret + selection FLOOR for every Material text field (the An caret law's root). Without it
      // Flutter falls back to the seeded `colorScheme.primary` — a hue that exists in NO token table
      // (fromSeed derives it from accent) — for the caret, and to `primaryColor.withOpacity(0.40)` for the
      // selection band. The band was the live bug: `TextField` has NO selectionColor parameter, so this
      // theme is the ONLY seam that can give it — every field was painting the seeded ghost while the
      // editor painted [AnColors.selection], two selection colours in one app. Fields still pass
      // `cursorColor` explicitly (an_input / an_composer / an_secret_field / an_code_editor — same token,
      // stated at the primitive); this is the net that catches anything that forgets.
      // 每个 Material 字段的光标+选区地板(An 光标法的根):不设则 Flutter 回落到 fromSeed 派生的 primary
      // (一个 token 表里根本不存在的色)当光标色、`primary.withOpacity(0.40)` 当选区带。选区带是真出血:
      // TextField **没有** selectionColor 参数,此主题是唯一能给它的缝——此前全部字段画幽灵靛、而编辑器画
      // AnColors.selection,同一 app 两种选区色。各字段仍显式传 cursorColor(同一 token,在原语处言明),
      // 本条是兜住「忘了传」的网。
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.selection,
      ),
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
