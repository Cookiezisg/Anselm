import 'package:flutter/material.dart';

/// The MONOCHROME semantic palette as a [ThemeExtension] — the one place colors are
/// defined, resolved per-brightness from `Theme.of(context).extension<AnColors>()` (sugar:
/// `context.colors`). The product is deliberately achromatic: there is NO decorative
/// accent hue. Emphasis is carried by ink (near-black) on bright surfaces; hierarchy by
/// the surface depth ladder + ink ladder; status/kind by icon + grayscale, never by color.
///
/// The SINGLE functional hue is `danger` (a restrained red) — kept only as a safety signal
/// for destructive/error states, not as an accent. Drop it (set to ink) for pure B&W.
///
/// 刻意无彩色:没有装饰性强调色。强调靠墨色(近黑)压在明亮表面上;层级靠表面深度阶梯+墨色阶梯;
/// 状态/种类靠图标+灰阶,绝不靠颜色。唯一功能色是 `danger`(克制的红)——只作危险/错误的安全信号,
/// 非强调;要纯黑白把它设成 ink 即可。命名按角色非色相(widget 要 `surfaceHover`,不要 `#f0f0f3`)。
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
    required this.danger,
    required this.dangerSoft,
    required this.shadowIsland,
    required this.shadowFloat,
    required this.shadowPop,
  });

  // Surface depth ladder (bright/airy island model: depth = small value steps + soft
  // shadows, not heavy borders). 表面深度阶梯。
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
  final Color onAccent; // text/icon on an ink-filled (emphasis) surface 墨底上的前景

  // Lines & scrim. 线与遮罩。
  final Color line;
  final Color lineStrong;
  final Color scrim;

  // Emphasis role = INK (no hue). accent* are the names; their VALUE is monochrome, so a
  // hue could be reintroduced by changing one value. 强调角色=墨(无色相);值单色,日后想加色相只改一处。
  final Color accent; // primary fill (ink) 主填充
  final Color accentHover; // pressed/hover (pure black) 悬停/按下
  final Color accentSoft; // selected-row wash (light gray) 选中行底
  final Color accentLine; // focus ring / selected border 焦点环/选中边

  // The one functional hue. 唯一功能色。
  final Color danger;
  final Color dangerSoft;

  // Elevation shadows. 高度阴影。
  final List<BoxShadow> shadowIsland;
  final List<BoxShadow> shadowFloat;
  final List<BoxShadow> shadowPop;

  /// Light is the soul: bright, airy, black-on-white. 明亮为魂:通透、黑压白。
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
  /// 暗色反转阶梯;强调变白压黑。已接未启。
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
    onAccent: Color(0xFF1C1C1E), // dark text on a white emphasis fill 白底上的深色前景
    line: Color.fromRGBO(255, 255, 255, 0.10),
    lineStrong: Color.fromRGBO(255, 255, 255, 0.16),
    scrim: Color.fromRGBO(0, 0, 0, 0.50),
    accent: Color(0xFFF5F5F7), // white emphasis 白强调
    accentHover: Color(0xFFFFFFFF),
    accentSoft: Color.fromRGBO(255, 255, 255, 0.10),
    accentLine: Color.fromRGBO(255, 255, 255, 0.32),
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
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      shadowIsland: s(shadowIsland, other.shadowIsland),
      shadowFloat: s(shadowFloat, other.shadowFloat),
      shadowPop: s(shadowPop, other.shadowPop),
    );
  }
}

/// Ergonomic, fail-fast access: `context.colors.ink`. Throws if the extension is not
/// registered (a wiring bug we want loud, not a silent fallback).
/// 顺手且 fail-fast。未注册即抛(装配 bug 要响,不静默兜底)。
extension AnColorsContext on BuildContext {
  AnColors get colors => Theme.of(this).extension<AnColors>()!;
}
