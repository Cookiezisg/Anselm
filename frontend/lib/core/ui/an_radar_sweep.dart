import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../perf/pulse_clock.dart';

/// The RADAR SWEEP (WRK-061 §7-5) — the trigger stage's HONEST WAITING signal: a single-tone ring with
/// a slow sweeping arc. It shows "we are listening", never fabricates progress. Rides the SHARED
/// [PulseClock] (own RepaintBoundary); reduced motion / an idle clock render the static ring.
///
/// 雷达扫描环——trigger 舞台的诚实等待信号:单色环+慢扫弧。只表达「在听」,绝不伪造进度。走共享
/// PulseClock(自带 RepaintBoundary);reduced/静息=静态环。
class AnRadarSweep extends StatefulWidget {
  const AnRadarSweep({this.size = 16, this.clock, super.key});

  final double size;

  /// Injectable for tests/gallery; defaults to the shared clock. 可注入;默认共享钟。
  final PulseClock? clock;

  @override
  State<AnRadarSweep> createState() => _AnRadarSweepState();
}

class _AnRadarSweepState extends State<AnRadarSweep> {
  PulseClock get _clock => widget.clock ?? PulseClock.shared;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sweep = decorative loop → reducedOrAssistive gate (static ring for screen readers too).
    // 扫光=装饰循环→reducedOrAssistive 门控(读屏同拿静态环)。
    if (!AnMotionPref.reducedOrAssistive(context)) _clock.poke();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (AnMotionPref.reducedOrAssistive(context)) {
      return _Ring(size: widget.size, phase: null, tone: c.accent, soft: c.accentSoft);
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) =>
            _Ring(size: widget.size, phase: _clock.idle ? null : _clock.value, tone: c.accent, soft: c.accentSoft),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.phase, required this.tone, required this.soft});

  final double size;
  final double? phase; // null = static pose 静态姿态
  final Color tone;
  final Color soft;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _SweepPainter(phase: phase, tone: tone, soft: soft),
      );
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.phase, required this.tone, required this.soft});

  final double? phase;
  final Color tone;
  final Color soft;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    canvas.drawCircle(center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AnSize.hairline
      ..color = soft);
    final p = phase;
    if (p == null) {
      // Static pose: a resting dot at 12 o'clock. 静态:12 点方向驻点。
      canvas.drawCircle(center.translate(0, -r), 1.5, Paint()..color = tone);
      return;
    }
    final angle = p * 2 * math.pi - math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      angle - 0.9,
      0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = tone,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.phase != phase;
}
