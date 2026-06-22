import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A loading placeholder that breathes between two surface grays (no flashy sweep — quiet
/// is on-brand). Use for list/detail skeletons before data arrives.
/// 加载占位:在两级表面灰间呼吸(不做炫目扫光——安静即调性)。用于数据到达前的骨架。
class AnSkeleton extends StatefulWidget {
  const AnSkeleton({super.key, this.width, this.height = 12, this.radius = AnRadius.tag});

  final double? width;
  final double height;
  final double radius;

  @override
  State<AnSkeleton> createState() => _AnSkeletonState();
}

class _AnSkeletonState extends State<AnSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        final v = 1 - (_ac.value - 0.5).abs() * 2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(c.surfaceActive, c.surfaceHover, v),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
