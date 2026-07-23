import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart'
    show BlockQuoteWidget;
import 'package:gpt_markdown/custom_widgets/markdown_config.dart'
    show GptMarkdownConfig;
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../i18n/strings.g.dart';
import '../design/an_fonts.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_code_chip.dart';
import 'an_code_editor.dart';
import 'an_prose_table.dart';
import 'icons.dart';

/// The chat markdown renderer — a token-locked FACADE over `gpt_markdown` (pinned exact; only this file
/// imports it). Feeds the assistant `text` block: paragraphs, bold/italic/links, inline + fenced code,
/// tables, lists, blockquotes, hr. Every default that violates our system is replaced:
///
/// - **Bold → w400 via `.weight()`** ([_AnBoldMd] swaps the package component): the package's bare
///   `copyWith(fontWeight: bold)` is OVERRIDDEN by our pinned `wght` axis — the default would render
///   bold as w300, i.e. not bold at all (two-weight rule made load-bearing).
/// - **Headings downshift**: md `#`/`##`/`###` → 22/18/15-w400 (a chat reading column must not shout;
///   h4–h6 fold into the readingH3 15-w400 tier). Hierarchy = size + colour, never heavier weight.
/// - **Fenced code → [AnCodeEditor]** (read-only): the ONE code anatomy — AnCodeSurface frame, lang
///   label, copy, wrap, gutter, and the single `highlightCode` tokenizer. Never a second highlighter.
/// - **Inline code** → mono on a [AnColors.surfaceSunken] chip (package default hardcodes bold → broken
///   on the pinned axis, and isn't mono).
/// - **Links** → accent, NEVER auto-open: schemes outside http/https/mailto are dropped (javascript:/
///   data:/file: inert); allowed ones surface through [onLinkTap] — opening is the HOST's job (this file
///   never imports url_launcher).
/// - **Images** → an inert placeholder chip; NO network fetch ever (prompt-injection exfiltration + local
///   SSRF stay closed).
/// - **Tables → [AnProseTable]** (a bordered hairline grid, 1:1 with the document editor's table; cells
///   parsed RICH via `MdWidget` — bold/italic/code/links render; header emphasis, body reading).
/// - **Blockquote** → the quiet-aside grammar (2px `lineStrong` left bar + `inkMuted` prose), same
///   register as the thinking rail.
/// - **LaTeX + `<u>` OFF**: math components stripped (no flutter_math cost); UnderLineMd stripped so
///   `<u>` renders literally — raw HTML stays inert text (the package has no HTML engine; we add none).
///
/// The markdown type SCALE — two ladders over ONE renderer. **reading** (15 body + the 22/18/15 heading阶,
/// the roomier 1.6 leading) is calibrated for the 720 reading column + chat message bubbles: prose a person
/// SITS AND READS. **embedded** treats the 13 chrome anchor as its body and gives headings just ONE louder
/// rung — h1/h2 → 15-w400, h3–h6 → 13-w400 (hierarchy carried by WEIGHT + top-space, never drama) — and
/// tightens the block gap + drops code a rung, for markdown that lives INSIDE a machine window / island
/// stage / preview card (the reading ladder's big headings SHOUT in a small frame). Zero NEW sizes: every
/// rung is an existing [AnText] token (industry: GitHub's hovercard + Notion's inline preview both set
/// embedded prose a rung under the page body). See design-system.md「markdown 双档」.
/// markdown 字阶双档(一套渲染器两把梯):**阅读档**(15 正文+22/18/15 标题、1.6 行高)给 720 阅读列+消息泡=人坐下来
/// 读的 prose;**嵌入档**把 13 chrome 锚当正文、标题只留一档(h1/h2→15-w400、h3–h6→13-w400,层级靠字重+上距不靠戏剧
/// 性)、块间距收紧一档、代码降一号——给住在机器窗/岛台/预览卡里的 markdown(阅读档大标题在小窗里喊)。零新字号,全取
/// 既有 AnText token(业界:GitHub hovercard / Notion 内联预览都把嵌入 prose 压页正文一档)。
enum AnMarkdownScale {
  /// The 720 reading column + chat message bubbles — 15 body, 22/18/15 headings. 阅读列+消息泡。
  reading,

