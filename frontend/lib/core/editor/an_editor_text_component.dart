import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_editor_inline_code.dart';
import 'an_editor_quote.dart';
import 'an_editor_selection.dart';

/// The height of the inline-code paint-beneath background — the JetBrains-Mono-13 line box (measured 20.0px),
/// which is exactly the height of the chat [AnCodeChip] (`Container(child: Text(AnText.mono))`, no vertical
/// padding). Drawing the gray at THIS height (anchored to the line bottom) rather than the taller reading prose
/// line box (24px) is what makes the editor code pill pixel-match the chat chip vertically. AnText.mono is fixed
/// at 13/1.5, so this is stable. 行内代码背景高=JetBrains Mono 13 行盒(20px)=chat AnCodeChip 高;贴行底画故字形居中。
const double kInlineCodeBoxHeight = 20;

/// A hair of downward nudge on the inline-code background so the mono glyphs sit balanced inside it exactly like
/// the chat [AnCodeChip] (measured: without it the gray was 5.0px above / 2.67px below the ink; the chip is
/// 4.0 / 3.67). The prose line BOTTOM (our anchor) sits a touch below the mono glyph descent, so we shift the
/// box down to re-centre it on the glyphs. 竖向微调:让字形在灰块里像 chat 芯片一样居中(实测灰块本偏上,下移一发丝)。
const double kInlineCodeBottomNudge = 1;

/// [AnTextComponent] = super_editor's [TextComponent] with ONE addition: a per-line rounded background painted
/// beneath any `codeAttribution` run (the paint-beneath inline-code design — inline code renders as plain,
/// WRAPPING, editable text with a rounded background drawn under it, instead of an atomic non-wrapping chip).
///
/// It EXTENDS [TextComponent]/[TextComponentState] (rather than a full ~450-line copy) so super_editor's test
/// robots/inspector — which cast the component state to [TextComponentState] — keep working. The parent's
/// `build` and `textLayout` both key off a PRIVATE `_textKey`, so we can't reuse them; instead we override
/// BOTH to key off our own [_anTextKey]. Every inherited geometry method (getPositionAtOffset / getRectFor…)
/// reads through the overridden `textLayout` getter, so they all resolve against our SuperText. The parent's
/// `_textStyleWithBlockType` is also private, so we re-implement it as [_styleWithBlockType]. Re-check against
/// super_editor text.dart:1248-1309 if the pin ever moves off dev.40.
/// AnTextComponent=super_editor TextComponent + 在 codeAttribution run 底下逐行画圆角背景(paint-beneath 行内代码:
/// 可换行可编辑文本 + 底层圆角背景,非原子不换行芯片)。extends 而非整份复制,以便 super_editor 测试 robot/inspector
/// 的 `as TextComponentState` 仍工作;父类 build/textLayout 用私有 _textKey,故两者都 override 成用自家 key。
class AnTextComponent extends TextComponent {
  const AnTextComponent({
    super.key,
    required super.text,
    super.textAlign,
    super.textDirection,
    super.textScaler,
    required super.textStyleBuilder,
    super.inlineWidgetBuilders,
    super.metadata,
    super.textSelection,
    super.selectionColor,
    super.highlightWhenEmpty,
    super.underlines,
    super.showDebugPaint,
    this.codeBackgroundColor,
    this.codeBackgroundRadius,
  });

  /// Fill + corner radius of the per-line rounded inline-code background. Null → no code background (behaves
  /// exactly like the parent). The 4px padding + fixed height are read from tokens by the painter, not passed
  /// here (they are design constants). 行内代码逐行圆角背景的填充与圆角;内距/高由 painter 直接读 token(设计常量)。
  final Color? codeBackgroundColor;
  final double? codeBackgroundRadius;

  @override
  AnTextComponentState createState() => AnTextComponentState();
}

class AnTextComponentState extends TextComponentState {
  // Our own text key (the parent's _textKey is private and unreachable). Both build() and the textLayout
  // getter key off THIS, so inherited geometry methods resolve against our SuperText. 自家 key(父私有 key 够不着)。
  final _anTextKey = GlobalKey<ProseTextState>();

  @override
  ProseTextLayout get textLayout => _anTextKey.currentState!.textLayout;

  // Re-implementation of the parent's private _textStyleWithBlockType. 复制父私有 _textStyleWithBlockType。
  TextStyle _styleWithBlockType(Set<Attribution> attributions) {
    final attributionsWithBlockType = Set<Attribution>.from(attributions);
    final Attribution? blockType = widget.metadata['blockType'];
    if (blockType != null) {
      attributionsWithBlockType.add(blockType);
    }
    return widget.textStyleBuilder(attributionsWithBlockType);
  }

