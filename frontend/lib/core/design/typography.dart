import 'package:flutter/material.dart';

/// Typography — a modular scale anchored on a 13px UI body (everything else derives). [uiFamily] =
/// the OS SYSTEM UI font (SF Pro on macOS) — exactly what the demo's `"MiSans", -apple-system, …`
/// stack resolves to on a Mac without MiSans installed, i.e. the light, native Apple type the
/// design targets. Bundled MiSans + system PingFang SC are the CJK fallback (Latin uses the system
/// face). Colorless on purpose: the theme applies ink once and it inherits, so light/dark just work.
///
/// 字体——模数阶梯,锚在 13px 正文。[uiFamily]=OS 系统 UI 字体(macOS 上即 SF Pro)——正是 demo 字体栈在未装
/// MiSans 的 Mac 上落到的 -apple-system,轻盈原生、设计本意。打包的 MiSans + 系统 PingFang SC 兜 CJK(Latin 用系统字)。
abstract final class AnText {
  static const String uiFamily = '.AppleSystemUIFont'; // SF on macOS; non-Apple falls to the chain 苹果系=SF,他平台走回退
  static const List<String> uiFallback = [
    'MiSans', 'PingFang SC', 'Microsoft YaHei', 'Segoe UI', 'Noto Sans', 'sans-serif',
  ];
  static const String monoFamily = 'JetBrains Mono'; // BUNDLED (assets/fonts) — deterministic code face 随包,代码字面确定
  static const List<String> monoFallback = [
    'SF Mono', 'SFMono-Regular', 'Menlo', 'Consolas', 'monospace',
  ];

  static const TextStyle h1 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 32, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.5,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 24, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: -0.3,
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
  static const TextStyle label = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 13, height: 1.4, fontWeight: FontWeight.w500,
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
