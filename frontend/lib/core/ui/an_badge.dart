import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_status_dot.dart';
import 'tone.dart';

/// A2 — a status / tag pill: soft-tinted plate + semantic text, optional leading status dot. Tone
/// carries meaning (neutral / ok / warn / danger / accent); colour comes from [AnToneColors]. The
/// label truncates (capped at [AnSize.block]) so an overlong tag never blows out the layout.
///
/// A2——状态/标签药丸:柔底 + 语义字,可选前置状态点。tone 携含义(neutral/ok/warn/danger/accent),
/// 色走 AnToneColors。label 截断(上限 block),超长标签不撑破布局。
class AnBadge extends StatelessWidget {
  const AnBadge(this.label, {this.tone = AnTone.none, this.dot, super.key});

  final String label;
  final AnTone tone;

  /// Optional leading status dot. 可选前置状态点。
  final AnStatus? dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.block),
      child: Container(
        height: AnSize.badge,
        padding: const EdgeInsets.symmetric(horizontal: AnSize.badgePadX),
        decoration: BoxDecoration(color: tone.softBg(c), borderRadius: BorderRadius.circular(AnRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              AnStatusDot(dot!),
              const SizedBox(width: AnSpace.s6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.meta.copyWith(color: tone.fg(c)).weight(AnText.emphasisWeight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
