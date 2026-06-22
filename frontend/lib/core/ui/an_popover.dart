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

class _AnPopoverState extends State<AnPopover> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(AnPopover old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  void _sync() {
    if (widget.controller.isOpen) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
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
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): widget.controller.close,
                  },
                  child: Focus(
                    autofocus: true,
                    child: widget.overlayBuilder(context, _link.leaderSize),
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
