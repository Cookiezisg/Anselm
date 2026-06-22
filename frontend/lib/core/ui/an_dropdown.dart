import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// A select field: shows the current value + chevron; opens a themed menu on tap. Generic
/// over the value type. Styling of the popup comes from the app PopupMenuTheme.
/// 下拉选择:显示当前值 + 箭头;点开主题化菜单。值类型泛型。弹层样式来自 app 的 PopupMenuTheme。
class AnDropdown<T> extends StatelessWidget {
  const AnDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.placeholder,
  });

  final T? value;
  final List<(T value, String label)> items;
  final ValueChanged<T>? onChanged;
  final String? placeholder;

  String? get _label {
    for (final (v, l) in items) {
      if (v == value) return l;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final picked = await showMenu<T>(
      context: context,
      position: pos,
      items: [
        for (final (v, l) in items)
          PopupMenuItem<T>(
            value: v,
            height: AnSize.row,
            child: Text(l, style: AnText.body),
          ),
      ],
    );
    if (picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    final label = _label;
    return GestureDetector(
      onTap: enabled ? () => _open(context) : null,
      child: Container(
        height: AnSize.control,
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
        decoration: BoxDecoration(
          color: enabled ? c.surface : c.surfaceHover,
          borderRadius: BorderRadius.circular(AnRadius.button),
          border: Border.all(color: c.line, width: AnSize.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? placeholder ?? '',
                overflow: TextOverflow.ellipsis,
                style: AnText.body.copyWith(color: label == null ? c.inkFaint : c.ink),
              ),
            ),
            const SizedBox(width: AnSpace.s8),
            Icon(AnIcons.chevronDown, size: AnSize.iconSm, color: c.inkMuted),
          ],
        ),
      ),
    );
  }
}
