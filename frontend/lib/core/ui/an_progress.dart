import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A thin linear progress bar (ink fill on a gray track). Pass [value] 0..1 for
/// determinate, or null for an indeterminate sweep.
/// 细线性进度条(灰轨墨填充)。[value] 0..1 确定;null 为不确定扫动。
class AnProgress extends StatelessWidget {
  const AnProgress({super.key, this.value, this.height = 4});

  final double? value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AnRadius.pill),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: c.surfaceActive,
        color: c.ink,
      ),
    );
  }
}
