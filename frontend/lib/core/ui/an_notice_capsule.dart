import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_a11y.dart';
import 'an_interactive.dart';
import 'an_notice_close_affordance.dart';
import 'an_notice_island_frame.dart';
import 'text_measure.dart';
import 'tone.dart';

/// The chrome-band notice capsule — the shared immediate surface for event copies and operation feedback.
/// A white-island pill in the title band's idle middle: it NEVER
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
/// PERFORMANCE (用户点名): the text is pre-measured and the final paragraph is built once — there are no
/// per-frame TextSpan rebuilds (typewriters are a relayout trap). One controller drives the small local
/// shell's width/clip/transform, isolated from the app by a [RepaintBoundary].
/// Reduced motion: instant in/out, dwell unchanged.
///
/// chrome 带通知胶囊。动画=用户亲述的对称时间线:像素→圆点(tone 点即圆心,与药丸自带的点是同一颗)→对称
/// 拉开成药丸(定高只动宽,pill 半径不随宽变,圆→药丸连续)→字从第一个字被右缘扫出(内容首端锚定,排版一次、
/// 局部壳扫出)→停留(hover 暂停)→同线倒放收回。性能:预测量一次排版、正文只建一次、小动画子树局部
/// layout/clip/transform、RepaintBoundary 隔离,绝无逐帧文本重建;reduced 即时进出。
class AnNoticeCapsule extends StatefulWidget {
  const AnNoticeCapsule({
    required this.text,
    required this.viewLabel,
    required this.closeLabel,
    this.icon,
    this.tone = AnTone.none,
    this.onTap,
    this.onClose,
    this.onExitStarted,
    required this.onDismissed,
    this.dismissRequested = false,
    this.pauseListenable,
    this.hold = AnMotion.noticeHold,
    super.key,
  });

  final String text;

  /// The muted trailing affordance label (i18n "View"). 灰尾「查看」文案(i18n)。
  final String viewLabel;

  /// Accessible name for the always-visible X. 每张展开卡常驻 X 的无障碍名称。
  final String closeLabel;

  /// Optional kind glyph between the dot and the text. 点与文案间的可选 kind 图标。
  final IconData? icon;

  /// Full semantic tone: operation feedback needs neutral / ok / warn / danger, not a red/amber bool.
  /// 完整语义色阶:操作反馈需要中性/成功/警告/危险,不能再用红/橙二值。
  final AnTone tone;

  final VoidCallback? onTap;

  /// Fired when the card's own X is pressed, before the reverse animation. 卡内 X 点击,倒放前回调。
  final VoidCallback? onClose;

  /// Fired once when any exit begins (timeout / view / X / snapshot clear), before the reverse.
  /// 宿主据此先收候场尾;超时/查看/X/快照清场全部同一套编舞。
  final VoidCallback? onExitStarted;

  /// Fired once after the exit animation completes (NOT on tap — the host owns tap teardown).
  /// 退场动画完成后回调一次(点击收场由宿主管,不经此)。
  final VoidCallback onDismissed;

  /// External snapshot clear asks the still-mounted card to reverse. 外部快照清场请求仍挂载的卡倒放。
  final bool dismissRequested;

  /// The queue tail can pause this pill while the pointer / keyboard is over `+N → X`.
  /// 候场尾可在用户操作 `+N → X` 时暂停药丸驻留。
  final ValueListenable<bool>? pauseListenable;

  /// On-screen dwell between entrance and exit. 登-退之间的停留时长。
  final Duration hold;

  @override
  State<AnNoticeCapsule> createState() => _AnNoticeCapsuleState();
}

