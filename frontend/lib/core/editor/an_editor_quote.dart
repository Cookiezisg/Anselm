import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The document metadata key carrying a node's blockquote nesting depth (0 = not quoted, 1 = one `>`, …). The
/// codec (an_editor_markdown.dart) tags it; the An component builders read it to draw that many left bars.
/// 节点的引用嵌套深度 metadata 键(0=非引用,1=一层 `>`…);codec 打、组件读。
const quoteDepthKey = 'quoteDepth';

/// A node's blockquote nesting depth. 节点引用深度。
int quoteDepthOf(DocumentNode? node) =>
    (node?.getMetadataValue(quoteDepthKey) as int?) ?? 0;

/// True when a node is a quoted block whose PREVIOUS block is ALSO quoted — i.e. a continuation inside the same
/// blockquote group (not the first line of the quote). Such blocks carry their inter-block gap INSIDE the bar
/// (so the left rule reads as one continuous line) and get ZERO external padding; the FIRST quoted block keeps
/// the normal block gap before the quote. 引用组内的延续块(上一块也是引用):块间距移进条内(条连续)、外距归零;
/// 引用首块保留正常块前距。
bool isQuoteContinuation(Document doc, DocumentNode node) {
  if (quoteDepthOf(node) < 1) return false;
  final index = doc.getNodeIndexById(node.id);
  return index > 0 && quoteDepthOf(doc.getNodeAt(index - 1)) >= 1;
}

/// Wrap a block's widget in [depth] blockquote bars — reconstructing chat's nested-quote visual on
/// super_editor's FLAT block model. Each level = a 2px [AnColors.lineStrong] left rule + an [AnSpace.s12] inset,
/// applied from the inside out so a `quoteDepth: 2` node shows two nested bars, exactly like chat's `> >`. The
/// bar stretches to the block's full height; consecutive quoted blocks each draw their own bar, so with the
/// inter-block gap moved inside the quote (see the stylesheet) the bars read as one continuous rule.
/// 把块包上 depth 层引用左条(2px lineStrong + s12 缩进,由内向外);depth=2 显两条嵌套条=chat 的 `> >`。
Widget wrapInQuote(
  Widget child,
  int depth,
  AnColors colors, {
  double topGap = 0,
}) {
  var w = child;
  for (var i = 0; i < depth; i++) {
    // A left BORDER (not a stretched Row child) draws the bar the full height of the wrapped block — the Row +
    // CrossAxisAlignment.stretch approach fails under super_editor's unbounded-height column layout. padding
    // after the border = the s12 inset. The OUTERMOST level also pads [topGap] on top so a continuation block's
    // inter-block gap sits INSIDE the bar → the left rule is continuous across the quote. 用左边框画条(整块高);
    // 最外层顶部再垫 topGap,让延续块的块间距落在条内→左条连续。
    final isOutermost = i == depth - 1;
    w = Container(
      padding: EdgeInsetsDirectional.only(
        start: AnSpace.s12,
        top: isOutermost ? topGap : 0,
      ),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: colors.lineStrong, width: AnSize.quoteBar),
        ),
      ),
      child: w,
    );
  }
  if (depth <= 0) return w;
  // The bar/inset wrapper is PURE VISUAL — pointers must fall through to super_editor's gesture layer, which
  // sits BENEATH the document content in the hit-test order. A bare BoxDecoration border makes the whole block
  // rect hit-opaque (RenderDecoratedBox delegates to BoxDecoration.hitTest, which returns true anywhere inside
  // a borderless-radius rectangle), so clicks on a loaded blockquote never reached the mouse interactor: no
  // caret placement, no hover I-beam, drag-selection breaking across quotes — while ARROW keys still worked
  // (keyboard navigation never hit-tests). Same shape as the upstream BlockquoteComponent and our
  // _AnBlockquoteComponent, which both wrap in IgnorePointer. 左条壳是纯视觉——指针必须穿透到内容层之下的手势层;
  // BoxDecoration 让整块矩形吞命中(点引用永不落光标/无 I-beam/拖选中断,键盘却好——键盘不走命中),故照上游与
  // _AnBlockquoteComponent 同款包 IgnorePointer。
  return IgnorePointer(child: w);
}
