import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A switch. On = ink track + thumb right; off = gray track + thumb left. Both track colors
/// are opaque (no transparent-black tween flash). Monochrome.
/// 开关。开=墨轨+拇指右;关=灰轨+拇指左。两态轨色皆不透明(无透明黑补间闪)。单色。
class AnToggle extends StatelessWidget {
  const AnToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: AnMotion.fast,
          width: 36,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? c.accent : c.surfaceActive,
            borderRadius: BorderRadius.circular(AnRadius.pill),
          ),
          child: AnimatedAlign(
            duration: AnMotion.fast,
            curve: AnMotion.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                boxShadow: c.shadowIsland,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
