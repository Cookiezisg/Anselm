import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// A bounded editorial spread: the decision column is invariant, the artwork is the only elastic
/// member, and surplus width returns as outer whitespace once the artwork reaches its ceiling.
///
/// 有界画册跨页：决策列恒定，只有作品弹性；作品封顶后，余宽回到整体两侧留白。
class AnEditorialSpread extends StatelessWidget {
  const AnEditorialSpread({
    required this.artwork,
    required this.brand,
    required this.decision,
    super.key,
  });

  final Widget artwork;
  final Widget brand;
  final Widget decision;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final usableWidth = math.max(
        AnSpace.s0,
        constraints.maxWidth - AnSpace.s48 * 2,
      );
      final gap =
          (usableWidth - AnSize.onboardingForm - AnSize.onboardingArtworkMax)
              .clamp(AnSize.onboardingGapMin, AnSize.onboardingGapMax);
      final artworkWidth = math.max(
        AnSpace.s0,
        math.min(
          AnSize.onboardingArtworkMax,
          usableWidth - AnSize.onboardingForm - gap,
        ),
      );
      final spreadWidth = artworkWidth + gap + AnSize.onboardingForm;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AnSpace.s48),
        child: Center(
          child: SizedBox(
            width: spreadWidth,
            child: Stack(
              children: [
                Align(alignment: Alignment.topRight, child: brand),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: artworkWidth,
                      child: Center(child: artwork),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: AnSize.onboardingForm,
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          decision,
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
