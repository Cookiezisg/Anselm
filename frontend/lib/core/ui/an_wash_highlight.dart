import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A one-shot landing WASH over [child] — an accent-soft fill that holds (~the flat first half), then
/// eases out to nothing (the Slack-permalink «you landed here» rhythm). Purely decorative: reduced motion
/// collapses it to the end state instantly. Used for a jump/scroll target's arrival highlight. The fading
/// fill is the ONE place this alpha ramp lives (a keyframe, not an [AnOpacity] tier).
/// 一次性落点洗亮:accentSoft 填充先驻留后淡出(「你到这了」节奏);纯装饰,reduced 直接落终态。渐隐填充=洗亮
/// 唯一处(是关键帧、非 AnOpacity 档)。
class AnWashHighlight extends StatelessWidget {
  const AnWashHighlight({
    required this.child,
    this.radius = AnRadius.card,
    super.key,
  });

  final Widget child;

  /// The wash's corner radius — matches the surface it lands on (default the card/machine-window tier).
  /// 洗亮圆角(默认 card 档,配落点面)。
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Wash = a functional one-shot reveal → the plain `reduced` gate is the right tier. 洗亮=功能揭示。
    final reduced = AnMotionPref.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: reduced ? Duration.zero : AnMotion.wash,
      // Hold for the flat first ~45%, then ease out. 前半驻留,后半淡出。
      curve: const Interval(0.45, 1, curve: AnMotion.easeOut),
      builder: (context, wash, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: c.accentSoft.withValues(alpha: c.accentSoft.a * wash),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
      child: child,
    );
  }
}
