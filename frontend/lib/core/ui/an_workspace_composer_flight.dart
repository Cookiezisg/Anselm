import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// Paint-only identity bridge between workspace creation and the real Chat composer. Neither
/// endpoint's EditableText/IME subtree is reparented.
///
/// workspace 创建框与真 Chat composer 之间的纯绘制身份桥；任一端的 EditableText/IME 都不跨树搬家。
class AnWorkspaceComposerFlight extends StatelessWidget {
  const AnWorkspaceComposerFlight({
    required this.progress,
    required this.sourceText,
    required this.destinationPlaceholder,
    super.key,
  });

  final double progress;
  final String sourceText;
  final String destinationPlaceholder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sourceOpacity =
        1 -
        _interval(progress, const Interval(0, 0.24, curve: AnMotion.easeOut));
    final destinationOpacity = _interval(
      progress,
      const Interval(0.58, 0.86, curve: AnMotion.easeOut),
    );
    final shadowOpacity = lerpDouble(1, 0.72, progress)!;

    Widget glyph(IconData icon, {Color? fill, Color? ink}) => SizedBox(
      width: AnSize.control,
      height: AnSize.control,
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Icon(icon, size: AnSize.icon, color: ink ?? c.inkMuted),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AnRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: c.accentSoft,
                  spreadRadius: AnSpace.s2,
                  blurRadius: AnSpace.s4,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AnRadius.pill),
              border: Border.all(color: c.line, width: AnSize.hairline),
              boxShadow: c.shadowFloat
                  .map(
                    (shadow) => shadow.copyWith(
                      color: shadow.color.withValues(
                        alpha: shadow.color.a * shadowOpacity,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AnSpace.s12,
                vertical: AnSpace.s8,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: sourceOpacity,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sourceText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AnText.reading.copyWith(color: c.ink),
                          ),
                        ),
                        const SizedBox(width: AnSpace.s8),
                        glyph(AnIcons.send, fill: c.accent, ink: c.onAccent),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: destinationOpacity,
                    child: Row(
                      children: [
                        glyph(AnIcons.mention),
                        const SizedBox(width: AnSpace.s4),
                        glyph(AnIcons.attach),
                        const SizedBox(width: AnSpace.s4),
                        Expanded(
                          child: Text(
                            destinationPlaceholder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AnText.reading.copyWith(color: c.inkFaint),
                          ),
                        ),
                        const SizedBox(width: AnSpace.s8),
                        glyph(AnIcons.microphone),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AnRadius.pill),
              border: Border.all(color: c.accentLine, width: AnSize.hairline),
            ),
          ),
        ),
      ],
    );
  }
}

double _interval(double value, Interval interval) =>
    interval.transform(value.clamp(0, 1));
