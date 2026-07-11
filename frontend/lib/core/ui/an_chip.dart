import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_interactive.dart';
import 'icons.dart';
import 'tone.dart';

/// The CHIP family head (WRK-066「同轨」族三) — the ONE small-label unit. Two looks: [AnChipLook.filled]
/// (soft tone background — status badges) and [AnChipLook.outlined] (hairline border — light list chips:
/// tool belts, morph rosters, pre-authorized pills). Hot-pluggable: leading [icon], [mono] label
/// (ids/paths), tap-to-copy ([copyValue], ✓ flash), [onTap] navigation, [strikethrough] (deleted
/// entries). Existing thin presets (AnRefPill / AnPathChip) keep their names and re-route through this.
///
/// 芯片族当家件(「同轨」族三)——唯一小标签单元。两形:filled(软底=状态徽)/outlined(细边=轻列表芯片:
/// 工具腰带/变更花名册/预授权药丸)。热插拔:icon、mono 标签(id/路径)、点击复制(✓ 一闪)、onTap 导航、
/// strikethrough 删除态。既有薄预设(AnRefPill/AnPathChip)保名字、内部改走本件。
enum AnChipLook { filled, outlined }

/// Standard truncation tiers — kills the 15+ hand-rolled `length > N ? substring…` ternaries.
/// 标准截断三档——清 15+ 处手搓三元式。
enum AnTrunc {
  id(12),
  word(24),
  line(48);

  const AnTrunc(this.chars);
  final int chars;
}

/// Truncate [text] to a standard tier with an ellipsis. 按档截断。
String truncate(String text, AnTrunc tier) =>
    text.length > tier.chars ? '${text.substring(0, tier.chars)}…' : text;

class AnChip extends StatefulWidget {
  const AnChip(
    this.label, {
    this.tone = AnTone.none,
    this.look = AnChipLook.filled,
    this.icon,
    this.mono = false,
    this.copyValue,
    this.onTap,
    this.strikethrough = false,
    super.key,
  });

  final String label;
  final AnTone tone;
  final AnChipLook look;
  final IconData? icon;

  /// Mono label face (ids / paths / slugs). 等宽标签(id/路径/slug)。
  final bool mono;

  /// Tap copies this value and flashes ✓ (absorbs AnCopyChip / WindowCopyButton semantics). Mutually
  /// exclusive with [onTap] (copy wins). 点击复制+✓一闪;与 onTap 互斥(copy 优先)。
  final String? copyValue;

  final VoidCallback? onTap;

  /// Deleted-entry face (morph rosters). 删除态(变更花名册)。
  final bool strikethrough;

  @override
  State<AnChip> createState() => _AnChipState();
}

class _AnChipState extends State<AnChip> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.copyValue!));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(AnMotion.dwell, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Color _ink(AnColors c) => switch (widget.tone) {
        AnTone.ok => c.ok,
        AnTone.warn => c.warn,
        AnTone.danger => c.danger,
        AnTone.accent => c.accent,
        AnTone.none => c.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = _ink(c);
    final interactive = widget.copyValue != null || widget.onTap != null;

    final chip = Container(
      height: AnSize.badge,
      padding: const EdgeInsets.symmetric(horizontal: AnSize.badgePadX),
      decoration: widget.look == AnChipLook.filled
          ? BoxDecoration(color: widget.tone.softBg(c), borderRadius: BorderRadius.circular(AnRadius.pill))
          : BoxDecoration(
              border: Border.all(color: widget.tone == AnTone.none ? c.line : ink, width: AnSize.hairline),
              borderRadius: BorderRadius.circular(AnRadius.chip),
            ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (widget.copyValue != null && _copied)
          Icon(AnIcons.check, size: AnSize.iconSm, color: c.ok)
        else if (widget.icon != null)
          Icon(widget.icon, size: AnSize.iconSm, color: ink),
        if (widget.icon != null || (widget.copyValue != null && _copied)) const SizedBox(width: AnSpace.s4),
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (widget.mono ? AnText.codeInline : AnText.meta).copyWith(
              color: ink,
              decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ]),
    );

    if (!interactive) return ConstrainedBox(constraints: const BoxConstraints(maxWidth: AnSize.block), child: chip);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.block),
      child: AnInteractive(
        onTap: widget.copyValue != null ? _copy : widget.onTap,
        // Hover feedback = the ✓ flash (copy) / cursor (nav); no bespoke dim tier (文法 #6). 悬停不私调透明。
        builder: (ctx, states) => chip,
      ),
    );
  }
}
