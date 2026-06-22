import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A key→value row for detail panels: muted label, then a string value or an arbitrary
/// [child] widget (a badge, a ref pill, a code snippet…).
/// 详情面板的键值行:弱化标签 + 字符串值或任意 [child](徽标/引用 pill/代码片段…)。
class AnKvRow extends StatelessWidget {
  const AnKvRow({super.key, required this.label, this.value, this.child, this.labelWidth = 120});

  final String label;
  final String? value;
  final Widget? child;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: AnText.meta.copyWith(color: c.inkMuted)),
          ),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: child ?? Text(value ?? '—', style: AnText.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}
