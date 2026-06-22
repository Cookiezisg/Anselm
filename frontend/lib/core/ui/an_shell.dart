import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_chrome_bar.dart';
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
    this.persistPrefix = 'an.shell',
  });

  final Widget Function(VoidCallback onCollapse) sidebarBuilder;
  final Widget Function(ScrollController scroll) oceanBuilder;
  final Widget? rightIsland;
  final String? headTitle;
  final List<Widget> headActions;
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
    // The OS window provides the frame (opaque white, rounded by macOS, real traffic
    // lights). Material gives the text a proper default style (no yellow debug underlines).
    return Material(
      color: c.surface,
      child: LayoutBuilder(
        builder: (context, cons) {
          // Responsive: force-collapse below breakpoints so the ocean never overflows;
          // above them, respect the user's manual toggles. 响应式:窄则强制收岛,宽则尊重手动。
          final collapsed = _collapsed || cons.maxWidth < AnSize.sidebarBreakpoint;
          final rightOpen = widget.rightIsland != null &&
              _rightOpen &&
              cons.maxWidth >= AnSize.rightIslandBreakpoint;
          return Padding(
            padding: const EdgeInsets.all(AnSpace.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left island — animated width; child held at full width + clipped so it
                // never squishes/overflows during the collapse animation. 定宽裁剪,收起不挤压。
                AnimatedContainer(
                  key: const ValueKey('anShellLeft'),
                  duration: _dragging ? Duration.zero : AnMotion.slow,
                  curve: AnMotion.spring,
                  width: collapsed ? 0 : _sideWidth,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: _sideWidth,
                      maxWidth: _sideWidth,
                      alignment: Alignment.centerLeft,
                      child: widget.sidebarBuilder(_toggleCollapse),
                    ),
                  ),
                ),
                if (!collapsed)
                  _Grip(
                    key: const ValueKey('anShellGrip'),
                    onDrag: _onGripDrag,
                    onDragStart: _onGripStart,
                    onDragEnd: _onGripEnd,
                  ),
                Expanded(child: _ocean(collapsed)),
                if (widget.rightIsland != null) _right(rightOpen),
              ],
            ),
          );
        },
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

  Widget _right(bool open) {
    // Gap + island folded into one animated width so they slide together.
    const w = AnSize.rightIsland + AnSpace.s8;
    return AnimatedContainer(
      key: const ValueKey('anShellRight'),
      duration: AnMotion.slow,
      curve: AnMotion.spring,
      width: open ? w : 0,
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

  Widget _ocean(bool collapsed) {
    return Stack(
      children: [
        Positioned.fill(child: widget.oceanBuilder(_scroll)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _OceanHeader(
            collapsed: collapsed,
            compact: _compact,
            title: widget.headTitle,
            actions: widget.headActions,
            hasRightIsland: widget.rightIsland != null,
            onReopen: _toggleCollapse,
            onToggleRight: _toggleRight,
          ),
        ),
      ],
    );
  }
}

/// The ocean's floating header: a white→transparent scrim with a shared [AnChromeBar] on top.
/// When the left island is collapsed it grows the window-controls leading zone + a reopen
/// button, so the ocean's top-left clears AND lines up with the real traffic lights (same
/// chrome-bar geometry as the sidebar's top); the compact page title fades in with scroll.
///
/// 海洋浮动头:白→透明渐隐 + 共用 [AnChromeBar]。左岛收起时长出窗控前导 + reopen 钮,让海洋左上
/// 既避开又对齐红绿灯(与侧栏顶栏同一顶栏条几何);紧凑标题随滚动淡入。
class _OceanHeader extends StatelessWidget {
  const _OceanHeader({
    required this.collapsed,
    required this.compact,
    required this.title,
    required this.actions,
    required this.hasRightIsland,
    required this.onReopen,
    required this.onToggleRight,
  });

  final bool collapsed;
  final double compact;
  final String? title;
  final List<Widget> actions;
  final bool hasRightIsland;
  final VoidCallback onReopen;
  final VoidCallback onToggleRight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
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
          // Top/left inset land the chrome bar on the SAME lines as the sidebar's (replicating
          // the island's border+pad offset; see AnSize docs). Collapsed → the leading edge
          // starts at the lights' left (= window pad + inset), so the reserved window-controls
          // zone clears the lights with the SAME breathing room the sidebar's top bar has.
          // 顶/左距让顶栏条与侧栏同线(复刻岛 边框+内距);收起时前导边对齐红绿灯左缘,窗控区给灯留出与侧栏一致的余量。
          Padding(
            padding: EdgeInsets.only(
              top: AnSize.oceanHeaderInset,
              left: collapsed ? AnSize.oceanHeaderInset : AnSpace.s12,
              right: AnSpace.s12,
            ),
            child: AnChromeBar(
              leading: collapsed,
              children: [
                if (collapsed)
                  AnIconButton(AnIcons.collapseLeft,
                      size: AnSize.controlSm, onPressed: onReopen),
                if (title != null)
                  Expanded(
                    child: Opacity(
                      opacity: compact,
                      child: Text(title!,
                          overflow: TextOverflow.ellipsis,
                          style: AnText.body
                              .copyWith(color: c.ink, fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  const Spacer(),
                for (final a in actions) ...[a, const SizedBox(width: AnSpace.s4)],
                if (hasRightIsland)
                  AnIconButton(AnIcons.collapseRight,
                      size: AnSize.controlSm, onPressed: onToggleRight),
              ],
            ),
          ),
        ],
      ),
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
