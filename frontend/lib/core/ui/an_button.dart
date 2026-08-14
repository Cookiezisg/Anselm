import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'an_spinner.dart';
import 'an_tooltip.dart';

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
    this.surface = false,
    this.block = false,
    this.elevated = false,
    this.round = false,
    this.toggled = false,
    this.busy = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Square icon-only button (label folds into the semantic label). [toggled] gives it an ON state
  /// (accent glyph over an accentSoft fill + a11y toggled) — a format/mode toggle in a toolbar.
  /// 方形纯图标钮;[toggled]=开态(accent 字形+accentSoft 底+a11y toggled),工具条格式/模式开关。
  const AnButton.iconOnly(
    IconData this.icon, {
    required this.onPressed,
    this.size = AnButtonSize.md,
    this.variant = AnButtonVariant.icon,
    this.outline = false,
    this.surface = false,
    this.elevated = false,
    this.round = false,
    this.toggled = false,
    this.busy = false,
    required String this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : label = null,
       block = false;

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AnButtonVariant variant;
  final AnButtonSize size;
  final bool outline;

  /// An opaque [AnColors.surface] fill + a hairline [AnColors.line] border, keeping the variant's own
  /// foreground colour (danger → red, ghost → ink). For a small verb button that must read on a grey
  /// row-hover wash — a ghost/danger fill is the SAME grey/soft tint as the wash and vanishes (0718
  /// 宁静化: the hover-revealed ⏹/↻). 白底描边:灰洗底上小动词钮可辨;底=surface、边=line、字色随变体。
  final bool surface;
  final bool block;

  /// A soft [AnColors.shadowFloat] elevation — a button that floats over busy content (a graph canvas).
  /// 浮起 float 阴影——浮在繁忙内容(图画布)上的钮。
  final bool elevated;

  /// Circle/stadium shape (pill radius) — the composer's filled send/stop button. 圆形/胶囊。
  final bool round;

  /// The ON state for a toggle button (accent glyph + accentSoft fill, a11y toggled). 开关按下态。
  final bool toggled;

  /// Replaces the glyph with the shared indeterminate spinner while an action is in flight. The
  /// button keeps its normal geometry; callers should also pass `onPressed: null` to block repeats.
  /// 动作在途时用统一不定转圈替换字形。按钮保留原有几何；调用方也应传 `onPressed: null` 防重复提交。
  final bool busy;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Square geometry for the icon variant AND any label-less glyph button (a primary round send is
    // `iconOnly(variant: primary)` — colours from the variant, geometry from the glyph-only shape).
    // 方形几何:icon 变体 + 一切无 label 的纯字形钮(primary 圆发送=iconOnly(variant: primary))。
    final isIcon =
        variant == AnButtonVariant.icon || (label == null && icon != null);
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
    final padX = isIcon
        ? 0.0
        : (size == AnButtonSize.sm ? AnSize.btnPadXSm : AnSize.btnPadX);
    final baseStyle = size == AnButtonSize.sm ? AnText.meta : AnText.body;

    // MergeSemantics folds this node's label/toggled with AnInteractive's button+tap node into ONE
    // (else a screen reader hits a label node WITHOUT the tap action — batch5 chip lesson).
    // 合并语义:标签/toggled 与 AnInteractive 的 button+tap 并一节点(否则读屏摸到无 tap 的标签节点)。
    // An ICON-ONLY button carries its meaning in a glyph, so a mouse user gets NO text at all unless
    // something supplies it. `semanticLabel` reached only the semantics tree — correct for a screen
    // reader, invisible to eyes. The count is why this belongs in the kit and not at call sites: 87
    // `AnButton.iconOnly` uses against 28 `AnTooltip` uses across the app, i.e. most icon buttons said
    // nothing on hover. The user hit exactly this and had to come ask what a button was
    // (WRK-077 §5.13: 「Library 里,新建页面为什么有一个下载的按钮,打开是这个?这是什么东西?」).
    //
    // A labelled button needs no tooltip — the label IS the text — so the wrap is icon-only.
    // Unconditional inside that branch, and the branch itself is decided by the constructor, so no
    // wrapper appears and disappears on a live instance (CLAUDE.md 禁止条件包装).
    //
    // 纯图标按钮的意思全在字形里,于是鼠标用户**一个字也得不到**,除非有人给。`semanticLabel` 只到语义树
    // ——对读屏是对的,对眼睛是不存在的。**数目**正是这件事该落地基而非落调用点的理由:全库
    // `AnButton.iconOnly` 87 处、`AnTooltip` 仅 28 处,即多数图标按钮 hover 时什么也不说。用户正是撞在这
    // 上面、不得不来问一个按钮是什么(WRK-077 §5.13:「Library 里,新建页面为什么有一个下载的按钮…这是什么
    // 东西?」)。
    //
    // 带文案的按钮不需要 tooltip——文案本身就是那段文字——故只包纯图标档。该分支内**无条件**包裹,而分支本身
    // 由构造决定,故活实例上不会有包装层来来去去(CLAUDE.md 禁止条件包装)。
    final tip = isIcon ? (semanticLabel ?? label) : null;
    Widget withTooltip(Widget child) => tip == null || tip.isEmpty
        ? child
        : AnTooltip(message: tip, child: child);

    return withTooltip(
      MergeSemantics(
        child: Semantics(
          button: true,
          enabled: enabled,
          toggled: toggled ? true : null,
          label: semanticLabel ?? label,
          child: Opacity(
            opacity: enabled ? 1 : AnOpacity.disabled,
            child: AnInteractive(
              // A label, not prose (TS 排除清单). 文案、非正文。
              chrome: true,
              enabled: enabled,
              onTap: onPressed,
              focusNode: focusNode,
              autofocus: autofocus,
              builder: (context, states) {
                final c = context.colors;
                final reduced = AnMotionPref.reduced(context);
                final active = states.isActive;
                final focused = states.contains(WidgetState.focused);

                late Color bg;
                late Color fg;
                // Regular (w400) label over the Light (w300) body — two-weight rule: no heavier CTA. 两种字重:加粗一律 Regular。
                final weight = AnText.emphasisWeight;
                switch (variant) {
                  // Resting bg = the hover colour at alpha 0 (whenActive) — pure alpha fade, no dark
                  // midpoint flash. ghost + icon (the app's INLINE row buttons: rail +/⋯, tray ⋯) hover a
                  // notch DEEPER (surfaceHoverStrong) so they read as buttons on a surfaceHover-washed row
                  // instead of melting into it (user 0719). 静止底=hover 色 alpha0(纯 alpha 淡入无暗闪);
                  // ghost+icon(行内钮:rail +/⋯、托盘 ⋯)hover 深一档 surfaceHoverStrong,不糊进灰洗底行。
                  case AnButtonVariant.ghost:
                    fg = active ? c.ink : c.inkMuted;
                    bg = c.surfaceHoverStrong.whenActive(active);
                  case AnButtonVariant.primary:
                    fg = c.onAccent;
                    bg = active ? c.accentHover : c.accent;
                  case AnButtonVariant.danger:
                    fg = c.danger;
                    bg = c.dangerSoft.whenActive(active);
                  case AnButtonVariant.icon:
                    fg = active ? c.ink : c.inkFaint;
                    bg = c.surfaceHoverStrong.whenActive(active);
                }

                // Toggle ON overrides the resting look: accent glyph over a solid accentSoft fill (the
                // format/mode "pressed" state). 开态覆写:accent 字形 + accentSoft 实底。
                if (toggled) {
                  fg = c.accent;
                  bg = c.accentSoft;
                }

                // surface overrides ONLY the fill (keeps the variant's fg): opaque surface at rest, a
                // gentle surfaceSunken on active so it stays a notch off the surrounding grey wash rather
                // than melting into it. 白底覆写只动底(字色不变),active 走 surfaceSunken 与洗底错开一档。
                if (surface) {
                  bg = active ? c.surfaceSunken : c.surface;
                }

                // Always allocate the border slot (transparent when unfocused) so gaining the focus ring
                // doesn't shift the content by 1px. Focus ring = inkMuted (≥3:1 light & dark; lineStrong
                // 0.13α was invisible in light). surface's own hairline is c.line, still ceding to the
                // focus ring when focused. 边框槽常驻(未聚焦透明),聚焦不挪 1px;焦点环 inkMuted;surface 边=line。
                final border = Border.all(
                  color: surface
                      ? (focused ? c.inkMuted : c.line)
                      : (outline ? fg : c.inkMuted.whenActive(focused)),
                  width: AnSize.hairline,
                );

                final glyph = icon != null
                    ? Icon(icon, size: iconSize, color: fg)
                    : null;

                // block fills width, but "fill width" needs a bounded parent — degrade to intrinsic
                // (not crash) when unbounded (Stack/overlay/unbounded Row). block 占满需有界父;无界则退化为自适应、不崩。
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final effBlock = block && constraints.hasBoundedWidth;
                    Widget child;
                    if (isIcon) {
                      child = busy
                          ? AnSpinner(size: iconSize)
                          : (glyph ?? const SizedBox.shrink());
                    } else {
                      child = Row(
                        mainAxisSize: effBlock
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        mainAxisAlignment: effBlock
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          if (busy || glyph != null) ...[
                            busy ? AnSpinner(size: iconSize) : glyph!,
                            const SizedBox(width: AnGap.inline),
                          ],
                          Flexible(
                            child: Text(
                              label ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // .weight, NOT copyWith(fontWeight:) — the pinned wght axis on the VF
                              // overrides a bare fontWeight, silently rendering Light. .weight 双轴同改,
                              // 裸 copyWith 会被钉死的 wght 轴覆盖、实渲 Light。
                              style: baseStyle
                                  .copyWith(color: fg)
                                  .weight(weight),
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
                        borderRadius: BorderRadius.circular(
                          round ? AnRadius.pill : AnRadius.button,
                        ),
                        border: border,
                        boxShadow: elevated ? c.shadowFloat : null,
                      ),
                      child: child,
                    );
                    return effBlock
                        ? SizedBox(width: double.infinity, child: box)
                        : box;
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
