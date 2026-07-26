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
  /// How long a light↔dark flip takes. ZERO on purpose (WRK-083 B6): MaterialApp's default hands the
  /// whole ThemeData to [AnimatedTheme], which LERPS it — our three ThemeExtensions included ([AnColors]
  /// alone is 46 colours + shadow lists) — for `kThemeAnimationDuration`, handing out a new extension
  /// instance every frame. Every widget reading `context.colors` therefore rebuilds a dozen times, and
  /// this app keeps EVERY visited screen mounted (S3), so that is five screens repainting twelve times
  /// for one click. The user felt it as「明暗切换卡卡的」. Swapping in one frame is both faster and the
  /// rule this codebase already follows for whole-surface updates:「原地换、零动画(快就是丝滑)」.
  ///
  /// 明↔暗切换耗时。**刻意为零**(WRK-083 B6):MaterialApp 的默认把整个 ThemeData 交给 [AnimatedTheme] 去
  /// **lerp**——连我们三个 ThemeExtension 一起(光 [AnColors] 就 46 个颜色 + 阴影列表)——持续
  /// `kThemeAnimationDuration`,且**每帧发一个新的 extension 实例**。于是每个读 `context.colors` 的 widget 重建
  /// 十几次,而本 app **把访问过的每一屏都保活挂着**(S3),一次点击就是五屏各重绘十几次。用户的体感就是
  /// 「明暗切换卡卡的」。一帧换完既更快,也正是本代码库对整面更新既有的规矩:「原地换、零动画(快就是丝滑)」。
  static const Duration switchDuration = Duration.zero;

  // Both themes are built ONCE. AnApp rebuilds on router / locale / theme-mode changes and would
  // otherwise construct two ThemeData (each with three extensions) every time.
  // 两套主题**只建一次**。AnApp 会因路由/语言/主题模式变化重建,否则每次都要造两个带三个 extension 的 ThemeData。
  static final ThemeData _light = _buildLight();
  static final ThemeData _dark = _buildDark();

  static ThemeData light() => _light;
  static ThemeData dark() => _dark;

  static ThemeData _buildLight() => _build(
    Brightness.light,
    AnColors.light,
    SyntaxColors.light,
    GraphColors.light,
  );
  static ThemeData _buildDark() => _build(
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
