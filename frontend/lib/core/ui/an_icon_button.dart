import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// Icon-only button for toolbars / row affordances. Ghost by default (transparent, gray
/// wash on hover); tone=danger for destructive icon actions.
/// 纯图标按钮(工具栏/行操作)。默认 ghost(透明、悬停灰底);tone=danger 用于破坏性操作。
enum AnIconButtonTone { neutral, danger }

class AnIconButton extends StatelessWidget {
  const AnIconButton(
    this.icon, {
    super.key,
    this.onPressed,
    this.tooltip,
    this.size = AnSize.control,
    this.tone = AnIconButtonTone.neutral,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final AnIconButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final danger = tone == AnIconButtonTone.danger;

    Color fg(Set<WidgetState> s) {
      if (s.contains(WidgetState.disabled)) return c.inkFaint;
      final active = s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed);
      if (danger) return c.danger;
      return active ? c.ink : c.inkMuted;
    }

    Color bg(Set<WidgetState> s) {
      if (s.contains(WidgetState.disabled)) return Colors.transparent;
      final active = s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed);
      if (!active) return Colors.transparent;
      return danger ? c.dangerSoft : c.surfaceHover;
    }

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: size <= AnSize.controlSm ? 14 : AnSize.icon,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(size, size)),
        fixedSize: WidgetStatePropertyAll(Size(size, size)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AnRadius.button)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(fg),
        iconColor: WidgetStateProperty.resolveWith(fg),
        backgroundColor: WidgetStateProperty.resolveWith(bg),
      ),
    );
  }
}
