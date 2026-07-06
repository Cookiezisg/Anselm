import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../../i18n/strings.g.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// A COPY CHIP (WRK-056 #16) — a monospace value in a hairline-bordered pill with a copy affordance;
/// tapping copies the value and briefly flashes a ✓ tick. For a webhook URL, an id, any value the user
/// will paste elsewhere. reduced motion: the tick just appears (no fade). 复制芯片:mono 值 + 复制 + ✓ tick。
class AnCopyChip extends StatefulWidget {
  const AnCopyChip({required this.value, this.label, super.key});

  /// The exact string copied to the clipboard AND shown (mono). 复制并展示的精确串。
  final String value;

  /// An optional leading label (e.g. a field name). 可选前置标签。
  final String? label;

  @override
  State<AnCopyChip> createState() => _AnCopyChipState();
}

class _AnCopyChipState extends State<AnCopyChip> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    // Revert the tick after a moment (a plain future, not a controller — no vsync needed). 片刻后复位。
    Future<void>.delayed(AnMotion.dwell, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    return Tooltip(
      message: _copied ? t.chat.tool.copyDone : widget.value,
      child: AnInteractive(
      onTap: _copy,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s2),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          border: Border.all(color: c.line, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.tag),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(widget.label!, style: AnText.meta.copyWith(color: c.inkFaint)),
              const SizedBox(width: AnGap.inline),
            ],
            Flexible(
              child: Text(widget.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.mono.copyWith(color: c.inkMuted)),
            ),
            const SizedBox(width: AnGap.inline),
            Icon(_copied ? AnIcons.check : AnIcons.copy,
                size: AnSize.iconSm, color: _copied ? c.ok : c.inkFaint),
          ],
        ),
      ),
    ),
    );
  }
}
