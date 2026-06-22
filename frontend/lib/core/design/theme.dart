import 'package:flutter/material.dart';

import 'colors.dart';
import 'syntax.dart';
import 'tokens.dart';
import 'typography.dart';

/// Assembles [ThemeData] from the design tokens. Two themes are produced (light is the
/// soul; dark is structurally ready) by feeding ONE [AnColors] palette into: the Material
/// [ColorScheme] (so stock widgets look right), the [TextTheme], divider/scrollbar themes,
/// and the [AnColors] extension itself (for our own widgets via `context.colors`).
///
/// Deliberate desktop choices: no ink ripple (`NoSplash`) and compact density for a crisp,
/// native — not webby — feel; the canvas (not white) is the scaffold background so white
/// islands read as raised surfaces.
///
/// 由 token 装配 [ThemeData]。产出两套主题(明亮为魂、暗色已就绪):同一份 [AnColors] 喂给 Material
/// [ColorScheme](让原生 widget 正常)、[TextTheme]、分割线/滚动条主题,以及 [AnColors] 扩展本身(供
/// 自有 widget 经 `context.colors` 读)。桌面取舍:无墨波纹 + 紧凑密度 = 利落原生而非 web 感;脚手架背景
/// 用 canvas(非纯白),让白色岛屿读作抬升表面。
abstract final class AnTheme {
  static ThemeData light() =>
      _build(AnColors.light, AnSyntax.light, Brightness.light);
  static ThemeData dark() =>
      _build(AnColors.dark, AnSyntax.dark, Brightness.dark);

  static ThemeData _build(AnColors c, AnSyntax syntax, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surfaceSubtle,
      surfaceContainer: c.surfaceHover,
      surfaceContainerHigh: c.surfaceActive,
      outline: c.lineStrong,
      outlineVariant: c.line,
      error: c.danger,
      onError: c.onAccent,
      scrim: c.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c, syntax],
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.surface,
      dividerColor: c.line,
      visualDensity: VisualDensity.compact,
      // Crisp desktop: no ripple, no highlight spread. 利落桌面:无波纹无高亮扩散。
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textTheme: AnText.textTheme(c.ink),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(AnRadius.pill),
        thumbColor: WidgetStatePropertyAll(c.lineStrong),
        thumbVisibility: const WidgetStatePropertyAll(false),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(AnRadius.button),
        ),
        textStyle: AnText.meta.copyWith(color: c.surface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnRadius.card),
          side: BorderSide(color: c.line, width: 1),
        ),
        textStyle: AnText.body.copyWith(color: c.ink),
      ),
    );
  }
}
