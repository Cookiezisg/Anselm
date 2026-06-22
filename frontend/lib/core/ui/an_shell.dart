import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_island.dart';
import 'an_window_controls.dart';

/// The three-island desktop shell skeleton: a left island ([sidebar]), the open ocean
/// ([ocean]) — the window's white surface, no card — and a right island ([inspector]). 8px
/// padding around + 8px gaps between. The LEFT island is drag-resizable (240–400, default 320);
/// the RIGHT island is FIXED (320). The ocean is the flex remainder; its content column is
/// elastic 480–720, and the window minimum guarantees the ocean never drops below 480 even with
/// the left island at its max. The left island carries the chrome bar (the macOS traffic lights
/// are centered by the OS in the taller title bar — see window_setup).
///
/// 三岛桌面 shell 骨架:左岛([sidebar],可拖 240–400 默认 320)· 敞开海洋([ocean],窗体白面无卡,
/// 内容列弹性 480–720)· 右岛([inspector],固定 320)。四周 8px + 岛间 8px。窗口最小尺寸保证即便左岛
/// 拖到最大、海洋仍 ≥ 480。左岛顶含 chrome 条(红绿灯由 OS 在加高标题栏居中,见 window_setup)。
class AnShell extends StatefulWidget {
  const AnShell({super.key, this.sidebar, this.ocean, this.inspector});

  final Widget? sidebar;
  final Widget? ocean;
  final Widget? inspector;

  @override
  State<AnShell> createState() => _AnShellState();
}

class _AnShellState extends State<AnShell> {
  double _leftW = AnSize.sidebar; // default 320, drag-clamped to [sidebarMin, sidebarMax]

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The ocean reads as the window's surface; Material gives text a default style (no debug
    // underlines). 海洋即窗体白面;Material 给文本默认样式(无调试下划线)。
    return Material(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(AnSize.shellPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _leftW,
              child: AnIsland(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ChromeBar(),
                    const SizedBox(height: AnSpace.s8),
                    Expanded(child: widget.sidebar ?? const _Placeholder('Sidebar')),
                  ],
                ),
              ),
            ),
            // Left island is draggable → the grip resizes it (and serves as the 8px gap).
            // 左岛可拖 → grip 调宽(兼作 8px 间距)。
            _Grip(
              key: const ValueKey('anShellLeftGrip'),
              onDrag: (dx) => setState(
                  () => _leftW = (_leftW + dx).clamp(AnSize.sidebarMin, AnSize.sidebarMax)),
            ),
            Expanded(child: widget.ocean ?? const _Placeholder('Ocean')),
            // Right island is fixed → a plain 8px gap (no grip). 右岛固定 → 纯 8px 间距(无 grip)。
            const SizedBox(width: AnSize.shellGap),
            SizedBox(
              width: AnSize.rightIsland,
              child: AnIsland(child: widget.inspector ?? const _Placeholder('Inspector')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The left island's top control strip. Reserves the macOS traffic-light zone at the leading
/// edge (the OS draws the real lights there, centered in the taller title bar). Action buttons
/// (collapse / search) land here once the UI kit ships. 左岛顶栏:行首留红绿灯位(OS 在加高标题栏
/// 画真灯居中);收起/搜索钮待 UI 套件落地后接入。
class _ChromeBar extends StatelessWidget {
  const _ChromeBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: AnSize.row,
      child: Row(children: [AnWindowControls(), Spacer()]),
    );
  }
}

/// Skeleton placeholder — a faint centered label so each empty region is identifiable. Replaced
/// by real feature content. 骨架占位:淡色居中标签,标识空区;真内容落地后替换。
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Text(label, style: TextStyle(color: c.inkFaint, fontSize: AnSize.iconSm)),
    );
  }
}

/// The drag handle between the left island and the ocean — also serves as the 8px gap. Shows a
/// hairline on hover. 左岛与海洋间的拖拽柄,兼作 8px 间距;悬停现细线。
class _Grip extends StatefulWidget {
  const _Grip({super.key, required this.onDrag});
  final ValueChanged<double> onDrag;
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
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: SizedBox(
          width: AnSize.shellGap,
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
