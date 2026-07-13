import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart' show BlockQuoteWidget;
import 'package:gpt_markdown/custom_widgets/markdown_config.dart' show GptMarkdownConfig;
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_code_editor.dart';
import 'an_thin_table.dart';
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
/// - **Tables → [AnThinTable]** (cells flattened to plain text — LLM table cells are rarely rich).
/// - **Blockquote** → the quiet-aside grammar (2px `lineStrong` left bar + `inkMuted` prose), same
///   register as the thinking rail.
/// - **LaTeX + `<u>` OFF**: math components stripped (no flutter_math cost); UnderLineMd stripped so
///   `<u>` renders literally — raw HTML stays inert text (the package has no HTML engine; we add none).
///
/// Streaming: `text` is a pure prop — the caller swaps in the growing string (coalesced ≤1/frame); the
/// package tolerates an unclosed fence (renders it as a live code block that grows). SelectionArea is the
/// caller's job. No animation → reduced-motion N/A.
///
/// chat markdown 渲染器——gpt_markdown 的 token 锁定门面(钉死版本;全库仅此文件 import 它)。所有违反体系的
/// 默认都被换掉:**粗体→w400 走 `.weight()`**(包默认裸 `copyWith(fontWeight:)` 被钉死的 wght 轴覆盖→会渲成
/// w300 即根本不粗——两档字重在此是功能必需);**标题降档** 22/18/15-w400(阅读列不喊,h4–h6 并入 readingH3 15 档);
/// **围栏代码→AnCodeEditor 只读**(唯一代码解剖+唯一高亮器);**内联 code**→mono+surfaceSunken chip;**链接**
/// accent、scheme 闸(http/https/mailto 之外一律惰性)、永不自动开(开链归宿主,本文件绝不 import url_launcher);
/// **图片**惰性占位、永不取网;**表格→AnThinTable**(cell 拍平);**引用**=静默旁白(2px lineStrong 左条+inkMuted,
/// 与 thinking rail 同语法);**LaTeX+`<u>` 关**(HTML 一律字面惰性)。流式:text 纯 prop、未闭合围栏容忍;
/// SelectionArea 归调用方;无动画。
class AnMarkdown extends StatelessWidget {
  const AnMarkdown(this.text, {this.onLinkTap, super.key});

  /// Markdown source — grows during streaming; stateless, so a longer string is just a rebuild.
  /// markdown 源——流式增长;无状态,换更长的串即重渲。
  final String text;

  /// Fires for an allowed-scheme link tap. Null → links are styled but inert. The host decides how to
  /// open (confirm dialog, url_launcher…) — the primitive never launches anything.
  /// 过闸链接点击回调;null=只染色不响应。怎么开(确认框/url_launcher…)是宿主的事,原语绝不自己开。
  final void Function(String url, String title)? onLinkTap;

  static const Set<String> _allowedSchemes = {'http', 'https', 'mailto'};

  // The default component tables minus LaTeX (block+inline), UnderLineMd (`<u>` must stay literal) and
  // RadioButtonMd (`(x)` radios are NOT standard markdown — a prose line starting "(x) …" would render a
  // surprise radio button), with BoldMd/BlockQuote/CheckBoxMd swapped for the token-locked versions. Order
  // mirrors the package defaults. Static so the lists keep a stable identity across builds.
  // 默认组件表剔 LaTeX(块+内联)、UnderLineMd(`<u>` 须字面)与 RadioButtonMd(`(x)` 单选非标准 markdown——正文
  // 行首 "(x) …" 会被惊吓渲成单选钮),换入 token 锁定版加粗/引用/任务勾;顺序镜像包默认;static 保身份稳定。
  static final List<MarkdownComponent> _components = [
    // _AnCheckBoxMd BEFORE UnOrderedList: a task line (`- [x] …`) is claimed whole by the checkbox
    // component, so it never also gets an unordered bullet. checkbox 排在无序列表前,task 行不再双记号。
    CodeBlockMd(), _AnNewLines(), _AnBlockQuoteMd(), TableMd(), _AnHTag(),
    _AnCheckBoxMd(), UnOrderedList(), OrderedList(), HrLine(), IndentMd(),
  ];
  static final List<MarkdownComponent> _inlineComponents = [
    ATagMd(), ImageMd(), TableMd(), StrikeMd(), _AnBoldMd(), ItalicMd(),
    HighlightedText(), SourceTag(),
  ];

