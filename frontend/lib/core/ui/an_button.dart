import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Button tiers for a monochrome system: emphasis comes from FILL, not hue.
/// primary = ink fill / white text · secondary = bordered surface · ghost = text-only ·
/// danger = the one red, for destructive actions only.
/// 单色按钮层级:强调靠填充非色相。primary 墨底白字 · secondary 描边 · ghost 纯文字 · danger 唯一红(仅破坏性)。
enum AnButtonVariant { primary, secondary, ghost, danger }

enum AnButtonSize { normal, small }

class AnButton extends StatelessWidget {
  const AnButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AnButtonVariant.secondary,
    this.size = AnButtonSize.normal,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AnButtonVariant variant;
  final AnButtonSize size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final small = size == AnButtonSize.small;
    final height = small ? AnSize.controlSm : AnSize.control;
    final padX = small ? AnSpace.s12 : AnSpace.s16;

    Color background(Set<WidgetState> s) {
      final disabled = s.contains(WidgetState.disabled);
      final hovered = s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed);
      switch (variant) {
        case AnButtonVariant.primary:
          if (disabled) return c.surfaceActive;
          return hovered ? c.accentHover : c.accent;
        case AnButtonVariant.danger:
          if (disabled) return c.surfaceActive;
          return hovered ? Color.lerp(c.danger, Colors.black, 0.15)! : c.danger;
        case AnButtonVariant.secondary:
          if (disabled) return Colors.transparent;
          return hovered ? c.surfaceHover : c.surface;
        case AnButtonVariant.ghost:
          return hovered && !disabled ? c.surfaceHover : Colors.transparent;
      }
    }

    Color foreground(Set<WidgetState> s) {
      if (s.contains(WidgetState.disabled)) return c.inkFaint;
      switch (variant) {
        case AnButtonVariant.primary:
        case AnButtonVariant.danger:
          return c.onAccent;
        case AnButtonVariant.secondary:
        case AnButtonVariant.ghost:
          return c.ink;
      }
    }

    BorderSide side(Set<WidgetState> s) {
      if (variant != AnButtonVariant.secondary) return BorderSide.none;
      final color = s.contains(WidgetState.disabled) ? c.line : c.lineStrong;
      return BorderSide(color: color, width: AnSize.hairline);
    }

    // Force an EXACT height (min == max) and standard density so nothing shrinks it below
    // [height]; tight line-height + center alignment keep the label optically centered.
    // 锁死精确高度(min==max)+标准密度,避免被压扁;紧行高+居中对齐使文字纵向居中。
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: padX)),
      alignment: Alignment.center,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      elevation: const WidgetStatePropertyAll(0),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AnRadius.button)),
      ),
      textStyle: WidgetStatePropertyAll(
        AnText.label.copyWith(fontWeight: FontWeight.w500, height: 1.0),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(background),
      foregroundColor: WidgetStateProperty.resolveWith(foreground),
      iconColor: WidgetStateProperty.resolveWith(foreground),
      side: WidgetStateProperty.resolveWith(side),
    );

    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AnSize.iconSm),
              const SizedBox(width: AnSpace.s8),
              Text(label),
            ],
          );

    return TextButton(onPressed: onPressed, style: style, child: child);
  }
}
