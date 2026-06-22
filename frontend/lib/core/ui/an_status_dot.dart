import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The 5 universal states every domain status folds into (matches the backend SSOT in the
/// demo's state-model: idle / run / wait / err / done). Color is functional, not decorative:
/// done = ok(green) · wait = warn(orange) · err = danger(red) · run = ink, breathing ·
/// idle = a hollow gray ring. Footprint is fixed at [size] in all states (the breathing
/// pulse animates opacity, not layout) so rows never reflow.
///
/// 全域状态统一折叠成的 5 个通用态(对齐 state-model SSOT)。颜色是功能非装饰:done 绿 · wait 橙 ·
/// err 红 · run 墨色呼吸 · idle 空心灰环。各态占位恒为 [size](呼吸只动透明度),行不重排。
enum AnStatus { idle, run, wait, err, done }

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
      AnStatus.run => c.ink,
      AnStatus.wait => c.warn,
      AnStatus.err => c.danger,
      AnStatus.done => c.ok,
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

    if (status != AnStatus.run) {
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
