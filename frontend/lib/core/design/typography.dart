import 'package:flutter/material.dart';

/// Typography — a modular scale anchored on a 13px UI body. [uiFamily] = BUNDLED Inter (the
/// variable font, wght 100–900), the Latin/numeral face; CJK glyphs fall through to BUNDLED MiSans
/// (VF, wght 150–700) first in [uiFallback] — BOTH ship in the bundle, so the bilingual UI renders
/// the same on every machine (the demo's intent; Inter has no CJK coverage by design). The body
/// renders LIGHT (w300) and the ramp climbs from there. Colorless on purpose: the theme applies ink
/// once and it inherits.
///
/// 字体——模数阶梯,锚 13px 正文。[uiFamily]=**随包 Inter**(变量字体,wght 100–900),拉丁/数字字面;
/// 中文字形回落到 [uiFallback] 首位的**随包 MiSans**(VF,150–700)——两者皆入包,每台机器同字面(demo 本意;
/// Inter 本就不含 CJK)。正文压细 w300,字重阶梯由此上爬。刻意无色:主题上一次 ink、全部继承。
abstract final class AnText {
  static const String uiFamily = 'Inter'; // BUNDLED VF (assets/fonts/InterVariable.ttf) 随包变量字体
  static const List<String> uiFallback = [
    'MiSans', // BUNDLED — the CJK face (deterministic across machines) 随包中文字面,跨机器确定
    'PingFang SC', 'Microsoft YaHei', 'Segoe UI', 'Noto Sans', 'sans-serif',
  ];
  static const String monoFamily = 'JetBrains Mono'; // BUNDLED (assets/fonts) — deterministic code face 随包,代码字面确定
  // MiSans FIRST: the bundled JetBrains Mono already owns every latin/mono glyph, so the only
  // job of the fallback head is CJK — Chinese inside mono contexts (code comments, tool prose
  // results, terminal output) must hit the BUNDLED CJK face deterministically. Platform monos
  // stay as tail insurance only; ahead of MiSans they'd shadow it non-deterministically (the
  // test binding resolves unknown families to the FlutterTest font, whose sparse cmap turns
  // select CJK into solid boxes).
  // MiSans 置首:随包 JetBrains Mono 已覆盖全部拉丁/等宽字形,回退链头部唯一职责是 CJK——mono 语境
  // 的中文(代码注释/工具散文结果/终端输出)必须**确定性**落随包中文字面。平台 mono 只作尾部保险;
  // 排在 MiSans 前会不确定地遮蔽它(测试绑定把未知族解析成 FlutterTest 字体,其稀疏 cmap 把个别
  // CJK 渲成实心块)。
  static const List<String> monoFallback = [
    'MiSans', 'SF Mono', 'SFMono-Regular', 'Menlo', 'Consolas', 'monospace',
  ];

  // TWO-WEIGHT RULE — the WHOLE UI uses exactly two MiSans weights: [bodyWeight] (Light w300) for normal
  // text and [emphasisWeight] (Regular w400) for EVERYTHING emphasized (headings, titles, labels, nav).
  // NEVER w500/w600/SemiBold — re-weight via `.weight(AnText.emphasisWeight)`. (The code face is separate.)
  // 两种字重铁律:整套 UI 只用两种 MiSans 字重——正文 bodyWeight(Light w300)、一切加粗 emphasisWeight(Regular w400);
  // 禁 w500/w600/SemiBold,加粗一律 `.weight(AnText.emphasisWeight)`。(代码字面是另一套,不在此限。)
  static const FontWeight bodyWeight = FontWeight.w300;
  static const FontWeight emphasisWeight = FontWeight.w400;

  // Weight ramp anchored on a Light body (w300). EVERY style sets BOTH fontWeight AND an explicit
  // wght [FontVariation] — Text honours fontWeight on a VF, but TextField/EditableText only render
  // the right weight when the axis is explicit, so without this an edit field looked heavier/wider
  // than the display text it replaced. With both, Text and field render identically.
  // 字重阶梯锚 Light(w300)。每个样式同时给 fontWeight + 显式 wght 变量轴——Text 认 fontWeight,但 TextField
  // 只在显式指定轴时才渲染对的字重,否则编辑框比展示文字更粗更宽。两者都给 → Text 与输入框完全一致。
  static const TextStyle h1 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 32, height: 1.25, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.5,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 24, height: 1.25, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.3,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 20, height: 1.3, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.2,
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

  /// The CODE-SURFACE style (G5) — mono at meta size (12px) with a roomier prose line-height (demo
  /// --t-meta / --lh-prose=1.6). The SINGLE style shared by AnCodeEditor's gutter + code area and
  /// AnVersionDiff's rows so line numbers stay row-aligned with code (WRK-040 §4). Distinct from
  /// [mono] (13/1.5, inline ids) — code blocks want the tighter size + looser leading.
  /// 代码面样式:mono · 12px(meta)· 行高 1.6(prose);行号列与代码区共用之保对齐。区别于 mono(13/1.5 内联 id)。
  static const TextStyle code = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 12, height: 1.6, fontWeight: FontWeight.w400,
  );

  /// The value-column base style — the single source for the "值列 tabular 铁律": tabular figures
  /// UNCONDITIONALLY so digit columns align AND the idle↔editing toggle never changes width; [mono] only
  /// switches the family (ids / hashes). Shared by AnKv / AnField / AnEditableValue / AnInput so a retune
  /// can't drift across copies. Callers add the colour via `copyWith`. 值列样式单源(无条件 tabular);颜色另加。
  static TextStyle value({bool mono = false}) => mono
      ? AnText.mono.copyWith(fontSize: meta.fontSize, fontFeatures: const [FontFeature.tabularFigures()])
      : body.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// The meta-sized tabular idiom — the single source for trailing counts / step indices (row meta,
  /// tab counts, menu/dropdown trailing numbers, stepper indices), so a digit-feature retune can't
  /// drift across copies (mirrors [value]'s rule at meta size). Callers add the colour via `copyWith`.
  /// 次级等宽数字单源(行/标签/菜单/下拉/步骤的尾随计数);颜色另加。
  static TextStyle metaTabular() => meta.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

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
