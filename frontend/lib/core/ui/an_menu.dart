import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A popup action menu. Call [showAnMenu] from a widget's context (e.g. an icon button's
/// onPressed) — it anchors below that widget. Entries carry their own callbacks; danger
/// entries render red. Popup card styling comes from the app PopupMenuTheme.
/// 弹出操作菜单。从触发 widget 的 context 调 [showAnMenu],锚在其下方。条目自带回调,danger 显红。
class AnMenuEntry {
  const AnMenuEntry({required this.label, required this.onSelected, this.icon, this.danger = false});

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool danger;
}

Future<void> showAnMenu(BuildContext context, List<AnMenuEntry> entries) async {
  final c = context.colors;
  final box = context.findRenderObject() as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final pos = RelativeRect.fromRect(
    Rect.fromPoints(
      box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );
  await showMenu<void>(
    context: context,
    position: pos,
    items: [
      for (final e in entries)
        PopupMenuItem<void>(
          height: AnSize.row,
          onTap: e.onSelected,
          child: Row(
            children: [
              if (e.icon != null) ...[
                Icon(e.icon, size: AnSize.iconSm, color: e.danger ? c.danger : c.inkMuted),
                const SizedBox(width: AnSpace.s8),
              ],
              Text(e.label, style: AnText.body.copyWith(color: e.danger ? c.danger : c.ink)),
            ],
          ),
        ),
    ],
  );
}
