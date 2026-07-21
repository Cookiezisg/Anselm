import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'an_a11y.dart';
import 'an_hover_region.dart';

/// The kit's canonical "visually engaged" predicate — hovered, pressed, OR (keyboard-)focused — so
/// every control derives its hover/active surface the SAME way (no per-widget hovered||pressed vs
/// hovered||focused drift). 套件统一的「视觉激活」判定:hover/press/(键盘)focus 任一,各控件一致取用。
extension AnWidgetStates on Set<WidgetState> {
  bool get isActive =>
      contains(WidgetState.hovered) ||
      contains(WidgetState.pressed) ||
      contains(WidgetState.focused);
}

/// The interaction substrate every actionable surface composes — buttons, rows, chips, tabs all
/// build on this one place so hover / focus / pressed / disabled behave identically everywhere.
/// Built on the framework's [FocusableActionDetector] (principle #8 — standard API over hand-rolled
/// MouseRegion/Focus/key handling): FAD drives hover + focus via the platform highlight mode (so the
/// focus ring shows on KEYBOARD focus, not on a mouse click) and nulls them when disabled; Enter/
/// Space activate through the standard [ActivateIntent]; we keep only the pressed tracking (a
/// GestureDetector) and the [builder]'s live [WidgetState] set. Disabled = non-focusable, inert.
///
/// 可交互基座——按钮/行/chip/tab 都搭在这一处,hover/focus/pressed/disabled 全局一致。搭在框架的
/// FocusableActionDetector 上(原则 #8:用标准 API 而非手搓):FAD 按平台高亮模式驱动 hover/focus(焦点环只在
/// 键盘聚焦时显、点击不显)并在禁用时清零;Enter/Space 走标准 ActivateIntent;我们只留 pressed 跟踪 + 态集。
class AnInteractive extends StatefulWidget {
  const AnInteractive({
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.selected,
    this.expanded,
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

  /// Caller-driven selected state (surfaced as [WidgetState.selected] + [SemanticsProperties.selected]).
  ///
  /// **null (the default) = "selection is not a concept here"** — a button, a chip, a menu trigger. It is
  /// NOT a synonym for `false`, and the difference is not cosmetic: any non-null value makes the node
  /// carry `hasSelectedState`, whose framework contract reads "the widget can be selected by the user"
  /// (dart:ui). A plain button claiming it is a lie, and a stock [TextButton] does not (dump-verified:
  /// stock = `isButton, hasEnabledState, isEnabled, isFocusable`; ours used to add `hasSelectedState`).
  ///
  /// So: pass a bool ONLY from surfaces that genuinely have a selected/unselected duality (rail rows,
  /// tabs, segments, cards in a picker). Everything else must leave it null. See design-system §2.
  ///
  /// 调用方驱动的选中态。**null(缺省)=「此处没有『选中』这个概念」**——按钮/chip/菜单触发器。它**不是** false 的
  /// 同义词:任何非空值都会让节点带上 `hasSelectedState`,而该旗标的框架契约是「此件可被用户选中」(dart:ui)。
  /// 普通按钮这么说就是撒谎,原装 TextButton 也不这么说(dump 实证)。故只有真有选中/未选中二元的面才传 bool。
  final bool? selected;

  /// Disclosure state for collapsible surfaces (AnRow collapsible, AnRowDetail) — surfaced as
  /// [SemanticsProperties.expanded] so a screen reader announces expanded/collapsed. null = not a
  /// disclosure control (most surfaces). 披露态(可折叠行/详情行)→ Semantics expanded;null=非披露控件。
  final bool? expanded;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Cursor override; defaults to a click cursor when activatable. 光标覆盖;可激活时默认 click。
  final MouseCursor? cursor;

  @override
  State<AnInteractive> createState() => _AnInteractiveState();
}

class _AnInteractiveState extends State<AnInteractive>
    with ScrollSilencedHoverMixin<AnInteractive> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  // Hover DEFERRED while an ancestor scroller is in motion (0718 滚动闪烁审定,见 [AnHoverRegion]):
  // applying a hover swap mid-scroll relayouts under the moving cursor and feeds the in-flight
  // trackpad drag a reverse delta → overscroll self-oscillation (探针实证:披露箭头/换件行 flicker)。
  // Flushed to [_hovered] once the scroller settles. press/tap/focus 不冻,只冻 hover;滚停一次应用。
  bool? _pendingHover;

  bool get _canActivate => widget.enabled && widget.onTap != null;

  Set<WidgetState> get _states => {
    if (!widget.enabled) WidgetState.disabled,
    if (widget.selected ?? false) WidgetState.selected,
    if (widget.enabled && _hovered) WidgetState.hovered,
    if (widget.enabled && _focused) WidgetState.focused,
    if (widget.enabled && _pressed) WidgetState.pressed,
  };

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  // FAD's hover highlight, gated on the ancestor scroll state (see [AnHoverRegion]): in motion →
  // stash the latest value, no rebuild; settled → apply at once. 滚动中缓存 hover 不重建,滚停直通。
  void _onHover(bool h) {
    if (hoverScrollActive) {
      _pendingHover = h;
      return;
    }
    _set(() => _hovered = h);
  }

  @override
  void onHoverScrollSettled() {
    final h = _pendingHover;
    if (h == null) return;
    _pendingHover = null;
    _set(() => _hovered = h);
  }

  @override
  void didUpdateWidget(AnInteractive old) {
    super.didUpdateWidget(old);
    // FAD stops tracking when disabled but won't fire a hover/focus-off if the pointer leaves while
    // disabled — so a control disabled mid-hover would re-enable stuck "hovered". Clear on disable.
    // FAD 禁用时停止跟踪,但禁用期间指针移开不会回调 → 重新启用会卡在 hover。禁用时清零(含缓存态)。
    if (old.enabled && !widget.enabled && (_hovered || _focused || _pressed)) {
      _hovered = false;
      _focused = false;
      _pressed = false;
      _pendingHover = null;
    }
  }

  void _activate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) {
    final canActivate = _canActivate;

    // Pressed is the one state FAD doesn't track — keep a GestureDetector for it + the tap. pressed 自管。
    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canActivate ? widget.onTap : null,
      onTapDown: canActivate ? (_) => _set(() => _pressed = true) : null,
      onTapUp: canActivate ? (_) => _set(() => _pressed = false) : null,
      onTapCancel: canActivate ? () => _set(() => _pressed = false) : null,
      child: widget.builder(context, _states),
    );

    return FocusableActionDetector(
      enabled: canActivate,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: canActivate
          ? (widget.cursor ?? SystemMouseCursors.click)
          : (widget.cursor ?? MouseCursor.defer),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      onShowHoverHighlight: _onHover,
      onShowFocusHighlight: (f) => _set(() => _focused = f),
      child: Semantics(
        button: widget.onTap != null,
        enabled: widget.enabled,
        // Never `false` — see [AnA11y.selected] (a pinned-engine defect turns an explicit false into
        // "selected"). null-when-unselected is also what a caller with no selection concept sends.
        // 绝不发 false——见 AnA11y.selected(钉住的引擎会把显式 false 念成「已选中」)。
        selected: AnA11y.selected(widget.selected),
        expanded: widget.expanded,
        child: result,
      ),
    );
  }
}
