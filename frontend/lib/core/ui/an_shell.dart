import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_icon_button.dart';
import 'icons.dart';

/// The three-island desktop shell, faithfully replicating the demo's `<an-shell>`: a rounded
/// white window on the desktop, 8px padding + 8px gaps between left island ([sidebarBuilder]),
/// ocean, and right island. Owns the chrome interactions:
///  • left island collapse/expand (animated; reopen button appears in the ocean header),
///  • left island drag-resize (240–420, persisted via shared_preferences),
///  • right island slide open/close,
///  • a floating ocean header whose compact title fades in as the page scrolls.
/// [sidebarBuilder] receives the collapse callback (wire it to the sidebar's collapse
/// button); [oceanBuilder] receives the scroll controller that drives the compact title.
///
/// 三岛桌面 shell,忠实复刻 demo:桌面圆角白窗,8px 内距+岛间距。shell 自管 chrome 交互:左岛收起/展开
/// (动画,reopen 钮在海洋头)、左岛拖拽调宽(240–420,shared_preferences 持久)、右岛滑入滑出、海洋浮动头
/// (滚动时紧凑标题淡入)。[sidebarBuilder] 收到收起回调;[oceanBuilder] 收到滚动控制器。
class AnShell extends StatefulWidget {
  const AnShell({
    super.key,
    required this.sidebarBuilder,
    required this.oceanBuilder,
    this.rightIsland,
    this.headTitle,
    this.headActions = const [],
    this.framed = true,
    this.persistPrefix = 'an.shell',
  });

  final Widget Function(VoidCallback onCollapse) sidebarBuilder;
  final Widget Function(ScrollController scroll) oceanBuilder;
  final Widget? rightIsland;
  final String? headTitle;
  final List<Widget> headActions;
  final bool framed;
  final String persistPrefix;

  @override
  State<AnShell> createState() => _AnShellState();
}

class _AnShellState extends State<AnShell> {
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);
  double _sideWidth = AnSize.sidebar;
  bool _collapsed = false;
  bool _dragging = false;
  bool _rightOpen = true;
  double _compact = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Persistence degrades to defaults where the plugin is unavailable (tests / headless).
  // 插件不可用处(测试/无头)优雅退回默认。
  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final w = p.getDouble('${widget.persistPrefix}.width');
      final col = p.getBool('${widget.persistPrefix}.collapsed');
      if (!mounted) return;
      setState(() {
        if (w != null) _sideWidth = w.clamp(AnSize.sidebarMin, AnSize.sidebarMax);
        if (col != null) _collapsed = col;
      });
    } catch (_) {/* defaults */}
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('${widget.persistPrefix}.width', _sideWidth);
      await p.setBool('${widget.persistPrefix}.collapsed', _collapsed);
    } catch (_) {/* ignore */}
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final t = (_scroll.offset / 80).clamp(0.0, 1.0);
    if ((t - _compact).abs() > 0.01) setState(() => _compact = t);
  }

  void _toggleCollapse() {
    setState(() => _collapsed = !_collapsed);
    _savePrefs();
  }

  void _toggleRight() => setState(() => _rightOpen = !_rightOpen);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Padding(
      padding: const EdgeInsets.all(AnSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left island — animated width; child held at full width + clipped so it never
          // squishes/overflows during the collapse animation. 左岛动画宽 + 定宽裁剪,收起不挤压。
          AnimatedContainer(
            key: const ValueKey('anShellLeft'),
            duration: _dragging ? Duration.zero : AnMotion.slow,
            curve: AnMotion.spring,
            width: _collapsed ? 0 : _sideWidth,
            child: ClipRect(
              child: OverflowBox(
                minWidth: _sideWidth,
                maxWidth: _sideWidth,
                alignment: Alignment.centerLeft,
                child: widget.sidebarBuilder(_toggleCollapse),
              ),
            ),
          ),
          if (!_collapsed)
            _Grip(
              key: const ValueKey('anShellGrip'),
              onDrag: _onGripDrag,
              onDragStart: _onGripStart,
              onDragEnd: _onGripEnd,
            ),
          Expanded(child: _ocean(c)),
          if (widget.rightIsland != null) _right(),
        ],
      ),
    );

    if (!widget.framed) return ColoredBox(color: c.surface, child: body);
    return ColoredBox(
      color: c.desk,
      child: Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AnRadius.island),
            boxShadow: c.shadowFloat,
          ),
          child: body,
        ),
      ),
    );
  }

  void _onGripStart() => setState(() => _dragging = true);
  void _onGripDrag(double dx) =>
      setState(() => _sideWidth = (_sideWidth + dx).clamp(AnSize.sidebarMin, AnSize.sidebarMax));
  void _onGripEnd() {
    setState(() => _dragging = false);
    _savePrefs();
  }

  Widget _right() {
    // Gap + island folded into one animated width so they slide together.
    const w = AnSize.rightIsland + AnSpace.s8;
    return AnimatedContainer(
      key: const ValueKey('anShellRight'),
      duration: AnMotion.slow,
      curve: AnMotion.spring,
      width: _rightOpen ? w : 0,
      child: ClipRect(
        child: OverflowBox(
          minWidth: w,
          maxWidth: w,
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(left: AnSpace.s8),
            child: widget.rightIsland,
          ),
        ),
      ),
    );
  }

  Widget _ocean(AnColors c) {
    return Stack(
      children: [
        Positioned.fill(child: widget.oceanBuilder(_scroll)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: AnSize.islandHead + AnSpace.s12,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [c.surface, c.surface, c.surface.withValues(alpha: 0)],
                          stops: const [0, 0.7, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: AnSize.islandHead,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
                    child: Row(
                      children: [
                        if (_collapsed)
                          AnIconButton(AnIcons.collapseLeft,
                              size: AnSize.controlSm, onPressed: _toggleCollapse),
                        if (widget.headTitle != null)
                          Expanded(
                            child: Opacity(
                              opacity: _compact,
                              child: Text(widget.headTitle!,
                                  overflow: TextOverflow.ellipsis,
                                  style: AnText.body.copyWith(
                                      color: c.ink, fontWeight: FontWeight.w600)),
                            ),
                          )
                        else
                          const Spacer(),
                        for (final a in widget.headActions) ...[a, const SizedBox(width: AnSpace.s4)],
                        if (widget.rightIsland != null)
                          AnIconButton(AnIcons.collapseRight,
                              size: AnSize.controlSm, onPressed: _toggleRight),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The drag handle between left island and ocean — also serves as the 8px gap. Shows a
/// hairline on hover. 左岛与海洋间的拖拽柄,兼作 8px 间距;悬停现细线。
class _Grip extends StatefulWidget {
  const _Grip({super.key, required this.onDrag, required this.onDragStart, required this.onDragEnd});
  final ValueChanged<double> onDrag;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  @override
  State<_Grip> createState() => _GripState();
}

class _GripState extends State<_Grip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => widget.onDragStart(),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => widget.onDragEnd(),
        child: SizedBox(
          width: AnSpace.s8,
          child: Center(
            child: AnimatedContainer(
              duration: AnMotion.fast,
              width: 2,
              decoration: BoxDecoration(
                color: _hover ? c.lineStrong : Colors.transparent,
                borderRadius: BorderRadius.circular(AnRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
