import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// The anchored-overlay base — a floating layer pinned to a trigger, built on Flutter's mature
/// [OverlayPortal] + [CompositedTransformFollower] (NOT hand-rolled positioning math; see
/// principle #8). Opens/closes via [AnPopoverController]; dismisses on outside tap or Escape. The
/// dropdown sits on this now; the menu/dialog/toast layer (G6) reuses it. The overlay builder
/// receives the anchor's size so a menu can match the trigger width.
///
/// 锚定浮层基座——钉在触发器上的浮层,搭在 Flutter 成熟的 OverlayPortal + CompositedTransformFollower 上
/// (非手搓定位,见原则 #8)。经 controller 开关;点外/Esc 关闭。下拉现搭于此,菜单/对话/toast(G6)复用。
class AnPopoverController extends ChangeNotifier {
  bool _open = false;
  bool get isOpen => _open;

  void open() => _set(true);
  void close() => _set(false);
  void toggle() => _set(!_open);

  void _set(bool v) {
    if (_open == v) return;
    _open = v;
    notifyListeners();
  }
}

class AnPopover extends StatefulWidget {
  const AnPopover({
    required this.controller,
    required this.anchor,
    required this.overlayBuilder,
    this.targetAnchor = Alignment.bottomLeft,
    this.followerAnchor = Alignment.topLeft,
    this.offset = const Offset(0, AnSpace.s4),
    super.key,
  });

  final AnPopoverController controller;

  /// The trigger; gets a [CompositedTransformTarget]. 触发器。
  final Widget anchor;

  /// Builds the floating content; receives the anchor size (for width matching). 浮层内容(收锚尺寸)。
  final Widget Function(BuildContext context, Size? anchorSize) overlayBuilder;

  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Offset offset;

  @override
  State<AnPopover> createState() => _AnPopoverState();
}

class _AnPopoverState extends State<AnPopover> with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  // Who held focus when the overlay opened — handed back on close. The overlay's FocusScope seizes
  // focus, and a bare scope (unlike a Navigator route) won't auto-restore it, so a keyboard / screen-
  // reader user would be dropped to the document root on pick / Esc / outside-tap (WCAG 2.4.3).
  // 开前焦点持有者,关时归还:浮层 FocusScope 夺焦、裸 scope 不像路由自动恢复,否则键盘/屏读落到 root。
  FocusNode? _restoreFocus;

  // Open/close transition — fade + a small scale-from-top (the standard dropdown reveal). Created
  // EAGERLY in initState (NOT a lazy `late final =`): an unopened popover would otherwise first
  // touch _anim in dispose() → build a controller mid-teardown → crash.
  // 开关过渡:淡入 + 自顶部微缩放。必须在 initState 急切创建(非懒 late final),否则没开过的浮层会在 dispose 才首次访问→崩。
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: AnMotion.fast);
    _scale = Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: _anim, curve: AnMotion.easeOut));
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(AnPopover old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync(); // new controller may have a different open-state with no pending notification 新 controller 状态可能不同、无待发通知
    }
  }

  void _sync() {
    if (widget.controller.isOpen) {
      if (!_portal.isShowing) {
        _restoreFocus = FocusManager.instance.primaryFocus; // remember the trigger before the scope seizes focus 记开前焦点
        _portal.show();
      }
      _anim.forward();
    } else if (_portal.isShowing) {
      // Animate out, then remove the overlay (unless reopened mid-reverse) and hand focus back to the
      // trigger (if it's still mounted) so traversal / SR position survives the close. 反向播完撤浮层 + 归还焦点。
      _anim.reverse().whenComplete(() {
        if (!widget.controller.isOpen && _portal.isShowing) {
          _portal.hide();
          final restore = _restoreFocus;
          _restoreFocus = null;
          if (restore != null && restore.context != null) restore.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        return Stack(
          children: [
            // Outside-tap barrier (transparent, full-screen). 点外关闭遮罩。
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.controller.close,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: widget.targetAnchor,
              followerAnchor: widget.followerAnchor,
              offset: widget.offset,
              child: Align(
                alignment: widget.followerAnchor,
                child: FadeTransition(
                  opacity: _anim,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.topCenter, // grow downward from the top edge 自顶向下展开
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape): widget.controller.close,
                      },
                      // FocusScope (not a plain Focus) so the overlay is a self-contained focus
                      // context: arrow keys traverse focusable content (e.g. dropdown menu rows) and
                      // Esc has a focused target. autofocus seeds it (a descendant autofocus wins).
                      // 用 FocusScope:浮层自成焦点域,方向键可在内部可聚焦内容间移动、Esc 有聚焦目标。
                      child: FocusScope(
                        autofocus: true,
                        child: widget.overlayBuilder(context, _link.leaderSize),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(link: _link, child: widget.anchor),
    );
  }
}