  void _guardedLinkTap(String url, String title) {
    final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase() ?? '';
    if (!_allowedSchemes.contains(scheme)) return; // javascript:/data:/file:/relative → inert 惰性
    onLinkTap?.call(url, title);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The style MUST carry the theme ink: the package regenerates spans only when `style` differs
    // (isSame), so a colourless const style would go stale on a theme flip.
    // style 必须带主题墨色:包只在 style 不同才重生成 span(isSame),无色常量换主题会陈旧。
    // Reading-column body — 15px w300 at the roomier 1.6 line-height (Notion-calibrated air for prose).
    // 阅读列正文:reading 15 w300 + 1.6 行高(照 Notion 校准给 prose 空气)。
    final body = AnText.reading.copyWith(color: c.ink);
    final h456 = AnText.readingH3.copyWith(color: c.ink);
    return GptMarkdownTheme(
      // The factory back-fills UNSPECIFIED fields from a fresh Material ThemeData, not ours — specify
      // every field. 工厂对未指定字段用全新 Material ThemeData 兜底——所有字段显式给值。
      gptThemeData: GptMarkdownThemeData(
        brightness: Theme.of(context).brightness,
        highlightColor: c.surfaceSunken, // superseded by highlightBuilder; pinned anyway 已被 builder 接管,仍钉住
        // The reading-column heading ladder (md # is not a page title; h4–h6 fold into h3). 阅读列标题阶梯
        // (# 非页标题;h4–h6 并入 h3)。
        h1: AnText.readingH1.copyWith(color: c.ink),
        h2: AnText.readingH2.copyWith(color: c.ink),
        h3: h456,
        h4: h456,
        h5: h456,
        h6: h456,
        hrLineThickness: AnSize.hairline,
        hrLineColor: c.line,
        hrLinePadding: EdgeInsets.zero, // the newline gap owns separation (no double-stack) 间距归换行

        linkColor: c.accent,
        linkHoverColor: c.accentHover,
        autoAddDividerLineAfterH1: false, // no decorative divider under H1 不给 H1 配装饰分割线
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
        components: _components,
        inlineComponents: _inlineComponents,
      ),
    );
  }

  // Fenced code → the ONE code anatomy, read-only. `closed` ignored: an unclosed fence renders
  // optimistically as a live block that grows with the stream. trimRight: the closing-fence newline
  // otherwise renders a trailing empty gutter line. 围栏→唯一代码解剖(只读);未闭合乐观渲染;trimRight 去掉
  // 闭合围栏换行带来的尾空行。
  // No outer padding — the flanking _AnNewLines gap (AnFlow.block) is the SINGLE block-separation term;
  // a padding here would stack on it and read too loose (the old inconsistency). 无外距,间距归换行统一。
  Widget _fencedCode(BuildContext context, String name, String code, bool closed) =>
      AnCodeEditor(code: code.trimRight(), lang: name.trim().isEmpty ? null : name.trim(), reading: true);

