import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The SUNKEN panel — a neutral inset well one rung below the base surface ([AnColors.surfaceSunken] +
/// [AnRadius.chip]). Since the grey-well retirement (WRK-066 族一: every machine/content container is
/// the white-framed AnWindow) its ONE remaining tenant is the chat USER BUBBLE — a bubble, not a
/// window; it keeps the grey so «what I said» reads as material apart from «what the machine made».
/// The header slot died with ToolWindow.
///
/// 凹陷面板——比 base surface 轻降一档的中性内嵌槽(surfaceSunken 底 + r-chip)。灰凹面退役后(族一:
/// 一切机器/内容容器=白框 AnWindow),唯一住户=聊天**用户泡**——泡不是窗,留灰让「我说的」与「机器产的」
/// 材质分明。header 槽随 ToolWindow 一并退役。
class AnSunkenPanel extends StatelessWidget {
  const AnSunkenPanel({required this.child, this.inset, super.key});

  final Widget child;

  /// Well inset — defaults to the machine s12/s8. The 15-prose bubble passes [AnInset.bubble]:
  /// the 13-era padding read pinched around the 24px reading line box. 内距:默认 s12/s8;15 prose
  /// 泡传 [AnInset.bubble](13 时代内距在 24px 阅读行盒旁显局促)。
  final EdgeInsets? inset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(AnRadius.chip),
      ),
      child: Padding(
        padding: inset ?? const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8),
        child: child,
      ),
    );
  }
}
