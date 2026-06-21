import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// Status conveyed WITHOUT color (the achromatic rule): a small dot whose meaning reads
/// from fill + motion, not hue. idle = hollow ring · running = filled, breathing ·
/// done = filled solid · failed = the one red. Footprint is fixed at [size] in all states
/// (the breathing pulse animates opacity, not layout) so rows never reflow.
///
/// 状态不靠颜色(无彩色铁律):点的含义来自填充+动效。idle 空心环 · running 实心呼吸 · done 实心 ·
/// failed 唯一红。各态占位恒为 [size](呼吸只动透明度不动布局),行不重排。
enum AnStatus { idle, running, done, failed }

class AnStatusDot extends StatefulWidget {
  const AnStatusDot(this.status, {super.key, this.size = AnSize.dot});

  final AnStatus status;
  final double size;

  @override
  State<AnStatusDot> createState() => _AnStatusDotState();
}

class _AnStatusDotState extends State<AnStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: AnMotion.breath)..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = widget.status;
    final fill = switch (status) {
      AnStatus.idle => c.inkFaint,
      AnStatus.running => c.ink,
      AnStatus.done => c.ink,
      AnStatus.failed => c.danger,
    };
    final hollow = status == AnStatus.idle;

    Widget dot(double opacity) => Opacity(
          opacity: opacity,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hollow ? Colors.transparent : fill,
              border: hollow ? Border.all(color: c.inkFaint, width: 1.2) : null,
            ),
          ),
        );

    if (status != AnStatus.running) {
      return SizedBox(width: widget.size, height: widget.size, child: Center(child: dot(1)));
    }
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        // Triangle wave 0→1→0 over the period → gentle breathing. 三角波 0→1→0,柔和呼吸。
        final v = 1 - (_ac.value - 0.5).abs() * 2;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: dot(0.45 + 0.55 * v)),
        );
      },
    );
  }
}
