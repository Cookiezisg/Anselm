import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// C1d — an expandable detail row: a [row] (an [AnRow]) with a [detail] panel that reveals below it
/// when [open]. The panel is indented to the row's label start (lead + gap + pad-row) and underlined by
/// a hairline. Controlled — the caller owns [open] (wire the row's onSelect / onToggle to flip it), so
/// this stays a pure layout: it reveals the panel via [AnimatedSize] (height animation, no hand-rolled
/// controller — the modern AnimatedSize has its own ticker). reduced-motion → instant.
///
/// C1d 可展开详情行:row(AnRow)+ open 时下方展开 detail 面板。面板缩进对齐 row 的 label 起点、底 hairline。
/// 受控——open 由调用方持有(把行的 onSelect/onToggle 接到翻转 open),本件纯布局:经 AnimatedSize 高度揭示
/// (无手搓 controller,现代 AnimatedSize 自带 ticker);reduced → 即时。
class AnRowDetail extends StatelessWidget {
  const AnRowDetail({required this.row, required this.detail, this.open = false, super.key});

  final Widget row;
  final Widget detail;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        AnimatedSize(
          duration: reduced ? Duration.zero : AnMotion.mid,
          curve: AnMotion.easeOut,
          alignment: Alignment.topCenter, // grow DOWNWARD only (default center穿模 上下行) 仅向下展开
          clipBehavior: Clip.hardEdge, // clip the panel during the height tween 展开中裁剪
          child: open
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line, width: AnSize.hairline)),
                  ),
                  child: Padding(
                    // indent to the row's label start: lead + gap + pad-row. 缩进对齐 label 起点。
                    padding: const EdgeInsetsDirectional.only(
                      start: AnSize.icon + AnSpace.s8 + AnSpace.s8,
                      end: AnSpace.s8,
                      top: AnSpace.s4,
                      bottom: AnSpace.s12,
                    ),
                    child: detail,
                  ),
                )
              : const SizedBox.shrink(), // collapsed → tweens to zero height 收起补间到 0
        ),
      ],
    );
  }
}
