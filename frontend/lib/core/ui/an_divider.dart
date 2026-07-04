import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A hairline rule ([AnSize.hairline] thick, [AnColors.line]). Horizontal = a full-bleed head↔body /
/// section separator (fills its cross axis). [AnDivider.vertical] = an in-line segment separator (a
/// floating-bar / toolbar pip), defaulting to a [AnSize.controlSm]-tall stroke with [AnSpace.s4] side
/// margins; pass [length]/[margin] to override. Collapses the raw colour-filled `Container`s that
/// features were hand-drawing as rules — [AnInspectorHead] and friends deliberately draw NO rule
/// themselves and delegate it here.
///
/// 发丝分隔线(hairline 粗 + line 色)。横向=通栏 head↔body / 段分隔(填满交叉轴)。[AnDivider.vertical]=行内段
/// 分隔(浮动条/工具条竖线),默认 controlSm 高 + s4 侧距,可经 [length]/[margin] 覆写。收口 features 各自用裸着色
/// Container 手画的分隔线——AnInspectorHead 等件刻意不自画线、把线甩到此处。
class AnDivider extends StatelessWidget {
  const AnDivider({super.key})
      : vertical = false,
        length = null,
        margin = EdgeInsets.zero;

  const AnDivider.vertical({
    this.length = AnSize.controlSm,
    this.margin = const EdgeInsets.symmetric(horizontal: AnSpace.s4),
    super.key,
  }) : vertical = true;

  final bool vertical;
  final double? length;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (vertical) {
      return Container(width: AnSize.hairline, height: length, margin: margin, color: c.line);
    }
    return Container(height: AnSize.hairline, color: c.line);
  }
}
