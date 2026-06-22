import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// An underline tab bar over a hairline baseline. Selected tab = ink label + ink underline.
/// Generic over the value type. Every tab carries a (transparent) 2px underline so heights
/// stay equal.
/// 下划线 tab,压在细线基线上。选中=墨字+墨下划线。值类型泛型。每个 tab 都有 2px 下划线(未选透明)以等高。
class AnTabs<T> extends StatelessWidget {
  const AnTabs({super.key, required this.tabs, required this.value, this.onChanged});

  final List<(T value, String label)> tabs;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line, width: AnSize.hairline)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (val, label) in tabs)
            GestureDetector(
              onTap: () => onChanged?.call(val),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AnSpace.s12, vertical: AnSpace.s8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: val == value ? c.ink : Colors.transparent,
                      width: 2,
                    ),
                  ),
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
