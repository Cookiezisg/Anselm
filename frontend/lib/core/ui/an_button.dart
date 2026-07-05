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
/// [round] makes the box a circle/stadium (pill radius) — the composer's filled send button.
///
/// Tiers: lg = 32 (AnSize.row) box · 20 icon — the CONTENT-workspace control tier (composer
/// actions beside 15 text); md = 28 · 16 — the chrome default; sm = 24 · 12 — dense affordances
/// (KV pencils, card chrome). 三档:lg 32/20=内容区控件档(15 文字旁),md 28/16=chrome 默认,
/// sm 24/12=密集触点。
///
/// B1——统一动作钮。变体:ghost(中性默认)· primary(墨 CTA,单色无装饰)· danger · icon(方钮)。
/// outline=当前字色描边;block=占满 + 左对齐;round=圆形/胶囊(pill 半径,composer 实心发送钮)。
/// 搭在 AnInteractive 上(hover/press/focus + 禁用契约共享:onPressed=null → 惰性、不可聚焦)。
/// label 仅受限宽时截断,超长不撑破。
enum AnButtonVariant { ghost, primary, danger, icon }

enum AnButtonSize { md, sm, lg }

class AnButton extends StatelessWidget {
  const AnButton({
    this.label,
    this.icon,
    this.onPressed,
    this.variant = AnButtonVariant.ghost,
    this.size = AnButtonSize.md,
    this.outline = false,
    this.block = false,
    this.elevated = false,
    this.round = false,
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
    this.variant = AnButtonVariant.icon,
    this.outline = false,
    this.elevated = false,
    this.round = false,
    required String this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  })  : label = null,
        block = false;

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AnButtonVariant variant;
  final AnButtonSize size;
  final bool outline;
  final bool block;

  /// A soft [AnColors.shadowFloat] elevation — a button that floats over busy content (a graph canvas).
  /// 浮起 float 阴影——浮在繁忙内容(图画布)上的钮。
  final bool elevated;

  /// Circle/stadium shape (pill radius) — the composer's filled send/stop button. 圆形/胶囊。
  final bool round;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Square geometry for the icon variant AND any label-less glyph button (a primary round send is
    // `iconOnly(variant: primary)` — colours from the variant, geometry from the glyph-only shape).
    // 方形几何:icon 变体 + 一切无 label 的纯字形钮(primary 圆发送=iconOnly(variant: primary))。
    final isIcon = variant == AnButtonVariant.icon || (label == null && icon != null);
    final height = switch (size) {
      AnButtonSize.lg => AnSize.row,
      AnButtonSize.md => AnSize.control,
      AnButtonSize.sm => AnSize.controlSm,
    };
    final iconSize = switch (size) {
      AnButtonSize.lg => AnSize.iconLg,
      AnButtonSize.md => AnSize.icon,
      AnButtonSize.sm => AnSize.iconSm,
    };
    final padX = isIcon ? 0.0 : (size == AnButtonSize.sm ? AnSize.btnPadXSm : AnSize.btnPadX);
    final baseStyle = size == AnButtonSize.sm ? AnText.meta : AnText.body;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: Opacity(
        opacity: enabled ? 1 : AnOpacity.disabled,
        child: AnInteractive(
          enabled: enabled,
          onTap: onPressed,
          focusNode: focusNode,
          autofocus: autofocus,
          builder: (context, states) {
            final c = context.colors;
            final reduced = AnMotionPref.reduced(context);
            final active = states.isActive;
            final focused = states.contains(WidgetState.focused);

            late final Color bg;
            late final Color fg;
            // Regular (w400) label over the Light (w300) body — two-weight rule: no heavier CTA. 两种字重:加粗一律 Regular。
            final weight = AnText.emphasisWeight;
            switch (variant) {
              // Resting bg = the hover colour at alpha 0 (whenActive) — pure alpha fade, no dark
              // midpoint flash. 静止底=hover 色 alpha0(whenActive),纯 alpha 淡入、无暗闪。
              case AnButtonVariant.ghost:
                fg = active ? c.ink : c.inkMuted;
                bg = c.surfaceHover.whenActive(active);
              case AnButtonVariant.primary:
                fg = c.onAccent;
                bg = active ? c.accentHover : c.accent;
              case AnButtonVariant.danger:
                fg = c.danger;
                bg = c.dangerSoft.whenActive(active);
              case AnButtonVariant.icon:
                fg = active ? c.ink : c.inkFaint;
                bg = c.surfaceHover.whenActive(active);
            }

            // Always allocate the border slot (transparent when unfocused) so gaining the focus ring
            // doesn't shift the content by 1px. Focus ring = inkMuted (≥3:1 light & dark; lineStrong
            // 0.13α was invisible in light). 边框槽常驻(未聚焦透明),聚焦不挪 1px;焦点环 inkMuted。
            final border = Border.all(
              color: outline ? fg : c.inkMuted.whenActive(focused),
              width: AnSize.hairline,
            );

            final glyph = icon != null ? Icon(icon, size: iconSize, color: fg) : null;

            // block fills width, but "fill width" needs a bounded parent — degrade to intrinsic
            // (not crash) when unbounded (Stack/overlay/unbounded Row). block 占满需有界父;无界则退化为自适应、不崩。
            return LayoutBuilder(builder: (context, constraints) {
              final effBlock = block && constraints.hasBoundedWidth;
              Widget child;
              if (isIcon) {
                child = glyph ?? const SizedBox.shrink();
              } else {
                child = Row(
                  mainAxisSize: effBlock ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: effBlock ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    if (glyph != null) ...[glyph, const SizedBox(width: AnGap.inline)],
                    Flexible(
                      child: Text(
                        label ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // .weight, NOT copyWith(fontWeight:) — the pinned wght axis on the VF
                        // overrides a bare fontWeight, silently rendering Light. .weight 双轴同改,
                        // 裸 copyWith 会被钉死的 wght 轴覆盖、实渲 Light。
                        style: baseStyle.copyWith(color: fg).weight(weight),
                      ),
                    ),
                  ],
                );
              }

              final box = AnimatedContainer(
                duration: reduced ? Duration.zero : AnMotion.fast,
                height: height,
                width: isIcon ? height : null,
                padding: EdgeInsets.symmetric(horizontal: padX),
                alignment: isIcon ? Alignment.center : null,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(round ? AnRadius.pill : AnRadius.button),
                  border: border,
                  boxShadow: elevated ? c.shadowFloat : null,
                ),
                child: child,
              );
              return effBlock ? SizedBox(width: double.infinity, child: box) : box;
            });
          },
        ),
      ),
    );
  }
}
