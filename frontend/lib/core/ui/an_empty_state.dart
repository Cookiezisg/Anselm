import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// The centered empty/zero placeholder: a faint glyph, a title, an optional hint, and an
/// optional call-to-action. The first-run / "no results" surface.
/// 居中空态占位:弱化图标 + 标题 + 可选提示 + 可选行动。首启 / 无结果 的面。
class AnEmptyState extends StatelessWidget {
  const AnEmptyState({super.key, required this.title, this.icon, this.hint, this.action});

  final String title;
  final IconData? icon;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AnSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? AnIcons.empty, size: 32, color: c.inkFaint),
            const SizedBox(height: AnSpace.s12),
            Text(title, style: AnText.strong.copyWith(color: c.inkMuted)),
            if (hint != null) ...[
              const SizedBox(height: AnSpace.s4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AnSpace.s16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
