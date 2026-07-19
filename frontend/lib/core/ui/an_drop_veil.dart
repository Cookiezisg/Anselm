import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The drag-hover VEIL (WRK-066 批7, B-070 — promoted from the chat ocean's private overlay): a
/// [AnOpacity.veil] surface wash that still hints at the content beneath, with a centered glyph +
/// hint. Pointer-transparent — the host's DropTarget keeps receiving events through it. Strings and
/// glyph come from the caller (the veil doesn't know what a drop means here).
///
/// 拖放悬停面纱(批7 B-070,自 chat 私件升格):veil 档表面洗(微透底)+ 居中字形与提示。指针穿透
/// (宿主 DropTarget 继续收事件)。字形/文案归调用方(面纱不懂这里的拖放语义)。
class AnDropVeil extends StatelessWidget {
  const AnDropVeil({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IgnorePointer(
      child: ColoredBox(
        color: c.surface.withValues(alpha: AnOpacity.veil),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AnSize.iconLg, color: c.inkMuted),
              const SizedBox(height: AnSpace.s8),
              Text(label, style: AnText.strong.copyWith(color: c.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
