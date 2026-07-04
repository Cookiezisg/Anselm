import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/status_state.dart';
import '../../../core/ui/an_edge_fade.dart';
import '../../../core/ui/an_expand_reveal.dart';
import '../../../core/ui/an_interactive.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_shimmer_text.dart';
import '../../../core/ui/an_status_dot.dart';

/// The reasoning ("thinking") block — deliberately NOT the tool_call disclosure (no bordered card, no
/// chevron, no glyph, no brain icon, no mono). Thinking is the model's quiet inner monologue: a thin left
/// ASIDE RAIL (neutral hairline) drops from under a breathing dot, dim prose (`inkMuted`) fills it.
///
/// It is ONE cohesive animated entity across its whole life:
/// - **BORN** (streaming mounts): the label WIPES in left→right ([AnShimmerText.reveal]) while the body
///   EXPANDS open ([AnExpandReveal]).
/// - **STREAMING**: prose flows up in a height-capped window (last [maxLiveLines] lines, bottom-pinned, NO
///   scrollbar, narrow edge-fades) while the label shimmers and the dot breathes.
/// - **SETTLE** (streaming→false): as one dissolve — shimmer stops, the label crossfades "thinking"→
///   "thought for Ns" ([AnimatedSwitcher]), the dot fades out, the window collapses to one quiet line.
/// - **COLLAPSED** (default): just "thought for Ns" — TAP THE TEXT to toggle (no link, no dot).
/// - **EXPAND / COLLAPSE**: a standard reveal ([AnExpandReveal]) of the full thought on the rail.
///
/// Every loop is reduced-motion-gated (shimmer/breath → static) and every reveal snaps under reduced motion.
/// Labels are injected so this stays i18n-agnostic. 纯呈现;标签注入。整条生命线一体、标准动效、无硬切。
class ChatThinking extends StatefulWidget {
  const ChatThinking({
    required this.text,
    required this.streaming,
    required this.liveLabel,
    required this.settledLabel,
    this.maxLiveLines = 5,
    this.initiallyExpanded = false,
    super.key,
  });

  final String text;
  final bool streaming;
  final String liveLabel; // "thinking"
  final String settledLabel; // "thought for 12s"
  final int maxLiveLines;
  final bool initiallyExpanded;

  @override
  State<ChatThinking> createState() => _ChatThinkingState();
}

class _ChatThinkingState extends State<ChatThinking> {
  static const double _fadeLineFraction = 0.55; // narrow edge fade 窄边渐隐

  late bool _expanded = widget.initiallyExpanded;
  late bool _bodyOpen; // BORN driver (streaming window opens) 诞生:窗展开
  bool _settling = false; // keep the flow-window child while the settle-collapse plays 融解时保持流窗内容
  Timer? _settleTimer;

