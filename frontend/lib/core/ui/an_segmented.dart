import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A segmented control: a gray track with a white "thumb" under the selected segment.
/// Generic over the value type. For 2–4 mutually exclusive view modes.
/// 分段控件:灰轨,选中段下有白色"滑块"。值类型泛型。用于 2–4 个互斥视图模式。
class AnSegmented<T> extends StatelessWidget {
  const AnSegmented({super.key, required this.segments, required this.value, this.onChanged});

  final List<(T value, String label)> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: AnSize.control,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceActive,
        borderRadius: BorderRadius.circular(AnRadius.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (val, label) in segments)
            GestureDetector(
              onTap: () => onChanged?.call(val),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AnMotion.fast,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
                decoration: BoxDecoration(
                  color: val == value ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AnRadius.button - 2),
                  boxShadow: val == value ? c.shadowIsland : null,
                ),
                child: Text(
                  label,
                  style: AnText.label.copyWith(color: val == value ? c.ink : c.inkMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
