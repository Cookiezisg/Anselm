import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The DECISION LADDER skeleton (WRK-066 批6, A-075) — a vertical ordered structure: every rung gets
/// a numbered circle, a hairline descent line to the next rung, and a content slot. The ladder owns
/// ONLY the skeleton (number + line + slot); rung content (CEL, ports, emit grids) belongs to the
/// consumer. Distinct from [AnStepper] (a HORIZONTAL discrete progress indicator with a «current
/// step» — a ladder has no progress: all rungs coexist as priority order).
///
/// CONSTRAINT: each rung is wrapped in [IntrinsicHeight] (the descent line stretches to the rung's
/// height), so rung content must support intrinsic sizing — no [AnWindow] / [LayoutBuilder] /
/// lazy viewports inside a rung (they throw at layout in debug). Text, chips, KV grids are fine.
///
/// 判别梯骨架(批6 A-075)——纵向有序结构:每级=序号圆+发丝降线+内容槽。梯只 owns 骨架,级内容
/// (CEL/端口/emit 格)归消费方。与 AnStepper(横向离散进度器,有「当前步」)角色不同,不并件。
/// **约束**:级裹 IntrinsicHeight(降线随级同高),级内容须支持固有尺寸——禁 AnWindow/LayoutBuilder/
/// 懒视口(布局期即抛);文本/芯片/KV 格安全。
class AnLadder extends StatelessWidget {
  const AnLadder({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: AnSize.icon,
                  height: AnSize.icon,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.line, width: AnSize.hairline),
                  ),
                  child: Text('${i + 1}', style: AnText.metaTabular().copyWith(color: c.inkFaint)),
                ),
                // The descent line binds a rung to the next — the last rung ends clean. 末级收线。
                if (i < children.length - 1)
                  Expanded(child: Container(width: AnSize.hairline, color: c.line)),
              ]),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i < children.length - 1 ? AnSpace.s8 : 0),
                  child: children[i],
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