  final ScrollController _scroll = ScrollController();
  bool _hiddenAbove = false, _hiddenBelow = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _bodyOpen = !widget.streaming && widget.initiallyExpanded; // streaming is born CLOSED then opens 流式生而关、随后开
    _scroll.addListener(_onScroll);
    if (widget.streaming) _armBorn();
  }

  // Post-frame open so AnExpandReveal tweens 0→cap (born, not a full-formed paint). 后帧开→补间揭示。
  void _armBorn() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _bodyOpen = true);
      });

  @override
  void didUpdateWidget(ChatThinking old) {
    super.didUpdateWidget(old);
    if (widget.streaming && !old.streaming) {
      _pinned = false;
      _settling = false;
      _bodyOpen = false;
      _armBorn(); // replay → re-born
    } else if (!widget.streaming && old.streaming) {
      // SETTLE: keep rendering the flow window while the body collapses (so it doesn't jump to full prose).
      // 融解:折叠期间保持流窗内容(避免跳成全文)。
      _settling = true;
      _bodyOpen = false;
      _settleTimer?.cancel();
      _settleTimer = Timer(AnMotion.mid, () {
        if (mounted) setState(() => _settling = false);
      });
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final off = _scroll.offset;
    final above = off > 1.0;
    final below = off < max - 1.0;
    if (above != _hiddenAbove || below != _hiddenBelow) {
      setState(() {
        _hiddenAbove = above;
        _hiddenBelow = below;
      });
    }
  }

  TextStyle _prose(AnColors c) => AnText.body.copyWith(color: c.inkMuted);
  TextStyle _label(AnColors c) => AnText.meta.copyWith(color: c.inkFaint);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    final headH = _lineHeight(_label(c));
    final bodyOpen = widget.streaming ? _bodyOpen : _expanded;
    final bodyChild = (widget.streaming || _settling) ? _scrollWindow(c) : Text(widget.text, style: _prose(c));

    // Header: `● thinking` (dot + shimmer) while streaming ⇄ a FLUSH-left, tappable "thought for Ns" once
    // settled. The dot lives INSIDE the streaming child, so the settle crossfade fades it out and the label
    // tops the left edge in one motion. 头:流式 ● thinking(圆点+流光)⇄ 想完的齐左可点 thought for Ns;圆点
    // 在流式子件内,融解交叉淡时圆点一起淡出、标签落到最左,一个动作。
    final header = AnimatedSwitcher(
      duration: reduced ? Duration.zero : AnMotion.mid,
      child: widget.streaming
          ? Row(
              key: const ValueKey('live'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnStatusDot(AnStatus.run),
                const SizedBox(width: AnSpace.s6),
                AnShimmerText(widget.liveLabel, style: _label(c).copyWith(color: c.inkMuted), reveal: true),
              ],
            )
          : KeyedSubtree(key: const ValueKey('settled'), child: _thought(c)),
    );

    final railVisible = bodyOpen || _settling;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The label row tops the LEFT edge (dot inline while streaming; settled "thought" is flush). 头齐左。
            SizedBox(height: headH, child: Align(alignment: Alignment.centerLeft, child: header)),
            const SizedBox(height: AnSpace.s6),
            // Body indented off the rail; ONE AnExpandReveal rides BORN open / SETTLE collapse / EXPAND /
            // COLLAPSE. Full-width child so short prose stays left-aligned (AnExpandReveal centres narrow
            // content). 正文缩进于 rail;一 reveal 通吃四态;满宽使短正文左对齐。
            Padding(
              padding: const EdgeInsets.only(left: AnSize.dot + AnSpace.s6),
              child: AnExpandReveal(open: bodyOpen, child: SizedBox(width: double.infinity, child: bodyChild)),
            ),
          ],
        ),
        // The rail: a hairline under the dot's centre, spanning ONLY the body — so its height IS the body's
        // live height (streaming: grows 1→maxLiveLines; expanded: the full thought; collapsed: gone).
        // 旁白细线:圆点正下,仅贯穿正文→高度=正文实时高(流式 1→5 行;展开=全文;收起=无)。
        if (railVisible)
          Positioned(
            left: AnSize.dot / 2 - AnSize.hairline / 2,
            top: headH + AnSpace.s6,
            bottom: 0,
            child: Container(width: AnSize.hairline, color: c.line),
          ),
      ],
    );
  }

  // The settled label IS the toggle — tap the whole "thought for Ns" text (no chevron, no link). faint→ink
  // on hover/focus; `expanded` drives the SR disclosure announce. 想完标签本身即开关:点整段文字切换。
  Widget _thought(AnColors c) => AnInteractive(
        onTap: _toggle,
        expanded: _expanded,
        builder: (context, states) => Text(
          widget.settledLabel,
          style: _label(c).copyWith(color: states.isActive ? c.ink : c.inkFaint),
        ),
      );

  // The height-capped, bottom-pinned, top/bottom edge-fading flow window — NO scrollbar. Short prose (≤ cap)
  // shows in full. 限高、钉底、边缘渐隐的流窗,无滚动条;短正文全显。
  Widget _scrollWindow(AnColors c) {
    final style = _prose(c);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(text: TextSpan(text: widget.text, style: style), textDirection: TextDirection.ltr)
          ..layout(maxWidth: constraints.maxWidth);
        final lineH = tp.preferredLineHeight;
        final cap = lineH * widget.maxLiveLines;
        final overflows = tp.height > cap + 0.5;
        if (!overflows) return Text(widget.text, style: style);

        if (widget.streaming && !_pinned) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
            _pinned = true;
            _onScroll();
          });
        }
        final fadeH = lineH * _fadeLineFraction;
        return SizedBox(
          height: cap,
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: const AnScrollBehavior(), // no scrollbar 无滚动条
                child: SingleChildScrollView(controller: _scroll, child: Text(widget.text, style: style)),
              ),
              if (_hiddenAbove) _edgeFade(c, top: true, height: fadeH),
              if (_hiddenBelow) _edgeFade(c, top: false, height: fadeH),
            ],
          ),
        );
      },
    );
  }

  Widget _edgeFade(AnColors c, {required bool top, required double height}) => Positioned(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: 0,
        right: 0,
        height: height,
        child: AnEdgeFade(fromTop: top, color: c.surface),
      );

  double _lineHeight(TextStyle s) =>
      (TextPainter(text: TextSpan(text: 'x', style: s), textDirection: TextDirection.ltr)..layout())
          .preferredLineHeight;
}
