import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// The notice island's own close language: a standard 28×28 interaction target without a visible
/// button tile. Pointer hover only deepens the glyph; press gives it one quiet scale beat; keyboard
/// focus alone receives a circular hairline halo. The low-mass X can therefore balance the tone dot
/// at the opposite coast instead of reading as a second surface nested inside a 36px island.
///
/// 通知岛专属关闭语法:命中仍是标准 28×28,但不画方钮底。鼠标只把 X 变深,按下轻缩,仅键盘焦点
/// 显圆形发丝环。这样右端是与左侧 tone 点呼应的轻锚,不会在 36px 小岛里再嵌一块按钮面。
class AnNoticeCloseAffordance extends StatelessWidget {
  const AnNoticeCloseAffordance({
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: AnInteractive(
          onTap: onPressed,
          builder: (context, states) => AnNoticeCloseFace(
            active: states.isActive,
            focused: states.contains(WidgetState.focused),
            pressed: states.contains(WidgetState.pressed),
          ),
        ),
      ),
    );
  }
}

/// The non-interactive visual face, shared by the persistent card X and the transient `+N → X` face.
/// Interaction/semantics remain with the caller when the face lives inside a larger fixed count slot.
/// 非交互视觉面;卡内常驻 X 与 `+N → X` 瞬态面共用。住在计数槽时,交互/语义仍由外层持有。
class AnNoticeCloseFace extends StatelessWidget {
  const AnNoticeCloseFace({
    this.active = false,
    this.focused = false,
    this.pressed = false,
    super.key,
  });

  final bool active;
  final bool focused;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    final duration = reduced ? Duration.zero : AnMotion.fast;
    return AnimatedScale(
      scale: pressed ? 0.9 : 1,
      duration: duration,
      curve: AnMotion.easeOut,
      child: SizedBox.square(
        dimension: AnSize.control,
        child: Center(
          child: AnimatedContainer(
            duration: duration,
            curve: AnMotion.easeOut,
            width: AnSize.controlSm,
            height: AnSize.controlSm,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: focused ? c.inkMuted : c.inkMuted.withValues(alpha: 0),
                width: AnSize.hairline,
              ),
            ),
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: AnMotion.easeOut,
              switchOutCurve: AnMotion.easeOut,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: <Widget>[...previous, ?current],
              ),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Icon(
                AnIcons.close,
                key: ValueKey<bool>(active),
                size: AnSize.icon,
                color: active ? c.ink : c.inkFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
