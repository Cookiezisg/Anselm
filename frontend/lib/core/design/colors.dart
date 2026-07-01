import 'package:flutter/material.dart';

/// The palette as a [ThemeExtension] — the one place colors are defined, resolved per-brightness
/// via `Theme.of(context).extension<AnColors>()` (sugar: `context.colors`). Values mirror the
/// demo's tokens.css. `accent*` is the toB BLUE (demo #0071e3) — emphasis (primary action,
/// selection, focus, run status) reads as blue, not black. Chrome stays neutral ink/surface;
/// functional color carries meaning (ok=green / warn=orange / danger=red; idle achromatic).
/// Named by ROLE, not by hue.
///
/// 调色板 = [ThemeExtension],颜色唯一定义处(糖:`context.colors`)。值镜像 demo tokens.css。
/// accent=toB 蓝(demo #0071e3)——强调(主动作/选中/聚焦/运行中)显蓝、非黑;chrome 中性墨/面;功能色保留。
@immutable
class AnColors extends ThemeExtension<AnColors> {
  const AnColors({
    required this.desk,
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceHover,
    required this.surfaceActive,
    required this.surfaceSunken,
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
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.shadowIsland,
    required this.shadowFloat,
    required this.shadowPop,
    required this.shadowWin,
  });

  // Surface depth ladder. 面阶梯。
  final Color desk;
  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceHover;
  final Color surfaceActive;

  /// A neutral fill a notch off the base [surface] — for contained, NON-interactive regions (chat bubbles,
  /// wells, inset panels). Distinct from [surfaceHover]/[surfaceActive] (those are hover/selected STATES) and
  /// from [surface] (the base): reusing a state colour for a resting fill mis-signals interactivity. Reads as
  /// a gentle inset in light, a gentle lift in dark. 比基础 [surface] 轻降一档的中性填充——供 contained、**非交互**
  /// 区域(聊天泡、凹槽、内嵌面板)。区别于 hover/active(状态色)与 base surface(拿状态色当静止填充会误示可交互)。
  /// 明亮下读作轻凹、暗色下读作轻凸。
  final Color surfaceSunken;

  // Ink hierarchy. 墨色层级。
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color onAccent;

  // Lines & scrim. 线与遮罩。
  final Color line;
  final Color lineStrong;
  final Color scrim;

  // Emphasis = toB BLUE (demo #0071e3). 强调=商务蓝。
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color accentLine; // hairline-weight accent for emphatic borders/insets (demo --accent-line); accentSoft 太浅做不了线

  // Functional status semantics. 功能状态语义。
  final Color ok;
  final Color okSoft;
  final Color warn;
  final Color warnSoft;
  final Color danger;
  final Color dangerSoft;

  // Skeleton/shimmer bones — monochrome muted fill + a slightly lighter sweep highlight. 骨架:哑底 + 微亮扫光。
  final Color skeletonBase;
  final Color skeletonHighlight;

  // Elevation shadows. 高度阴影。
  final List<BoxShadow> shadowIsland;
  final List<BoxShadow> shadowFloat;
  final List<BoxShadow> shadowPop;
  // The modal-dialog window shadow (demo --shadow-win) — a SINGLE deep-spread layer, NOT the
  // two-layer shadowPop: a centered modal earns one big soft drop, not a popover's tight 2-stop
  // stack. The one place its single-vs-double shape differs from the other three tiers (whose dark
  // variants also diverge in offset/blur — never type-pun across tiers). 模态窗影:单层深扩,非 shadowPop 双层。
  final List<BoxShadow> shadowWin;

