import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_icon_button.dart';
import 'icons.dart';

/// 左岛 — a single island card (white, radius 12, float shadow, hairline border, 12px pad),
/// faithfully replicating the demo's `<an-sidebar>`. Top: macOS traffic lights + collapse +
/// search. Then a horizontal Notion-style ocean nav (unselected = icon only; selected =
/// icon + label pill). Then the feature list ([body]). Footer: workspace+gear / bell.
///
/// 左岛——单张岛卡(白、圆角 12、浮阴影、细边、内距 12),忠实复刻 demo 的 `<an-sidebar>`。顶部:红绿灯 +
/// 收起 + 搜索。横向 Notion 式海洋导航(未选只图标、选中=图标+标签药丸)。中部 feature 列表([body])。
/// 底部:工作区+齿轮 / 铃铛。
class AnSidebarNav {
  const AnSidebarNav({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class AnSidebar extends StatelessWidget {
  const AnSidebar({
    super.key,
    required this.workspaceName,
    required this.nav,
    required this.selectedIndex,
    required this.body,
    this.onSelect,
    this.onCollapse,
    this.onSearch,
    this.onWorkspace,
    this.onBell,
    this.unread = false,
    this.peek,
  });

  final String workspaceName;
  final List<AnSidebarNav> nav;
  final int selectedIndex;
  final Widget body;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onCollapse;
  final VoidCallback? onSearch;
  final VoidCallback? onWorkspace;
  final VoidCallback? onBell;
  final bool unread;
  final Widget? peek; // transient status chip floating at the island bottom 左下浮条

  // macOS traffic-light colors — the one named-color exception (platform chrome). In a real
  // frameless macOS window these become the OS controls. 红绿灯:唯一具名色例外(平台 chrome)。
  static const _tlClose = Color(0xFFFF5F57);
  static const _tlMin = Color(0xFFFEBC2E);
  static const _tlMax = Color(0xFF28C840);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.chip),
        boxShadow: c.shadowFloat,
      ),
      padding: const EdgeInsets.all(AnSpace.s12),
      child: Stack(
        children: [
          _content(context, c),
          if (peek != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: AnSize.controlSm + AnSpace.s8,
              child: peek!,
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AnColors c) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // top: traffic lights + collapse + search
          SizedBox(
            height: AnSize.row,
            child: Row(
              children: [
                const _TrafficLights(),
                const Spacer(),
                AnIconButton(AnIcons.collapseLeft,
                    size: AnSize.controlSm, tooltip: 'Collapse', onPressed: onCollapse),
                AnIconButton(AnIcons.search,
                    size: AnSize.controlSm, tooltip: 'Search', onPressed: onSearch),
              ],
            ),
          ),
          const SizedBox(height: AnSpace.s8),
          // horizontal Notion-style nav
          SizedBox(
            height: AnSize.row,
            child: Row(
              children: [
                for (var i = 0; i < nav.length; i++)
                  _NavBtn(
                    nav: nav[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelect?.call(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AnSpace.s12),
          // feature list
          Expanded(child: body),
          const SizedBox(height: AnSpace.s8),
          // footer: workspace + bell
          Row(
            children: [
              Expanded(child: _WorkspaceBtn(name: workspaceName, onTap: onWorkspace)),
              const SizedBox(width: AnSpace.s4),
              _BellBtn(unread: unread, onTap: onBell),
            ],
          ),
        ],
    );
  }
}

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();
  @override
  Widget build(BuildContext context) {
    Widget dot(Color color) => Container(
          width: AnSize.iconSm,
          height: AnSize.iconSm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AnSpace.s8,
        children: [dot(AnSidebar._tlClose), dot(AnSidebar._tlMin), dot(AnSidebar._tlMax)],
      ),
    );
  }
}

class _NavBtn extends StatefulWidget {
  const _NavBtn({required this.nav, required this.selected, required this.onTap});
  final AnSidebarNav nav;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = widget.selected;
    final bg = selected ? c.surfaceActive : (_hover ? c.surfaceHover : Colors.transparent);
    final color = selected ? c.ink : c.inkMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AnMotion.fast,
          height: AnSize.row,
          margin: const EdgeInsets.only(right: 2),
          padding: EdgeInsets.symmetric(horizontal: selected ? AnSpace.s8 : 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.nav.icon, size: 18, color: color),
              if (selected) ...[
                const SizedBox(width: AnSpace.s8),
                Text(widget.nav.label, style: AnText.label.copyWith(color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceBtn extends StatefulWidget {
  const _WorkspaceBtn({required this.name, this.onTap});
  final String name;
  final VoidCallback? onTap;
  @override
  State<_WorkspaceBtn> createState() => _WorkspaceBtnState();
}

class _WorkspaceBtnState extends State<_WorkspaceBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: AnSize.controlSm,
          padding: const EdgeInsets.only(left: AnSpace.s8, right: 2),
          decoration: BoxDecoration(
            color: _hover ? c.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.name,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600)),
              ),
              Icon(AnIcons.settings, size: AnSize.iconSm, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellBtn extends StatefulWidget {
  const _BellBtn({required this.unread, this.onTap});
  final bool unread;
  final VoidCallback? onTap;
  @override
  State<_BellBtn> createState() => _BellBtnState();
}

class _BellBtnState extends State<_BellBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: AnSize.controlSm,
          height: AnSize.controlSm,
          decoration: BoxDecoration(
            color: _hover ? c.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(AnIcons.notifications, size: 18, color: _hover ? c.ink : c.inkFaint),
              if (widget.unread)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    width: AnSize.dot,
                    height: AnSize.dot,
                    decoration: BoxDecoration(
                      color: c.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
