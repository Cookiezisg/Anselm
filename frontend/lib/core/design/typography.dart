import 'package:flutter/material.dart';

/// Typography — a modular scale anchored on a 13px UI body. [uiFamily] = BUNDLED MiSans, a variable
/// font (wght axis 150–700) covering Latin + Simplified Chinese, so the bilingual UI renders the
/// same on every machine (the demo's intent). We render it LIGHT — body at Light (w300) — to shed
/// the heavy look MiSans has at Regular (ExtraLight 200 was too thin for some glyphs); the ramp
/// climbs from there. Colorless on purpose: the theme applies ink once and it inherits.
///
/// 字体——模数阶梯,锚 13px 正文。[uiFamily]=**随包 MiSans**(变量字体,wght 150–700,Latin+简中),每台机器同字面
/// (demo 本意)。整体**压细**——正文 Light(w300)(ExtraLight 200 部分字偏细);字重阶梯由此上爬。
abstract final class AnText {
  static const String uiFamily = 'MiSans'; // BUNDLED VF (assets/fonts/MiSansVF.ttf), rendered light 随包变量字体,渲染压细
  static const List<String> uiFallback = [
    'PingFang SC', 'Microsoft YaHei', 'Segoe UI', 'Noto Sans', 'sans-serif',
  ];
  static const String monoFamily = 'JetBrains Mono'; // BUNDLED (assets/fonts) — deterministic code face 随包,代码字面确定
  static const List<String> monoFallback = [
    'SF Mono', 'SFMono-Regular', 'Menlo', 'Consolas', 'monospace',
  ];

  // Weight ramp anchored on a Light body (w300). EVERY style sets BOTH fontWeight AND an explicit
  // wght [FontVariation] — Text honours fontWeight on a VF, but TextField/EditableText only render
  // the right weight when the axis is explicit, so without this an edit field looked heavier/wider
  // than the display text it replaced. With both, Text and field render identically.
  // 字重阶梯锚 Light(w300)。每个样式同时给 fontWeight + 显式 wght 变量轴——Text 认 fontWeight,但 TextField
  // 只在显式指定轴时才渲染对的字重,否则编辑框比展示文字更粗更宽。两者都给 → Text 与输入框完全一致。
  static const TextStyle h1 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 32, height: 1.25, fontWeight: FontWeight.w500, fontVariations: [FontVariation('wght', 500)], letterSpacing: -0.5,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 24, height: 1.25, fontWeight: FontWeight.w500, fontVariations: [FontVariation('wght', 500)], letterSpacing: -0.3,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 20, height: 1.3, fontWeight: FontWeight.w500, fontVariations: [FontVariation('wght', 500)], letterSpacing: -0.2,
  );
  static const TextStyle strong = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 16, height: 1.4, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], // emphasis = Regular 强调=Regular
  );
  static const TextStyle body = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 13, height: 1.4, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)], // the UI anchor — Light 正文锚·Light
  );
  static const TextStyle label = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 13, height: 1.4, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)], // Light 标签·Light
  );
  static const TextStyle meta = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)], // muted secondary — Light 次级·Light
  );
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 13, height: 1.5, fontWeight: FontWeight.w400,
  );

  /// The value-column base style — the single source for the "值列 tabular 铁律": tabular figures
  /// UNCONDITIONALLY so digit columns align AND the idle↔editing toggle never changes width; [mono] only
  /// switches the family (ids / hashes). Shared by AnKv / AnField / AnEditableValue / AnInput so a retune
  /// can't drift across copies. Callers add the colour via `copyWith`. 值列样式单源(无条件 tabular);颜色另加。
  static TextStyle value({bool mono = false}) => mono
      ? AnText.mono.copyWith(fontSize: meta.fontSize, fontFeatures: const [FontFeature.tabularFigures()])
      : body.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

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

/// Re-weight a variable-font [TextStyle] CORRECTLY — sets BOTH [fontWeight] AND the explicit `wght`
/// [FontVariation]. On a VF the explicit `wght` axis OVERRIDES [fontWeight]; since every [AnText]
/// style already pins `fontVariations`, changing only `fontWeight` via `copyWith` renders the BASE
/// weight (the axis wins). The single correct idiom for any re-weight (group labels, ref pills, card
/// titles, table headers). 变量字体重定权:双轴同改——单改 fontWeight 会被已钉的 wght 轴覆盖、渲染原重。
extension AnTextWeight on TextStyle {
  TextStyle weight(FontWeight w) =>
      copyWith(fontWeight: w, fontVariations: [FontVariation('wght', w.value.toDouble())]);
}
