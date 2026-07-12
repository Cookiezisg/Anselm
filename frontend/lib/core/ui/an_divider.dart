import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

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
        margin = EdgeInsets.zero,
        label = null,
        icon = null;

  const AnDivider.vertical({
    this.length = AnSize.controlSm,
    this.margin = const EdgeInsets.symmetric(horizontal: AnSpace.s4),
    super.key,
  })  : vertical = true,
        label = null,
        icon = null;

  /// A rule with a centred whisper label (optional leading icon) — the «context compacted» seam
  /// mark and friends (WRK-066 A-086: the ONE labelled-rule implementation; features stop
  /// sandwiching hand-drawn hairlines around text). The label ellipsizes at narrow widths.
  /// 带居中低语标签的分隔线(可带前导 icon)——「上下文已压缩」缝标等(A-086:唯一带标线实现,
  /// features 不再手夹发丝线);窄宽下标签省略。
  const AnDivider.labeled(String this.label, {this.icon, super.key})
      : vertical = false,
        length = null,
        margin = EdgeInsets.zero;

  final bool vertical;
  final double? length;
  final EdgeInsetsGeometry margin;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (vertical) {
      return Container(width: AnSize.hairline, height: length, margin: margin, color: c.line);
    }
    final rule = Container(height: AnSize.hairline, color: c.line);
    if (label == null) return rule;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: rule),
        // Flexible (not a fixed Padding) so a long label ellipsizes instead of overflowing narrow
        // hosts. Flexible:窄宽省略不溢出。
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AnSize.iconSm, color: c.inkFaint),
                  const SizedBox(width: AnSpace.s6),
                ],
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.copyWith(color: c.inkFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: Container(height: AnSize.hairline, color: c.line)),
      ],
    );
  }
}
