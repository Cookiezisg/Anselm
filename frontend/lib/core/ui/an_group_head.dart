import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// The ONE collapsible big-GROUP head for the left-island rail / bell tray — a faint emphasis label + an
/// optional count + a rotating disclosure chevron, the WHOLE head toggling open/closed (keyboard-operable,
/// not a mouse-only lead chevron). [trailing] adds an action affordance (a ⋯ [AnMenu]) that sits between the
/// label/count cluster and the chevron — the notification tray's per-group bulk menu (待你处理 → 全部批准/
/// 拒绝, notification groups → 全部已读). Sticky → an opaque [AnColors.surface] fill so virtualized list rows
/// scroll UNDER it (VS Code sticky-scroll). [AnSidebarList]'s big group head and the notification tray's
/// group heads both ride this — never re-rolled per site (#8).
///
/// 左岛 rail / 铃托盘唯一的可折叠大组头:灰加粗 label + 可选计数 + 转 chevron,整头折叠(键盘可达)。trailing 在
/// 计数簇与 chevron 之间加动作(⋯ AnMenu)——托盘逐组批量菜单。sticky → opaque 面,虚拟列表行从其下滚过。
/// AnSidebarList 大组头 + 托盘组头共用它,绝不逐处重搓。
class AnGroupHead extends StatelessWidget {
  const AnGroupHead({
    required this.label,
    this.count,
    required this.open,
    required this.onToggle,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.only(start: AnSpace.s8, end: AnSpace.s12),
    this.sticky = false,
    super.key,
  });

  final String label;

  /// The total row count shown after the label, or null to omit it. 计数(label 后),null 省略。
  final int? count;

  final bool open;
  final VoidCallback onToggle;

  /// An action affordance in the head's trailing position (a ⋯ [AnMenu]); it owns its own tap, so
  /// activating it never toggles the head. Null → no trailing. 组头尾动作(⋯ 菜单);自持点击、不触发折叠。
  final Widget? trailing;

  /// Head padding. Default = the rail convention (start s8, end s12); the bell tray passes a 12-left single
  /// source so heads/rows/cards share one edge. 组头内距,默认 rail 约定;托盘传 12 左缘单源。
  final EdgeInsetsGeometry padding;

  /// Opaque surface (a pinned sticky ancestor head) so list rows scroll under it. 吸顶 opaque。
  final bool sticky;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnInteractive(
      onTap: onToggle,
      expanded: open,
      builder: (ctx, states) => Container(
        height: AnSize.row,
        color: sticky ? c.surface : c.surfaceHover.whenActive(states.isActive),
        padding: padding,
        child: Row(
          children: [
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
            ),
            if (count != null) ...[
              const SizedBox(width: AnSpace.s6),
              Text('$count',
                  style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
            ],
            const Spacer(),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: AnSpace.s6),
            ],
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid,
              curve: AnMotion.spring,
              child: Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
