import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// One ENTRY-ONLY fade + rise (WRK-066 批7, B-056 — the chat landing's greeting entrance, promoted
/// from a feature-private copy). Runs exactly once on mount (mid, easeOut, [rise] px up); renders
/// static under reduced motion. Distinct from the hit-list cascade (one controller staggering N
/// rows) — this is a single-child entrance.
///
/// 仅入场一次的淡入上移(批7 B-056,自 chat landing 私件升格)。挂载即播一次(mid/easeOut/上移
/// [rise]px);reduced 直接静态。与命中列级联(单控制器错峰 N 行)角色不同。
class AnFadeRiseIn extends StatelessWidget {
  const AnFadeRiseIn({required this.child, this.rise = AnSpace.s6, super.key});

  final Widget child;

  /// Entrance rise distance. 入场上移距离。
  final double rise;

  @override
  Widget build(BuildContext context) {
    if (AnMotionPref.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AnMotion.mid,
      curve: AnMotion.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * rise),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
