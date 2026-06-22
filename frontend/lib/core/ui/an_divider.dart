import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A hairline divider — horizontal (optionally with a centered label) or vertical.
/// Vertical needs a bounded height from its parent (e.g. inside a fixed-height Row).
/// 细线分割——水平(可带居中标签)或垂直。垂直需父级给定高度(如固定高 Row 内)。
class AnDivider extends StatelessWidget {
  const AnDivider({super.key, this.vertical = false, this.label});

  final bool vertical;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (vertical) return Container(width: AnSize.hairline, color: c.line);
    if (label == null) return Container(height: AnSize.hairline, color: c.line);
    return Row(
      children: [
        Expanded(child: Container(height: AnSize.hairline, color: c.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
          child: Text(label!, style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
        Expanded(child: Container(height: AnSize.hairline, color: c.line)),
      ],
    );
  }
}