  @override
  Widget build(BuildContext context) {
    final anWidget = widget as AnTextComponent;
    // Wrap in [_AnBaselineProxy] so this component's OUTER RenderBox reports the SuperText's real first-line
    // alphabetic baseline — without it a parent Row with CrossAxisAlignment.baseline top-aligns the text (the
    // ~2px-high list marker bug). 外层裹基线代理:让本组件外 box 上报真基线,父 Row 的 baseline 才生效。
    return _AnBaselineProxy(
      child: IgnorePointer(
        child: SuperText(
          key: _anTextKey,
          richText: widget.text.computeInlineSpan(context, _styleWithBlockType, widget.inlineWidgetBuilders),
          textAlign: widget.textAlign ?? TextAlign.left,
          textDirection: widget.textDirection ?? TextDirection.ltr,
          textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
          layerBeneathBuilder: (context, textLayout) {
            return Stack(
              children: [
                // Inline-code rounded background, BENEATH the selection highlight (selection paints on top so it
                // stays visible over code). 行内代码圆角背景,在选区高亮之下(选区叠其上仍可见)。
                if (anWidget.codeBackgroundColor != null)
                  CodeBackgroundLayer(
                    textLayout: textLayout,
                    text: widget.text,
                    color: anWidget.codeBackgroundColor!,
                    radius: anWidget.codeBackgroundRadius ?? 0,
                  ),
                // Selection highlight beneath the text — the An painter (per-visual-line merged, full line
                // box, zero inflation) instead of the upstream TextLayoutSelectionHighlight, whose raw boxes
                // + hardcoded ±2px inflation gave split pills at script boundaries and 4px overlaps between
                // wrapped lines (semi-transparent colour doubled = darker bands). 选区高亮换 An 画法(逐视觉行
                // 并盒、满行盒、零膨胀);上游默认在 script 边界断盒、行间又叠 4px 半透明色叠深。
                if (widget.text.length > 0)
                  AnSelectionHighlightLayer(
                    textLayout: textLayout,
                    selection: widget.textSelection ?? const TextSelection.collapsed(offset: -1),
                    color: widget.selectionColor,
                  )
                else if (widget.highlightWhenEmpty)
                  TextLayoutEmptyHighlight(
                    textLayout: textLayout,
                    style: SelectionHighlightStyle(color: widget.selectionColor),
                  ),
                for (final underlines in widget.underlines)
                  TextUnderlineLayer(
                    textLayout: textLayout,
                    style: underlines.style,
                    underlines: [
                      for (final range in underlines.underlines) TextLayoutUnderline(range: range),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Makes [AnTextComponent]'s outer [RenderBox] report the real first-line ALPHABETIC BASELINE of the
/// [SuperText] it wraps, so a parent [Row] with [CrossAxisAlignment.baseline] seats list markers on the text
/// baseline exactly like the chat renderer ([AnMarkdown]) — no magic number, font/scale independent.
///
/// WHY: [SuperText]'s render box (super_editor's `RenderSuperTextLayout`) lays its text child — a
/// [RenderParagraph] — at offset zero with `size = text.size`, but never overrides
/// `computeDistanceToActualBaseline`, so it inherits [RenderBox]'s default `null`. [RenderFlex] with
/// [CrossAxisAlignment.baseline] TOP-aligns any child whose baseline is `null` — which is exactly why the
/// bullet / numeral used to seat ~2px above the prose (previously papered over with a Transform nudge). This
/// proxy descends to that paragraph and forwards its real baseline. 让 AnTextComponent 外 box 上报真基线:
/// RenderSuperTextLayout 不转发基线→null→父 Row 的 baseline 退化顶对齐(记号偏高);此代理下探段落取值转发。
class _AnBaselineProxy extends SingleChildRenderObjectWidget {
  const _AnBaselineProxy({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProseBaseline();
}

class _RenderProseBaseline extends RenderProxyBox {
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    // DFS to the SuperText's [RenderParagraph], summing parentData.offset.dy on the way down (all zero today —
    // the paragraph sits at origin — but the RenderShiftedBox idiom keeps us correct if a future package rev
    // ever offsets it). Matching the framework [RenderParagraph] (not super_text_layout's internal subclass)
    // keeps super_editor coupling at zero; SuperText's `[background, text, foreground]` child order means the
    // CustomPaint layers are visited first and hold no paragraph, so `text` is the first RenderParagraph hit —
    // and we stop there, never descending into inline-widget paragraphs. Call `getDistanceToActualBaseline`
    // (the @protected caching variant) — the exact call RenderProxyBoxMixin / RenderShiftedBox make in a
    // baseline pass; the paragraph is already laid out when RenderFlex queries. 下探 SuderText 段落取真基线并
    // 累加沿途偏移(当下全零);匹配框架 RenderParagraph→零 super_editor 耦合;背景层无段落故首个命中即文本段落。
    RenderParagraph? para;
    double dy = 0;
    void walk(RenderObject? node, double acc) {
      if (para != null || node == null) return;
      if (node is RenderParagraph) {
        para = node;
        dy = acc;
        return;
      }
      node.visitChildren((child) {
        if (para != null) return;
        final pd = child.parentData;
        walk(child, acc + (pd is BoxParentData ? pd.offset.dy : 0.0));
      });
    }

    walk(child, 0);
    final base = para?.getDistanceToActualBaseline(baseline);
    return base == null ? super.computeDistanceToActualBaseline(baseline) : base + dy;
  }
}

/// Paints the rounded inline-code background beneath every `codeAttribution` run so it is PIXEL-IDENTICAL to the
/// chat renderer's [AnCodeChip] (mono on a padded, rounded [AnColors.surfaceSunken] pill) while remaining plain,
/// WRAPPING, editable text. Three moves make it 1:1 + wrap-correct + CJK-safe:
///   • CONTENT range — the box excludes the run's NBSP padding spacers ([codeSpacerAttribution]); the visible
///     [AnSpace.s4] (4px) padding is added by inflating the box instead. The 4px spacer only RESERVES layout
///     clearance so the outer inflation lands flush against a glued neighbour instead of overlapping it.
///   • MERGE per visual line — [ProseTextLayout.getBoxesForSelection] returns SEPARATE boxes at every script
///     run boundary (so a CJK-in-code comment came back as 2–3 boxes → the old painter drew a broken, gapped
///     pill). We union boxes that share a line into one rect, so the gray is continuous. Per WRAPPED line it is
///     still one rect each, so the 4px inflate also gives padding at the wrap edges (not flush like before).
///   • Fixed HEIGHT, bottom-aligned — the box is [kInlineCodeBoxHeight] (the mono 13 line box = the chip's
///     height) anchored to the line's BOTTOM, so the mono glyphs sit balanced inside it. Using the taller prose
///     line box (24) left the gray top-heavy (too much air above the shorter mono glyphs).
/// 画行内代码圆角背景,与 chat 的 [AnCodeChip] 逐像素一致:内容区(去 NBSP 内距、4px 靠膨胀补)+ 逐行并 box(修 CJK 断裂/
/// 换行补内距)+ 定高贴底(mono 行盒高,字形居中不头重)。
class CodeBackgroundLayer extends StatelessWidget {
  const CodeBackgroundLayer({
    super.key,
    required this.textLayout,
    required this.text,
    required this.color,
    required this.radius,
  });

  final TextLayout textLayout;
  final AttributedText text;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CodeBackgroundPainter(textLayout: textLayout, text: text, color: color, radius: radius),
    );
  }
}

class _CodeBackgroundPainter extends CustomPainter {
  _CodeBackgroundPainter({
    required this.textLayout,
    required this.text,
    required this.color,
    required this.radius,
  });

  final TextLayout textLayout;
  final AttributedText text;
  final Color color;
  final double radius;

  bool _isSpacer(int offset) =>
      offset >= 0 && offset < text.length && text.getAllAttributionsAt(offset).contains(codeSpacerAttribution);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final span in text.getAttributionSpans({codeAttribution})) {
      // Content range = the run minus its outer NBSP padding spacers (the 4px padding is drawn by inflation, so
      // the spacer chars themselves must not be counted twice). span.end is INCLUSIVE. 内容区=去两侧 NBSP 内距。
      var start = span.start, end = span.end;
      if (_isSpacer(start)) start++;
      if (_isSpacer(end)) end--;
      if (end < start) continue; // spacer-only (empty code) — nothing to draw
      final selection = TextSelection(baseOffset: start, extentOffset: end + 1);
      final lines = mergeBoxesByLine(textLayout.getBoxesForSelection(selection, boxHeightStyle: BoxHeightStyle.max));
      for (final line in lines) {
        // Per visual line: 4px horizontal padding (matches AnCodeChip; also pads the wrap edges), fixed mono-box
        // height anchored to the line bottom so the glyphs sit balanced. 逐行:水平 4px + 定高贴底。
        final bottom = line.bottom + kInlineCodeBottomNudge;
        final rect = Rect.fromLTRB(
          line.left - AnSpace.s4,
          bottom - kInlineCodeBoxHeight,
          line.right + AnSpace.s4,
          bottom,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CodeBackgroundPainter old) =>
      old.textLayout != textLayout || old.text != text || old.color != color || old.radius != radius;
}

/// [AnParagraphComponent] = super_editor's `ParagraphComponent` with its inner text widget swapped to
/// [AnTextComponent], so paragraphs AND headings paint the inline-code background. Copied because the inner
/// `TextComponent` is hardcoded in the private `_ParagraphComponentState.build`. Re-check against
/// paragraph.dart:468-532 if the super_editor pin moves. 段落/标题换 AnTextComponent 内芯,让行内代码有背景层。
class AnParagraphComponent extends StatefulWidget {
  const AnParagraphComponent({
    super.key,
    required this.viewModel,
    this.showDebugPaint = false,
    this.codeBackgroundColor,
    this.codeBackgroundRadius,
  });

  final ParagraphComponentViewModel viewModel;
  final bool showDebugPaint;
  final Color? codeBackgroundColor;
  final double? codeBackgroundRadius;

  @override
  State<AnParagraphComponent> createState() => _AnParagraphComponentState();
}

class _AnParagraphComponentState extends State<AnParagraphComponent>
    with ProxyDocumentComponent<AnParagraphComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable => childDocumentComponentKey.currentState as TextComposable;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.viewModel.textDirection,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: widget.viewModel.indentCalculator(
              widget.viewModel.textStyleBuilder({}),
              widget.viewModel.indent,
            ),
          ),
          Expanded(
            child: AnTextComponent(
              key: _textKey,
              text: widget.viewModel.text,
              textDirection: widget.viewModel.textDirection,
              textAlign: widget.viewModel.textAlignment,
              textScaler: widget.viewModel.textScaler,
              textStyleBuilder: widget.viewModel.textStyleBuilder,
              inlineWidgetBuilders: widget.viewModel.inlineWidgetBuilders,
              metadata: widget.viewModel.blockType != null ? {'blockType': widget.viewModel.blockType} : {},
              textSelection: widget.viewModel.selection,
              selectionColor: widget.viewModel.selectionColor,
              highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
              underlines: widget.viewModel.createUnderlines(),
              showDebugPaint: widget.showDebugPaint,
              codeBackgroundColor: widget.codeBackgroundColor,
              codeBackgroundRadius: widget.codeBackgroundRadius,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swaps the default paragraph/heading component for [AnParagraphComponent]. Reuses the default builder's
/// createViewModel; overrides ONLY createComponent. Carries the inline-code background color/radius.
/// 段落/标题换 AnParagraphComponent(带行内代码背景色/圆角);复用默认 createViewModel,只覆写 createComponent。
class AnParagraphComponentBuilder extends ParagraphComponentBuilder {
  const AnParagraphComponentBuilder(
      {this.codeBackgroundColor, this.codeBackgroundRadius, this.document, this.quoteColors});

  final Color? codeBackgroundColor;
  final double? codeBackgroundRadius;
  // The live document + colours — read to wrap a quoted paragraph (quoteDepth>0) in blockquote bars. 引用段包左条。
  final Document? document;
  final AnColors? quoteColors;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel) return null;
    final Widget comp = AnParagraphComponent(
      key: componentContext.componentKey,
      viewModel: componentViewModel,
      codeBackgroundColor: codeBackgroundColor,
      codeBackgroundRadius: codeBackgroundRadius,
    );
    if (document != null && quoteColors != null) {
      final node = document!.getNodeById(componentViewModel.nodeId);
      final depth = quoteDepthOf(node);
      if (depth > 0) {
        final topGap = node != null && isQuoteContinuation(document!, node) ? AnFlow.block : 0.0;
        return wrapInQuote(comp, depth, quoteColors!, topGap: topGap);
      }
    }
    return comp;
  }
}

/// [AnTextWithHintComponent] = super_editor's `TextWithHintComponent` (the empty-doc placeholder overlay for the
/// single first paragraph) with its inner `TextComponent` swapped to [AnTextComponent], so a single-paragraph
/// document with inline code STILL paints the rounded code background. Without this, a doc whose only node is
/// the first paragraph gets a [HintComponentViewModel] (a sibling of ParagraphComponentViewModel, NOT a subtype)
/// which [AnParagraphComponentBuilder] can't touch. Mirrors text.dart:752-778 — re-check if the pin moves.
/// AnTextWithHintComponent=空文档占位组件,内芯换 AnTextComponent,让单段文档的行内代码仍有圆角背景(单节点=HintVM,
/// 非 ParagraphVM 子类,AnParagraph 够不着)。
class AnTextWithHintComponent extends StatefulWidget {
  const AnTextWithHintComponent({
    super.key,
    required this.text,
    this.inlineWidgetBuilders = const [],
    this.hintText,
    this.hintStyleBuilder,
    this.textAlign,
    this.textDirection,
    required this.textStyleBuilder,
    this.metadata = const {},
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.highlightWhenEmpty = false,
    this.underlines = const [],
    this.showDebugPaint = false,
    this.codeBackgroundColor,
    this.codeBackgroundRadius,
  });

  final AttributedText text;
  final InlineWidgetBuilderChain inlineWidgetBuilders;
  final AttributedText? hintText;
  final AttributionStyleBuilder? hintStyleBuilder;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final AttributionStyleBuilder textStyleBuilder;
  final Map<String, dynamic> metadata;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool highlightWhenEmpty;
  final List<Underlines> underlines;
  final bool showDebugPaint;
  final Color? codeBackgroundColor;
  final double? codeBackgroundRadius;

  @override
  State<AnTextWithHintComponent> createState() => _AnTextWithHintComponentState();
}

class _AnTextWithHintComponentState extends State<AnTextWithHintComponent>
    with ProxyDocumentComponent<AnTextWithHintComponent>, ProxyTextComposable {
  // The child key must resolve to a TextComponentState — AnTextComponentState IS-A TextComponentState, so
  // super_editor's proxy/robot casts still work. 子 key 须解析为 TextComponentState(AnTextComponentState 是其子类)。
  final _childTextComponentKey = GlobalKey<TextComponentState>();

  @override
  GlobalKey get childDocumentComponentKey => _childTextComponentKey;

  @override
  TextComposable get childTextComposable => _childTextComponentKey.currentState!;

  TextStyle _styleBuilder(Set<Attribution> attributions) {
    final attributionsWithBlock = Set.of(attributions);
    final blockType = widget.metadata['blockType'];
    if (blockType != null && blockType is Attribution) {
      attributionsWithBlock.add(blockType);
    }
    final contentStyle = widget.textStyleBuilder(attributionsWithBlock);
    return contentStyle.merge(widget.hintStyleBuilder?.call(attributionsWithBlock) ?? const TextStyle());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.text.isEmpty)
          IgnorePointer(
            child: Text.rich(
              widget.hintText?.computeInlineSpan(context, _styleBuilder, const []) ?? const TextSpan(text: ''),
            ),
          ),
        AnTextComponent(
          key: _childTextComponentKey,
          text: widget.text,
          inlineWidgetBuilders: widget.inlineWidgetBuilders,
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
          textStyleBuilder: widget.textStyleBuilder,
          metadata: widget.metadata,
          textSelection: widget.textSelection,
          selectionColor: widget.selectionColor,
          highlightWhenEmpty: widget.highlightWhenEmpty,
          underlines: widget.underlines,
          showDebugPaint: widget.showDebugPaint,
          codeBackgroundColor: widget.codeBackgroundColor,
          codeBackgroundRadius: widget.codeBackgroundRadius,
        ),
      ],
    );
  }
}

/// The empty-doc placeholder builder, An-flavored: identical hint behavior to [HintComponentBuilder] but renders
/// through [AnTextWithHintComponent] so the single-first-paragraph case also paints inline-code backgrounds.
/// Reuses the inherited `hint`/`hintStyleBuilder` (public on the parent) + createViewModel. 空文档占位建造器 An 版。
class AnHintComponentBuilder extends HintComponentBuilder {
  const AnHintComponentBuilder(
    super.hint,
    super.hintStyleBuilder, {
    this.codeBackgroundColor,
    this.codeBackgroundRadius,
  });

  final Color? codeBackgroundColor;
  final double? codeBackgroundRadius;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! HintComponentViewModel) return null;
    return AnTextWithHintComponent(
      key: componentContext.componentKey,
      text: componentViewModel.text,
      inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      textStyleBuilder: componentViewModel.textStyleBuilder,
      hintText: AttributedText(componentViewModel.hintText),
      hintStyleBuilder: (attributions) => hintStyleBuilder(componentContext.context),
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      underlines: componentViewModel.createUnderlines(),
      metadata: {
        if (componentViewModel.blockType != null) 'blockType': componentViewModel.blockType,
      },
      codeBackgroundColor: codeBackgroundColor,
      codeBackgroundRadius: codeBackgroundRadius,
    );
  }
}
