import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'text_measure.dart';

/// The chrome-band notice capsule — the ONLY floating surface for event notifications (用户 0720 拍板:
/// 右上 toast 退役,浮层文化降级为例外). A white-island pill in the title band's idle middle: it NEVER
/// covers work content, never reflows layout.
///
/// THE ANIMATION (用户 0720 亲述,一条对称时间线「一个点长成一句话,说完缩回那个点」):
///  1. birth — a pixel grows into a DOT (scale + fast fade; the tone dot IS the circle's center: the
///     pill's own dot, one and the same throughout);
///  2. stretch — the circle pulls open SYMMETRICALLY into the pill (fixed height, width H→W; the pill
///     radius is width-invariant so circle→stadium is one continuous shape);
///  3. text sweep — the copy is REVEALED first-character-first: content is start-anchored inside the
///     shell, so the shell's right edge sweeps the (laid-out-once) text out as it opens — the dot sits
///     ~center of the newborn circle and "slides" to the start edge purely as a consequence of the
///     geometry, zero extra choreography;
///  4. dwell (hover pauses, WCAG) → the SAME line played in reverse (text tucks back, pill shrinks to
///     the dot, gone). Exit is `reverse()` — symmetry is structural, not re-animated.
///
/// PERFORMANCE (用户点名): the text is laid out ONCE (width pre-measured via [measureText]); every frame
/// is clip + transform only — no per-frame TextSpan rebuilds (typewriters are a relayout trap), one
/// [AnimationController] drives all beats, and the whole capsule sits under a [RepaintBoundary].
/// Reduced motion: instant in/out, dwell unchanged.
///
/// chrome 带通知胶囊。动画=用户亲述的对称时间线:像素→圆点(tone 点即圆心,与药丸自带的点是同一颗)→对称
/// 拉开成药丸(定高只动宽,pill 半径不随宽变,圆→药丸连续)→字从第一个字被右缘扫出(内容首端锚定,排版一次、
/// 每帧只裁切)→停留(hover 暂停)→同线倒放收回。性能:预测量一次排版、单 controller、RepaintBoundary,
/// 绝无逐帧文本重建;reduced 即时进出。
class AnNoticeCapsule extends StatefulWidget {
  const AnNoticeCapsule({
    required this.text,
    required this.viewLabel,
    this.icon,
    this.danger = true,
    this.onTap,
    required this.onDismissed,
    this.hold = AnMotion.toast,
    super.key,
  });

  final String text;

  /// The muted trailing affordance label (i18n "View"). 灰尾「查看」文案(i18n)。
  final String viewLabel;

  /// Optional kind glyph between the dot and the text. 点与文案间的可选 kind 图标。
  final IconData? icon;

  /// Severity: true = danger red dot, false = warn amber. 严重度点色。
  final bool danger;

  final VoidCallback? onTap;

  /// Fired once after the exit animation completes (NOT on tap — the host owns tap teardown).
  /// 退场动画完成后回调一次(点击收场由宿主管,不经此)。
  final VoidCallback onDismissed;

  /// On-screen dwell between entrance and exit. 登-退之间的停留时长。
  final Duration hold;

  @override
  State<AnNoticeCapsule> createState() => _AnNoticeCapsuleState();
}

class _AnNoticeCapsuleState extends State<AnNoticeCapsule> with SingleTickerProviderStateMixin {
  /// Shell height — [AnSize.control] so the newborn circle matches the band's control tier. 壳高=28 控件档。
  static const double _h = AnSize.control;

  late final AnimationController _c;
  late final Animation<double> _birth;
  late final Animation<double> _stretch;
  Timer? _dwell;

  /// Content width, measured ONCE before ignition (text laid out a single time — the sweep is pure
  /// clipping). 内容宽,点火前测量一次;扫出纯靠裁切。
  double _targetW = AnSize.toastMaxWidth;

  // Pause bookkeeping mirrors AnToast (WCAG hover-pause): remaining time shrinks across re-arms.
  // 暂停记账同 AnToast:剩余时长跨重臂递减。
  late int _remainingMs;
  int _armedAt = 0;
  bool _exiting = false;

