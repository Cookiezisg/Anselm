import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_editor_inline_code.dart';
import 'an_editor_quote.dart';
import 'an_editor_mention.dart';

/// The measured advance of one JetBrains-Mono glyph cell at [AnText.mono]'s font size 13 (13 × 0.619 ≈ 8.05px).
/// Used to size the inline-code NBSP padding spacer: its advance is shrunk to [AnSpace.s4] (4px) via
/// `letterSpacing = AnSpace.s4 - kMonoCellWidth`, which reserves exactly the painter's visible 4px padding while
/// keeping the spacer at full font size (so the caret stays full height on it). AnText.mono is fixed at 13, so
/// this is stable. mono 13 单格步进(实测 8.05px);内距占位靠它算负 letterSpacing 把步进缩到 4px。
const double kMonoCellWidth = 8.05;

/// The editor's block stylesheet — written FROM SCRATCH (never `defaultStylesheet.copyWith`, which
/// silently drops [Styles.maxWidth] when you add rules; E0 post-mortem discipline #4). It carries the An
/// PROSE voice onto super_editor's text blocks so a paragraph/heading in the editor reads pixel-for-pixel
/// like the same block anywhere else in the product: body = [AnText.reading] (15/1.6/w300, ink), the
/// heading ladder = [AnText.readingH1]/[readingH2]/[readingH3] (22/18/15, w400 — hierarchy is size+colour,
/// never a heavier weight, the two-weight rule), and ONE block gap = [AnFlow.block] (12) with headings
/// asymmetric (more air ABOVE, tight to their body BELOW).
///
/// Colours are resolved from [AnColors] at build time (the editor's `build` closes over `context.colors`)
/// because super_editor's [StyleRule] callbacks get no BuildContext. Rebuild the sheet on brightness flip.
///
/// Non-text block skins (blockquote bar, code well, list bullets, task checkboxes) are their own
/// ComponentBuilders (E2b+), NOT text rules here — this sheet governs the TEXT tiers + the vertical rhythm.
///
/// 编辑器块样式表:从零写(绝不 copyWith defaultStylesheet——加规则会静默丢 maxWidth,E0 教训)。把 An prose
/// 声搬上 super_editor:正文 reading 15/1.6/w300 ink、标题阶梯 readingH1/2/3(22/18/15,w400——层级靠字号+颜色
/// 非更重字重)、唯一块间距 12(标题不对称:上多、贴其正文下紧)。颜色 build 期从 AnColors 闭包取(StyleRule 无 context)。
Stylesheet buildAnEditorStylesheet(AnColors colors) {
  TextStyle ink(TextStyle s) => s.copyWith(color: colors.ink);

  return Stylesheet(
    inlineTextStyler: (attributions, existingStyle) => anInlineTextStyler(colors, attributions, existingStyle),
    // The @mention pill builder runs first; the rest of the chain (inline images) stays. Inline code is NOT a
    // widget builder — it's plain codeAttribution text with a rounded background painted beneath it by
    // AnTextComponent (paint-beneath). 提及药丸在前;行内代码不再走 widget builder,而是 codeAttribution 文本+底层圆角背景。
    inlineWidgetBuilders: [anMentionInlineWidgetBuilder, ...defaultInlineWidgetBuilderChain],
    rules: _rules(colors, ink),
  );
}

