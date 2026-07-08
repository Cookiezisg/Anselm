import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The quota/usage meter (WRK-062 S2) — a quiet horizontal bar with an optional value line. Tone
/// escalates by fill: accent under [warnAt], warn past it, danger past [dangerAt] (defaults 0.85 /
/// 0.97 — the free-tier card's grammar). Indeterminate (null ratio) renders a hollow track (an
/// unknown must not fake a fill). Reduced motion = no fill animation.
///
/// 用量/配额条——安静横条+可选值行。填充率越档变声:warnAt(默认 0.85)前 accent、后 warn,dangerAt
/// (0.97)后 danger。ratio=null 渲空轨(未知绝不假装有值)。reduced 无填充动画。
class AnMeter extends StatelessWidget {
  const AnMeter({
    required this.ratio,
    this.label,
    this.warnAt = 0.85,
    this.dangerAt = 0.97,
    this.semanticLabel,
    super.key,
  });

  /// 0..1 fill, or null = unknown/indeterminate. 填充率;null=未知。
  final double? ratio;

  /// The quiet value line under the bar (e.g. «1 234 / 5 000 · resets 8/1»). 条下值行。
  final String? label;

  final double warnAt;
  final double dangerAt;
  final String? semanticLabel;

  static const double _height = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = ratio?.clamp(0.0, 1.0);
    final fill = r == null
        ? c.line
        : r >= dangerAt
            ? c.danger
            : r >= warnAt
                ? c.warn
                : c.accent;
    return Semantics(
      label: semanticLabel,
      value: r == null ? null : '${(r * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_height / 2),
            child: Container(
              height: _height,
              decoration: BoxDecoration(color: c.surfaceSunken),
              child: r == null
                  ? null
                  : FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: r == 0 ? 0.005 : r, // a sliver of presence at 0 也留一丝存在感
                      child: AnimatedContainer(
                        duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid,
                        color: fill,
                      ),
                    ),
            ),
          ),
          if (label != null && label!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4),
              child: Text(label!, style: AnText.meta.copyWith(color: c.inkMuted)),
            ),
        ],
      ),
    );
  }
}
