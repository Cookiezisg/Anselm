import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// C5 — a typewriter that types → holds → deletes → cycles a list of [phrases], with a caret that is
/// solid while moving and breathes while paused. HAND-ROLL (animated_text_kit CAN'T delete/backspace,
/// wraps nothing in Semantics, and never checks reduced-motion — failing 3 hard requirements). ONE
/// SingleTicker controller drives the whole phase machine (per-phrase duration + status-driven
/// advance, so it stays Single and TickerMode auto-pauses it offstage — NO Timer); slicing is
/// GRAPHEME-safe (`String.characters`) so emoji / CJK never split. Text clips (maxLines:1), and the
/// row reserves the caret height + end pad so it never reflows.
///
/// Two-layer a11y: the animated text is [ExcludeSemantics] (a screen reader must NOT spell the
/// half-typed string), and the outer [Semantics] exposes the COMPLETE current phrase as a static
/// label; liveRegion is FALSE (a cycling label would flood the SR queue — it's decorative).
/// Reduced-motion (reducedOrAssistive — a cycling caret is a decorative loop): render the full static
/// [phrases].first, no controller, steady caret.
///
/// C5——打字机:type→hold→delete→循环 phrases;光标移动时实、停顿时呼吸。HAND-ROLL。一个 SingleTicker 控制器
/// 跑整个相位机(每句时长 + status 驱动推进 → 保持 Single,离屏 TickerMode 自停、无 Timer);字素安全切片
/// (String.characters,emoji/CJK 不裂)。文字截断(maxLines:1),行预留光标高+尾距、不重排。两层 a11y:动画文字
/// ExcludeSemantics(SR 不读半串),外层 Semantics 暴露完整当前短语、liveRegion=false(循环 label 会刷爆 SR)。
/// 降级:渲染完整静态 phrases.first、不跑控制器、稳定光标。
class AnTypewriter extends StatefulWidget {
  const AnTypewriter(
    this.phrases, {
    this.loop = true,
    this.showCaret = true,
    this.accentCaret = false,
    this.textStyle,
    this.onDone,
    super.key,
  });

  final List<String> phrases;

  /// Cycle the phrases; when false, type the last phrase and stop (steady caret). 循环;false=打完末句停。
  final bool loop;
  final bool showCaret;

  /// Fires ONCE when a non-looping run finishes its last phrase (a host can then swap in its static
  /// widget). Under reduced motion (static render) it fires on the next frame. Never fires while
  /// looping. 非循环打完末句触发一次(宿主可切回静态件);reduced 下下一帧即触发;循环模式永不触发。
  final VoidCallback? onDone;

  /// Accent the caret (welcome/run feel) vs the default ink. 光标着 accent。
  final bool accentCaret;

  final TextStyle? textStyle;

  @override
  State<AnTypewriter> createState() => _AnTypewriterState();
}

class _AnTypewriterState extends State<AnTypewriter> with SingleTickerProviderStateMixin {
  late final AnimationController _c; // EAGER-INIT (assign in initState) 急切初始化