/// The INLINE (span-level) styler — maps super_editor's inline attributions to An visuals, replacing the
/// package default so emphasis obeys the two-weight rule and code/links wear our tokens:
///  • **bold** → [AnText.emphasisWeight] (w400), NOT `FontWeight.bold` (w700) — emphasis is one weight up,
///    never heavier (two-weight rule). The `fontVariation` MUST move too or the variable UI face stays at
///    the body's wght 300.
///  • *italic* / underline / ~~strike~~ → the usual decorations (combined so they stack).
///  • `inline code` → the mono content-inline tier ([AnText.mono], 13 = the 0.87 prose-to-code ratio
///    against the 15 body) on a [AnColors.surfaceSunken] highlight.
///  • [link](x) → [AnColors.accent] + underline (the toB blue, not the package's lightBlue).
///
/// 行内样式器:把 super_editor 行内 attribution 映成 An 视觉——粗=w400(两字重铁律,非 w700;须同步 fontVariation)、
/// 斜/下划/删除线照常(可叠)、行内代码=mono 13+surfaceSunken 凹槽、链接=accent 蓝+下划线。
TextStyle anInlineTextStyler(AnColors colors, Set<Attribution> attributions, TextStyle existingStyle) {
  var s = existingStyle;
  TextDecoration add(TextDecoration d) =>
      s.decoration == null ? d : TextDecoration.combine([s.decoration!, d]);

  for (final a in attributions) {
    if (a == boldAttribution) {
      // `.weight()` moves BOTH the fontWeight and the VF wght axis (a bare copyWith(fontWeight:) renders
      // the base weight on the pinned-axis variable face — the two-weight guard forbids it). 双轴重定权。
      s = s.weight(AnText.emphasisWeight);
    } else if (a == italicsAttribution) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    } else if (a == underlineAttribution) {
      s = s.copyWith(decoration: add(TextDecoration.underline));
    } else if (a == strikethroughAttribution) {
      s = s.copyWith(decoration: add(TextDecoration.lineThrough));
    } else if (a == codeAttribution) {
      // Mono voice only — the rounded [AnColors.surfaceSunken] background is painted BENEATH the run by
      // AnTextComponent's CodeBackgroundLayer (paint-beneath), NOT a tight TextStyle.backgroundColor
      // rectangle (which can't wrap with rounded corners). mono 声;圆角背景由 AnTextComponent 底层绘制,非矩形。
      s = s.copyWith(
        fontFamily: AnText.mono.fontFamily,
        fontFamilyFallback: AnText.mono.fontFamilyFallback,
        fontSize: AnText.mono.fontSize,
        fontVariations: const [], // clear the UI VF wght — the mono face isn't that axis 清变量轴
      );
    } else if (a is LinkAttribution) {
      s = s.copyWith(color: colors.accent, decoration: add(TextDecoration.underline));
    } else if (a is ColorAttribution) {
      s = s.copyWith(color: a.color);
    } else if (a is BackgroundColorAttribution) {
      s = s.copyWith(backgroundColor: a.color);
    } else if (a is FontSizeAttribution) {
      s = s.copyWith(fontSize: a.fontSize);
    }
  }
  // The inline-code NBSP padding spacer: shrink its ADVANCE to the 4px reservation via NEGATIVE letterSpacing,
  // but keep the FULL mono font size — otherwise the caret, whose height is taken from the character it sits on,
  // turns stubby the instant it lands on the spacer at a code edge (a shrunk-fontSize spacer gave a tiny caret).
  // letterSpacing is trailing, so a lone NBSP's advance = monoCell (8.05) + letterSpacing → AnSpace.s4 (4px);
  // the painter's 4px inflation then lands flush against a glued neighbour. 内距占位:用负 letterSpacing 缩「步进」到 4px,
  // 但字号保持满 mono——否则光标落到占位符上会因字号变矮(高度取自所在字符);步进=8.05+letterSpacing=4px。
  if (attributions.contains(codeSpacerAttribution)) {
    s = s.copyWith(letterSpacing: AnSpace.s4 - kMonoCellWidth);
  }
  return s;
}

// Space ABOVE a heading: the section-separation [AnFlow.headingTop] (24) by default, but the "consecutive
// heading override" — [AnFlow.headingStack] (12) — when the PREVIOUS block is ALSO a heading, so stacked
// headings group tightly instead of making the oversized gaps that read as broken (prose-typography best
// practice; matches chat, whose blank-line block gap doesn't fire between adjacent headings). 标题上距:默认 24,
// 上一个块也是标题时收紧到 12(连续标题覆写,与 chat 一致)。
double _headingTopFor(Document doc, DocumentNode node) {
  final index = doc.getNodeIndexById(node.id);
  if (index > 0 && _isHeaderNode(doc.getNodeAt(index - 1))) return AnFlow.headingStack;
  return AnFlow.headingTop;
}

bool _isHeaderNode(DocumentNode? node) {
  final bt = node?.getMetadataValue('blockType');
  return bt == header1Attribution ||
      bt == header2Attribution ||
      bt == header3Attribution ||
      bt == header4Attribution ||
      bt == header5Attribution ||
      bt == header6Attribution;
}

