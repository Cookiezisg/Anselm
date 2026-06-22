import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'icons.dart';

/// A checkbox. Checked = ink fill + white Lucide check; unchecked = bordered surface.
/// 复选框。选中=墨底+白色 Lucide 勾;未选=描边表面。
class AnCheckbox extends StatelessWidget {
  const AnCheckbox({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    return GestureDetector(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: AnMotion.fast,
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: value ? c.accent : c.surface,
            borderRadius: BorderRadius.circular(AnRadius.tag),
            border: value ? null : Border.all(color: c.lineStrong, width: 1.5),
          ),
          child: value ? Icon(AnIcons.check, size: 13, color: c.onAccent) : null,
        ),
      ),
    );
  }
}
