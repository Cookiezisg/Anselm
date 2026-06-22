import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A keyboard key cap (for shortcut hints, e.g. ⌘K). Mono glyph in a small bordered cap.
/// 键帽(快捷键提示,如 ⌘K)。小边框内的等宽字。
class AnKbd extends StatelessWidget {
  const AnKbd(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.tag),
      ),
      child: Text(label, style: AnText.mono.copyWith(fontSize: 11, color: c.inkMuted)),
    );
  }
}