  /// Machine windows / island stages / preview cards — 13 body, a single 15-w400 h1/h2, h3–h6 folded onto
  /// a 13-w400 rung, a tighter block gap, code one rung down. 窗/岛台/预览:13 正文+单一大标题档。
  embedded,
}

/// **Two SCALES over ONE renderer** ([AnMarkdownScale]): the **reading** ladder (15 body, 22/18/15 headings)
/// is the default — prose a person SITS AND READS (the 720 reading column + chat message bubbles); the
/// **embedded** ladder treats the 13 chrome anchor as its body and keeps ONE louder heading rung (h1/h2 →
/// 15-w400, h3–h6 → 13-w400) for markdown living INSIDE a machine window / island stage / preview card,
/// where the reading ladder's big headings shout. Zero NEW sizes — every rung is an existing [AnText] token.
///
/// Streaming: `text` is a pure prop — the caller swaps in the growing string (coalesced ≤1/frame); the
/// package tolerates an unclosed fence (renders it as a live code block that grows). SelectionArea is the
/// caller's job. No animation → reduced-motion N/A.
///
/// chat markdown 渲染器——gpt_markdown 的 token 锁定门面(钉死版本;全库仅此文件 import 它)。所有违反体系的
/// 默认都被换掉:**粗体→w400 走 `.weight()`**(包默认裸 `copyWith(fontWeight:)` 被钉死的 wght 轴覆盖→会渲成
/// w300 即根本不粗——两档字重在此是功能必需);**标题降档**(阅读档 22/18/15-w400,嵌入档 15/13-w400,h4–h6 并入);
/// **围栏代码→AnCodeEditor 只读**(唯一代码解剖+唯一高亮器);**内联 code**→mono+surfaceSunken chip;**链接**
/// accent、scheme 闸(http/https/mailto 之外一律惰性)、永不自动开(开链归宿主,本文件绝不 import url_launcher);
/// **图片**惰性占位、永不取网;**表格→AnProseTable**(有框发丝网格、与编辑器表 1:1;单元格经 MdWidget 富渲);**引用**=静默旁白(2px lineStrong 左条+inkMuted,
/// 与 thinking rail 同语法);**LaTeX+`<u>` 关**(HTML 一律字面惰性)。**尺度双档**(阅读/嵌入,见 [AnMarkdownScale]):
/// 阅读档=720 阅读列+消息泡;嵌入档=住在窗/岛台/预览里的 markdown,零新字号。流式:text 纯 prop、未闭合围栏容忍;
/// SelectionArea 归调用方;无动画。
class AnMarkdown extends StatelessWidget {
  const AnMarkdown(
    this.text, {
    this.onLinkTap,
    this.scale = AnMarkdownScale.reading,
    this.prose,
    super.key,
  });

  /// Markdown source — grows during streaming; stateless, so a longer string is just a rebuild.
  /// markdown 源——流式增长;无状态,换更长的串即重渲。
  final String text;

  /// Fires for an allowed-scheme link tap. Null → links are styled but inert. The host decides how to
  /// open (confirm dialog, url_launcher…) — the primitive never launches anything.
  /// 过闸链接点击回调;null=只染色不响应。怎么开(确认框/url_launcher…)是宿主的事,原语绝不自己开。
  final void Function(String url, String title)? onLinkTap;

  /// READING (default) vs EMBEDDED type scale — see [AnMarkdownScale]. Existing call sites (the chat
  /// answer, the message bubble, the document/memory MAIN reading面) omit it → reading; markdown that lives
  /// INSIDE a window / island stage / preview passes [AnMarkdownScale.embedded]. 尺度档:默认阅读档;窗/岛台/预览走嵌入档。
  final AnMarkdownScale scale;