class _AnNoticeCapsuleState extends State<AnNoticeCapsule>
    with SingleTickerProviderStateMixin {
  /// One shared crown for the pill and approval header: 28px controls breathe inside a 36px island.
  /// 普通药丸与审批标题共用 36 冠部,28 控件上下各留 4。
  static const double _h = AnSize.noticeBar;

  late final AnimationController _c;
  late final Animation<double> _birth;
  late final Animation<double> _stretch;
  Timer? _dwell;

  /// Content width, measured once before ignition; the paragraph itself stays stable while the local
  /// shell reveals it. 内容宽点火前测一次;正文稳定,仅局部壳负责扫出。
  double _targetW = AnSize.noticeMaxWidth;

  // WCAG hover-pause bookkeeping: remaining time shrinks across re-arms. 暂停记账:剩余时长跨重臂递减。
  late int _remainingMs;
  int _armedAt = 0;
  bool _exiting = false;
  bool _entered = false;
  bool _hovered = false;
  bool _focusWithin = false;
  bool _announced = false;

  bool get _reduced => AnMotionPref.reduced(context);

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _remainingMs = widget.hold.inMilliseconds;
    _c = AnimationController(
      vsync: this,
      duration: AnMotion.capsuleIn,
      reverseDuration: AnMotion.capsuleOut,
    );
    // Beat 1 (birth, first ~28%): pixel→dot, with a whisper of overshoot (the reverse plays its mirror).
    // Beat 2 (stretch, the rest): dot→pill; the start-anchored content makes the text sweep for free.
    // 拍1 诞生(前 ~28%,轻微过冲弹性,倒放自镜像);拍2 拉开(其余),首端锚定让扫字白拿。
    _birth = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOutBack),
    );
    _stretch = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.24, 1.0, curve: Curves.easeOutCubic),
    );
    widget.pauseListenable?.addListener(_syncPause);
  }

  @override
  void didUpdateWidget(AnNoticeCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pauseListenable != widget.pauseListenable) {
      oldWidget.pauseListenable?.removeListener(_syncPause);
      widget.pauseListenable?.addListener(_syncPause);
      _syncPause();
    }
    if (!oldWidget.dismissRequested && widget.dismissRequested) _exit();
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
    if (widget.dismissRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _exit());
      return;
    }
    _enter();
    if (!_announced) {
      _announced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AnA11y.announce(
          context,
          widget.text,
          assertiveness:
              widget.tone == AnTone.warn || widget.tone == AnTone.danger
              ? Assertiveness.assertive
              : Assertiveness.polite,
        );
      });
    }
  }

  Future<void> _enter() async {
    if (_reduced) {
      _c.value = 1;
    } else {
      await _c.forward();
    }
    if (!mounted || _exiting) return;
    _entered = true;
    _arm(); // dwell starts after the sentence is fully open, never during its entrance 全开后才驻留
  }

  /// One-shot width plan: paddings + dot + gaps + optional icon + text (natural, clamped) + optional
  /// view tail — the SAME rungs the build lays out, so the sweep's final frame is exact.
  /// 一次性宽度预算:与 build 同一组构件求和,扫出终帧即精确终态。
  void _measure() {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // Optical symmetry, not equal box padding: the tone dot's centre is 15.5px from the leading edge;
    // the invisible 28px close target ends 2px from the trailing edge, putting the X centre at 16px.
    // 正的是视觉重心、不是盒距:点心距首缘 15.5;隐形 28 关闭盒距尾缘 2,X 心距尾缘 16。
    var w =
        AnInset.noticeCoast +
        AnSize.dot +
        AnGap.inline +
        AnGap.inlineLoose +
        AnSize.control +
        AnInset.noticeActionEdge;
    if (widget.icon != null) w += AnSize.iconSm + AnGap.inline;
    final copy = TextSpan(
      text: widget.text,
      style: AnText.body,
      children: widget.onTap == null
          ? null
          : <InlineSpan>[
              TextSpan(text: '  · ${widget.viewLabel}', style: AnText.meta),
            ],
    );
    w += measureText(
      copy,
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
      read: (p) => p.width,
    );
    // +8 slack: off-screen TextPainter widths run a few px UNDER live RenderParagraph needs on mixed
    // CJK/latin runs (glyph-positioning rounding accumulates; probed 5.25px on a 14-glyph line) — an
    // exact-width Flexible then trips ellipsis. Ellipsis stays legitimate past the max-width clamp.
    // +8 余量:离屏测量在中英混排上系统性偏窄几 px(字形定位取整累积,实测 5.25/14 字形),恰宽 Flexible
    // 会误省略;真超 340 上限时 ellipsis 依然正当。
    _targetW = (w + 8).clamp(_h, AnSize.noticeMaxWidth);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    widget.pauseListenable?.removeListener(_syncPause);
    _c.dispose();
    super.dispose();
  }

  void _arm() {
    if (!_entered ||
        _hovered ||
        _focusWithin ||
        (widget.pauseListenable?.value ?? false) ||
        _exiting) {
      return;
    }
    _armedAt = DateTime.now().millisecondsSinceEpoch;
    _dwell?.cancel();
    _dwell = Timer(Duration(milliseconds: _remainingMs), _exit);
  }

  void _pause() {
    if (_exiting || _dwell == null) return;
    _dwell?.cancel();
    _dwell = null;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _armedAt;
    _remainingMs = (_remainingMs - elapsed).clamp(
      0,
      widget.hold.inMilliseconds,
    );
  }

  void _resume() {
    if (_exiting ||
        !_entered ||
        _hovered ||
        _focusWithin ||
        (widget.pauseListenable?.value ?? false)) {
      return;
    }
    _arm();
  }

  void _setHovered(bool hovered) {
    _hovered = hovered;
    if (hovered) {
      _pause();
    } else {
      _resume();
    }
  }

  void _setFocusWithin(bool focused) {
    _focusWithin = focused;
    if (focused) {
      _pause();
    } else {
      _resume();
    }
  }

  void _syncPause() {
    if (widget.pauseListenable?.value ?? false) {
      _pause();
    } else {
      _resume();
    }
  }

  Future<void> _exit() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    widget.onExitStarted?.call();
    _dwell?.cancel();
    _dwell = null;
    if (_reduced) {
      _c.value = 0;
    } else {
      await _c.reverse(); // the same line, backwards — 同一条线倒放
    }
    if (mounted) widget.onDismissed();
  }

  void _activate() {
    widget.onTap?.call();
    _exit();
  }

  void _close() {
    widget.onClose?.call();
    _exit();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Content is laid out ONCE at its final width; the animated shell clips it. Start-anchored so the
    // opening right edge sweeps the text out first-character-first, and the dot rides the start edge
    // (≈ the newborn circle's center) for free. 内容按终宽排版一次,动画壳裁切;首端锚定=字从第一个字
    // 被扫出、点天然坐圆心再滑到首端。
    final main = Padding(
      padding: const EdgeInsetsDirectional.only(start: AnInset.noticeCoast),
      child: Row(
        children: [
          Container(
            width: AnSize.dot,
            height: AnSize.dot,
            decoration: BoxDecoration(
              color: widget.tone.fg(c),
              shape: BoxShape.circle,
            ),
          ),
          if (widget.icon != null) ...[
            const SizedBox(width: AnGap.inline),
            Icon(widget.icon, size: AnSize.iconSm, color: c.inkMuted),
          ],
          const SizedBox(width: AnGap.inline),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: widget.text,
                style: AnText.body.copyWith(color: c.ink),
                children: widget.onTap == null
                    ? null
                    : <InlineSpan>[
                        TextSpan(
                          text: '  · ${widget.viewLabel}',
                          style: AnText.meta.copyWith(color: c.inkFaint),
                        ),
                      ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
    final content = SizedBox(
      width: _targetW,
      height: _h,
      child: Row(
        children: [
          Expanded(
            child: AnInteractive(
              onTap: widget.onTap == null ? null : _activate,
              builder: (context, states) => main,
            ),
          ),
          const SizedBox(width: AnGap.inlineLoose),
          AnNoticeCloseAffordance(
            semanticLabel: widget.closeLabel,
            onPressed: _close,
          ),
          const SizedBox(width: AnInset.noticeActionEdge),
        ],
      ),
    );

    return RepaintBoundary(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _setFocusWithin,
        child: MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: AnimatedBuilder(
            animation: _c,
            child: content,
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
                    child: AnNoticeIslandFrame(
                      radius: _h / 2,
                      child: OverflowBox(
                        minWidth: _targetW,
                        maxWidth: _targetW,
                        alignment: AlignmentDirectional.centerStart,
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
