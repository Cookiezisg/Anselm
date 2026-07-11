import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The engaged-state ring for OPAQUE actionable surfaces (WRK-066 批1 复审) — cards whose face is a
/// solid fill (AnWindow peers, future opaque tiles) can't show the classic behind-tint, so hover /
/// keyboard-focus draw an [AnSize.ring] accent ring AROUND the child instead (WCAG 2.4.7: keyboard
/// focus must be visible). Painted as a foregroundDecoration: zero layout shift, rides the child's
/// own radius. Pair with [AnInteractive]: `builder: (ctx, s) => AnFocusRing(active: s.isActive, …)`.
///
/// 不透明可点面的激活环(批1 复审)——实底面(AnWindow 同席卡等)透不出经典背后着色,hover/键盘焦点改在
/// 子件外画 accent 环(WCAG 2.4.7 焦点必须可见)。foregroundDecoration 绘制:零布局位移,随子件圆角。
/// 与 AnInteractive 配对:builder 里 `AnFocusRing(active: states.isActive, child: …)`。
class AnFocusRing extends StatelessWidget {
  const AnFocusRing({required this.active, required this.child, this.radius = AnRadius.card, super.key});

  final bool active;
  final Widget child;

  /// Must match the child's own corner radius (the ring hugs the card). 须与子件圆角一致(环贴卡)。
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      foregroundDecoration: active
          ? BoxDecoration(
              border: Border.all(color: c.accent, width: AnSize.ring),
              borderRadius: BorderRadius.circular(radius),
            )
          : null,
      child: child,
    );
  }
}