  /// The CONTENT (②) font override — the serif / system face the chat MESSAGE BUBBLE layers over its
  /// prose (from `contentFaceProvider`). `null` = the default sans (follow the UI face) → zero change,
  /// so every EMBEDDED / chrome call site (tool cards, previews) stays on the UI face untouched. Applies
  /// to prose ONLY (body / headings / lists / tables); fenced + inline code stay mono (the code axis
  /// governs them). 内容字体覆盖:仅 chat 消息泡传衬线/系统脸;null=默认 sans(跟随 UI 脸)→零改,嵌入/chrome
  /// 调用点不受影响;只覆盖 prose,代码块与内联码守 mono(代码轴管)。
  final AnFace? prose;

  bool get _embedded => scale == AnMarkdownScale.embedded;

  static const Set<String> _allowedSchemes = {'http', 'https', 'mailto'};

  // The default component tables minus LaTeX (block+inline), UnderLineMd (`<u>` must stay literal) and
  // RadioButtonMd (`(x)` radios are NOT standard markdown — a prose line starting "(x) …" would render a
  // surprise radio button), with BoldMd/BlockQuote/CheckBoxMd swapped for the token-locked versions. Order
  // mirrors the package defaults. Static so the lists keep a stable identity across builds.
  // 默认组件表剔 LaTeX(块+内联)、UnderLineMd(`<u>` 须字面)与 RadioButtonMd(`(x)` 单选非标准 markdown——正文
  // 行首 "(x) …" 会被惊吓渲成单选钮),换入 token 锁定版加粗/引用/任务勾;顺序镜像包默认;static 保身份稳定。
  // TWO block-component lists, one per scale — they differ ONLY in the block-gap the _AnNewLines / _AnHTag
  // carry (reading = AnFlow.block 12; embedded tightens ONE tier to AnGap.stack 8). Static so each list keeps
  // a STABLE identity across builds — GptMarkdown re-parses when the component list identity changes; a fresh
  // list per build would re-parse settled prose every frame. 双档块组件表:仅换行/标题上距的块间距不同(阅读 12、
  // 嵌入收紧一档 8);static 保身份稳定——变身份触发重解析,每帧新建会重解析已落定的 prose。
  static final List<MarkdownComponent> _componentsReading = _makeComponents(
    AnFlow.block,
  );
  static final List<MarkdownComponent> _componentsEmbedded = _makeComponents(
    AnGap.stack,
  );

  static List<MarkdownComponent> _makeComponents(double blockGap) => [
    // _AnCheckBoxMd BEFORE UnOrderedList: a task line (`- [x] …`) is claimed whole by the checkbox
    // component, so it never also gets an unordered bullet. checkbox 排在无序列表前,task 行不再双记号。
    CodeBlockMd(),
    _AnNewLines(blockGap),
    _AnBlockQuoteMd(),
    TableMd(),
    _AnHTag(blockGap),
    _AnCheckBoxMd(), UnOrderedList(), OrderedList(), HrLine(), IndentMd(),
  ];
  static final List<MarkdownComponent> _inlineComponents = [
    ATagMd(),
    ImageMd(),
    TableMd(),
    StrikeMd(),
    _AnBoldMd(),
    ItalicMd(),
    HighlightedText(),
    SourceTag(),
  ];

