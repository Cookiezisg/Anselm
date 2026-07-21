import 'package:flutter/widgets.dart';

import '../contract/todo.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_status_dot.dart';
import 'icons.dart';

/// The TASK RING (WRK-061 §6-②) — the rundown's progress brow: a small arc ring filling
/// completed/total. The arc TWEENS on progress (reduced: jumps); a full board rests in ok tone —
/// a quiet glow, never confetti. 场记进度环:completed/total 补弧(reduced 跳变);全满 ok 色安静收束,
/// 绝不彩带。
class AnTaskRing extends StatelessWidget {
  const AnTaskRing({
    required this.completed,
    required this.total,
    this.size = 16,
    super.key,
  });

  final int completed;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final target = total <= 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final done = total > 0 && completed >= total;
    final reduced = AnMotionPref.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: reduced ? Duration.zero : AnMotion.mid,
      curve: AnMotion.easeOut,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          fraction: v,
          tone: done ? c.ok : c.accent,
          rail: c.surfaceSunken,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.tone,
    required this.rail,
  });

  final double fraction;
  final Color tone;
  final Color rail;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 1.5;
    final railPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = rail;
    canvas.drawCircle(center, r, railPaint);
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -1.5708, // 12 o'clock 十二点起
        fraction * 6.2832,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = tone,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.tone != tone;
}

/// The RUNDOWN LIST (WRK-061 §6-②) — the read-only task board under the stage: pending = an empty
/// circle + content; in_progress = the ACTIVE-FORM phrasing + a solid accent dot (the present tense of
/// work); completed = a check + struck, sunk grey. Rows are plain (no per-row animation machinery —
/// the board replaces wholesale, R-12 discipline). 场记清单(只读):pending 空圈/in_progress activeForm
/// 进行时+accent 实点/completed 勾+划线灰沉。行朴素(整表替换,不搞逐行动画机器)。
class AnRundownList extends StatelessWidget {
  const AnRundownList({required this.todos, super.key});

  final List<TodoEntry> todos;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final todo in todos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AnSize.iconSm,
                  height: AnSize.icon,
                  child: Center(child: _lead(c, todo.status)),
                ),
                const SizedBox(width: AnSpace.s6),
                Expanded(
                  child: Text(
                    todo.status == 'in_progress' && todo.activeForm.isNotEmpty
                        ? todo.activeForm
                        : todo.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: switch (todo.status) {
                      'completed' => AnText.label.copyWith(
                        color: c.inkFaint,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: c.inkFaint,
                      ),
                      'in_progress' => AnText.label.copyWith(color: c.ink),
                      _ => AnText.label.copyWith(color: c.inkMuted),
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _lead(AnColors c, String status) => switch (status) {
    'completed' => Icon(AnIcons.check, size: AnSize.iconXs, color: c.inkFaint),
    'in_progress' => AnStatusDot.raw(c.accent),
    // hollow + null colour = the faint ring (pending marker). 空心无色即 faint 环(待办记号)。
    _ => const AnStatusDot.raw(null, hollow: true),
  };
}
