import 'package:flutter/material.dart';

/// Typography — a modular scale anchored on a 13px UI body. [uiFamily] = BUNDLED Inter (the
/// variable font, wght 100–900), the Latin/numeral face; CJK glyphs fall through to BUNDLED MiSans
/// (VF, wght 150–700) first in [uiFallback] — BOTH ship in the bundle, so the bilingual UI renders
/// the same on every machine (the demo's intent; Inter has no CJK coverage by design). The body
/// renders LIGHT (w300) and the ramp climbs from there. Colorless on purpose: the theme applies ink
/// once and it inherits.
///
/// **DUAL-TRACK TYPE LADDER — the registry (which surface uses which rung).** Two axes, chosen by
/// what the text IS, never by where it sits:
///
///   • **PROSE — flowing content a person READS as the point of the surface** → the 15 rung:
///     [reading] (15) body, [readingH1]/[readingH2]/[readingH3] (22/18/15) content headings.
///     The registry: the chat COMPOSER input + placeholder, the USER message bubble (live +
///     optimistic), the ASSISTANT answer (via AnMarkdown), the DOCUMENT / SKILL body (via
///     AnDocEditor), and anything AnMarkdown renders. If you add a new surface whose job is to be
///     read as prose, it joins this list — use [reading].
///
///   • **DENSE UI CHROME — labels, controls, metadata, machine output a person OPERATES** → the 13
///     anchor: [body] (13), [label] (13), [meta] (12), [strong] (16), [h3]/[h2]/[h1] (20/24/32),
///     [value]/[metaTabular]. The registry: nav rows, buttons, tabs, menus, KV/field rows, inputs,
///     dropdowns, toasts, chips, headers, badges, tooltips, status lines, empty-state affordances
///     (AnState), callouts (AnCallout), dialog messages, table cells (even inside markdown, via
///     AnThinTable), tool-card receipts, the run terminal, the reasoning aside (a deliberately
///     quiet secondary voice), and code (mono, its own face). Chrome stays compact — the 32px row
///     rhythm depends on it.
///
/// The line is PRIMARY CONVERSATIONAL / DOCUMENT CONTENT (prose 15) vs EVERYTHING THAT FRAMES OR
/// OPERATES ON IT (chrome 13). It is a human judgment the guard test can't make — the guard
/// (`test/core/design/type_scale_guard_test.dart`) only enforces the MECHANICAL invariants: every
/// size flows from here (no raw `fontSize:` literals elsewhere) and only two weights exist
/// (w300/w400). New prose surfaces are checked visually against the AnMarkdown baseline
/// (`test/dev/capture_md_parity.dart`).
///
/// 字体——模数阶梯,锚 13px 正文。[uiFamily]=**随包 Inter**(变量字体,wght 100–900),拉丁/数字字面;
/// 中文字形回落到 [uiFallback] 首位的**随包 MiSans**(VF,150–700)——两者皆入包,每台机器同字面(demo 本意;
/// Inter 本就不含 CJK)。正文压细 w300,字重阶梯由此上爬。刻意无色:主题上一次 ink、全部继承。
///
/// **双轨字阶——登记表(哪个面用哪档,按文字「是什么」判、绝不按「在哪」)**:
///   • **prose(人当内容读的流动文字)→ 15 档**([reading] + [readingH1]/[H2]/[H3])。登记:chat
///     composer 输入+占位、用户气泡(实时+乐观)、助手答案(经 AnMarkdown)、文档/skill 正文(经
///     AnDocEditor)、一切 AnMarkdown 渲染。新增以「被当 prose 读」为职责的面即入此表、用 [reading]。
///   • **dense UI chrome(人操作的标签/控件/元数据/机器输出)→ 13 锚**([body]/[label]/[meta]/[strong]/
///     [h1–h3]/[value])。登记:导航/按钮/tab/菜单/KV/输入/下拉/toast/chip/头/徽章/tooltip/状态行、
///     空态 affordance(AnState)、callout、对话框消息、表格 cell(markdown 内也走 AnThinTable)、tool 卡
///     回执、run 终端、推理旁白(刻意的安静次要声)、代码(mono 自成一体)。chrome 保紧凑,32px 行律靠它。
///   分界=**主对话/文档内容(prose 15)vs 一切框住或操作它的东西(chrome 13)**。此判断守卫测试做不了——
///   守卫(`type_scale_guard_test.dart`)只守机械不变量:字号全出此处(别处禁裸 `fontSize:`)、只两档字重
///   (w300/w400);新 prose 面靠 AnMarkdown 对照板(`capture_md_parity.dart`)肉眼验。
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

  /// The READING-COLUMN body — 15px w300 at 1.6 line-height (24px line box, a clean 2:1 over the 12px
  /// block gap). ONE rung ABOVE the 13px dense-UI anchor (the industry ladder: sidebar/nav 13-14, prose
  /// 15-16) so navigation and content stop reading as the same voice. Used ONLY by prose reading
  /// surfaces (AnMarkdown + the document ocean), NOT the dense 32px-row UI chrome. 阅读列正文:15px w300、
  /// 行高 1.6(24px 行盒,与 12 块间距成 2:1)。比 13 密集 UI 锚**高一档**(业界阶梯:侧栏 13-14/正文 15-16),
  /// 导航与内容不再同声。仅 prose 阅读面用(AnMarkdown+文档海洋),密集 UI chrome 不用。
  static const TextStyle reading = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 15, height: 1.6, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)],
  );

  /// READING-COLUMN headings — the content ladder riding the 15px [reading] body (in-document h1 22 /
  /// h2 18 / h3 15-emphasis; the page's BIG title stays [h2] 24). w400 only — hierarchy is size+colour,
  /// never heavier weight (two-weight rule). The dense-UI chrome ladder ([h1] 32/[h2] 24/[h3] 20/[strong]
  /// 16) is a SEPARATE axis and does not move. 阅读列标题阶梯(文档内 h1 22/h2 18/h3 15 强调;页大标题仍
  /// [h2] 24)。只用 w400——层级靠字号+颜色(两字重铁律)。密集 UI 的标题阶梯是独立轴、不动。
  static const TextStyle readingH1 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 22, height: 1.3, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.2,
  );
  static const TextStyle readingH2 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 18, height: 1.35, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)],
  );
  static const TextStyle readingH3 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 15, height: 1.5, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)],
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

  /// Inline mono at [code]'s size (12px) but with a tighter [height] 1.4 for SINGLE-LINE row content
  /// (a tool call's target / an entity id echoed on a bare row): code BLOCKS want the looser 1.6
  /// leading, row-embedded inline mono wants the row's rhythm. The one-rung-down twin of the
  /// [mono](13/1.5, inline ids) ↔ [code](12/1.6, code blocks) split. 内联 mono:code 的 12px + 更紧
  /// 行高 1.4,给单行行内内容(工具 target / 行内 id);代码块用 1.6、行内用行节奏。
  static const TextStyle codeInline = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w400,
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
