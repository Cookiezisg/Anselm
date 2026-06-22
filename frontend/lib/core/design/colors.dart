import 'package:flutter/material.dart';

/// The palette as a [ThemeExtension] — the one place colors are defined, resolved
/// per-brightness from `Theme.of(context).extension<AnColors>()` (sugar: `context.colors`).
///
/// Principle: MONOCHROME CHROME, COLORED SEMANTICS. There is NO decorative accent hue —
/// emphasis (primary action, selection, focus) is ink (near-black) on bright surfaces, and
/// `accent*` names hold monochrome values. But functional color is kept where it carries
/// meaning: the 5-state status model (ok=green / warn=orange / danger=red; run & idle are
/// achromatic) and code syntax highlighting (see [AnSyntax]). Charts/graphs are B&W (node
/// kinds read from icon + grayscale, never hue). Naming is by ROLE, not by hue.
///
/// 原则:单色 chrome、彩色语义。无装饰强调色——强调(主操作/选中/焦点)是墨色压亮面,`accent*` 持单色值。
/// 但功能色保留(承载语义):5 态状态(ok 绿 / warn 橙 / danger 红;run 与 idle 无彩)+ 代码高亮(见 [AnSyntax])。
/// 图表黑白(节点种类靠图标+灰阶,不靠色相)。命名按角色非色相。
@immutable
class AnColors extends ThemeExtension<AnColors> {
  const AnColors({
    required this.desk,
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceHover,
    required this.surfaceActive,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.onAccent,
    required this.line,
    required this.lineStrong,
    required this.scrim,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.accentLine,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.danger,
    required this.dangerSoft,
    required this.shadowIsland,
    required this.shadowFloat,
    required this.shadowPop,
  });

  // Surface depth ladder (depth = small value steps + soft shadows, not heavy borders).
  final Color desk;
  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceHover;
  final Color surfaceActive;

  // Ink hierarchy. 墨色层级。
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color onAccent; // foreground on an emphasis (ink/colored) fill 强调底上的前景

  // Lines & scrim. 线与遮罩。
  final Color line;
  final Color lineStrong;
  final Color scrim;

  // Emphasis = INK (monochrome). 强调=墨(单色)。
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color accentLine;

  // Functional status semantics (the colored part). 功能状态语义(有彩色的部分)。
  final Color ok; // done / success 完成
  final Color okSoft;
  final Color warn; // wait / warning 等待/告警
  final Color warnSoft;
  final Color danger; // err / destructive 失败/破坏
  final Color dangerSoft;

  // Elevation shadows. 高度阴影。
  final List<BoxShadow> shadowIsland;
  final List<BoxShadow> shadowFloat;
  final List<BoxShadow> shadowPop;