  // Inline `code` → mono on a sunken chip (the package default is bold-only — broken on the pinned axis).
  // 内联 code→mono+凹陷 chip(包默认仅加粗——钉轴上渲错)。
  Widget _inlineCode(BuildContext context, String text, TextStyle style) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
        decoration: BoxDecoration(
          color: context.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AnRadius.tag),
        ),
        child: Text(text, style: AnText.mono.copyWith(color: context.colors.ink)),
      );

  // Images: an inert chip, NEVER a network fetch (no NetworkImage anywhere) — remote images from model/tool
  // output are an exfiltration + local-SSRF channel. 图片:惰性 chip,绝不取网(渗出/SSRF 通道封死)。
  Widget _imagePlaceholder(BuildContext context, String imageUrl, double? width, double? height) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(AnRadius.tag),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(AnIcons.image, size: AnSize.iconSm, color: c.inkFaint)),
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

  // md table → AnThinTable (cells flattened; ragged rows clipped to the header width). 表→AnThinTable。
  Widget _table(BuildContext context, List<CustomTableRow> rows, TextStyle style, GptMarkdownConfig config) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final header = rows.firstWhere((r) => r.isHeader, orElse: () => rows.first);
    // trim: the package passes cells with their ` | ` padding intact — untrimmed data would misalign
    // right-aligned columns. 包传来的 cell 带竖线两侧空格——不 trim 会顶歪右对齐列。
    final columns = [
      for (final (i, f) in header.fields.indexed)
        AnTableColumn('c$i', label: f.data.trim(), align: _mapAlign(f.alignment)),
    ];
    final dataRows = [
      for (final r in rows.where((r) => !identical(r, header) && !r.isHeader))
        {
          for (final (i, f) in r.fields.indexed)
            if (i < columns.length) 'c$i': f.data.trim(),
        },
    ];
    return AnThinTable(columns: columns, rows: dataRows); // no outer padding — the newline gap owns separation 间距归换行
  }

  static AnTableAlign _mapAlign(TextAlign a) => switch (a) {
        TextAlign.center => AnTableAlign.center,
        TextAlign.right || TextAlign.end => AnTableAlign.right,
        _ => AnTableAlign.left,
      };

  // List markers — the package's ordered default hardcodes w100 (broken on the pinned axis); both markers
  // re-done in inkFaint, layout mirroring the package (baseline row, start 12 / gap 8).
  // 列表记号:包的有序默认硬编码 w100(钉轴上渲错);两种记号统一 inkFaint,布局镜像包默认。
  Widget _orderedItem(BuildContext context, String no, Widget child, GptMarkdownConfig config) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AnSpace.s12, end: AnSpace.s8),
            // Reading-sized tabular figures so markers match the prose rung AND multi-digit numbers align
            // down a long list. 记号随阅读档 + 等宽数字,长列表序号齐位。
            child: Text('$no.',
                style: AnText.reading
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()], color: context.colors.inkFaint)),
          ),
          Flexible(child: child),
        ],
      );

  Widget _unorderedItem(BuildContext context, Widget child, GptMarkdownConfig config) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AnSpace.s12, end: AnSpace.s8),
            child: Text('•', style: AnText.reading.copyWith(color: context.colors.inkFaint)),
          ),
          Flexible(child: child),
        ],
      );
}

/// The SINGLE block-gap authority. The package's `NewLines` emits a `"\n\n"` span at height 1.15 (≈15px,
/// font-metric-dependent, no theme knob); combined with each block's own padding the rhythm drifted
/// (prose ~15 / quote ~17 / code ~23 / hr ~27). This pins EVERY block transition to one deterministic
/// [AnFlow.block] (12px) — with the per-block paddings zeroed (see AnMarkdown), the flanking blank line
/// is the ONLY separation term, so para↔para, heading↔body, ↔code, ↔table, ↔quote, ↔hr all read at 12.
/// 唯一块间距权威:把包的 ~15px 换行改成确定 12px;各块外距归零后,换行是唯一间距源 → 全部块间距统一 12。
class _AnNewLines extends NewLines {
  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) => TextSpan(
        // fontSize == the gap, height 1.0 → the blank line is exactly AnFlow.block tall, font-independent.
        // fontSize=间距、height=1.0 → 空行恰为 AnFlow.block 高,与字体无关。
        text: '\n\n',
        style: const TextStyle(fontSize: AnFlow.block, height: 1.0),
      );
}

/// Headings breathe MORE above than below (Notion's signature ~2:1) — a heading belongs to the content
/// beneath it. On top of the uniform [AnFlow.block] (12) the flanking newline already gives, add
/// [AnFlow.block] more ABOVE only → ≈24 above / 12 below. Mirrors the package HTag build, wrapping it in a
/// top pad. 标题上方留白多于下方(Notion 2:1,归组下文):在换行统一 12 之上,仅上方再加 12 → 上≈24 / 下 12。
class _AnHTag extends HTag {
  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) => Padding(
        padding: const EdgeInsets.only(top: AnFlow.block),
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
      children: MarkdownComponent.generate(context, '${match?[1]}', conf, false),
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
          padding: const EdgeInsetsDirectional.only(start: AnSpace.s12, end: AnSpace.s8),
          child: Icon(
            AnIcons.task(done: checked),
            size: AnSize.icon,
            color: checked ? c.ok : c.inkFaint,
          ),
        ),
        Flexible(child: MdWidget(context, '${match?[2]}', false, config: config)),
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
    final child = TextSpan(children: MarkdownComponent.generate(context, data, conf, true));
    return TextSpan(
      children: [
        WidgetSpan(
          child: Directionality(
            textDirection: config.textDirection,
            child: Padding(
              padding: EdgeInsets.zero, // the newline gap owns separation (was s2 → cramped) 间距归换行(原 s2 太挤)
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
