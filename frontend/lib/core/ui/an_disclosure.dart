import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_expand_reveal.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// A disclosure group: a tappable header (a PERSISTENT rotating chevron + optional lead icon + label +
/// optional trailing) over a body revealed by [AnExpandReveal]. Distinct from [AnRow]'s collapsible mode
/// — AnRow's chevron is a HOVER-SWAP (icon↔chevron on hover), whereas a streamed trace / log wants the
/// expand affordance ALWAYS visible. The header is one [AnInteractive] (so it announces its `expanded`
/// disclosure state + is keyboard-activatable); the body is indented (top s4 / left s16) under it.
/// Controlled: the caller owns [open] and flips it in [onToggle].
///
/// 披露组:可点头(**常驻**旋转 chevron + 可选 lead icon + label + 可选尾随)+ AnExpandReveal body。异于 AnRow
/// 的折叠态(AnRow chevron 是 hover 互换)——流式轨迹/日志要展开 affordance **常显**。头=一个 AnInteractive(透
/// expanded 披露态 + 键盘可激活);body 缩进(上 s4/左 s16)。受控:caller 持 open、在 onToggle 翻转。
class AnDisclosure extends StatelessWidget {
  const AnDisclosure({
    required this.label,
    required this.open,
    required this.onToggle,
    this.icon,
    this.iconColor,
    this.labelStyle,
    this.trailing,
    this.child,
    super.key,
  });

  final String label;
  final bool open;
  final VoidCallback onToggle;

  /// Optional lead glyph after the chevron (e.g. reasoning / tool icon). chevron 后的可选前导字形。
  final IconData? icon;

  /// Lead-glyph color (defaults to [AnColors.inkMuted]). 前导字形色。
  final Color? iconColor;

  /// Header label style (defaults to faint [AnText.meta]; e.g. a mono tool name overrides it). 头标签样式。
  final TextStyle? labelStyle;

  /// Optional trailing widget pinned after the label (e.g. a danger [AnChip]). 尾随件(如危险徽章)。
  final Widget? trailing;

  /// The revealed body; null = a header-only toggle. 展开体;null=仅头。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnInteractive(
          onTap: onToggle,
          expanded: open, // a11y: screen reader announces collapsed/expanded 披露态播报
          builder: (context, _) => Row(
            children: [
              AnimatedRotation(
                duration: reduced ? Duration.zero : AnMotion.fast,
                turns: open ? 0.25 : 0,
                child: Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
              ),
              const SizedBox(width: AnSpace.s4),
              if (icon != null) ...[
                Icon(icon, size: AnSize.iconSm, color: iconColor ?? c.inkMuted),
                const SizedBox(width: AnSpace.s6),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle ?? AnText.meta.copyWith(color: c.inkMuted)),
              ),
              if (trailing != null) ...[const SizedBox(width: AnSpace.s6), trailing!],
            ],
          ),
        ),
        if (child != null)
          AnExpandReveal(
            open: open,
            child: Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4, left: AnSpace.s16),
              child: child!,
            ),
          ),
      ],
    );
  }
}
