import 'package:flutter/material.dart';

/// Typography — a modular scale anchored on a 13px UI body (the reading-comfort anchor;
/// everything else derives). [uiFamily] = MiSans, the demo's first-choice family, BUNDLED with
/// the app (a variable font covering Latin + Simplified Chinese; see pubspec.yaml). Bundling is
/// deliberate: the bilingual UI renders the exact same face on every machine, with no drift
/// from whatever fonts happen to be installed. The fallback chain only catches glyphs MiSans
/// lacks (system UI font → CJK → generic). Colorless on purpose: color is applied once by the
/// theme and inherited, so text adapts to light/dark without any widget restating it.
///
/// 字体——模数阶梯,锚在 13px 正文。[uiFamily]=MiSans(demo 首选),**随 app 打包**(变量字体,覆盖
/// Latin+简体中文,见 pubspec.yaml)。打包是刻意的:双语 UI 在每台机器渲染同一字面,不随机器装了什么漂移。
/// 回退链只兜 MiSans 缺的字形(系统 UI 字 → 中文 → 通用)。刻意不带色:色由主题统一施加并继承。
abstract final class AnText {
  /// Bundled UI family — MiSans variable font (pubspec). 打包 UI 字族——MiSans 变量字体。
  static const String uiFamily = 'MiSans';
  static const List<String> uiFallback = [
    '.AppleSystemUIFont', 'SF Pro Text', 'PingFang SC',
    'Microsoft YaHei', 'Hiragino Sans GB', 'Segoe UI', 'Noto Sans', 'sans-serif',
  ];
  static const String monoFamily = 'SF Mono';
  static const List<String> monoFallback = [
    'SFMono-Regular', 'JetBrains Mono', 'Menlo', 'Roboto Mono', 'Consolas', 'monospace',
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