List<StyleRule> _rules(AnColors colors, TextStyle Function(TextStyle) ink) {
  return [
      // Base cascade — the An reading measure (720) + the body voice every block inherits. Horizontal
      // padding is the CONTAINER's job (the reading column / ocean), so 0 here. In-app the host sliver's
      // symmetric pageX padding already clamps the text column to 672 — this cap only bites in a
      // standalone host. 基底:720 阅读列 + 正文声;app 内宿主 sliver 两侧 pageX 已钳 672,此帽为独立宿主兜底。
      StyleRule(
        BlockSelector.all,
        (doc, node) => {
          Styles.maxWidth: AnSize.content,
          Styles.padding: const CascadingPadding.symmetric(horizontal: 0),
          Styles.textStyle: ink(AnText.reading),
        },
      ),

      // Heading ladder — size+colour carry hierarchy; UNIFORM top air matching chat's AnMarkdown exactly
      // (`_AnHTag` there = one block gap on top of the flanking block gap → ~24 above / 12 below, same for
      // every level). The B-021 asymmetric 32/24/16 ladder is retired in favour of chat parity (user 0714:
      // documents markdown must read 1:1 with chat). One token — [AnFlow.headingTop] (24) — all levels.
      // 标题上距:统一 24,与 chat AnMarkdown 逐像素一致(那边 _AnHTag=块间距上再加一块=上 24 下 12,各级同)。
      // B-021 的 32/24/16 阶梯退役,换 chat 对齐(用户 0714:文档 markdown 须与 chat 1:1)。
      StyleRule(
        const BlockSelector('header1'),
        (doc, node) => {
          Styles.padding: CascadingPadding.only(top: _headingTopFor(doc, node)), // 24 — chat parity
          Styles.textStyle: ink(AnText.readingH1),
        },
      ),
      StyleRule(
        const BlockSelector('header2'),
        (doc, node) => {
          Styles.padding: CascadingPadding.only(top: _headingTopFor(doc, node)),
          Styles.textStyle: ink(AnText.readingH2),
        },
      ),
      StyleRule(
        const BlockSelector('header3'),
        (doc, node) => {
          Styles.padding: CascadingPadding.only(top: _headingTopFor(doc, node)),
          Styles.textStyle: ink(AnText.readingH3),
        },
      ),
      // h4–h6 fold into the level-3 reading size (per the outline invariant) but STILL need the heading top gap
      // — without their own rules they fell through with no top padding, so H4–H6 packed tight against each
      // other while chat gives every heading the 24 gap. h4–h6 并入 h3 尺寸,但仍需 24 顶距(缺规则会挤成一坨)。
      StyleRule(
        const BlockSelector('header4'),
        (doc, node) => {
          Styles.padding: CascadingPadding.only(top: _headingTopFor(doc, node)),
          Styles.textStyle: ink(AnText.readingH3),
        },
      ),
      StyleRule(
        const BlockSelector('header5'),
        (doc, node) => {
          Styles.padding: CascadingPadding.only(top: _headingTopFor(doc, node)),
          Styles.textStyle: ink(AnText.readingH3),
        },
      ),
      StyleRule(
        const BlockSelector('header6'),
        (doc, node) => {
          Styles.padding: CascadingPadding.only(top: _headingTopFor(doc, node)),
          Styles.textStyle: ink(AnText.readingH3),
        },
      ),

      // Body blocks — ONE house gap (12) above every stacked block. 正文块:唯一 12 块间距。
      StyleRule(
        const BlockSelector('paragraph'),
        // A quoted continuation paragraph carries its gap INSIDE the bar (wrapInQuote's topGap), so its external
        // top padding is 0 → the left rule stays continuous. 引用延续段外距归零(间距落条内)。
        (doc, node) => {Styles.padding: CascadingPadding.only(top: isQuoteContinuation(doc, node) ? 0 : AnFlow.block)},
      ),
      // List items — the bullet/numeral is a QUIET inkMuted marker (never competes with the body ink);
      // consecutive items sit tight (s4), only the FIRST gets the full block gap (handled by the
      // .after(listItem) override below). 列表:bullet/序号=inkMuted 静默标记;连续项收紧,只首项吃满 12。
      StyleRule(
        const BlockSelector('listItem'),
        (doc, node) => {
          Styles.padding: const CascadingPadding.only(top: AnFlow.block),
          Styles.dotColor: colors.inkFaint, // chat parity — list markers ride inkFaint (an_markdown.dart)
        },
      ),
      StyleRule(
        const BlockSelector('listItem').after('listItem'),
        (doc, node) => {Styles.padding: CascadingPadding.only(top: isQuoteContinuation(doc, node) ? 0 : AnFlow.listItem)},
      ),

      // Tasks ride the reading body voice; consecutive tasks sit tight (the An glyph + done-strike are
      // drawn by AnTaskComponentBuilder). 任务:reading 声,连续项收紧(勾/删除线由组件画)。
      StyleRule(
        const BlockSelector('task'),
        (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.block)},
      ),
      StyleRule(
        const BlockSelector('task').after('task'),
        // 任务连续项收紧,与列表项同档(li↔li)。consecutive tasks sit at the list-item tight gap.
        (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.listItem)},
      ),

      // Blockquote — the quiet-aside voice: reading body dropped to inkMuted (the left bar is drawn by
      // AnBlockquoteComponentBuilder, not here). 引用:reading 声降到 inkMuted(左条由组件画)。
      StyleRule(
        const BlockSelector('blockquote'),
        (doc, node) => {
          Styles.padding: const CascadingPadding.only(top: AnFlow.block),
          Styles.textStyle: AnText.reading.copyWith(color: colors.inkMuted),
        },
      ),

      // Fenced code — the content-tier code voice (mono 13/1.6, ink); the framed white island is drawn
      // by AnCodeBlockComponentBuilder. 围栏代码:内容档代码声(mono 13/1.6 ink);白岛框由组件画。
      StyleRule(
        const BlockSelector('code'),
        (doc, node) => {
          Styles.padding: const CascadingPadding.only(top: AnFlow.block),
          Styles.textStyle: AnText.codeReading.copyWith(color: colors.ink),
        },
      ),

      // Table (E8) — An hairline grid + emphasis header + snug cell padding. Vertical padding is GFM's
      // canonical 6px (tightened from 8 — the 15/1.6 reading line box already breathes; 8 made a 40px row).
      // This is the ONE value shared with the chat table primitive [AnProseTable] so the two are 1:1.
      // 表格:发丝网格 + 强调表头 + 紧凑内距;竖内距=GFM 6px(从 8 收紧,1.6 行盒已有留白);与 chat AnProseTable 同值。
      StyleRule(
        BlockSelector(tableBlockAttribution.name),
        (doc, node) => {
          Styles.padding: const CascadingPadding.only(top: AnFlow.block),
          Styles.textStyle: AnText.reading.copyWith(color: colors.ink),
          TableStyles.border: TableBorder.all(color: colors.line, width: AnSize.hairline),
          TableStyles.headerTextStyle: AnText.reading.weight(AnText.emphasisWeight).copyWith(color: colors.ink),
          TableStyles.cellPadding: const CascadingPadding.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s6),
        },
      ),

      // NO tight-below override — chat gives every block after a heading the uniform block gap (12), so the
      // editor does too (B-021's stackTight "hug" is retired for chat parity). A paragraph after a heading
      // falls through to the general `paragraph` rule (top 12). 标题下方=统一 12(chat 无「贴紧」,B-021 hug 退役)。

      // The first block never gets a top gap (it would push the whole document down); the last gets a
      // GENEROUS trailing runway — an editor deliberately wants more bottom room than a page (room to
      // scroll the last line up + a click-target below the content), so it's the page runway plus a
      // section unit (48 + 24), NOT the plain page [AnInset.pageBottom]. Named by composition, not a lone
      // magic literal (B-021). 首块不加顶距;末块=慷慨尾部余量(编辑器比页面要更多底部空间:末行可上滚+下方点击区),
      // =页面余量 + 一个 section 单位(48+24),非裸魔数(B-021)。
      StyleRule(
        BlockSelector.all.first(),
        (doc, node) => {Styles.padding: const CascadingPadding.only(top: 0)},
      ),
      StyleRule(
        BlockSelector.all.last(),
        (doc, node) => {Styles.padding: const CascadingPadding.only(bottom: AnInset.pageBottom + AnGap.section)},
      ),
    ];
}
