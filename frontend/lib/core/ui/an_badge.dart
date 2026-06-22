import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A small inline label/tag. [variant] = fill style (solid / soft / outline); [tone] =
/// semantic color, matching the status TONE map (neutral & accent are achromatic ink,
/// ok/warn/danger carry the functional color). Most chrome tags are neutral; status tags
/// (Active/Waiting/Failed) take ok/warn/danger.
/// 小内联标签。variant=填充式;tone=语义色,对齐状态 TONE(neutral/accent 为墨,ok/warn/danger 带功能色)。
enum AnBadgeVariant { solid, soft, outline }

enum AnBadgeTone { neutral, accent, ok, warn, danger }

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
    // (strong, soft, mutedText) per tone. neutral stays gray; accent is ink emphasis.
    final (Color strong, Color soft) = switch (tone) {
      AnBadgeTone.neutral => (c.inkMuted, c.surfaceActive),
      AnBadgeTone.accent => (c.accent, c.accentSoft),
      AnBadgeTone.ok => (c.ok, c.okSoft),
      AnBadgeTone.warn => (c.warn, c.warnSoft),
      AnBadgeTone.danger => (c.danger, c.dangerSoft),
    };

    final (Color bg, Color fg, Border? border) = switch (variant) {
      AnBadgeVariant.solid => (strong, c.onAccent, null),
      AnBadgeVariant.soft => (soft, tone == AnBadgeTone.neutral ? c.inkMuted : strong, null),
      AnBadgeVariant.outline => (
          Colors.transparent,
          strong,
          Border.all(
            color: tone == AnBadgeTone.neutral ? c.line : strong,
            width: AnSize.hairline,
          ),
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
