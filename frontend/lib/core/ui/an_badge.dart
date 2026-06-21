import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A small inline label/tag. Monochrome by default: solid (ink), soft (gray wash), or
/// outline. Pass [tone] = danger for the one functional red (e.g. a failed state tag).
/// 小内联标签。默认单色:solid 墨底 / soft 灰底 / outline 描边。tone=danger 用唯一红(如失败态)。
enum AnBadgeVariant { solid, soft, outline }

enum AnBadgeTone { neutral, danger }

class AnBadge extends StatelessWidget {
  const AnBadge(
    this.label, {
    super.key,
    this.variant = AnBadgeVariant.soft,
    this.tone = AnBadgeTone.neutral,
  });

  final String label;
  final AnBadgeVariant variant;
  final AnBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final danger = tone == AnBadgeTone.danger;
    final solidBg = danger ? c.danger : c.accent;
    final softBg = danger ? c.dangerSoft : c.accentSoft;
    final mark = danger ? c.danger : c.ink;

    final (Color bg, Color fg, Border? border) = switch (variant) {
      AnBadgeVariant.solid => (solidBg, c.onAccent, null),
      AnBadgeVariant.soft => (softBg, mark, null),
      AnBadgeVariant.outline => (
          Colors.transparent,
          danger ? c.danger : c.inkMuted,
          Border.all(color: danger ? c.danger : c.line, width: AnSize.hairline),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AnRadius.tag),
        border: border,
      ),
      child: Text(label, style: AnText.meta.copyWith(color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
