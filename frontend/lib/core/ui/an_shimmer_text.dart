import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A "working" text shimmer — a light band sweeps left→right across the glyphs while [active], the shared
/// "…in progress" tell for any transient label (the chat reasoning "thinking", a running tool_call's name,
/// anything mid-flight). Same sweep mechanism as [AnSkeleton] (one SingleTicker slides a [LinearGradient] via
/// a [GradientTransform]) but blended `srcIn` so it recolours the TEXT itself instead of an opaque bone.
///
/// [reveal]: the FIRST sweep doubles as a WIPE-IN — ahead of the band the glyphs are still transparent
/// (not yet born), behind it they land at [style]'s colour, so the light "writes" the word on left→right on
/// its debut, then the sweep settles into the plain [base]→[highlight]→[base] loop. (Both the reveal pass and
/// the loop end all-base, so the swap is seamless.)
///
/// Reduced-motion (gated on [AnMotionPref.reducedOrAssistive] — a shimmer is a decorative loop that competes
/// with a screen reader) OR `active:false`: render the plain [Text] at [style], no controller, full word
/// (the wipe-in is decorative — the word is simply present).
///
/// 「正在忙」文字流光——光带左→右扫过字形([active] 时);任何在途标签的共享 tell。机制同 [AnSkeleton] 但 `srcIn`
/// 染文字本身。[reveal]:**首过即揭示**——光带前方字形仍透明(尚未诞生)、后方落到 base 色,光把词从左到右「写」出来,
/// 之后转入 base→highlight→base 循环(两者都收在全 base、无缝切换)。降级或 active:false:纯静态全词。
class AnShimmerText extends StatefulWidget {
  const AnShimmerText(
    this.text, {
    required this.style,
    this.highlight,
    this.active = true,
    this.reveal = false,
    super.key,
  });

  final String text;

  /// The resting text style; its `color` is the shimmer's base. 静止样式;其 color 为流光 base。
  final TextStyle style;

  /// The sweeping "light" colour; null → base lifted toward the surface (a light streak). 光带色;null=提亮 base。
  final Color? highlight;

  /// Shimmer only while true (e.g. streaming / running); false → a plain static [Text]. 仅 true 时流光。
  final bool active;

  /// The first sweep wipes the word in (transparent → base, left→right) before the loop begins. 首扫即揭示。
  final bool reveal;

  @override
  State<AnShimmerText> createState() => _AnShimmerTextState();
}

class _AnShimmerTextState extends State<AnShimmerText>
    with SingleTickerProviderStateMixin {
  // EAGER-INIT (assign in initState, never a lazy `late final =` field). 急切初始化。
  late final AnimationController _c;
  late bool
  _revealDone; // false only while the one-shot wipe-in is still owed 仅首次揭示未完时 false

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AnMotion.breath);
    _revealDone = !widget.reveal;
    _c.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(); // reduced-motion lives in MediaQuery → re-sync when it (or active) changes 降级标志在 MediaQuery
  }

  @override
  void didUpdateWidget(AnShimmerText old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  // The reveal pass is a single forward(); on completion, swap to the plain loop. 揭示=一次 forward,完则转循环。
  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && !_revealDone) {
      _revealDone = true;
      if (widget.active &&
          !AnMotionPref.reducedOrAssistive(context) &&
          mounted) {
        _c.duration = AnMotion
            .breath; // reveal (slow) done → settle into the breath loop 揭示完转 breath 循环
        _c.repeat();
      }
      if (mounted) {
        setState(() {}); // swap the reveal gradient → loop gradient 换渐变
      }
    }
  }

  void _sync() {
    if (widget.active && !AnMotionPref.reducedOrAssistive(context)) {
      if (_c.isAnimating) return;
      if (_revealDone) {
        _c.duration = AnMotion.breath;
        _c.repeat();
      } else {
        _c.duration = AnMotion
            .slow; // a quick wipe-in, then settle to the slow breath loop 首扫快、再转慢循环
        _c.forward(from: 0);
      }
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.removeStatusListener(_onStatus);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Text(widget.text, style: widget.style);
    // Static fallback: plain full-word text, no sweep (reduced-motion or inactive). 静态兜底:全词、无扫光。
    if (!widget.active || AnMotionPref.reducedOrAssistive(context)) return text;

    final base = widget.style.color ?? c.ink;
    // Default streak = base lifted 60% toward the surface — a light band, not a full wink-to-white. 提亮 60%。
    final highlight = widget.highlight ?? Color.lerp(base, c.surface, 0.6)!;
    // Reveal pass: ahead of the band is transparent (unborn); loop: base both sides. 揭示:带前透明;循环:两侧 base。
    final trailing = _revealDone ? base : base.withValues(alpha: 0);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        // Linear (NOT eased): easeOut on a .repeat() stutters at the loop boundary (same as AnSkeleton).
        // 线性(非 ease):repeat 上 ease 会在循环点抖(同 AnSkeleton)。
        builder: (ctx, child) => ShaderMask(
          blendMode: BlendMode
              .srcIn, // recolour the glyphs (vs AnSkeleton's srcATop over opaque bones) 染字形
          shaderCallback: (rect) => LinearGradient(
            colors: [base, highlight, trailing],
            stops: const [0.35, 0.5, 0.65],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            tileMode: TileMode.clamp,
            transform: _ShimmerSweep(_c.value),
          ).createShader(rect),
          child: child,
        ),
        child: text,
      ),
    );
  }
}

// Slides the band left→right across the bounds as v goes 0→1 (translate −w → +w); clamp keeps the outside at
// the edge stop (base on the left, base-or-transparent on the right). 随 v 0→1 把光带从左滑到右;带外 clamp 到边色。
class _ShimmerSweep extends GradientTransform {
  const _ShimmerSweep(this.v);

  final double v;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (2 * v - 1), 0, 0);
}
