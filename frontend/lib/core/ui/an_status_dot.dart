import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../model/status_state.dart';

/// A1 — a 7px semantic status dot. Colour by state (idle gray / run accent / wait warn / err danger
/// / done ok); `run` is the only animated one — a soft ring breathes outward (the demo's pulse).
/// State folding is the single source ([AnStatus.fromRaw]); pass an already-folded [AnStatus].
///
/// A1——7px 语义状态点。色随态(idle 灰 / run 强调 / wait 橙 / err 红 / done 绿);仅 run 有动效——
/// 柔环向外呼吸(demo 的 pulse)。状态归一走单源(AnStatus.fromRaw),此处收已折好的 AnStatus。
class AnStatusDot extends StatefulWidget {
  const AnStatusDot(this.status, {super.key});

  final AnStatus status;

  @override
  State<AnStatusDot> createState() => _AnStatusDotState();
}

class _AnStatusDotState extends State<AnStatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AnMotion.breath);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AnStatusDot old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _sync();
  }

  // Only `run` breathes; everything else is static. 仅 run 呼吸,余静止。
  void _sync() {
    if (widget.status == AnStatus.run) {
      _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color _color(AnColors c) => switch (widget.status) {
        AnStatus.run => c.accent,
        AnStatus.wait => c.warn,
        AnStatus.err => c.danger,
        AnStatus.done => c.ok,
        AnStatus.idle => c.inkFaint,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _color(c);
    if (widget.status != AnStatus.run) {
      return _dot(color, const []);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = AnMotion.easeOut.transform(_c.value);
        // Ring expands 0 → dotPulse while fading out — the demo keyframe. 环扩张并淡出。
        return _dot(color, [
          BoxShadow(
            color: c.accentSoft.withValues(alpha: c.accentSoft.a * (1 - t)),
            spreadRadius: AnSize.dotPulse * t,
          ),
        ]);
      },
    );
  }

  Widget _dot(Color color, List<BoxShadow> shadow) => Container(
        width: AnSize.dot,
        height: AnSize.dot,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: shadow),
      );
}