  /// Light is the soul: bright, airy, ink-on-white chrome + functional status color.
  /// 明亮为魂:通透,墨压白的 chrome + 功能状态色。
  static const AnColors light = AnColors(
    desk: Color(0xFFD4D5D9),
    canvas: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFFBFBFD),
    surfaceHover: Color(0xFFF0F0F3),
    surfaceActive: Color(0xFFE9E9EC),
    ink: Color(0xFF1D1D1F),
    inkMuted: Color(0xFF6E6E73),
    inkFaint: Color(0xFF8E8E93),
    onAccent: Color(0xFFFFFFFF),
    line: Color.fromRGBO(0, 0, 0, 0.08),
    lineStrong: Color.fromRGBO(0, 0, 0, 0.13),
    scrim: Color.fromRGBO(0, 0, 0, 0.28),
    accent: Color(0xFF1D1D1F), // ink 墨
    accentHover: Color(0xFF000000),
    accentSoft: Color.fromRGBO(0, 0, 0, 0.06),
    accentLine: Color.fromRGBO(0, 0, 0, 0.28),
    ok: Color(0xFF2DA44E),
    okSoft: Color.fromRGBO(45, 164, 78, 0.12),
    warn: Color(0xFFBF6A02),
    warnSoft: Color.fromRGBO(191, 106, 2, 0.12),
    danger: Color(0xFFD70015),
    dangerSoft: Color.fromRGBO(215, 0, 21, 0.10),
    shadowIsland: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.035), blurRadius: 10, offset: Offset(0, 3)),
    ],
    shadowFloat: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.045), blurRadius: 22, offset: Offset(0, 8)),
    ],
    shadowPop: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 8, offset: Offset(0, 2)),
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.10), blurRadius: 32, offset: Offset(0, 12)),
    ],
  );

  /// Dark inverts the ladder; emphasis becomes white-on-near-black. Wired now, not exposed.
  static const AnColors dark = AnColors(
    desk: Color(0xFF000000),
    canvas: Color(0xFF0A0A0A),
    surface: Color(0xFF1C1C1E),
    surfaceSubtle: Color(0xFF232326),
    surfaceHover: Color(0xFF2A2A2D),
    surfaceActive: Color(0xFF323236),
    ink: Color(0xFFF5F5F7),
    inkMuted: Color(0xFFA1A1A6),
    inkFaint: Color(0xFF6E6E73),
    onAccent: Color(0xFF1C1C1E),
    line: Color.fromRGBO(255, 255, 255, 0.10),
    lineStrong: Color.fromRGBO(255, 255, 255, 0.16),
    scrim: Color.fromRGBO(0, 0, 0, 0.50),
    accent: Color(0xFFF5F5F7),
    accentHover: Color(0xFFFFFFFF),
    accentSoft: Color.fromRGBO(255, 255, 255, 0.10),
    accentLine: Color.fromRGBO(255, 255, 255, 0.32),
    ok: Color(0xFF30D158),
    okSoft: Color.fromRGBO(48, 209, 88, 0.16),
    warn: Color(0xFFFF9F0A),
    warnSoft: Color.fromRGBO(255, 159, 10, 0.16),
    danger: Color(0xFFFF453A),
    dangerSoft: Color.fromRGBO(255, 69, 58, 0.16),
    shadowIsland: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.40), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.50), blurRadius: 28, offset: Offset(0, 8)),
    ],
    shadowFloat: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.40), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.50), blurRadius: 24, offset: Offset(0, 8)),
    ],
    shadowPop: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.55), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.60), blurRadius: 50, offset: Offset(0, 20)),
    ],
  );

  @override
  AnColors copyWith({
    Color? desk,
    Color? canvas,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceHover,
    Color? surfaceActive,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? onAccent,
    Color? line,
    Color? lineStrong,
    Color? scrim,
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? accentLine,
    Color? ok,
    Color? okSoft,
    Color? warn,
    Color? warnSoft,
    Color? danger,
    Color? dangerSoft,
    List<BoxShadow>? shadowIsland,
    List<BoxShadow>? shadowFloat,
    List<BoxShadow>? shadowPop,
  }) {
    return AnColors(
      desk: desk ?? this.desk,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfaceActive: surfaceActive ?? this.surfaceActive,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      onAccent: onAccent ?? this.onAccent,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      scrim: scrim ?? this.scrim,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      accentLine: accentLine ?? this.accentLine,
      ok: ok ?? this.ok,
      okSoft: okSoft ?? this.okSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      shadowIsland: shadowIsland ?? this.shadowIsland,
      shadowFloat: shadowFloat ?? this.shadowFloat,
      shadowPop: shadowPop ?? this.shadowPop,
    );
  }

  @override
  AnColors lerp(ThemeExtension<AnColors>? other, double t) {
    if (other is! AnColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t)!;
    return AnColors(
      desk: c(desk, other.desk),
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceSubtle: c(surfaceSubtle, other.surfaceSubtle),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      surfaceActive: c(surfaceActive, other.surfaceActive),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      onAccent: c(onAccent, other.onAccent),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      scrim: c(scrim, other.scrim),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentSoft: c(accentSoft, other.accentSoft),
      accentLine: c(accentLine, other.accentLine),
      ok: c(ok, other.ok),
      okSoft: c(okSoft, other.okSoft),
      warn: c(warn, other.warn),
      warnSoft: c(warnSoft, other.warnSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      shadowIsland: s(shadowIsland, other.shadowIsland),
      shadowFloat: s(shadowFloat, other.shadowFloat),
      shadowPop: s(shadowPop, other.shadowPop),
    );
  }
}

/// Ergonomic, fail-fast access: `context.colors.ink`. Throws if not registered.
/// 顺手且 fail-fast。未注册即抛(装配 bug 要响)。
extension AnColorsContext on BuildContext {
  AnColors get colors => Theme.of(this).extension<AnColors>()!;
}
