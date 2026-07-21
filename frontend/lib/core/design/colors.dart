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
    required this.surfaceHoverStrong,
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
    required this.selection,
    required this.dangerLine,
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

  /// A DEEPER interactive fill for an INLINE control (icon-only / ghost button) that sits ON a row which
  /// is itself washed [surfaceHover] on hover — one clear notch darker than [surfaceHover] so the button
  /// reads as a button, not as a smear in the row wash (the rail +/⋯, the tray group-head ⋯; user 0719:
  /// «钮淹死在行底里»). Three distinguishable tiers: row hover [surfaceHover] < inline-button hover
  /// [surfaceHoverStrong] < selection [surfaceActive] — the guard test asserts all three are distinct. On
  /// white it also reads clearer than [surfaceHover] (one token, every app-wide inline button benefits).
  /// Named like [line]→[lineStrong]. 行内钮(iconOnly/ghost)的更深交互底:比 surfaceHover 明显深一档,让钮在
  /// 灰洗底行上仍读作按钮而非糊进行底(rail +/⋯、托盘组头 ⋯;用户 0719「钮淹死在行底里」)。三档可辨:行 hover
  /// < 钮 hover < 选中,守卫断言三值互异;白底上也比 surfaceHover 更清楚(一处改全 app 行内钮受益)。命名同 line→lineStrong。
  final Color surfaceHoverStrong;
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
  final Color
  accentLine; // hairline-weight accent for emphatic borders/insets (demo --accent-line); accentSoft 太浅做不了线
  final Color
  selection; // text-selection highlight (editor/prose sweeps) — accent at ~macOS selection alpha; accentSoft(0.10) 太浅盖不出「选中了」。文本划选高亮
  final Color
  dangerLine; // hairline-weight danger for warning borders (批7 B-034 — dangerSoft 太浅做不了线,镜像 accentLine)

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
    surfaceHoverStrong: Color(
      0xFFE0E0E3,
    ), // one clear notch below surfaceHover (and below surfaceActive) — inline-button hover 行内钮 hover
    surfaceActive: Color(0xFFE9E9EC),
    surfaceSunken: Color(
      0xFFECECEF,
    ), // between surfaceHover and surfaceActive — a gentle inset well 轻凹填充
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
    selection: Color.fromRGBO(0, 113, 227, 0.22),
    dangerLine: Color.fromRGBO(215, 0, 21, 0.30),
    ok: Color(0xFF2DA44E),
    okSoft: Color.fromRGBO(45, 164, 78, 0.12),
    warn: Color(0xFFBF6A02),
    warnSoft: Color.fromRGBO(191, 106, 2, 0.12),
    danger: Color(0xFFD70015),
    dangerSoft: Color.fromRGBO(215, 0, 21, 0.10),
    skeletonBase: Color(0xFFE4E4E8),
    skeletonHighlight: Color(0xFFF2F2F4),
    shadowIsland: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.03),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.035),
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ],
    shadowFloat: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.05),
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.045),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
    ],
    shadowPop: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.06),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.10),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
    ],
    shadowWin: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.20),
        blurRadius: 50,
        offset: Offset(0, 16),
      ),
    ],
  );

  /// Dark inverts the ladder; emphasis becomes white-on-near-black. 暗色翻转阶梯。
  static const AnColors dark = AnColors(
    desk: Color(0xFF000000),
    canvas: Color(0xFF0A0A0A),
    surface: Color(0xFF1C1C1E),
    surfaceSubtle: Color(0xFF232326),
    surfaceHover: Color(0xFF2A2A2D),
    surfaceHoverStrong: Color(
      0xFF38383C,
    ), // one clear lift above surfaceHover (and above surfaceActive) — dark inverts 暗色行内钮 hover
    surfaceActive: Color(0xFF323236),
    surfaceSunken: Color(
      0xFF26262A,
    ), // gentle lift above the near-black base surface (dark inverts) 暗色轻凸
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
    selection: Color.fromRGBO(10, 132, 255, 0.30),
    dangerLine: Color.fromRGBO(255, 69, 58, 0.40),
    ok: Color(0xFF30D158),
    okSoft: Color.fromRGBO(48, 209, 88, 0.16),
    warn: Color(0xFFFF9F0A),
    warnSoft: Color.fromRGBO(255, 159, 10, 0.16),
    danger: Color(0xFFFF453A),
    dangerSoft: Color.fromRGBO(255, 69, 58, 0.16),
    skeletonBase: Color(0xFF2E2E33),
    skeletonHighlight: Color(0xFF3C3C42),
    shadowIsland: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.40),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.50),
        blurRadius: 28,
        offset: Offset(0, 8),
      ),
    ],
    shadowFloat: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.40),
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.50),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
    shadowPop: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.55),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.60),
        blurRadius: 50,
        offset: Offset(0, 20),
      ),
    ],
    shadowWin: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.50),
        blurRadius: 50,
        offset: Offset(0, 16),
      ),
    ],
  );

  @override
  AnColors copyWith({
    Color? desk,
    Color? canvas,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceHover,
    Color? surfaceHoverStrong,
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
    Color? selection,
    Color? dangerLine,
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
      surfaceHoverStrong: surfaceHoverStrong ?? this.surfaceHoverStrong,
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
      selection: selection ?? this.selection,
      dangerLine: dangerLine ?? this.dangerLine,
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
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t)!;
    return AnColors(
      desk: c(desk, other.desk),
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceSubtle: c(surfaceSubtle, other.surfaceSubtle),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      surfaceHoverStrong: c(surfaceHoverStrong, other.surfaceHoverStrong),
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
      selection: c(selection, other.selection),
      dangerLine: c(dangerLine, other.dangerLine),
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

  final Color
  comment; // demo --cd-com (rendered italic by the highlighter) 注释(高亮器渲斜体)
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

/// The GRAPH palette — a SEPARATE [ThemeExtension] (same reasoning as [SyntaxColors]: a cohesive
/// sub-palette that must not bloat [AnColors], consumed by painters as plain values). Two axes:
/// the node-kind hue families the chrome palette lacks (violet=trigger, teal=agent — action/control/
/// approval reuse [AnColors.accent]/warn/danger), and the canvas strokes (edge / future edge / grid
/// dot). Values mirror demo tokens.css. The ONE source for graph colours — NEVER inline.
///
/// 图调色板 = 独立 [ThemeExtension](同 SyntaxColors 理由:自成一概念、不胀 AnColors,painter 吃纯值)。
/// 两轴:chrome 板缺的节点 kind 色族(violet=trigger、teal=agent;action/control/approval 复用
/// accent/warn/danger)+ 画布笔画(边/未走边/网格点)。值镜像 demo tokens.css。图色唯一源,禁内联。
@immutable
class GraphColors extends ThemeExtension<GraphColors> {
  const GraphColors({
    required this.violet,
    required this.violetSoft,
    required this.teal,
    required this.tealSoft,
    required this.edge,
    required this.edgeFuture,
    required this.gridDot,
  });

  final Color violet; // trigger nodes 触发节点
  final Color violetSoft;
  final Color teal; // agent nodes 智能体节点
  final Color tealSoft;
  final Color edge; // resting edge stroke (demo --edge) 静止边
  final Color
  edgeFuture; // run-mode not-yet-walked edge (demo --edge-future) 未走边
  final Color gridDot; // canvas dot grid (demo --grid-dot) 网格点

  static const GraphColors light = GraphColors(
    violet: Color(0xFF7C5CFF),
    violetSoft: Color.fromRGBO(124, 92, 255, 0.12),
    teal: Color(0xFF0B9AAB),
    tealSoft: Color.fromRGBO(11, 154, 171, 0.12),
    edge: Color.fromRGBO(0, 0, 0, 0.22),
    edgeFuture: Color.fromRGBO(0, 0, 0, 0.10),
    gridDot: Color.fromRGBO(0, 0, 0, 0.05),
  );

  static const GraphColors dark = GraphColors(
    violet: Color(0xFFA78BFA),
    violetSoft: Color.fromRGBO(167, 139, 250, 0.18),
    teal: Color(0xFF2DD4BF),
    tealSoft: Color.fromRGBO(45, 212, 191, 0.18),
    edge: Color.fromRGBO(255, 255, 255, 0.28),
    edgeFuture: Color.fromRGBO(255, 255, 255, 0.12),
    gridDot: Color.fromRGBO(255, 255, 255, 0.05),
  );

  @override
  GraphColors copyWith({
    Color? violet,
    Color? violetSoft,
    Color? teal,
    Color? tealSoft,
    Color? edge,
    Color? edgeFuture,
    Color? gridDot,
  }) {
    return GraphColors(
      violet: violet ?? this.violet,
      violetSoft: violetSoft ?? this.violetSoft,
      teal: teal ?? this.teal,
      tealSoft: tealSoft ?? this.tealSoft,
      edge: edge ?? this.edge,
      edgeFuture: edgeFuture ?? this.edgeFuture,
      gridDot: gridDot ?? this.gridDot,
    );
  }

  @override
  GraphColors lerp(ThemeExtension<GraphColors>? other, double t) {
    if (other is! GraphColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GraphColors(
      violet: c(violet, other.violet),
      violetSoft: c(violetSoft, other.violetSoft),
      teal: c(teal, other.teal),
      tealSoft: c(tealSoft, other.tealSoft),
      edge: c(edge, other.edge),
      edgeFuture: c(edgeFuture, other.edgeFuture),
      gridDot: c(gridDot, other.gridDot),
    );
  }
}

/// Fail-fast access: `context.graphColors.violet`. Throws if not registered (assembly bug).
/// 顺手且 fail-fast 的图色访问。
extension GraphColorsContext on BuildContext {
  GraphColors get graphColors => Theme.of(this).extension<GraphColors>()!;
}
