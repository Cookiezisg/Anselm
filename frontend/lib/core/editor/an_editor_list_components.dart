import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_editor_text_component.dart';
import 'an_editor_quote.dart';

/// Per-nesting-level indent step for editor list items — matched to the chat renderer's nested-list indent so
/// the two are 1:1. 列表每级嵌套缩进步长(对齐 chat 的嵌套缩进)。
const double kListIndentStep = 24;

/// Editor list items rebuilt to be PIXEL-IDENTICAL to the chat renderer ([AnMarkdown]'s `_unorderedItem` /
/// `_orderedItem`). Two things the super_editor default got wrong for our design:
///   • The marker (bullet / numeral) style was taken from `getAllAttributionsAt(0)` — the FIRST character — so
///     a list item whose first word is inline `code` (mono 13) produced a tiny, mis-positioned marker (the
///     reported bug). Here the marker is ALWAYS the prose reading style, independent of content.
///   • The inner text was a plain `TextComponent` (no inline-code background). Here it is [AnTextComponent], so
///     inline code paints its rounded background inside list items too.
/// The marker itself is a `•` / `$n.` glyph in [AnText.reading] · [AnColors.inkFaint] with 12px lead + 8px gap,
/// exactly matching the chat item. 列表项重建为与 chat 逐像素一致:记号恒用正文档(非第一个字符,修首词代码 bug)+
/// 内芯换 AnTextComponent(行内代码有背景);记号=`•`/`$n.` reading·inkFaint,12 前导 + 8 间距,同 chat。
class AnListItemComponentBuilder extends ListItemComponentBuilder {
  const AnListItemComponentBuilder(this.colors, this.document);

  final AnColors colors;
  // The live document — read to find a list item's quoteDepth (a list INSIDE a blockquote → wrapped in bars).
  // 活文档:读列表项的 quoteDepth(引用内的列表 → 包左条)。
  final Document document;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    final Widget? comp;
    if (componentViewModel is UnorderedListItemComponentViewModel) {
      comp = AnListItemComponent(
        componentKey: componentContext.componentKey,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        marker: '•',
        colors: colors,
        indent: componentViewModel.indent,
        textDirection: componentViewModel.textDirection,
        textAlignment: componentViewModel.textAlignment,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        underlines: componentViewModel.createUnderlines(),
        inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      );
    } else if (componentViewModel is OrderedListItemComponentViewModel) {
      comp = AnListItemComponent(
        componentKey: componentContext.componentKey,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        marker: '${componentViewModel.ordinalValue ?? 1}.',
        tabular: true,
        colors: colors,
        indent: componentViewModel.indent,
        textDirection: componentViewModel.textDirection,
        textAlignment: componentViewModel.textAlignment,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        underlines: componentViewModel.createUnderlines(),
        inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      );
    } else {
      return null;
    }
    final node = document.getNodeById(componentViewModel.nodeId);
    final depth = quoteDepthOf(node);
    if (depth == 0) return comp;
    final topGap = node != null && isQuoteContinuation(document, node)
        ? AnFlow.block
        : 0.0;
    return wrapInQuote(comp, depth, colors, topGap: topGap);
  }
}

/// One list item (ordered or unordered) — a marker glyph + [AnTextComponent], mirroring chat's item Row.
class AnListItemComponent extends StatefulWidget {
  const AnListItemComponent({
    super.key,
    required this.componentKey,
    required this.text,
    required this.styleBuilder,
    required this.marker,
    required this.colors,
    this.tabular = false,
    this.indent = 0,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.textSelection,
    this.selectionColor = const Color(0x00000000),
    this.highlightWhenEmpty = false,
    this.underlines = const [],
    this.inlineWidgetBuilders = const [],
  });

  final GlobalKey componentKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final String marker; // '•' or '3.'
  final AnColors colors;
  final bool
  tabular; // tabular figures for numerals so multi-digit numbers align
  final int indent;
  final TextDirection textDirection;
  final TextAlign textAlignment;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool highlightWhenEmpty;
  final List<Underlines> underlines;
  final InlineWidgetBuilderChain inlineWidgetBuilders;

  @override
  State<AnListItemComponent> createState() => _AnListItemComponentState();
}

class _AnListItemComponentState extends State<AnListItemComponent> {
  final GlobalKey _innerTextComponentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // The marker is ALWAYS the prose reading style — never derived from the first character. 记号恒用正文档。
    final markerStyle = AnText.reading.copyWith(
      color: widget.colors.inkFaint,
      fontFeatures: widget.tabular
          ? const [FontFeature.tabularFigures()]
          : null,
    );
    // Scale the marker with the SAME text scaler [AnTextComponent] uses (MediaQuery). Hardcoding linear(1.0)
    // here while the text scales left the marker tiny & floating high whenever the app ran at a text scale
    // ≠ 1.0 (the reported "dots/numbers sit high" bug). 记号随正文同一 textScaler 缩放,否则放大时记号不长、浮高。
    final textScaler = MediaQuery.textScalerOf(context);
    final start = AnSpace.s12 + widget.indent * kListIndentStep;

    return ProxyTextDocumentComponent(
      key: widget.componentKey,
      textComponentKey: _innerTextComponentKey,
      child: Directionality(
        textDirection: widget.textDirection,
        child: Row(
          // Marker and text share the ALPHABETIC BASELINE — verbatim with the chat renderer's list item
          // ([AnMarkdown._unorderedItem/_orderedItem], which use the same baseline + alphabetic). This now
          // works because [AnTextComponent] reports its real first-line baseline (see _AnBaselineProxy); no
          // Transform nudge, no magic number, font/scale independent. 记号与文本同字母基线(同 chat);
          // AnTextComponent 现上报真基线,故 baseline 生效——无 Transform、无魔数、随字体/缩放自适应。
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: start,
                end: AnSpace.s8,
              ),
              child: Text(
                widget.marker,
                style: markerStyle,
                textScaler: textScaler,
              ),
            ),
            Expanded(
              child: AnTextComponent(
                key: _innerTextComponentKey,
                text: widget.text,
                textDirection: widget.textDirection,
                textAlign: widget.textAlignment,
                textStyleBuilder: widget.styleBuilder,
                inlineWidgetBuilders: widget.inlineWidgetBuilders,
                textSelection: widget.textSelection,
                selectionColor: widget.selectionColor,
                highlightWhenEmpty: widget.highlightWhenEmpty,
                underlines: widget.underlines,
                codeBackgroundColor: widget.colors.surfaceSunken,
                codeBackgroundRadius: AnRadius.tag,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
