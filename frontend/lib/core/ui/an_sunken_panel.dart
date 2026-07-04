import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The SUNKEN panel — a neutral inset well one rung below the base surface ([AnColors.surfaceSunken] +
/// [AnRadius.chip] + a standard s12/s8 inset). The semantic opposite of the raised [AnCard]/[AnIsland]:
/// a contained, non-interactive fill for chat bubbles / machine tool windows / embedded panels. An
/// optional [header] rides above the [child] with an s4 gap (a command echo, an omitted-lines note).
/// Collapses the well chrome that was hand-inlined in the chat user bubble, the tool [ToolWindow], and
/// the tool progress tail (≥3 sites) into one place — the surfaceSunken colour existed for exactly this
/// but the widget wrapping it was copied by hand.
///
/// 凹陷面板——比 base surface 轻降一档的中性内嵌槽(surfaceSunken 底 + r-chip + 标准 s12/s8 内距)。是浮起
/// AnCard/AnIsland 的语义对偶:contained、非交互的填充,供聊天泡 / 机器工具窗 / 内嵌面板。可选 [header] 以 s4
/// 间距压在 [child] 上方(命令回显 / 省略行提示)。收口此前在聊天用户泡、工具 ToolWindow、工具进度尾手抄的
/// 凹陷 chrome(≥3 处)——surfaceSunken 语义色本就为此而设,包它的 widget 却被逐字复制。
class AnSunkenPanel extends StatelessWidget {
  const AnSunkenPanel({required this.child, this.header, super.key});

  final Widget child;

  /// Optional header above the child (e.g. a terminal-style command echo). 可选窗头。
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(AnRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8),
        child: header == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [header!, const SizedBox(height: AnSpace.s4), child],
              ),
      ),
    );
  }
}