  bool get _reduced => AnMotionPref.reduced(context);

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _remainingMs = widget.hold.inMilliseconds;
    _c = AnimationController(
        vsync: this, duration: AnMotion.capsuleIn, reverseDuration: AnMotion.capsuleOut);
    // Beat 1 (birth, first ~28%): pixel→dot, with a whisper of overshoot (the reverse plays its mirror).
    // Beat 2 (stretch, the rest): dot→pill; the start-anchored content makes the text sweep for free.
    // 拍1 诞生(前 ~28%,轻微过冲弹性,倒放自镜像);拍2 拉开(其余),首端锚定让扫字白拿。
    _birth = CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.28, curve: Curves.easeOutBack));
    _stretch = CurvedAnimation(
        parent: _c, curve: const Interval(0.24, 1.0, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ignite HERE, not in a post-frame callback (which silently never fired under the capture harness's
    // frame pumping); measurement needs an ambient context anyway. 点火在此(capture 泵帧下 postFrame 曾
    // 静默不触发);测量本就要 context。
    if (_started) return;
    _started = true;
    _measure();
    if (_reduced) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    _arm();
  }

  /// One-shot width plan: paddings + dot + gaps + optional icon + text (natural, clamped) + optional
  /// view tail — the SAME rungs the build lays out, so the sweep's final frame is exact.
  /// 一次性宽度预算:与 build 同一组构件求和,扫出终帧即精确终态。
  void _measure() {
    double textW(String s, TextStyle style) =>
        measureText(TextSpan(text: s, style: style), maxLines: 1, read: (p) => p.width);
    var w = AnSpace.s12 * 2 + AnSize.dot + AnSpace.s6;
    if (widget.icon != null) w += AnSize.iconSm + AnSpace.s6;
    var tail = 0.0;
    if (widget.onTap != null) tail = AnSpace.s6 + textW('· ${widget.viewLabel}', AnText.meta);
    w += textW(widget.text, AnText.body) + tail;
    // +8 slack: off-screen TextPainter widths run a few px UNDER live RenderParagraph needs on mixed
    // CJK/latin runs (glyph-positioning rounding accumulates; probed 5.25px on a 14-glyph line) — an
    // exact-width Flexible then trips ellipsis. Ellipsis stays legitimate past the max-width clamp.
    // +8 余量:离屏测量在中英混排上系统性偏窄几 px(字形定位取整累积,实测 5.25/14 字形),恰宽 Flexible
    // 会误省略;真超 360 上限时 ellipsis 依然正当。
    _targetW = (w + 8).clamp(_h, AnSize.toastMaxWidth);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _arm() {
    _armedAt = DateTime.now().millisecondsSinceEpoch;
    _dwell?.cancel();
    _dwell = Timer(Duration(milliseconds: _remainingMs), _exit);
  }

  void _pause() {
    if (_exiting || _dwell == null) return;
    _dwell?.cancel();
    _dwell = null;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _armedAt;
    _remainingMs = (_remainingMs - elapsed).clamp(0, widget.hold.inMilliseconds);
  }

  void _resume() {
    if (_exiting) return;
    _arm();
  }

  Future<void> _exit() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    if (_reduced) {
      _c.value = 0;
    } else {
      await _c.reverse(); // the same line, backwards — 同一条线倒放
    }
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Content is laid out ONCE at its final width; the animated shell clips it. Start-anchored so the
    // opening right edge sweeps the text out first-character-first, and the dot rides the start edge
    // (≈ the newborn circle's center) for free. 内容按终宽排版一次,动画壳裁切;首端锚定=字从第一个字
    // 被扫出、点天然坐圆心再滑到首端。
    final content = SizedBox(
      width: _targetW,
      height: _h,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
        child: Row(
          children: [
            Container(
              width: AnSize.dot,
              height: AnSize.dot,
              decoration: BoxDecoration(
                color: widget.danger ? c.danger : c.warn,
                shape: BoxShape.circle,
              ),
            ),
            if (widget.icon != null) ...[
              const SizedBox(width: AnSpace.s6),
              Icon(widget.icon, size: AnSize.iconSm, color: c.inkMuted),
            ],
            const SizedBox(width: AnSpace.s6),
            Flexible(
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: AnText.body.copyWith(color: c.ink),
              ),
            ),
            if (widget.onTap != null) ...[
              const SizedBox(width: AnSpace.s6),
              Text('· ${widget.viewLabel}', style: AnText.meta.copyWith(color: c.inkFaint)),
            ],
          ],
        ),
      ),
    );

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _pause(),
        onExit: (_) => _resume(),
        child: AnimatedBuilder(
          animation: _c,
          child: AnInteractive(
            onTap: widget.onTap,
            builder: (context, states) => content,
          ),
          builder: (context, child) {
            final birth = _birth.value;
            final stretch = _stretch.value;
            final w = _h + (_targetW - _h) * stretch;
            return Opacity(
              // A fast fade rides the very start of birth (a pixel, not a pop-in). 淡入骑诞生最前段。
              opacity: (birth * 3).clamp(0.0, 1.0),
              child: Transform.scale(
                // Pixel→dot: the shell grows from near-nothing; easeOutBack may overshoot slightly
                // past 1 (the alive beat). 像素→圆点,轻微过冲=活拍。
                scale: 0.15 + 0.85 * birth,
                child: SizedBox(
                  width: w,
                  height: _h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AnRadius.pill),
                      border: Border.all(color: c.line, width: AnSize.hairline),
                      boxShadow: c.shadowIsland,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AnRadius.pill),
                      child: OverflowBox(
                        minWidth: _targetW,
                        maxWidth: _targetW,
                        alignment: AlignmentDirectional.centerStart,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
