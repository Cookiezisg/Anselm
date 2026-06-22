import 'package:flutter/material.dart';

/// Typography — a modular scale anchored on a 13px UI body (the reading-comfort anchor;
/// everything else derives). Styles carry an explicit family ([uiFamily] = Inter) with
/// system fallbacks: today, Inter is not yet bundled so it falls back to the platform UI
/// font (SF Pro on macOS) — identical to before — but declaring it gives cross-platform
/// consistency the moment Inter is bundled, and a single named family the screenshot
/// harness can inject. Colorless on purpose: color is applied once by the theme and
/// inherited, so text adapts to light/dark without any widget restating it.
///
/// 字体——模数阶梯,锚在 13px 正文。样式带显式字族([uiFamily]=Inter)+ 系统回退:Inter 暂未打包,
/// 故回退到平台 UI 字体(macOS=SF Pro,与之前一致);声明它使打包后三平台一致,且给截图夹具一个可注入的
/// 字族名。刻意不带色:色由主题统一施加并继承,文本自适应明暗。
abstract final class AnText {
  /// Intended UI family (not yet bundled → falls back to system). 预期 UI 字族(未打包→回退系统)。
  static const String uiFamily = 'Inter';
  static const List<String> uiFallback = [
    'SF Pro Text', 'PingFang SC', 'Microsoft YaHei', 'Hiragino Sans GB',
    'Segoe UI', 'Noto Sans', 'sans-serif',
  ];
  static const String monoFamily = 'SF Mono';
  static const List<String> monoFallback = [
    'SFMono-Regular', 'Menlo', 'JetBrains Mono', 'Consolas', 'monospace',
  ];

  static const TextStyle h1 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 32, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 24, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.3,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.2,
  );
  static const TextStyle strong = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 16, height: 1.4, fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, // the UI anchor 正文锚
  );
  static const TextStyle bodyProse = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 13, height: 1.6, fontWeight: FontWeight.w400, // long-form reading 长文阅读
  );
  static const TextStyle label = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w500, letterSpacing: 0.1,
  );
  static const TextStyle meta = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w400, // muted secondary 次级
  );
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 13, height: 1.5, fontWeight: FontWeight.w400,
  );

  /// Map the scale onto Material's [TextTheme] and bake the ink color in once.
  /// 把字阶映射到 Material [TextTheme] 并一次性注入墨色。
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
