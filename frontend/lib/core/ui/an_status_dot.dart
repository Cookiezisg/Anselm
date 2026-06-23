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
  // EAGER-INIT: declare + assign in initState, NOT a `late final = AnimationController(...)` field
  // initializer — that lazy form first builds the controller on first READ, which can be during
  // teardown (vsync already deactivated) → crash. 急切初始化:在 initState 赋值,非惰性字段初始化器。
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AnMotion.breath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(); // the reduced-motion flag lives in MediaQuery → re-sync when it (or status) changes 降级标志在 MediaQuery
  }

  @override
  void didUpdateWidget(AnStatusDot old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _sync();
  }

  // Only `run` breathes — and only when reduced-motion is OFF (it's a decorative loop). 仅 run 且非降级时呼吸。
  void _sync() {
    if (widget.status == AnStatus.run && !AnMotionPref.reducedOrAssistive(context)) {
      if (!_c.isAnimating) _c.repeat();
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
    // Static for everything but a running dot — and a running dot under reduced-motion renders the
    // solid dot at run tone, no oscillation (the defined static fallback). 降级下 run 也静态:实心点不振荡。
    if (widget.status != AnStatus.run || AnMotionPref.reducedOrAssistive(context)) {
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
