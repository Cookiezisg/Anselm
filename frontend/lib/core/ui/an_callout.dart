import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// An inline note box. tone drives the soft tint + icon: neutral (gray), ok (green),
/// warn (orange), danger (red). Optional title above the message.
/// 内联提示框。tone 决定柔底色 + 图标:neutral 灰 / ok 绿 / warn 橙 / danger 红。可选标题。
enum AnCalloutTone { neutral, ok, warn, danger }

class AnCallout extends StatelessWidget {
  const AnCallout(this.message, {super.key, this.tone = AnCalloutTone.neutral, this.title, this.icon});

  final String message;
  final AnCalloutTone tone;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color tint, Color soft, IconData glyph) = switch (tone) {
      AnCalloutTone.neutral => (c.inkMuted, c.surfaceActive, AnIcons.info),
      AnCalloutTone.ok => (c.ok, c.okSoft, AnIcons.success),
      AnCalloutTone.warn => (c.warn, c.warnSoft, AnIcons.error),
      AnCalloutTone.danger => (c.danger, c.dangerSoft, AnIcons.error),
    };
    return Container(
      padding: const EdgeInsets.all(AnSpace.s12),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AnRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? glyph, size: AnSize.icon, color: tint),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(title!, style: AnText.label.copyWith(color: c.ink)),
                  const SizedBox(height: AnSpace.s2),
                ],
                Text(message, style: AnText.body.copyWith(color: c.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
