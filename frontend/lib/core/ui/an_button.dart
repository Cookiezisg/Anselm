import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';

/// B1 — the unified action button. Variants: ghost (neutral default) · primary (the ink CTA —
/// monochrome, no decorative hue) · danger · icon (square). [outline] adds a stroke in the current
/// text colour; [block] fills width and left-aligns. Built on [AnInteractive] so hover/press/focus
/// and the disabled contract (null [onPressed] → inert, non-focusable) are shared. The label
/// truncates only under a width constraint, so an overlong label never blows out the layout.
///
/// B1——统一动作钮。变体:ghost(中性默认)· primary(墨 CTA,单色无装饰)· danger · icon(方钮)。
/// outline=当前字色描边;block=占满 + 左对齐。搭在 AnInteractive 上(hover/press/focus + 禁用契约共享:
/// onPressed=null → 惰性、不可聚焦)。label 仅受限宽时截断,超长不撑破。
enum AnButtonVariant { ghost, primary, danger, icon }

enum AnButtonSize { md, sm }

class AnButton extends StatelessWidget {
  const AnButton({
    this.label,
    this.icon,
    this.onPressed,
    this.variant = AnButtonVariant.ghost,
    this.size = AnButtonSize.md,
    this.outline = false,
    this.block = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Square icon-only button (label folds into the semantic label). 方形纯图标钮。
  const AnButton.iconOnly(
    IconData this.icon, {
    required this.onPressed,
    this.size = AnButtonSize.md,
    this.outline = false,
    required String this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  })  : variant = AnButtonVariant.icon,
        label = null,
        block = false;

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AnButtonVariant variant;
  final AnButtonSize size;
  final bool outline;
  final bool block;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isIcon = variant == AnButtonVariant.icon;
    final height = size == AnButtonSize.sm ? AnSize.controlSm : AnSize.control;
    final iconSize = size == AnButtonSize.sm ? AnSize.iconSm : AnSize.icon;
    final padX = isIcon ? 0.0 : (size == AnButtonSize.sm ? AnSize.btnPadXSm : AnSize.btnPadX);
    final baseStyle = size == AnButtonSize.sm ? AnText.meta : AnText.body;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: AnInteractive(
          enabled: enabled,
          onTap: onPressed,
          focusNode: focusNode,
          autofocus: autofocus,
          builder: (context, states) {
            final c = context.colors;
            final active = states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed);
            final focused = states.contains(WidgetState.focused);

            late final Color bg;
            late final Color fg;
            var weight = FontWeight.w500;
            switch (variant) {
              case AnButtonVariant.ghost:
                fg = active ? c.ink : c.inkMuted;
                bg = active ? c.surfaceHover : const Color(0x00000000);
              case AnButtonVariant.primary:
                fg = c.onAccent;
                bg = active ? c.accentHover : c.accent;
                weight = FontWeight.w600;
              case AnButtonVariant.danger:
                fg = c.danger;
                bg = active ? c.dangerSoft : const Color(0x00000000);
              case AnButtonVariant.icon:
                fg = active ? c.ink : c.inkFaint;
                bg = active ? c.surfaceHover : const Color(0x00000000);
            }

            final border = outline
                ? Border.all(color: fg, width: AnSize.hairline)
                : (focused ? Border.all(color: c.lineStrong, width: AnSize.hairline) : null);

            final glyph = icon != null ? Icon(icon, size: iconSize, color: fg) : null;
            Widget child;
            if (isIcon) {
              child = glyph ?? const SizedBox.shrink();
            } else {
              child = Row(
                mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: block ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  if (glyph != null) ...[glyph, const SizedBox(width: AnSpace.s6)],
                  Flexible(
                    child: Text(
                      label ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: baseStyle.copyWith(color: fg, fontWeight: weight),
                    ),
                  ),
                ],
              );
            }

            final box = AnimatedContainer(
              duration: AnMotion.fast,
              height: height,
              width: isIcon ? height : null,
              padding: EdgeInsets.symmetric(horizontal: padX),
              alignment: isIcon ? Alignment.center : null,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AnRadius.button),
                border: border,
              ),
              child: child,
            );
            return block ? SizedBox(width: double.infinity, child: box) : box;
          },
        ),
      ),
    );
  }
}
