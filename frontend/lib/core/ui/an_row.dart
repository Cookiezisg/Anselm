import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The density workhorse: a 32px-tall list row with an optional leading icon slot, a title,
/// and an optional trailing widget. Hover (gray wash) and selected (stronger wash + bold)
/// states are explicit so list density stays crisp across the islands.
/// 密度主力:32px 行,可选行首图标槽、标题、行尾件。hover(灰底)与 selected(更强底+加粗)显式,
/// 使各岛列表密度利落。
class AnRow extends StatefulWidget {
  const AnRow({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final IconData? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<AnRow> createState() => _AnRowState();
}

class _AnRowState extends State<AnRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // "off" is surfaceHover at 0 alpha (NOT transparent-black) so the hover tween stays
    // light — the dark-flash bug came from lerping through transparent black.
    final bg = widget.selected
        ? c.accentSoft
        : (_hover ? c.surfaceHover : c.surfaceHover.withValues(alpha: 0));

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // Smooth hover (fast) — standard micro-interaction. 平滑悬停(fast),标准微交互。
        child: AnimatedContainer(
          duration: AnMotion.fast,
          height: AnSize.row,
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                Icon(
                  widget.leading,
                  size: AnSize.icon,
                  color: widget.selected ? c.ink : c.inkMuted,
                ),
                const SizedBox(width: AnSpace.s8),
              ],
              Expanded(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.body.copyWith(
                    color: c.ink,
                    fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: AnSpace.s8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