  void _guardedLinkTap(String url, String title) {
    final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase() ?? '';
    if (!_allowedSchemes.contains(scheme)) {
      return; // javascript:/data:/file:/relative → inert 惰性
    }
    onLinkTap?.call(url, title);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The style MUST carry the theme ink: the package regenerates spans only when `style` differs
    // (isSame), so a colourless const style would go stale on a theme flip.
    // style 必须带主题墨色:包只在 style 不同才重生成 span(isSame),无色常量换主题会陈旧。
    // The two ladders (AnMarkdownScale): reading = 15 body + 22/18/15 headings at the roomier 1.6 leading
    // (Notion-calibrated prose air); embedded = the 13 chrome body + a SINGLE 15-w400 h1/h2, with h3–h6
    // folded onto a 13-w400 rung. Zero new sizes — every rung is an existing AnText token. 双档:阅读=15 正文
    // +22/18/15 标题(1.6 行高);嵌入=13 正文+单一 15-w400 h1/h2、h3–h6 并入 13-w400 档。零新字号。
    // `prose` (the CONTENT ② face) is layered onto the PROSE rungs only — body / headings / lists /
    // tables — via [applyContentFace]; null (sans) is a pass-through. Code (fenced + inline) is never
    // touched here — the code axis governs it. prose 脸只覆盖 prose 档(正文/标题/列表/表);null=直通;代码不碰。
    final body = applyContentFace(
      prose,
      (_embedded ? AnText.body : AnText.reading),
    ).copyWith(color: c.ink);
    final h1 = applyContentFace(
      prose,
      (_embedded ? AnText.readingH3 : AnText.readingH1),
    ).copyWith(color: c.ink);
    final h2 = applyContentFace(
      prose,
      (_embedded ? AnText.readingH3 : AnText.readingH2),
    ).copyWith(color: c.ink);
    // h4–h6 fold onto ONE rung with h3: reading = readingH3 (15-w400); embedded = the body re-weighted to
    // w400 (13, same size as the embedded body — hierarchy from weight + the _AnHTag top-space). h4–h6 并入 h3。
    final h456 = applyContentFace(
      prose,
      (_embedded
          ? AnText.body.weight(AnText.emphasisWeight)
          : AnText.readingH3),
    ).copyWith(color: c.ink);
    return GptMarkdownTheme(
      // The factory back-fills UNSPECIFIED fields from a fresh Material ThemeData, not ours — specify
      // every field. 工厂对未指定字段用全新 Material ThemeData 兜底——所有字段显式给值。
      gptThemeData: GptMarkdownThemeData(
        brightness: Theme.of(context).brightness,
        highlightColor: c
            .surfaceSunken, // superseded by highlightBuilder; pinned anyway 已被 builder 接管,仍钉住
        // The heading ladder per scale (md # is not a page title; h4–h6 fold into h3). 标题阶梯(按档;# 非页标题;h4–h6 并入 h3)。
        h1: h1,
        h2: h2,
        h3: h456,
        h4: h456,
        h5: h456,
        h6: h456,
        hrLineThickness: AnSize.hairline,
        hrLineColor: c.line,
        hrLinePadding: EdgeInsets
            .zero, // the newline gap owns separation (no double-stack) 间距归换行

        linkColor: c.accent,
        linkHoverColor: c.accentHover,
        autoAddDividerLineAfterH1:
            false, // no decorative divider under H1 不给 H1 配装饰分割线
      ),
      child: GptMarkdown(
        text,
        style: body,
        onLinkTap: _guardedLinkTap,
        codeBuilder: _fencedCode,
        highlightBuilder: _inlineCode,
        imageBuilder: _imagePlaceholder,
        tableBuilder: _table,
        orderedListBuilder: _orderedItem,
        unOrderedListBuilder: _unorderedItem,
        components: _embedded ? _componentsEmbedded : _componentsReading,
        inlineComponents: _inlineComponents,
      ),
    );
  }

  // Fenced code → the ONE code anatomy. An UNCLOSED fence is still streaming in — it rides the LIVE
  // face (S10: the tool cards' bounded stick-to-bottom code viewport, O(window) tail slice), because
  // the upstream open block re-parses per coalesced frame and a read-only face would re-tokenize the
  // WHOLE growing code each time (the `_highlight` memo necessarily misses while the code grows);
  // the live face also keeps a huge incoming block from stretching the transcript (the viewport pins
  // the newest lines). The close swaps ONCE to the settled content-height read-only face — same
  // AnCodeSurface chrome, no material flip (A-095). trimRight: the closing-fence newline otherwise
  // renders a trailing empty gutter line.
  // 围栏→唯一代码解剖。未闭合=仍在流入——走**live 脸**(S10:工具卡同款有界贴底代码视口,O(window)
  // 尾切),因为上游 open 块逐合并帧重解析,只读脸会每帧全量重 tokenize 增长中的整块(码在长,
  // `_highlight` 记忆必 miss);live 视口也防巨块流入把 transcript 撑长(钉最新行)。close 一次性换
  // 落定内容高只读脸——同 AnCodeSurface chrome,无材质翻转(A-095)。trimRight 去尾空行。
  // No outer padding — the flanking _AnNewLines gap is the SINGLE block-separation term; a padding here
  // would stack on it and read too loose (the old inconsistency). 无外距,间距归换行统一。
  // `reading: !_embedded`: content code rides the 13 codeReading tier; embedded code drops a rung to the 12
  // machine `code` tier (aligns the code with its tighter frame). 内容码走 13、嵌入码降一号到 12 机器档。
  Widget _fencedCode(
    BuildContext context,
    String name,
    String code,
    bool closed,
  ) => AnCodeEditor(
    code: code.trimRight(),
    lang: name.trim().isEmpty ? null : name.trim(),
    reading: !_embedded,
    live: !closed,
  );

