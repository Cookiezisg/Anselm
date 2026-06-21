import 'package:flutter/material.dart';

/// The semantic color palette as a [ThemeExtension] — the one place colors are defined,
/// resolved per-brightness from `Theme.of(context).extension<AnColors>()` (sugar:
/// `context.colors`). Modeling colors as an extension (not const fields) is what makes
/// "read from the theme, never hardcode" enforceable and makes dark mode structural
/// rather than a retrofit: every color has a light and a dark value and lerps on switch.
///
/// Naming is by ROLE, not by hue: a widget asks for `surfaceHover`, not "#f0f0f3". The
/// surface ladder (canvas → surface → raised → hover → active) is the bright/airy island
/// depth model — depth comes from small value steps + soft shadows, not heavy borders.
/// Node-family colors (violet/teal/…) back the workflow graph node kinds and entity-kind
/// badges, so they are semantic, not decoration.
///
/// 语义色板,做成 [ThemeExtension]——色的唯一定义处,按明暗从 theme 解析(糖:`context.colors`)。
/// 用扩展而非常量,才能让"从主题读、不硬编码"可强制,且让暗色是结构性的而非补丁:每色都有明/暗
/// 两值、切换时 lerp。命名按角色非色相。表面阶梯(canvas→surface→raised→hover→active)即明亮通透的
/// 岛屿深度模型——深度靠细微值差+柔阴影,不靠重边框。节点族色(violet/teal…)承载图节点种类与实体
/// 种类徽标,是语义非装饰。
@immutable
class AnColors extends ThemeExtension<AnColors> {
  const AnColors({
    // Surface depth ladder. 表面深度阶梯。
    required this.desk,
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceHover,
    required this.surfaceActive,
    // Ink hierarchy. 墨色层级。
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.onAccent,
    // Lines & scrim. 线与遮罩。
    required this.line,
    required this.lineStrong,
    required this.scrim,
    // Accent. 强调。
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.accentLine,
    // Semantics. 语义。
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.danger,
    required this.dangerSoft,
    // Node / entity-kind family. 节点 / 实体种类族。
    required this.violet,
    required this.violetSoft,
    required this.teal,
    required this.tealSoft,
    // Elevation shadows. 高度阴影。
    required this.shadowIsland,
    required this.shadowFloat,
    required this.shadowPop,
  });

  final Color desk;
  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceHover;
  final Color surfaceActive;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color onAccent;

  final Color line;
  final Color lineStrong;
  final Color scrim;

  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color accentLine;

  final Color ok;
  final Color okSoft;
  final Color warn;
  final Color warnSoft;
  final Color danger;
  final Color dangerSoft;

  final Color violet;
  final Color violetSoft;
  final Color teal;
  final Color tealSoft;

  final List<BoxShadow> shadowIsland;
  final List<BoxShadow> shadowFloat;
  final List<BoxShadow> shadowPop;

  /// Light is the product's visual soul: bright, airy, low-chroma + one calm accent.
  /// 明亮是产品视觉灵魂:通透、低彩度 + 一个沉静强调色。
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
    accent: Color(0xFF0071E3),
    accentHover: Color(0xFF0077ED),
    accentSoft: Color.fromRGBO(0, 113, 227, 0.10),
    accentLine: Color.fromRGBO(0, 113, 227, 0.30),
    ok: Color(0xFF2DA44E),
    okSoft: Color.fromRGBO(45, 164, 78, 0.12),
    warn: Color(0xFFBF6A02),
    warnSoft: Color.fromRGBO(191, 106, 2, 0.12),
    danger: Color(0xFFD70015),
    dangerSoft: Color.fromRGBO(215, 0, 21, 0.10),
    violet: Color(0xFF7C5CFF),
    violetSoft: Color.fromRGBO(124, 92, 255, 0.12),
    teal: Color(0xFF0B9AAB),
    tealSoft: Color.fromRGBO(11, 154, 171, 0.12),
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

  /// Dark keeps the same value ladder, only the hues invert — defined now so it never has
  /// to be retrofitted; the app defaults to light.
  /// 暗色保持同一值阶梯,仅反色——现在就定义好以免日后补丁;app 默认明亮。
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
    onAccent: Color(0xFFFFFFFF),
    line: Color.fromRGBO(255, 255, 255, 0.10),
    lineStrong: Color.fromRGBO(255, 255, 255, 0.16),
    scrim: Color.fromRGBO(0, 0, 0, 0.50),
    accent: Color(0xFF0A84FF),
    accentHover: Color(0xFF409CFF),
    accentSoft: Color.fromRGBO(10, 132, 255, 0.16),
    accentLine: Color.fromRGBO(10, 132, 255, 0.40),
    ok: Color(0xFF30D158),
    okSoft: Color.fromRGBO(48, 209, 88, 0.16),
    warn: Color(0xFFFF9F0A),
    warnSoft: Color.fromRGBO(255, 159, 10, 0.16),
    danger: Color(0xFFFF453A),
    dangerSoft: Color.fromRGBO(255, 69, 58, 0.16),
    violet: Color(0xFFA78BFA),
    violetSoft: Color.fromRGBO(167, 139, 250, 0.18),
    teal: Color(0xFF2DD4BF),
    tealSoft: Color.fromRGBO(45, 212, 191, 0.18),
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
    Color? violet,
    Color? violetSoft,
    Color? teal,
    Color? tealSoft,
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
      violet: violet ?? this.violet,
      violetSoft: violetSoft ?? this.violetSoft,
      teal: teal ?? this.teal,
      tealSoft: tealSoft ?? this.tealSoft,
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
      violet: c(violet, other.violet),
      violetSoft: c(violetSoft, other.violetSoft),
      teal: c(teal, other.teal),
      tealSoft: c(tealSoft, other.tealSoft),
      shadowIsland: s(shadowIsland, other.shadowIsland),
      shadowFloat: s(shadowFloat, other.shadowFloat),
      shadowPop: s(shadowPop, other.shadowPop),
    );
  }
}

/// Ergonomic, fail-fast access: `context.colors.accent`. Throws if the extension is not
/// registered (a wiring bug we want loud, not a silent fallback).
/// 顺手且 fail-fast 的访问。未注册即抛(装配 bug 要响,不静默兜底)。
extension AnColorsContext on BuildContext {
  AnColors get colors => Theme.of(this).extension<AnColors>()!;
}
