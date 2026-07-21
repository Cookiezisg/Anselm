import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A white panel with a SEMANTIC-TONE hairline border at the machine-window radius ([AnRadius.card], 16)
/// + card padding. It is a plain decorated container (NOT an [AnWindow]), so it can HOST an AnWindow
/// without the window-in-window ban — the human-gate's card-16 shell (danger/ask border) that must sit at
/// the same radius as the adjacent AnWindow tool cards yet carry a tone edge AnCard's chip-12 can't
/// (WRK-066 A-028: card-16 white + tone border + nestable). 白面板 + 语义 tone 发丝边 + card-16 机器窗圆角 +
/// 卡内距;是普通装饰容器(非 AnWindow),故可嵌 AnWindow 不犯窗禁套窗——人闸 card-16 壳(danger/ask 边),
/// 与相邻工具卡同圆角却带 AnCard chip-12 给不了的 tone 边。
class AnTonedPanel extends StatelessWidget {
  const AnTonedPanel({
    required this.child,
    required this.borderColor,
    super.key,
  });

  final Widget child;

  /// The semantic border colour (a danger / caution / accent tone). 语义边框色。
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: AnInset.card,
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AnRadius.card),
      border: Border.all(color: borderColor, width: AnSize.hairline),
    ),
    child: child,
  );
}
