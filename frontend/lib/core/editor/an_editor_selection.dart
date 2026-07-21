/// An selection painting — the two pieces that make a text sweep read as ONE continuous ribbon (the
/// browser/Notion standard) instead of super_editor's default gappy patchwork:
///
///  1. [AnSelectionHighlightLayer] — the per-text-block highlight, swapped in for super_text_layout's
///     `TextLayoutSelectionHighlight` inside [AnTextComponent]. The default paints `getBoxesForSelection`
///     boxes raw with a hardcoded ±2px vertical inflation: script-run boundaries (CJK↔Latin) split one line
///     into several boxes, and the inflation makes adjacent wrapped lines OVERLAP by 4px (a semi-transparent
///     colour doubles up = darker bands). This layer merges boxes per VISUAL LINE (the inline-code painter's
///     proven move) and paints each line's FULL line box (BoxHeightStyle.max) — wrapped lines tile edge-to-
///     edge with zero gap and zero overlap.
///
///  2. [AnSelectionGapLayerBuilder] — a document overlay that fills the INTER-BLOCK padding when an expanded
///     selection crosses block boundaries. Per-component highlights can only paint inside their own
///     SuperText; the block gap (12) / heading gap (24) lives OUTSIDE every component, so a cross-block
///     sweep showed white bands there. The gaps hold no content (pure padding), so an overlay fill ABOVE
///     the content is visually identical to an underlay.
///
/// An 选区绘制:让划选读作一条连续色带(浏览器/Notion 标准)的两件——①逐块高亮换掉上游默认(默认裸画
/// getBoxesForSelection + 写死 ±2px 竖向膨胀:CJK/拉丁 run 边界把一行拆多盒,膨胀又让相邻行重叠 4px、半透明
/// 色叠深),改为逐视觉行并盒(行内代码画法同款)+ 每行画满行盒,零缝零叠;②跨块缝隙填充 overlay——块间距在
/// 组件之外、任何组件画不到,跨块划选在那里露白条;缝隙是纯 padding 无内容,盖在上面与垫在下面视觉等同。
library;

import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle, TextBox;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Union text boxes that share a visual line into ONE rect per line. Extracted from the inline-code
/// painter (the CJK split-box lesson) so the selection layer shares the same proven merge.
///
/// Same-line test = vertical CENTERS nearly coincide, NOT "vertical spans overlap": with real fonts,
/// [BoxHeightStyle.max] boxes of ADJACENT wrapped lines can overlap by a sub-pixel sliver (measured
/// 0.3px on an Inter+mono mixed line — line1.bottom 24.0 vs line2.top 23.7), and the overlap test then
/// unioned BOTH lines into one tall rect — the fixed-height bottom-anchored code pill painted only the
/// BOTTOM line (the top line lost its pill, the bottom line's stretched to the union's width; the
/// mid-code-typing wrap bug). Boxes split on the SAME line (script-run boundaries) share the line box,
/// so their centers differ by a sub-pixel; adjacent lines differ by a whole line box (~24) — half the
/// smaller box height separates the two cases with a huge margin.
/// 同视觉行的盒并一(行内代码画法抽出共用;CJK 断盒教训)。同行判据=**竖向中心几乎重合**,非「竖向重叠」:
/// 真字体下 max 盒在相邻行间会重叠亚像素(实测 0.3px),裸重叠判据把两行并一——定高贴底的码灰只画出下行
/// (首行丢灰、下行灰取 union 宽越界,即「码中打字折行」bug)。同行断盒共享行盒、中心差亚像素;相邻行中心差
/// ≈整行高(~24),取较小盒半高作容差,两种情形相距悬殊。
List<Rect> mergeBoxesByLine(List<TextBox> boxes) {
  final rects = <Rect>[];
  for (final b in boxes) {
    final r = b.toRect();
    var merged = false;
    for (var i = 0; i < rects.length; i++) {
      final e = rects[i];
      final tolerance = math.min(r.height, e.height) / 2;
      if ((r.center.dy - e.center.dy).abs() < tolerance) {
        rects[i] = Rect.fromLTRB(
          math.min(e.left, r.left),
          math.min(e.top, r.top),
          math.max(e.right, r.right),
          math.max(e.bottom, r.bottom),
        );
        merged = true;
        break;
      }
    }
    if (!merged) rects.add(r);
  }
  return rects;
}

/// The per-text-block selection highlight: full-line-box rects, one per visual line, no inflation.
/// 逐块选区高亮:每视觉行一整行盒矩形,无膨胀。
class AnSelectionHighlightLayer extends StatelessWidget {
  const AnSelectionHighlightLayer({
    super.key,
    required this.textLayout,
    required this.selection,
    required this.color,
  });

