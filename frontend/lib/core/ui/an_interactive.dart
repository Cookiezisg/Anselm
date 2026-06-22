import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The interaction substrate every actionable surface composes — buttons, rows, chips, tabs all
/// build on this one place so hover / focus / pressed / disabled behave identically everywhere
/// (the demo had this scattered; the rebuild's `_Grip` hand-rolled a MouseRegion — this replaces
/// that pattern). The [builder] receives the live [WidgetState] set; the caller paints per state
/// from tokens. Pointer AND keyboard activate ([onTap] fires on tap and on Enter/Space when
/// focused). When disabled the surface is non-focusable and swallows neither pointer nor key — a
/// disabled control truly can't be activated (the demo matrix's disabled-passthrough gate).
///
/// 可交互基座——按钮/行/chip/tab 都搭在这一处,hover/focus/pressed/disabled 全局一致(取代 _Grip 里
/// 手搓的 MouseRegion)。builder 收到实时 WidgetState 集,调用方据态用 token 上色。指针与键盘都能激活
/// (onTap 在点击 + 聚焦时 Enter/Space 触发)。禁用时不可聚焦、指针/按键都不激活(对齐 demo 的 disabled 门)。
class AnInteractive extends StatefulWidget {
  const AnInteractive({
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
    this.cursor,
    super.key,
  });

  /// Paints the surface for the current interaction state. 据交互态绘制表面。
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;

  /// Activation callback. When null the surface is inert (no click cursor, not focusable).
  /// 激活回调;为 null 则惰性(无点击光标、不可聚焦)。
  final VoidCallback? onTap;
  final bool enabled;

  /// Caller-driven selected state (surfaced as [WidgetState.selected]). 调用方驱动的选中态。
  final bool selected;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Cursor override; defaults to a click cursor when activatable. 光标覆盖;可激活时默认 click。
  final MouseCursor? cursor;

  @override
  State<AnInteractive> createState() => _AnInteractiveState();
}

class _AnInteractiveState extends State<AnInteractive> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _canActivate => widget.enabled && widget.onTap != null;

  Set<WidgetState> get _states => {
        if (!widget.enabled) WidgetState.disabled,
        if (widget.selected) WidgetState.selected,
        if (widget.enabled && _hovered) WidgetState.hovered,
        if (widget.enabled && _focused) WidgetState.focused,
        if (widget.enabled && _pressed) WidgetState.pressed,
      };

  void _press(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  void _hover(bool v) {
    if (_hovered != v) setState(() => _hovered = v);
  }

  @override
  void didUpdateWidget(AnInteractive old) {
    super.didUpdateWidget(old);
    // Disabling clears stale interaction state — when disabled the MouseRegion onExit is null, so a
    // mouse-away can't clear _hovered; without this it'd stick "hovered" after re-enable.
    // 禁用时清残留交互态:禁用时 onExit 为 null,鼠标移开清不掉 hover,不清则重新启用后卡在 hover。
    if (old.enabled && !widget.enabled && (_hovered || _focused || _pressed)) {
      setState(() {
        _hovered = false;
        _focused = false;
        _pressed = false;
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onTap!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final canActivate = _canActivate;
    Widget result = widget.builder(context, _states);

    result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canActivate ? widget.onTap : null,
      onTapDown: canActivate ? (_) => _press(true) : null,
      onTapUp: canActivate ? (_) => _press(false) : null,
      onTapCancel: canActivate ? () => _press(false) : null,
      child: result,
    );

    result = MouseRegion(
      cursor: canActivate ? (widget.cursor ?? SystemMouseCursors.click) : (widget.cursor ?? MouseCursor.defer),
      onEnter: widget.enabled ? (_) => _hover(true) : null,
      onExit: widget.enabled ? (_) => _hover(false) : null,
      child: result,
    );

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: canActivate,
      skipTraversal: !canActivate,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: canActivate ? _onKey : null,
      child: result,
    );
  }
}
