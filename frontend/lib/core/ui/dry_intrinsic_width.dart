import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [IntrinsicWidth] that doesn't choke on a child (TextField/EditableText) which lacks dry-layout
/// support — a drop-in shim (Matthew Carroll's pattern; principle #8: a tiny proven shim over
/// hand-rolled measuring). Plain IntrinsicWidth forwards a dry-layout query to its child, and
/// TextField asserts "does not support dry layout" in nested/scroll contexts; here the dry query is
/// routed through the intrinsic-width path instead. The real layout pass is unchanged (it already
/// sizes to max intrinsic width). Shared by AnInlineEdit and AnTags' inline add field so a seamless
/// field grows to its typed content.
///
/// 不被无 dry-layout 子(TextField)噎住的 IntrinsicWidth(社区垫片,原则 #8)。原版会把 dry 查询转给子,
/// TextField 在嵌套/滚动上下文断言「不支持 dry layout」;此处把 dry 改走固有宽路径。真实布局不变(本就按
/// 最大固有宽)。AnInlineEdit / AnTags 内联添加框共用,让 seamless 框按内容增长。
class DryIntrinsicWidth extends SingleChildRenderObjectWidget {
  const DryIntrinsicWidth({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDryIntrinsicWidth();
}

class _RenderDryIntrinsicWidth extends RenderIntrinsicWidth {
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final width = constraints.constrainWidth(child.getMaxIntrinsicWidth(constraints.maxHeight));
    final height = constraints.constrainHeight(child.getMinIntrinsicHeight(width));
    return Size(width, height);
  }
}