  /// Light is the soul: bright, airy, ink-on-white. 明亮为魂:通透,墨压白。
  static const AnColors light = AnColors(
    desk: Color(0xFFD4D5D9),
    canvas: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFFBFBFD),
    surfaceHover: Color(0xFFF0F0F3),
    surfaceActive: Color(0xFFE9E9EC),
    surfaceSunken: Color(0xFFECECEF), // between surfaceHover and surfaceActive — a gentle inset well 轻凹填充
    ink: Color(0xFF1D1D1F),
    inkMuted: Color(0xFF6E6E73),
    inkFaint: Color(0xFF8E8E93),
    onAccent: Color(0xFFFFFFFF),
    line: Color.fromRGBO(0, 0, 0, 0.08),
    lineStrong: Color.fromRGBO(0, 0, 0, 0.13),
    scrim: Color.fromRGBO(0, 0, 0, 0.28),
    accent: Color(0xFF0071E3), // toB blue (demo --accent) 商务蓝
    accentHover: Color(0xFF0077ED),
    accentSoft: Color.fromRGBO(0, 113, 227, 0.10),
    accentLine: Color.fromRGBO(0, 113, 227, 0.30),
    ok: Color(0xFF2DA44E),
    okSoft: Color.fromRGBO(45, 164, 78, 0.12),
    warn: Color(0xFFBF6A02),
    warnSoft: Color.fromRGBO(191, 106, 2, 0.12),
    danger: Color(0xFFD70015),
    dangerSoft: Color.fromRGBO(215, 0, 21, 0.10),
    skeletonBase: Color(0xFFE4E4E8),
    skeletonHighlight: Color(0xFFF2F2F4),
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
    shadowWin: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.20), blurRadius: 50, offset: Offset(0, 16)),
    ],
  );

  /// Dark inverts the ladder; emphasis becomes white-on-near-black. 暗色翻转阶梯。
  static const AnColors dark = AnColors(
    desk: Color(0xFF000000),
    canvas: Color(0xFF0A0A0A),
    surface: Color(0xFF1C1C1E),
    surfaceSubtle: Color(0xFF232326),
    surfaceHover: Color(0xFF2A2A2D),
    surfaceActive: Color(0xFF323236),
    surfaceSunken: Color(0xFF26262A), // gentle lift above the near-black base surface (dark inverts) 暗色轻凸
    ink: Color(0xFFF5F5F7),
    inkMuted: Color(0xFFA1A1A6),
    inkFaint: Color(0xFF6E6E73),
    onAccent: Color(0xFFFFFFFF),
    line: Color.fromRGBO(255, 255, 255, 0.10),
    lineStrong: Color.fromRGBO(255, 255, 255, 0.16),
    scrim: Color.fromRGBO(0, 0, 0, 0.50),
    accent: Color(0xFF0A84FF), // toB blue, dark variant (demo) 商务蓝·暗
    accentHover: Color(0xFF409CFF),
    accentSoft: Color.fromRGBO(10, 132, 255, 0.16),
    accentLine: Color.fromRGBO(10, 132, 255, 0.40),
    ok: Color(0xFF30D158),
    okSoft: Color.fromRGBO(48, 209, 88, 0.16),
    warn: Color(0xFFFF9F0A),
    warnSoft: Color.fromRGBO(255, 159, 10, 0.16),
    danger: Color(0xFFFF453A),
    dangerSoft: Color.fromRGBO(255, 69, 58, 0.16),
    skeletonBase: Color(0xFF2E2E33),
    skeletonHighlight: Color(0xFF3C3C42),
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
    shadowWin: [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.50), blurRadius: 50, offset: Offset(0, 16)),
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
    Color? surfaceSunken,
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
    Color? skeletonBase,
    Color? skeletonHighlight,
    List<BoxShadow>? shadowIsland,
    List<BoxShadow>? shadowFloat,
    List<BoxShadow>? shadowPop,
    List<BoxShadow>? shadowWin,
  }) {
    return AnColors(
      desk: desk ?? this.desk,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfaceActive: surfaceActive ?? this.surfaceActive,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
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
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      shadowIsland: shadowIsland ?? this.shadowIsland,
      shadowFloat: shadowFloat ?? this.shadowFloat,
      shadowPop: shadowPop ?? this.shadowPop,
      shadowWin: shadowWin ?? this.shadowWin,
    );
  }

  @override
  AnColors lerp(ThemeExtension<AnColors>? other, double t) {
    if (other is! AnColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) => BoxShadow.lerpList(a, b, t)!;
    return AnColors(
      desk: c(desk, other.desk),
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceSubtle: c(surfaceSubtle, other.surfaceSubtle),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      surfaceActive: c(surfaceActive, other.surfaceActive),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
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
      skeletonBase: c(skeletonBase, other.skeletonBase),
      skeletonHighlight: c(skeletonHighlight, other.skeletonHighlight),
      shadowIsland: s(shadowIsland, other.shadowIsland),
      shadowFloat: s(shadowFloat, other.shadowFloat),
      shadowPop: s(shadowPop, other.shadowPop),
      shadowWin: s(shadowWin, other.shadowWin),
    );
  }
}

/// Ergonomic, fail-fast access: `context.colors.ink`. Throws if not registered (assembly bug).
/// 顺手且 fail-fast:未注册即抛(装配 bug 要响)。
extension AnColorsContext on BuildContext {
  AnColors get colors => Theme.of(this).extension<AnColors>()!;
}

