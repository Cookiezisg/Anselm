import 'package:flutter/material.dart';

import 'an_fonts.dart';

/// Typography — a modular scale anchored on a 13px UI body. [uiFamily] = BUNDLED Inter (the
/// variable font, wght 100–900), the Latin/numeral face; CJK glyphs fall through to BUNDLED MiSans
/// (VF, wght 150–700) first in [uiFallback] — BOTH ship in the bundle, so the bilingual UI renders
/// the same on every machine (the demo's intent; Inter has no CJK coverage by design). The body
/// renders LIGHT (w300) and the ramp climbs from there. Colorless on purpose: the theme applies ink
/// once and it inherits.
///
/// **DUAL-TRACK TYPE LADDER — the registry (which surface uses which rung).** The line: the CONTENT
/// WORKSPACE (the centre area a person reads/works in) rides the 15 system; everything that frames
/// or operates on it stays on the 13 anchor. Inside content there are TWO TIERS — values/prose the
/// person reads = 15, labels/metadata = 13:
///
///   • **CONTENT — the 15 system**: [reading] (15/1.6) prose, [readingH1]/[readingH2]/[readingH3]
///     (22/18/15) content headings, [valueReading] (15/1.4 + tabular; mono 13) content KV values,
///     [codeReading] (mono 13/1.6) content code blocks. The registry: composer input + placeholder,
///     user bubble (live + optimistic), assistant answer (AnMarkdown), the THINKING aside (15,
///     demoted by inkMuted COLOUR — never by size), document/skill body (AnEditor), content KV
///     values (entity overviews + document properties via AnKv/AnField default tier), content code
///     (markdown/doc fenced blocks, entity source/prompt blocks, the version tab's diff), the chat
///     head title (readingH3), content section heads (AnSection plain → readingH2).
///
///   • **CONTENT LABELS / METADATA — the 13 tier inside content**: [label]/[body] (13). KV keys,
///     tab labels + counts, timestamps/counts in value columns (AnKvRow.meta), crumbs, tool-card
///     verb lines, thinking's "thought for Ns" label, stop banners, attachment chips/cards, ref
///     pills, InfoCard heads. NEVER 12 inside the content column — meta 12 is chrome-only.
///
///   • **CHROME — the 13 anchor, [meta] 12 secondary**: nav rails, buttons, menus/popovers
///     (incl. the mention panel), dialogs, toasts, badges/tags, AnState, the right-island
///     inspectors, the run terminal + cockpit + approval prompts, tool-card machine windows +
///     receipts ([code] 12 — the terminal twin), markdown tables (AnThinTable, the 0.87 industry
///     ratio), the graph canvas (geometry-locked). The 32px row rhythm depends on chrome staying
///     compact.
///
/// It is a human judgment the guard test can't make — the guard
/// (`test/core/design/type_scale_guard_test.dart`) only enforces the MECHANICAL invariants: every
/// size flows from here (no raw `fontSize:`/`height:` literals elsewhere), only two weights exist
/// (w300/w400), and re-weights go through `.weight()` (never bare `copyWith(fontWeight:)` — the
/// pinned wght axis wins on a VF). New prose surfaces are checked visually against the AnMarkdown
/// baseline (`test/dev/capture_md_parity.dart`).
///
/// 字体——模数阶梯。[uiFamily]=**随包 Inter**(变量字体,wght 100–900),拉丁/数字字面;中文字形回落到
/// [uiFallback] 首位的**随包 MiSans**(VF,150–700)——两者皆入包,每台机器同字面。正文压细 w300,
/// 字重阶梯由此上爬。刻意无色:主题上一次 ink、全部继承。
///
/// **双轨字阶——登记表**。分界:**内容工作区(人阅读/工作的中心区)走 15 体系**,框住/操作它的一切守 13 锚;
/// 内容区内部两级——人读的值/正文=15,标签/元数据=13:
///   • **内容 15 体系**:[reading] 15/1.6 正文、[readingH1/H2/H3] 22/18/15 内容标题、[valueReading]
///     15/1.4+tabular(mono 13)内容 KV 值、[codeReading] mono 13/1.6 内容代码。登记:composer 输入+占位、
///     用户气泡、助手答案(AnMarkdown)、**thinking 旁白(15,靠 inkMuted 颜色降权、绝不靠字号)**、文档/skill
///     正文(AnEditor)、实体 overview + 文档属性的 KV 值(AnKv/AnField 默认档)、内容代码(markdown/doc
///     代码块、实体源码/提示块、版本 tab diff)、chat 头标题(readingH3)、内容分节头(AnSection plain→readingH2)。
///   • **内容内标签/元数据 = 13**([label]/[body]):KV 键、tab 标签+计数、值列时间戳/计数(AnKvRow.meta)、
///     面包屑、tool 卡动词行、thinking 的 thought 标签、终止横幅、附件 chip/卡、ref 药丸、InfoCard 头。
///     **内容列内绝不用 12**——meta 12 仅限 chrome。
///   • **chrome 13 锚(次级 [meta] 12)**:导航/按钮/菜单浮层(含 mention 面板)/对话框/toast/徽章标签/
///     AnState/右岛检查器/run 终端+驾驶舱+审批提示/tool 卡机器窗+回执([code] 12,终端孪生)/markdown
///     表格(AnThinTable,0.87 业界比)/图画布(几何锁定)。32px 行律靠 chrome 紧凑。
///   守卫(`type_scale_guard_test.dart`)只守机械不变量:字号/行高字面全出此处、只两档字重、重定权必走
///   `.weight()`(裸 copyWith(fontWeight:) 会被钉死的 wght 轴覆盖);新 prose 面靠 AnMarkdown 对照板
///   (`capture_md_parity.dart`)肉眼验。
abstract final class AnText {
  // The UI (①) + code (③) FAMILIES delegate to the [AnFonts] font axes — the SINGLE source both this
  // ladder and [AnTheme] read. Default (no boot) = the bundled bilingual faces (Inter + MiSans / JetBrains
  // Mono), so an untouched install is today's app byte-for-byte. These are the RESTART axes: [AnFonts]
  // resolves them ONCE before runApp; because they feed the `static final` styles below (materialized on
  // first access, after boot), a changed choice takes effect on the NEXT launch (settings says「重启后
  // 生效」). The CONTENT (②) axis is separate + HOT — the prose surfaces layer its face at build time and
  // never touch this ladder (see an_fonts.dart / contentFaceProvider). UI/代码族委托 AnFonts 字体轴(本阶梯
  // 与 AnTheme 的唯一源);默认=随包双拼(现状);此二为重启轴(启动前解析一次,喂下方 static final 样式)。内容轴另
  // 走热路,prose 面 build 期覆盖、不碰本阶梯。
  static String? get uiFamily => AnFonts.ui.family;
  static List<String> get uiFallback => AnFonts.ui.fallback;
  static String? get monoFamily => AnFonts.mono.family;
  static List<String> get monoFallback => AnFonts.mono.fallback;

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
  static final TextStyle h1 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 32, height: 1.25, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.5,
  );
  static final TextStyle h2 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 24, height: 1.25, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.3,
  );
  static final TextStyle h3 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 20, height: 1.3, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.2,
  );
  static final TextStyle strong = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 16, height: 1.4, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], // emphasis = Regular 强调=Regular
  );

  /// The BRAND wordmark — "Anselm" set in Newsreader (OFL serif). The SOLE deliberate exception to both the
  /// UI font family AND the two-weight rule: an identity asset, never UI text. Only [AnWindowControls]' brand
  /// lockup uses it (fullscreen / Windows-Linux, where the OS hides the traffic lights and the brand takes
  /// that spot). 18/1.0 pairs with the 16px naked mark; plain (no tracking/embellishment, 拍板). Colour is
  /// applied at the call site. 品牌 wordmark:Newsreader(OFL 衬线)排的「Anselm」——UI 字族 + 两字重铁律的**唯一**刻意例外
  /// (identity 资产、非 UI 文本);仅 AnWindowControls 品牌锁定组合用(全屏/Win-Linux 无 OS 红绿灯处)。18/1.0 配 16 裸 mark;纯净无点缀;色在调用处给。
  static final TextStyle wordmark = TextStyle(
    fontFamily: 'Newsreader',
    fontSize: 18, height: 1.0, fontWeight: FontWeight.w400,
  );
  static final TextStyle body = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 13, height: 1.4, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)], // the UI anchor — Light 正文锚·Light
  );

  /// The READING-COLUMN body — 15px w300 at 1.6 line-height (24px line box, a clean 2:1 over the 12px
  /// block gap). ONE rung ABOVE the 13px dense-UI anchor (the industry ladder: sidebar/nav 13-14, prose
  /// 15-16) so navigation and content stop reading as the same voice. Used ONLY by prose reading
  /// surfaces (AnMarkdown + the document ocean), NOT the dense 32px-row UI chrome. 阅读列正文:15px w300、
  /// 行高 1.6(24px 行盒,与 12 块间距成 2:1)。比 13 密集 UI 锚**高一档**(业界阶梯:侧栏 13-14/正文 15-16),
  /// 导航与内容不再同声。仅 prose 阅读面用(AnMarkdown+文档海洋),密集 UI chrome 不用。
  static final TextStyle reading = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 15, height: 1.6, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)],
  );

  /// READING-COLUMN headings — the content ladder riding the 15px [reading] body (in-document h1 22 /
  /// h2 18 / h3 15-emphasis; the page's BIG title stays [h2] 24). w400 only — hierarchy is size+colour,
  /// never heavier weight (two-weight rule). The dense-UI chrome ladder ([h1] 32/[h2] 24/[h3] 20/[strong]
  /// 16) is a SEPARATE axis and does not move. 阅读列标题阶梯(文档内 h1 22/h2 18/h3 15 强调;页大标题仍
  /// [h2] 24)。只用 w400——层级靠字号+颜色(两字重铁律)。密集 UI 的标题阶梯是独立轴、不动。
  static final TextStyle readingH1 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 22, height: 1.3, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)], letterSpacing: -0.2,
  );
  static final TextStyle readingH2 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 18, height: 1.35, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)],
  );
  static final TextStyle readingH3 = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 15, height: 1.5, fontWeight: FontWeight.w400, fontVariations: [FontVariation('wght', 400)],
  );
  static final TextStyle label = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 13, height: 1.4, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)], // Light 标签·Light
  );
  static final TextStyle meta = TextStyle(
    fontFamily: uiFamily, fontFamilyFallback: uiFallback,
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w300, fontVariations: [FontVariation('wght', 300)], // muted secondary — Light 次级·Light
  );
  static final TextStyle mono = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 13, height: 1.5, fontWeight: FontWeight.w400,
  );

  /// The CODE-SURFACE style (G5) — mono at meta size (12px) with a roomier prose line-height (demo
  /// --t-meta / --lh-prose=1.6). The MACHINE-tier rung of the code pair (content code rides
  /// [codeReading]); within a surface, gutter + code area share ONE rung so line numbers stay
  /// row-aligned (WRK-040 §4 — AnCodeEditor/AnVersionDiff switch both via `reading`). Distinct from
  /// [mono] (13/1.5, inline ids) — code blocks want the looser leading.
  /// 代码面样式:mono · 12px(meta)· 行高 1.6(prose);行号列与代码区共用之保对齐。区别于 mono(13/1.5 内联 id)。
  static final TextStyle code = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 12, height: 1.6, fontWeight: FontWeight.w400,
  );

  /// Inline mono at [code]'s size (12px) but with a tighter [height] 1.4 for SINGLE-LINE row content
  /// (a tool call's target / an entity id echoed on a bare row): code BLOCKS want the looser 1.6
  /// leading, row-embedded inline mono wants the row's rhythm. The one-rung-down twin of the
  /// [mono](13/1.5, inline ids) ↔ [code](12/1.6, code blocks) split. 内联 mono:code 的 12px + 更紧
  /// 行高 1.4,给单行行内内容(工具 target / 行内 id);代码块用 1.6、行内用行节奏。
  static final TextStyle codeInline = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 12, height: 1.4, fontWeight: FontWeight.w400,
  );

  /// The CONTENT-tier code-block style — mono **13**/1.6, one rung over [code] (12), for code the
  /// person READS inside the 15 content column: markdown/doc fenced blocks, entity source/prompt
  /// blocks, the version tab's diff. 13/15 = 0.87 — the industry prose-to-code ratio (Tailwind
  /// prose 0.875em, GitHub 85%; ChatGPT's 12.5px code was mass-reported unreadable). MACHINE
  /// windows (tool cards, JSON tree, run terminal, gantt/canvas) deliberately stay on [code] 12 —
  /// the terminal-twin identity. 内容档代码块:mono 13/1.6,比 [code] 高一档,给 15 内容列里**人读**
  /// 的代码(markdown/doc 代码块、实体源码/提示、版本 diff);13/15=0.87 恰为业界 prose:code 比。机器窗
  /// (tool 卡/json 树/终端/甘特/画布)钦定守 [code] 12——终端孪生身份。
  static final TextStyle codeReading = TextStyle(
    fontFamily: monoFamily, fontFamilyFallback: monoFallback,
    fontSize: 13, height: 1.6, fontWeight: FontWeight.w400,
  );

  /// The value-column base style — the single source for the "值列 tabular 铁律": tabular figures
  /// UNCONDITIONALLY so digit columns align AND the idle↔editing toggle never changes width; [mono] only
  /// switches the family (ids / hashes). Shared by AnKv / AnField / AnEditableValue / AnInput so a retune
  /// can't drift across copies. Callers add the colour via `copyWith`. This is the CHROME tier (13/12);
  /// content KV values ride [valueReading]. 值列样式单源(无条件 tabular);颜色另加。chrome 档;内容值走
  /// [valueReading]。
  static TextStyle value({bool mono = false}) => mono
      ? AnText.mono.copyWith(fontSize: meta.fontSize, fontFeatures: const [FontFeature.tabularFigures()])
      : body.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// The CONTENT-tier value-column style — the 15 twin of [value] for KV values the person READS
  /// (entity overviews, document properties). **15 at HEIGHT 1.4** (21px line box), NOT [reading]'s
  /// 1.6: AnLeadValue centre-aligns line boxes against the 13 key (18.2px — a 24px box would sink
  /// the value ~3px), the 32px row keeps headroom (21+8=29≤32), and the in-place edit frame's
  /// vertical bleed still fits (21+2×editBoxPadY=29). The mono variant is the mono family at 13
  /// (the content label tier) so ids/hashes read one rung under the 15 words, mirroring the chrome
  /// 13/12 split. 内容档值列:15/**1.4**+tabular(21px 行盒——1.6 会让值盒 24px 压过 13 键盒 3px、
  /// 且吃光 32 行余量);mono 变体=mono 族 13(内容标签档),镜像 chrome 的 13/12 两级。
  static TextStyle valueReading({bool mono = false}) => mono
      ? AnText.mono.copyWith(fontFeatures: const [FontFeature.tabularFigures()])
      : reading.copyWith(height: 1.4, fontFeatures: const [FontFeature.tabularFigures()]);

  /// The meta-sized tabular idiom — the single source for CHROME trailing counts / step indices
  /// (row meta, menu/dropdown trailing numbers, stepper indices), so a digit-feature retune can't
  /// drift across copies (mirrors [value]'s rule at meta size). Content-column counts (AnTabs) ride
  /// [value] 13 instead — metadata inside content never drops to 12. Callers add the colour via
  /// `copyWith`. chrome 次级等宽数字单源(行/菜单/下拉/步骤尾随计数);内容列计数(AnTabs)走 value() 13。
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