  final TextLayout textLayout;
  final TextSelection selection;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AnSelectionPainter(
        textLayout: textLayout,
        selection: selection,
        color: color,
      ),
    );
  }
}

class _AnSelectionPainter extends CustomPainter {
  _AnSelectionPainter({
    required this.textLayout,
    required this.selection,
    required this.color,
  });

  final TextLayout textLayout;
  final TextSelection selection;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (!selection.isValid || selection.isCollapsed) return;
    final paint = Paint()..color = color;
    final boxes = textLayout.getBoxesForSelection(
      selection,
      boxHeightStyle: BoxHeightStyle.max,
    );
    for (final line in mergeBoxesByLine(boxes)) {
      canvas.drawRect(line, paint);
    }
  }

  @override
  bool shouldRepaint(_AnSelectionPainter old) =>
      old.textLayout != textLayout ||
      old.selection != selection ||
      old.color != color;
}

/// Fills the inter-block gaps inside an expanded selection (see the library note). For each ADJACENT node
/// pair the selection spans, the fill runs from the END of the upstream node's content to the START of the
/// downstream node's content, horizontally spanning both anchors — the browser's cross-paragraph sweep.
/// 跨块缝隙填充层:选区跨过的每对相邻节点,从上游节点内容底到下游节点内容顶,水平跨两锚点。
class AnSelectionGapLayerBuilder implements SuperEditorLayerBuilder {
  const AnSelectionGapLayerBuilder(this.color);

  /// The selection colour ([AnColors.selection]) — resolved by the caller at build (StyleRule-style: no
  /// BuildContext inside the layer's compute pass). 选区色(调用处解析)。
  final Color color;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperEditorContext editContext,
  ) {
    return AnSelectionGapLayer(
      composer: editContext.composer,
      document: editContext.document,
      color: color,
    );
  }
}

class AnSelectionGapLayer extends DocumentLayoutLayerStatefulWidget {
  const AnSelectionGapLayer({
    super.key,
    required this.composer,
    required this.document,
    required this.color,
  });

  final DocumentComposer composer;
  final Document document;
  final Color color;

  @override
  DocumentLayoutLayerState<AnSelectionGapLayer, List<Rect>> createState() =>
      _AnSelectionGapLayerState();
}

class _AnSelectionGapLayerState
    extends DocumentLayoutLayerState<AnSelectionGapLayer, List<Rect>> {
  @override
  void initState() {
    super.initState();
    widget.composer.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(AnSelectionGapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.composer.selectionNotifier.addListener(_onSelectionChange);
    }
  }

  @override
  void dispose() {
    widget.composer.selectionNotifier.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    // Same re-entrancy guard as the caret overlay: only force a rebuild when the pipeline isn't already
    // building (in-build changes are picked up by the layout pass that follows). 同 caret 层的重入守卫。
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
    }
  }

  @override
  List<Rect> computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final selection = widget.composer.selection;
    if (selection == null || selection.isCollapsed) return const [];

    final nodes = widget.document.getNodesInside(
      selection.base,
      selection.extent,
    );
    if (nodes.length < 2) return const [];

    final gaps = <Rect>[];
    for (var i = 0; i < nodes.length - 1; i++) {
      final above = nodes[i];
      final below = nodes[i + 1];
      final aboveEnd = documentLayout.getRectForPosition(
        DocumentPosition(nodeId: above.id, nodePosition: above.endPosition),
      );
      final belowStart = documentLayout.getRectForPosition(
        DocumentPosition(
          nodeId: below.id,
          nodePosition: below.beginningPosition,
        ),
      );
      if (aboveEnd == null || belowStart == null) continue;
      final top = aboveEnd.bottom;
      final bottom = belowStart.top;
      if (bottom <= top) {
        continue; // no gap (or overlapping frames) — nothing to fill 无缝可填
      }
      gaps.add(
        Rect.fromLTRB(
          math.min(aboveEnd.left, belowStart.left),
          top,
          math.max(aboveEnd.right, belowStart.right),
          bottom,
        ),
      );
    }
    return gaps;
  }

  @override
  Widget doBuild(BuildContext context, List<Rect>? gaps) {
    if (gaps == null || gaps.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final gap in gaps)
            Positioned.fromRect(
              rect: gap,
              child: ColoredBox(color: widget.color),
            ),
        ],
      ),
    );
  }
}