  int _i = 0; // current phrase index
  String _phrase = '';
  int _n = 0; // grapheme count
  int _typeMs = 0, _holdEnd = 0, _delEnd = 0, _total = 1; // phase boundaries (ms)
  bool _doneFired = false; // onDone once per run (didChangeDependencies re-restarts) 每轮只触发一次

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this)..addStatusListener(_onStatus);
  }

  bool? _lastReduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restart ONLY when the reduced-motion flag actually flipped — this fires on ANY inherited
    // change (theme flip, MediaQuery resize), and an unconditional restart retyped the reveal from
    // zero mid-stream. 仅在降级标志真翻转时重启——本钩子随任何继承变化触发(换主题/改窗),无条件重启
    // 会让揭示中途从零重打。
    final reduced = _reduced;
    if (_lastReduced == reduced) return;
    _lastReduced = reduced;
    _restart();
  }

  @override
  void didUpdateWidget(AnTypewriter old) {
    super.didUpdateWidget(old);
    // CONTENT equality, not list identity — hosts (chat head / rail) build a fresh `[title]` list
    // every build, and an identity compare restarted the reveal from zero on ANY parent rebuild
    // (theme flip, provider tick mid-stream). 内容相等而非列表同一:宿主每 build 新建列表,按同一性比较
    // 会在任何父重建时从零重打。
    if (!listEquals(old.phrases, widget.phrases) || old.loop != widget.loop) _restart();
  }

  bool get _reduced => AnMotionPref.reducedOrAssistive(context);
  bool get _stopOnThis => !widget.loop && _i == widget.phrases.length - 1;

  void _restart() {
    _c.stop();
    _doneFired = false;
    if (_reduced || widget.phrases.isEmpty) {
      // The static fallback IS the finished state — let a waiting host proceed. 静态兜底即完成态,放宿主走。
      _fireDone();
      return; // build renders the static fallback 静态兜底
    }
    _i = 0;
    _startPhrase();
  }

  void _fireDone() {
    if (widget.loop || _doneFired || widget.onDone == null) return;
    _doneFired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone!();
    });
  }

  void _startPhrase() {
    _i = _i.clamp(0, widget.phrases.length - 1);
    _phrase = widget.phrases[_i];
    _n = _phrase.characters.length;
    _typeMs = _n * AnMotion.typePerChar.inMilliseconds;
    _holdEnd = _typeMs + AnMotion.typeHold.inMilliseconds;
    _delEnd = _holdEnd + _n * AnMotion.deletePerChar.inMilliseconds;
    // The last phrase of a non-looping run types + holds, then STOPS (no delete/gap). 末句不删不留白。
    _total = _stopOnThis ? _holdEnd : _delEnd + AnMotion.typeGap.inMilliseconds;
    _c.duration = Duration(milliseconds: _total <= 0 ? 1 : _total);
    _c.forward(from: 0);
  }

  void _onStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    if (_stopOnThis) {
      _fireDone();
      return;
    }
    _i = (_i + 1) % widget.phrases.length;
    _startPhrase();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Visible (grapheme-safe) slice for the current controller value. 当前值对应的可见切片。
  String _visible(double v) {
    final ms = v * _total;
    if (ms < _typeMs) return _take((ms / AnMotion.typePerChar.inMilliseconds).floor());
    if (ms < _holdEnd) return _phrase;
    if (ms < _delEnd) return _take(_n - ((ms - _holdEnd) / AnMotion.deletePerChar.inMilliseconds).floor());
    return ''; // gap
  }

  String _take(int k) => _phrase.characters.take(k.clamp(0, _n)).join();

  // Solid while typing/deleting; breathes (decision ②: breath period) while holding/gap. 移动实、停顿呼吸。
  double _caretOpacity(double v) {
    final ms = v * _total;
    final moving = ms < _typeMs || (ms >= _holdEnd && ms < _delEnd);
    if (moving) return 1;
    final half = AnMotion.breath.inMilliseconds / 2;
    return (ms ~/ half).isEven ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = widget.textStyle ?? AnText.body.copyWith(color: c.ink);
    final caretColor = widget.accentCaret ? c.accent : c.ink;

    if (_reduced || widget.phrases.isEmpty) {
      final text = widget.phrases.isEmpty ? '' : widget.phrases.first;
      return Semantics(
        label: text.isEmpty ? null : text,
        child: ExcludeSemantics(child: _line(text, widget.showCaret ? 1 : 0, style, caretColor)),
      );
    }

    return Semantics(
      // the COMPLETE current phrase (never the half-typed string); NOT a live region (decorative cycle).
      label: widget.phrases[_i],
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (ctx, _) =>
                _line(_visible(_c.value), widget.showCaret ? _caretOpacity(_c.value) : 0, style, caretColor),
          ),
        ),
      ),
    );
  }

  Widget _line(String text, double caretOpacity, TextStyle style, Color caretColor) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: style)),
          const SizedBox(width: AnSpace.s2),
          Opacity(
            opacity: caretOpacity,
            // Caret hugs the ACTIVE style's glyphs (fontSize + caretRise), same derivation as AnInput.
            // 光标随有效样式(fontSize+caretRise),与 AnInput 同推导。
            child: Container(
              width: AnSize.caret,
              height: (style.fontSize ?? AnText.body.fontSize)! + AnSize.caretRise,
              color: caretColor,
            ),
          ),
          const SizedBox(width: AnSize.caretEndPad), // end-of-line room (flutter#24612) 行尾留位
        ],
      );
}