  // Inline `code` → [AnCodeChip] (mono on a sunken padded pill; the package default is bold-only — broken on the
  // pinned axis). This is the READ-ONLY markdown renderer (chat bubbles, doc previews) — a WidgetSpan pill is
  // fine here since it never wraps mid-token in practice and is never edited. The document EDITOR uses a
  // different mechanism (paint-beneath: codeAttribution text with a rounded background painted under it, so it
  // wraps + edits in place). 内联 code→AnCodeChip(只读 markdown 渲染;编辑器另用 paint-beneath 可换行可编辑)。
  // `dense` in embedded → the 12 codeInline face (a rung under the shared mono 13); the DEFAULT chip stays
  // mono 13 so the editor's rest-state chip + the chat reading chip remain pixel-identical. 嵌入=12 小码档;
  // 默认仍 mono 13,保编辑器静置 chip 与 chat 阅读 chip 逐像素一致。
  Widget _inlineCode(BuildContext context, String text, TextStyle style) =>
      AnCodeChip(text, dense: _embedded);

  // Images: an inert chip, NEVER a network fetch (no NetworkImage anywhere) — remote images from model/tool
  // output are an exfiltration + local-SSRF channel. 图片:惰性 chip,绝不取网(渗出/SSRF 通道封死)。
  Widget _imagePlaceholder(
    BuildContext context,
    String imageUrl,
    double? width,
    double? height,
  ) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnSpace.s8,
        vertical: AnSpace.s4,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(AnRadius.tag),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(AnIcons.image, size: AnSize.iconSm, color: c.inkFaint),
          ),
          const SizedBox(width: AnSpace.s6),
          Flexible(
            child: Text(
              '${Translations.of(context).markdown.imageNotLoaded} · $imageUrl',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AnText.meta.copyWith(color: c.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  // md table → AnProseTable (bordered hairline grid, RICH cells; 1:1 with the document editor's table).
  // Each cell parses via MdWidget so bold/italic/code/links render; header = reading·emphasis·ink, body =
  // reading·ink; per-column align rides the header field's TextAlign (a tight Table cell honours
  // Text.rich(textAlign:) — no Align wrapper). No outer padding — the newline gap owns block separation.
  // trim: the package pads cells with ` | ` — untrimmed data would misalign right-aligned columns.
  // 表→有框富表(与编辑器逐像素一致):MdWidget 富渲单元格、头强调体正文、对齐随字段 TextAlign、间距归换行。
  Widget _table(
    BuildContext context,
    List<CustomTableRow> rows,
    TextStyle style,
    GptMarkdownConfig config,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final header = rows.firstWhere((r) => r.isHeader, orElse: () => rows.first);
    final cols = header.fields.length;
    if (cols == 0) return const SizedBox.shrink();
    final tableBase = applyContentFace(
      prose,
      _embedded ? AnText.body : AnText.reading,
    ); // header/body share ONE scale rung 同档
    final bodyStyle = tableBase.copyWith(color: c.ink);
    final headerStyle = tableBase
        .weight(AnText.emphasisWeight)
        .copyWith(color: c.ink);
    List<Widget> cells(CustomTableRow row, TextStyle rowStyle) => [
      for (var i = 0; i < cols; i++)
        MdWidget(
          context,
          (i < row.fields.length ? row.fields[i].data : '')
              .trim(), // pad short / clip long to header width
          false, // inline pipeline only (no block components inside a cell)
          config: config.copyWith(
            style: rowStyle,
            textAlign: header.fields[i].alignment,
          ),
        ),
    ];
    final data = rows.where((r) => !identical(r, header) && !r.isHeader);
    return AnProseTable(
      rows: [
        cells(header, headerStyle),
        for (final r in data) cells(r, bodyStyle),
      ],
    );
  }

  // List markers — the package's ordered default hardcodes w100 (broken on the pinned axis); both markers
  // re-done in inkFaint, layout mirroring the package (baseline row, start 12 / gap 8).
  // 列表记号:包的有序默认硬编码 w100(钉轴上渲错);两种记号统一 inkFaint,布局镜像包默认。
  Widget _orderedItem(
    BuildContext context,
    String no,
    Widget child,
    GptMarkdownConfig config,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AnSpace.s12,
          end: AnSpace.s8,
        ),
        // Scale-sized tabular figures so markers match the prose rung AND multi-digit numbers align
        // down a long list. 记号随当前档 + 等宽数字,长列表序号齐位。
        child: Text(
          '$no.',
          style:
              applyContentFace(
                prose,
                (_embedded ? AnText.body : AnText.reading),
              ).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: context.colors.inkFaint,
              ),
        ),
      ),
      Flexible(child: child),
    ],
  );

  Widget _unorderedItem(
    BuildContext context,
    Widget child,
    GptMarkdownConfig config,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AnSpace.s12,
          end: AnSpace.s8,
        ),
        child: Text(
          '•',
          style: applyContentFace(
            prose,
            (_embedded ? AnText.body : AnText.reading),
          ).copyWith(color: context.colors.inkFaint),
        ),
      ),
      Flexible(child: child),
    ],
  );
}

