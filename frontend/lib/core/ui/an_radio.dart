import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A radio button. Selected = ink ring + ink dot; unselected = gray ring.
/// 单选钮。选中=墨环+墨点;未选=灰环。
class AnRadio<T> extends StatelessWidget {
  const AnRadio({super.key, required this.value, required this.groupValue, this.onChanged});

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = value == groupValue;
    final enabled = onChanged != null;
    return GestureDetector(
      onTap: enabled ? () => onChanged!(value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? c.accent : c.lineStrong,
              width: selected ? 1.5 : 1.5,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: AnMotion.fast,
              width: selected ? 8 : 0,
              height: selected ? 8 : 0,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
