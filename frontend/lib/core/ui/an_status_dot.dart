import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../model/status_state.dart';
import '../perf/pulse_clock.dart';

/// A1 — a 7px semantic status dot. Colour by state (idle gray / run accent / wait warn / err danger
/// / done ok); `run` is the only animated one — a soft ring breathes outward (the demo's pulse).
/// State folding is the single source ([AnStatus.fromRaw]); pass an already-folded [AnStatus].
///
/// The breath rides the SHARED [PulseClock] (T1/WRK-070): a self-owned `AnimationController.repeat()`
/// kept the whole app at 120fps while ANY run dot was visible — 24.92% CPU measured, the one
/// user-feelable idle heat source. Now a live run dot only POKES the clock (arrival + every rebuild
/// that reaches it = stream heartbeat), so breath tracks real activity and rests to the solid pose
/// once the app goes quiet; static faces never subscribe at all. RepaintBoundary alone never helped —
/// repaint isolation ≠ frame scheduling; the cure is the ticker STOPPING.
///
/// A1——7px 语义状态点。色随态(idle 灰 / run 强调 / wait 橙 / err 红 / done 绿);仅 run 有动效——
/// 柔环向外呼吸(demo 的 pulse)。状态归一走单源(AnStatus.fromRaw),此处收已折好的 AnStatus。
/// 呼吸走共享 PulseClock(T1/WRK-070):自持 `.repeat()` 曾让任一 run 点可见时全 app 永久 120fps=
/// 24.92% CPU。现在活 run 点只 poke 钟(到场+每次 rebuild 触达=流心跳),呼吸跟随真实活动、app 安静后
/// 归静息实心姿态;静态面根本不订阅。RepaintBoundary 从来救不了——重绘隔离≠帧调度,救命的是钟会停。
class AnStatusDot extends StatefulWidget {
  const AnStatusDot(AnStatus this.status, {this.clock, super.key})
    : rawColor = null,
      hollow = false,
      size = AnSize.dot;

  /// The RAW face (WRK-066 批5): a direct-colour, optionally hollow, tiered-size dot — the ONE
  /// implementation behind bead strips / colour swatches / fired markers that used to hand-roll
  /// `Container+BoxDecoration(circle)` (A-038/039/048). Pure static: no animation branch.
  /// 直喂色形态(批5):任意色/可空心/档位尺寸——珠串/色点/fire 记号的唯一实现(收手搓圆点)。纯静态。
  const AnStatusDot.raw(
    this.rawColor, {
    this.hollow = false,
    this.size = AnSize.dot,
    super.key,
  }) : status = null,
       clock = null;

  /// Semantic state (null on the raw face). 语义态(raw 形为 null)。
  final AnStatus? status;

  /// Direct colour for the raw face; null + [hollow] falls back to a faint ring. raw 形直喂色。
  final Color? rawColor;

  /// Ring instead of solid (un-fired / un-lit markers). 空心环(未触发/未点亮记号)。
  final bool hollow;

  /// Dot diameter — pass an [AnSize] tier ([AnSize.dot]/[AnSize.dotSm]/[AnSize.swatch]), never a
  /// bare number. 直径(AnSize 档,禁裸数)。
  final double size;

  /// Injectable for tests/gallery; defaults to the app-wide shared clock. 可注入;默认共享钟。
  final PulseClock? clock;

  @override
  State<AnStatusDot> createState() => _AnStatusDotState();
}

class _AnStatusDotState extends State<AnStatusDot> {
  PulseClock get _clock => widget.clock ?? PulseClock.shared;

  // Live = a run face that is allowed to breathe: reduced motion renders the defined static pose
  // (decorative loop → reducedOrAssistive gate), and an off-stage dot (TickerMode off — hidden tab /
  // Offstage subtree) neither pokes nor subscribes, matching what the old vsync controller got from
  // TickerMode for free. 活着=允许呼吸的 run 面:reduced 走法定静态姿态;离屏(TickerMode 关)不 poke
  // 不订阅——旧 vsync 控制器从 TickerMode 免费得到的离屏自停,在此显式接住。
  bool get _live =>
      widget.status == AnStatus.run &&
      !AnMotionPref.reducedOrAssistive(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live) _clock.poke(); // arrival IS activity 出现即起搏
  }

  @override
  void didUpdateWidget(AnStatusDot old) {
    super.didUpdateWidget(old);
    // Every rebuild that reaches a live run dot re-arms the clock's idle window: stream frames
    // rebuild their rows, so breath sustains exactly while data flows and rests when it stops.
    // 每次 rebuild 触达活 run 点即顺延静息窗:流帧会重建所在行——数据在流呼吸就在,流停呼吸歇。
    if (_live) _clock.poke();
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
    // Static for everything but a live running dot — run under reduced motion / off-stage renders the
    // solid dot at run tone, no oscillation (the defined static fallback). 非活 run 一律静态:降级/离屏
    // 下 run 也是实心点不振荡。
    if (!_live) return _dot(color, const []);
    // RepaintBoundary (C-017): confines the breath ring's repaint to the tiny (7px + pulse spread) dot
    // layer instead of dirtying the whole turn/accordion row per clock tick. 隔层:呼吸重绘只发生在点上,
    // 不逐拍脏整行。
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          // Clock idle → phase froze at 0 → the same solid pose; while running, the demo keyframe:
          // ring expands 0 → dotPulse while fading out. 钟静息→相位冻 0=实心姿态;运转=环扩张并淡出。
          final t = AnMotion.easeOut.transform(_clock.value);
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
        ? BoxDecoration(
            border: Border.all(color: color, width: AnSize.hairline),
            shape: BoxShape.circle,
          )
        : BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: shadow,
          ),
  );
}
