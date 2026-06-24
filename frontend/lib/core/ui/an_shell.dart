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
  const AnShell({super.key, this.sidebar, this.ocean, this.inspector, this.inspectorOpen = true});

  final Widget? sidebar;
  final Widget? ocean;
  final Widget? inspector;

  /// Reveal / hide the right island (a feature opens it for a selected entity, closes it otherwise). It
  /// slides in/out (width + gap animate 0↔[AnSize.rightIsland]); the content stays full-width behind a clip
  /// so it doesn't reflow during the slide. Default true (the island is shown). 右岛揭示/收起(滑入滑出、内容不重排)。
  final bool inspectorOpen;

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
            // Right island REVEAL: the gap + island width animate 0↔320; the content is held full-width by
            // an OverflowBox behind a ClipRect so it slides (doesn't reflow) during the reveal. 右岛揭示:宽+间距动画、内容不重排。
            _RightReveal(
              open: widget.inspectorOpen,
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

/// Animated reveal / hide of the fixed-width right island: the leading gap + the island width animate
/// 0↔[AnSize.rightIsland] together, while an [OverflowBox] holds the content at full width behind a
/// [ClipRect] so it slides rather than reflowing during the reveal. reduced-motion → instant.
/// 右岛揭示:间距 + 宽一起动画 0↔320,内容经 OverflowBox 保持满宽、ClipRect 裁切,滑入而非重排;reduced→即时。
class _RightReveal extends StatelessWidget {
  const _RightReveal({required this.open, required this.child});
  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dur = AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(duration: dur, curve: AnMotion.easeOut, width: open ? AnSize.shellGap : 0),
        ClipRect(
          child: AnimatedContainer(
            duration: dur,
            curve: AnMotion.easeOut,
            width: open ? AnSize.rightIsland : 0,
            child: OverflowBox(
              minWidth: AnSize.rightIsland,
              maxWidth: AnSize.rightIsland,
              alignment: AlignmentDirectional.centerStart,
              // When closed the content stays laid out at full width (so it slides, not reflows), but the
              // ClipRect only clips paint/hit-test — so make the hidden subtree fully inert, else its
              // buttons/fields stay keyboard-focusable + screen-reader-announced behind the 0-width clip
              // (a focus trap; same fix as AnRow._HoverSwap). 收起时内容仍满宽布局,故彻底惰化隐藏子树(同 _HoverSwap)。
              child: SizedBox(
                width: AnSize.rightIsland,
                child: open
                    ? child
                    : ExcludeFocus(child: ExcludeSemantics(child: IgnorePointer(child: child))),
              ),
            ),
          ),
        ),
      ],
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
    final reduced = AnMotionPref.reduced(context);
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
              duration: reduced ? Duration.zero : AnMotion.fast, // hover hairline = functional micro-feedback 功能性微反馈
              width: AnSize.gripLine,
              decoration: BoxDecoration(
                color: c.lineStrong.whenActive(_hover), // no-flash fade 无暗闪淡入
                borderRadius: BorderRadius.circular(AnRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