/// The CODE syntax palette — a SEPARATE [ThemeExtension] so the syntax sub-palette stays a cohesive
/// concern (not bloating the chrome/ink/status [AnColors]) and the highlighter [highlightCode] can be
/// a pure function that takes it (no context). The ONE source of syntax token colours for
/// AnCodeEditor / AnVersionDiff / AnJsonTree — NEVER inline a raw code colour (same rule as AnColors,
/// G4 review ⑥). Values mirror demo tokens.css (One Light `:root` / One Dark `[data-theme=dark]`).
/// [arg] (interpolation `${}` / `$n` / `{{ }}` — incl. CEL) mirrors [AnColors.accent] BY VALUE: kept
/// here so the highlighter is self-contained, documented as the accent so a retune stays in sync.
///
/// 代码语法调色板 = 独立 [ThemeExtension](语法子板自成一概念、不胀 AnColors;让 highlightCode 纯函数吃它、不碰 context)。
/// 三件唯一语法色源,禁内联(同 AnColors)。值镜像 demo tokens.css(One Light/One Dark)。arg(插值/CEL)按值镜像 accent。
@immutable
class SyntaxColors extends ThemeExtension<SyntaxColors> {
  const SyntaxColors({
    required this.comment,
    required this.keyword,
    required this.string,
    required this.number,
    required this.function,
    required this.arg,
  });

  final Color comment; // demo --cd-com (rendered italic by the highlighter) 注释(高亮器渲斜体)
  final Color keyword; // demo --cd-kw 关键字
  final Color string; // demo --cd-str 字符串
  final Color number; // demo --cd-num 数字
  final Color function; // demo --cd-fn 标识符后跟 ( 视为函数名
  final Color arg; // demo --cd-arg = --accent;插值 ${}/$n/{{}}(含 CEL)bold

  /// One Light (demo `:root`). 明亮。
  static const SyntaxColors light = SyntaxColors(
    comment: Color(0xFFA0A1A7),
    keyword: Color(0xFFA626A4),
    string: Color(0xFF50A14F),
    number: Color(0xFF986801),
    function: Color(0xFF4078F2),
    arg: Color(0xFF0071E3), // = AnColors.light.accent
  );

  /// One Dark (demo `[data-theme=dark]`). 暗色。
  static const SyntaxColors dark = SyntaxColors(
    comment: Color(0xFF7F848E),
    keyword: Color(0xFFC678DD),
    string: Color(0xFF98C379),
    number: Color(0xFFD19A66),
    function: Color(0xFF61AFEF),
    arg: Color(0xFF0A84FF), // = AnColors.dark.accent
  );

  @override
  SyntaxColors copyWith({
    Color? comment,
    Color? keyword,
    Color? string,
    Color? number,
    Color? function,
    Color? arg,
  }) {
    return SyntaxColors(
      comment: comment ?? this.comment,
      keyword: keyword ?? this.keyword,
      string: string ?? this.string,
      number: number ?? this.number,
      function: function ?? this.function,
      arg: arg ?? this.arg,
    );
  }

  @override
  SyntaxColors lerp(ThemeExtension<SyntaxColors>? other, double t) {
    if (other is! SyntaxColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SyntaxColors(
      comment: c(comment, other.comment),
      keyword: c(keyword, other.keyword),
      string: c(string, other.string),
      number: c(number, other.number),
      function: c(function, other.function),
      arg: c(arg, other.arg),
    );
  }
}

/// Fail-fast access: `context.syntax.keyword`. Throws if not registered (assembly bug).
/// 顺手且 fail-fast 的语法色访问。
extension SyntaxColorsContext on BuildContext {
  SyntaxColors get syntax => Theme.of(this).extension<SyntaxColors>()!;
}

/// No-flash hover/active fill: `c.surfaceHover.whenActive(active)` → the colour when active, else the
/// SAME colour at alpha 0 (so an AnimatedContainer fades pure-alpha, never through a dark midpoint —
/// the documented Color.lerp pitfall). The single source for the kit's resting-bg idiom.
/// 无暗闪的悬停/激活底:激活时给该色,否则同色 alpha0(AnimatedContainer 纯 alpha 淡入、不经暗中点)。套件统一用它。
extension AnColorWhenActive on Color {
  Color whenActive(bool active) => active ? this : withValues(alpha: 0);
}
