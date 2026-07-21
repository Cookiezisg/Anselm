import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A relative HEAT bar — a short accent-soft rounded fill whose width tracks [fraction] (0..1) of the
/// [AnSize.heatBar] tier, floored so a tiny non-zero count still reads. Deliberately NOT an [AnMeter]
/// (that's a full-width quota row; this is an inline «how hot vs the peers» tick beside a count).
/// 相对热力短条:accentSoft 圆角填充,宽随 fraction 占 heatBar 档(下限保底,微量也可见);刻意非 AnMeter
/// (那是整行配额,此为计数旁的「相对热度」内联 tick)。
class AnHeatBar extends StatelessWidget {
  const AnHeatBar({required this.fraction, super.key});

  /// The share of the peak (0..1); clamped to a visible floor. 占峰值比(0..1,保底可见)。
  final double fraction;

  @override
  Widget build(BuildContext context) => Container(
    width: AnSize.heatBar * fraction.clamp(0.15, 1.0),
    height: AnSpace.s4,
    decoration: BoxDecoration(
      color: context.colors.accentSoft,
      borderRadius: BorderRadius.circular(AnRadius.tag),
    ),
  );
}
