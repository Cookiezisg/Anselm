import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// A PATH CHIP (WRK-056 #16) — a long file path shown as its BASENAME (the part you read), with the
/// FULL path on hover (a [Tooltip]) and a tap-to-copy of the full path. Tolerant of a partial/streaming
/// path (shows whatever has arrived). For Write/Edit body headers, mount refs, anywhere a path would
/// otherwise truncate uninformatively. reduced motion: the ✓ just appears. 路径芯片:显 basename、hover
/// 全路径、点击复制全路径;容忍流中半截路径。
class AnPathChip extends StatefulWidget {
  const AnPathChip({required this.path, this.leadingIcon = true, super.key});

  /// The full path (possibly still streaming). 全路径(可能流中)。
  final String path;

  /// Show a leading file glyph. 前导文件字形。
  final bool leadingIcon;

  @override
  State<AnPathChip> createState() => _AnPathChipState();
}

class _AnPathChipState extends State<AnPathChip> {
  bool _copied = false;

  /// The basename — the segment after the last `/` (or the whole thing if none). 末段(basename)。
  String get _basename {
    final p = widget.path;
    final trimmed = p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    final slash = trimmed.lastIndexOf('/');
    final base = slash < 0 ? trimmed : trimmed.substring(slash + 1);
    return base.isEmpty ? p : base;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.path));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(AnMotion.dwell, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: widget.path,
      child: AnInteractive(
        onTap: _copy,
        builder: (ctx, states) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leadingIcon) ...[
              Icon(AnIcons.doc, size: AnSize.iconSm, color: c.inkFaint),
              const SizedBox(width: AnGap.inline),
            ],
            Flexible(
              child: Text(_basename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.mono.copyWith(color: states.isActive ? c.ink : c.inkMuted)),
            ),
            const SizedBox(width: AnGap.inline),
            Icon(_copied ? AnIcons.check : AnIcons.copy,
                size: AnSize.iconSm, color: _copied ? c.ok : c.inkFaint),
          ],
        ),
      ),
    );
  }
}
