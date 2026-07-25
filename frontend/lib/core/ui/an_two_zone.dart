import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// The kit's right-anchored two-zone row content (the demo's `.lab{flex:1}` + `.meta{flex:none;
/// max-width}`, in Flutter): primary [label] fills the LEFT and ellipsis-truncates last; secondary
/// [meta] sits RIGHT, capped at ≤45% of the row so a long id can't crowd out the label, ellipsis when
/// over; [trailing] (caret / check / actions) is pinned to the right edge because the label is
/// [Expanded] (greedy). Both texts truncate independently — no overflow.
///
/// Promoted from AnDropdown's private `_TwoZone` — principle #8: the shared skeleton lives in one
/// place, consumers don't re-roll Row+Spacer. **Consumers today: AnDropdown (trigger + menu rows),
/// AnSection head, AnInfoCard head.**
///
/// TWO row-family surfaces deliberately do NOT use it, and both exclusions are structural rather than
/// oversight (WRK-083 B2 — until then this doc claimed AnRow's trailing slot was a consumer, which it
/// never was):
///
///   - **AnMenuItem** cannot: this is a `LayoutBuilder`, and AnMenu's popover wraps its body in
///     `IntrinsicWidth` to hug the widest row. A `LayoutBuilder` throws when asked for an intrinsic
///     dimension, so the menu expresses the same rule with flex instead. (AnDropdown is fine — its
///     popover is a plain `ConstrainedBox`, no intrinsic pass.)
///   - **AnRow's trail** cannot: its meta and its hover actions must occupy the SAME right anchor and
///     cross-fade without reflow, whereas this primitive lays meta and [trailing] out SIDE BY SIDE.
///     Passing both here would render them together instead of swapping.
///
/// (AnKv does NOT use this either — its row is key-hugs-left + value-grows-right, not
/// label-greedy-Expanded.)
///
/// 套件右锚两区行内容(demo 的 lab flex:1 + meta flex:none·max-width 的 Flutter 版):label 占满左、最后才省略;
/// meta 居右、上限 45%(长 id 挤不掉 label)、超长省略;trailing(箭头/勾/动作)因 label Expanded 而钉在右沿。
/// 两者各自截断、不溢出。由 AnDropdown 的 private `_TwoZone` 升格(原则 #8:骨架归一处、消费方不再各搓 Row+Spacer)。
/// **今日消费方:AnDropdown(触发器 + 菜单行)· AnSection head · AnInfoCard head。**
///
/// **有两个行族面刻意不用它**,且两处都是**结构性**原因、不是疏忽(WRK-083 B2——在那之前本注释声称 AnRow 尾槽是
/// 消费方,而它从来不是):
///
///   - **AnMenuItem 用不了**:本原语是 `LayoutBuilder`,而 AnMenu 的浮层把 body 包在 `IntrinsicWidth` 里以贴最宽
///     那行。`LayoutBuilder` 被问 intrinsic 尺寸时**直接抛**,故菜单改用 flex 表达同一条规则。(AnDropdown 没事——
///     它的浮层是纯 `ConstrainedBox`、没有 intrinsic 那一趟。)
///   - **AnRow 的 trail 用不了**:它的 meta 与 hover 动作必须占**同一个**右锚并交叉淡入淡出、不重排,而本原语把
///     meta 与 [trailing] **并排**摆。两个都传进来会变成同时显示、而不是互换。
///
/// (AnKv 也不用它——Kv 行是 key 贴内容左 + value 撑右,非 label 贪婪 Expanded 的几何。)
const double _kMetaMaxFraction =
    0.45; // meta zone ≤ 45% of the row (label keeps ≥ 55%) meta 区上限
const double _kMetaFallbackWidth =
    160; // meta cap when the row width is unbounded 无界时 meta 上限

class AnTwoZone extends StatelessWidget {
  const AnTwoZone({
    required this.label,
    this.meta,
    this.metaStyle,
    required this.trailing,
    super.key,
  });

  final Widget label;
  final String? meta;
  final TextStyle? metaStyle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metaCap = constraints.maxWidth.isFinite
            ? constraints.maxWidth * _kMetaMaxFraction
            : _kMetaFallbackWidth;
        return Row(
          children: [
            Expanded(child: label),
            if (meta != null) ...[
              const SizedBox(width: AnSpace.s8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metaCap),
                child: Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: metaStyle,
                ),
              ),
            ],
            const SizedBox(width: AnSpace.s8),
            trailing,
          ],
        );
      },
    );
  }
}
