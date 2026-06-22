import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// An inline entity-reference chip (icon + name) — for @mentions, dependency links, and
/// "used by" lists. Clickable to navigate to the referenced entity.
/// 内联实体引用 pill(图标+名)——用于 @提及、依赖链接、"被谁用"。可点击跳到被引实体。
class AnRefPill extends StatefulWidget {
  const AnRefPill({super.key, required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  State<AnRefPill> createState() => _AnRefPillState();
}

class _AnRefPillState extends State<AnRefPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AnMotion.fast,
          height: AnSize.controlSm,
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
          decoration: BoxDecoration(
            color: _hover ? c.surfaceHover : c.surfaceActive,
            borderRadius: BorderRadius.circular(AnRadius.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: AnSize.iconSm, color: c.inkMuted),
                const SizedBox(width: AnSpace.s4),
              ],
              Text(widget.label, style: AnText.meta.copyWith(color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
