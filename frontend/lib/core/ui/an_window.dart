import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_fade_collapse.dart';

/// The WINDOW family head (WRK-066「同轨」族一 · 2026-07-11 拍板修订) — the ONE content container, with
/// ONE face: white surface + hairline border + card radius. The grey «sunken well» material is RETIRED
/// app-wide (the user chat bubble is the only grey survivor — it's a bubble, not a window; interaction
/// greys like hover/inputs are controls, not containers). A left [header] slot (command echo / title),
/// a right [actions] slot (chip-family copy etc.), an [AnSize]-tier [maxHeight] clamp, an optional
/// [collapsible] fade. Windows are LEAF containers: never nest a window in a window (double hairlines
/// touching read as a defect) — and code/diff bring their own [AnCodeSurface] shell, never wrapped.
///
/// 窗族当家件(「同轨」族一 · 拍板修订)——唯一内容容器,唯一的脸:白底+发丝边+card 圆角。灰凹面材质全 App
/// 退役(用户消息泡是唯一灰底幸存者——它是气泡不是窗;hover/输入等交互灰是控件不是容器)。左 header 槽、
/// 右 actions 槽、AnSize 档钳高、可折叠。**窗是叶子容器:窗内禁套窗**(双发丝边贴脸读作缺陷);代码/diff
/// 自带 AnCodeSurface 壳,绝不再包窗。
class AnWindow extends StatelessWidget {
  const AnWindow({
    required this.child,
    this.header,
    this.actions = const [],
    this.maxHeight,
    this.collapsible = false,
    super.key,
  });

  final Widget child;

  /// Left header slot (command echo / title line). 左头槽。
  final Widget? header;

  /// Right action slot (copy chips etc.), flush-right on the header row. 右动作槽。
  final List<Widget> actions;

  /// Height clamp — pass an [AnSize] viewport tier, never a bare number. 高钳(AnSize 档,禁裸数)。
  final double? maxHeight;

  /// Past [maxHeight], fade-collapse with the standard expand/collapse affordance (instead of a hard
  /// clip). 超高时 FadeCollapse(标准展开/收起),而非硬裁。
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final head = (header == null && actions.isEmpty)
        ? null
        : Row(children: [
            if (header != null)
              Expanded(
                child: DefaultTextStyle.merge(
                    style: AnText.label.copyWith(color: c.inkFaint), child: header!),
              )
            else
              const Spacer(),
            for (final a in actions)
              Padding(padding: const EdgeInsets.only(left: AnSpace.s4), child: a),
          ]);

    Widget body = child;
    if (maxHeight != null) {
      body = collapsible
          ? AnFadeCollapse(
              collapsible: true,
              collapsedHeight: maxHeight!,
              expandLabel: context.t.chat.tool.proseExpand,
              collapseLabel: context.t.chat.tool.proseCollapse,
              fadeColor: c.surface,
              child: child,
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!),
              child: ClipRect(child: child),
            );
    }

    return Container(
      width: double.infinity,
      padding: AnInset.card,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: head == null
          ? body
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              head,
              const SizedBox(height: AnSpace.s6),
              body,
            ]),
    );
  }
}
