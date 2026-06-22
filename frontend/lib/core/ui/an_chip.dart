import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A selectable filter chip. Selected = ink fill / white text; unselected = bordered
/// surface with a gray hover. Monochrome (selection by fill, not hue).
/// 可选过滤 chip。选中=墨底白字;未选=描边表面+灰悬停。单色(靠填充非色相表达选中)。
class AnChip extends StatefulWidget {
  const AnChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  State<AnChip> createState() => _AnChipState();
}

class _AnChipState extends State<AnChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = widget.selected;
    final bg = selected ? c.accent : (_hover ? c.surfaceHover : c.surface);
    final fg = selected ? c.onAccent : c.ink;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: AnSize.control,
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AnRadius.pill),
            border: selected ? null : Border.all(color: c.line, width: AnSize.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: AnSize.iconSm, color: fg),
                const SizedBox(width: AnSpace.s4),
              ],
              Text(widget.label, style: AnText.label.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
