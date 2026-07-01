import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// The sidebar-footer workspace trigger — the workspace name (ellipsised) + a chevron, on a hover/active
/// surface. Tapped to open the workspace quick-actions menu; the CALLER wraps it in an [AnMenu] (its
/// `anchorBuilder` supplies `toggle` for [onTap] and `isOpen` for [isOpen], which shows the active surface
/// + flips the chevron while the menu is open).
///
/// 侧栏底栏 workspace 触发钮:名字(省略)+ chevron,hover/激活底。点开工作区快捷操作菜单;
/// 由调用方裹进 [AnMenu](anchorBuilder 给 toggle→onTap、isOpen→isOpen:菜单开时显激活底 + 翻转 chevron)。
class AnWorkspaceButton extends StatelessWidget {
  const AnWorkspaceButton({
    required this.name,
    this.onTap,
    this.isOpen = false,
    super.key,
  });

  final String name;
  final VoidCallback? onTap;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    return AnInteractive(
      onTap: onTap,
      selected: isOpen,
      builder: (context, states) {
        final hot = isOpen || states.isActive;
        return AnimatedContainer(
          duration: reduced ? Duration.zero : AnMotion.fast,
          height: AnSize.controlSm,
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6),
          decoration: BoxDecoration(
            color: (isOpen ? c.surfaceActive : c.surfaceHover).whenActive(hot),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink),
                ),
              ),
              const SizedBox(width: AnSpace.s4),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: reduced ? Duration.zero : AnMotion.fast,
                child: Icon(AnIcons.chevronDown, size: AnSize.iconSm, color: c.inkFaint),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The left-island FOOTER — three separated zones (the demo's `.foot`, refined): the workspace quick-
/// actions trigger ([workspace], a flexible slot the caller fills with an [AnMenu]-wrapped
/// [AnWorkspaceButton]) + two equal square cells: SETTINGS (gear → its ocean; [settingsActive] highlights
/// it) and NOTIFICATIONS (bell → takes over the left island; [notificationsActive] highlights it, a red
/// dot shows when [unreadCount] > 0). Settings/notifications are TWO distinct axes, so both can be
/// highlighted independently. Riverpod-free; state fed as props.
///
/// 左岛底栏——三分区(demo `.foot` 精炼版):workspace 快捷操作触发(flex 槽,调用方填 AnMenu 裹的 AnWorkspaceButton)+
/// 两个等大方格:设置(齿轮→设置海洋,settingsActive 高亮)、通知(铃→接管左岛,notificationsActive 高亮,unreadCount>0 显红点)。
/// 设置/通知是两条独立轴,可各自高亮。Riverpod-free,状态以 props 喂入。
class AnSidebarFooter extends StatelessWidget {
  const AnSidebarFooter({
    required this.workspace,
    required this.onSettings,
    required this.onNotifications,
    required this.settingsLabel,
    required this.notificationsLabel,
    this.settingsActive = false,
    this.notificationsActive = false,
    this.unreadCount = 0,
    super.key,
  });

  final Widget workspace;
  final VoidCallback onSettings;
  final VoidCallback onNotifications;
  final String settingsLabel;
  final String notificationsLabel;
  final bool settingsActive;
  final bool notificationsActive;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: workspace),
        const SizedBox(width: AnSpace.s2),
        _Cell(icon: AnIcons.gear, label: settingsLabel, active: settingsActive, onTap: onSettings),
        const SizedBox(width: AnSpace.s2),
        _Cell(
          icon: AnIcons.bell,
          label: notificationsLabel,
          active: notificationsActive,
          onTap: onNotifications,
          badge: unreadCount > 0,
        ),
      ],
    );
  }
}

/// A square footer icon cell (settings / notifications). 方形底栏图标格。
class _Cell extends StatelessWidget {
  const _Cell({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    return AnInteractive(
      onTap: onTap,
      selected: active,
      builder: (context, states) {
        final hot = active || states.isActive;
        return Semantics(
          label: label,
          child: SizedBox(
            width: AnSize.controlSm,
            height: AnSize.controlSm,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: reduced ? Duration.zero : AnMotion.fast,
                    decoration: BoxDecoration(
                      color: (active ? c.surfaceActive : c.surfaceHover).whenActive(hot),
                      borderRadius: BorderRadius.circular(AnRadius.button),
                    ),
                  ),
                ),
                Center(child: Icon(icon, size: AnSize.icon, color: hot ? c.ink : c.inkFaint)),
                if (badge)
                  Positioned(
                    top: AnSpace.s2,
                    right: AnSpace.s2,
                    child: Container(
                      width: AnSize.dot,
                      height: AnSize.dot,
                      decoration: BoxDecoration(
                        color: c.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