/// The SINGLE block-gap authority. The package's `NewLines` emits a `"\n\n"` span at height 1.15 (≈15px,
/// font-metric-dependent, no theme knob); combined with each block's own padding the rhythm drifted
/// (prose ~15 / quote ~17 / code ~23 / hr ~27). This pins EVERY block transition to one deterministic [gap]
/// (reading = AnFlow.block 12; embedded tightens ONE tier to AnGap.stack 8) — with the per-block paddings
/// zeroed (see AnMarkdown), the flanking blank line is the ONLY separation term, so para↔para, heading↔body,
/// ↔code, ↔table, ↔quote, ↔hr all read at the ONE gap. 唯一块间距权威:把包的 ~15px 换行改成确定 [gap](阅读 12、
/// 嵌入 8);各块外距归零后,换行是唯一间距源 → 全部块间距统一。
class _AnNewLines extends NewLines {
  _AnNewLines(this.gap);

  /// The block-separation gap for this scale's component list. 该档块间距。
  final double gap;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) => TextSpan(
    // fontSize == the gap, height 1.0 → the blank line is exactly [gap] tall, font-independent.
    // fontSize=间距、height=1.0 → 空行恰为 gap 高,与字体无关。
    text: '\n\n',
    style: TextStyle(fontSize: gap, height: 1.0),
  );
}

/// Headings breathe MORE above than below (Notion's signature ~2:1) — a heading belongs to the content
/// beneath it. On top of the uniform [gap] the flanking newline already gives, add the same [gap] more
/// ABOVE only → 2× above / 1× below (reading ≈24/12, embedded ≈16/8). Mirrors the package HTag build,
/// wrapping it in a top pad. 标题上方留白多于下方(Notion 2:1,归组下文):在换行统一 gap 之上,仅上方再加 gap → 上 2×/下 1×。
class _AnHTag extends HTag {
  _AnHTag(this.gap);

  /// The heading space-ABOVE (= this scale's block gap, doubling the flanking newline). 标题上距(=该档块间距)。
  final double gap;

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) =>
      Padding(
        padding: EdgeInsets.only(top: gap),
        child: super.build(context, text, config),
      );
}

