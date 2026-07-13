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
  const AnStatusDot(AnStatus this.status, {super.key})
      : rawColor = null,
        hollow = false,
        size = AnSize.dot;

  /// The RAW face (WRK-066 批5): a direct-colour, optionally hollow, tiered-size dot — the ONE
  /// implementation behind bead strips / colour swatches / fired markers that used to hand-roll
  /// `Container+BoxDecoration(circle)` (A-038/039/048). Pure static: no animation branch.
  /// 直喂色形态(批5):任意色/可空心/档位尺寸——珠串/色点/fire 记号的唯一实现(收手搓圆点)。纯静态。
  const AnStatusDot.raw(this.rawColor, {this.hollow = false, this.size = AnSize.dot, super.key})
      : status = null;

  /// Semantic state (null on the raw face). 语义态(raw 形为 null)。
  final AnStatus? status;

  /// Direct colour for the raw face; null + [hollow] falls back to a faint ring. raw 形直喂色。
  final Color? rawColor;

  /// Ring instead of solid (un-fired / un-lit markers). 空心环(未触发/未点亮记号)。
  final bool hollow;

  /// Dot diameter — pass an [AnSize] tier ([AnSize.dot]/[AnSize.dotSm]/[AnSize.swatch]), never a
  /// bare number. 直径(AnSize 档,禁裸数)。
  final double size;

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
        // Raw face: direct colour; hollow-without-colour falls back to the faint ring. raw 直喂。
        null => widget.rawColor ?? c.inkFaint,
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
    // RepaintBoundary (C-017): without it, the breath ring's per-frame BoxShadow marks EVERYTHING up to
    // the nearest ancestor boundary dirty — a running dot inside a turn row / accordion row repaints that
    // whole subtree at 60fps. Isolating the tiny (7px + pulse spread) dot onto its own layer confines the
    // repaint to the dot itself (same armouring [AnShimmerText] already carries). 隔层:否则呼吸环逐帧脏到
    // 最近祖先边界=整条回合行/手风琴行 60fps 重绘;隔离到 7px 点自身图层,重绘只发生在点上。
    return RepaintBoundary(
      child: AnimatedBuilder(
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
      ),
    );
  }

  Widget _dot(Color color, List<BoxShadow> shadow) => Container(
        width: widget.size,
        height: widget.size,
        decoration: widget.hollow
            // Hollow ring: hairline stroke, transparent fill (un-fired markers). 空心环。
            ? BoxDecoration(border: Border.all(color: color, width: AnSize.hairline), shape: BoxShape.circle)
            : BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: shadow),
      );
}