/// BoldMd under the two-weight rule — mirrors the package `span` with ONE change: re-weight via
/// `.weight(emphasisWeight)` (pins the `wght` axis). The package's bare `copyWith(fontWeight: bold)` is
/// overridden by our pinned axis and would render w300. 两档字重版加粗:镜像包实现、只改 style 一行(走 `.weight()`
/// 钉轴);包默认裸 copyWith 被钉轴覆盖、会渲成 w300。
class _AnBoldMd extends BoldMd {
  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text.trim());
    final conf = config.copyWith(
      style: (config.style ?? AnText.body).weight(AnText.emphasisWeight),
    );
    return TextSpan(
      children: MarkdownComponent.generate(
        context,
        '${match?[1]}',
        conf,
        false,
      ),
      style: conf.style,
    );
  }
}

/// GFM task-list rows without the Material Checkbox (oversized + tap-target padding — off the reading prose
/// rhythm): a quiet 16px glyph — `taskDone` in `ok` / `taskOpen` in `inkFaint` — beside the item, layout
/// mirroring the list markers. Read-only prose, so no interactivity is lost. 任务勾:去 Material Checkbox
/// (过大+触target空隙、不合阅读列律),换 16px 安静字形(勾=ok / 空=inkFaint),布局同列表记号;只读无损。
class _AnCheckBoxMd extends CheckBoxMd {
  // Match the FULL task line INCLUDING the leading list marker (`- [x] …` / `* [ ] …`), so this component
  // claims the whole item and the checkbox is the ONE marker — the package default matches only `[x] …`,
  // letting UnOrderedList ALSO draw a bullet (the double-marker bug). Must be ordered BEFORE UnOrderedList.
  // 匹配含前导 `- `/`* ` 的整行,独占该项、勾框是唯一记号(包默认只匹 `[x]`→无序列表另画圆点=双记号);须排在 UnOrderedList 前。
  @override
  String get expString => r"(?:\-|\*)\ \[((?:x|\ ))\]\ (\S[^\n]*?)$";

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text.trim());
    final checked = '${match?[1]}' == 'x';
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AnSpace.s12,
            end: AnSpace.s8,
          ),
          child: Icon(
            AnIcons.task(done: checked),
            size: AnSize.icon,
            color: checked ? c.ok : c.inkFaint,
          ),
        ),
        // A completed task greys to inkFaint — NO strikethrough (matches the editor; user 0715). 完成态灰、不删除线。
        Flexible(
          child: MdWidget(
            context,
            '${match?[2]}',
            false,
            config: checked
                ? config.copyWith(
                    style: (config.style ?? AnText.reading).copyWith(
                      color: c.inkFaint,
                    ),
                  )
                : config,
          ),
        ),
      ],
    );
  }
}

/// BlockQuote in the quiet-aside grammar (the thinking rail's register): a 2px `lineStrong` left bar,
/// `inkMuted` prose, s12 inset. Mirrors the package `span` (the `> ` stripping), swapping only the shell
/// colours/metrics for tokens. 静默旁白版引用:2px lineStrong 左条 + inkMuted + s12 缩进;镜像包实现、只换壳 token。
class _AnBlockQuoteMd extends BlockQuote {
  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    final dataBuilder = StringBuffer();
    for (final each in (match?[0] ?? '').split('\n')) {
      if (each.startsWith(RegExp(r'\ *>'))) {
        var sub = each.trimLeft().substring(1);
        if (sub.startsWith(' ')) sub = sub.substring(1);
        dataBuilder.writeln(sub);
      } else {
        dataBuilder.writeln(each);
      }
    }
    final data = dataBuilder.toString().trim();
    final c = context.colors;
    final conf = config.copyWith(
      style: (config.style ?? AnText.body).copyWith(color: c.inkMuted),
    );
    final child = TextSpan(
      children: MarkdownComponent.generate(context, data, conf, true),
    );
    return TextSpan(
      children: [
        WidgetSpan(
          child: Directionality(
            textDirection: config.textDirection,
            child: Padding(
              padding: EdgeInsets
                  .zero, // the newline gap owns separation (was s2 → cramped) 间距归换行(原 s2 太挤)
              child: BlockQuoteWidget(
                color: c.lineStrong,
                direction: config.textDirection,
                width: AnSize.quoteBar,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: AnSpace.s12),
                  child: conf.getRich(child),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
