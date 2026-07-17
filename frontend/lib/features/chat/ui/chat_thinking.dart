import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/status_state.dart';
import '../../../core/ui/an_expand_reveal.dart';
import '../../../core/ui/an_interactive.dart';
import '../../../core/ui/an_live_tail.dart';
import '../../../core/ui/an_shimmer_text.dart';
import '../../../core/ui/an_status_dot.dart';
import '../../../core/ui/text_measure.dart';

/// The reasoning ("thinking") block — deliberately NOT the tool_call disclosure (no bordered card, no
/// chevron, no glyph, no brain icon, no mono). Thinking is the model's quiet inner monologue: a thin left
/// ASIDE RAIL (neutral hairline) drops from under a breathing dot, dim prose (`inkMuted`) fills it.
///
/// It is ONE cohesive animated entity across its whole life:
/// - **BORN** (streaming mounts): the label WIPES in left→right ([AnShimmerText.reveal]) while the body
///   EXPANDS open ([AnExpandReveal]).
/// - **STREAMING**: prose flows up in the live-tail family's BARE prose face ([AnLiveTail] — bottom-
///   pinned clamp, top fade on overflow, no window chrome: thinking stays inline prose, WRK-066 族六)
///   while the label shimmers and the dot breathes.
/// - **SETTLE** (streaming→false): as one dissolve — shimmer stops, the label crossfades "thinking"→
///   "thought for Ns" ([AnimatedSwitcher]), the dot fades out, the window collapses to one quiet line.
/// - **COLLAPSED** (default): just "thought for Ns" — TAP THE TEXT to toggle (no link, no dot).
/// - **EXPAND / COLLAPSE**: a standard reveal ([AnExpandReveal]) of the full thought on the rail.
///
/// Every loop is reduced-motion-gated (shimmer/breath → static) and every reveal snaps under reduced motion.
/// Labels are injected so this stays i18n-agnostic. 纯呈现;标签注入;流式体=活尾族 prose 无框脸(贴底钳+
/// 溢出顶渐隐,thinking 保持内联散文、不披机器窗)。
class ChatThinking extends StatefulWidget {
  const ChatThinking({
    required this.text,
    required this.streaming,
    required this.liveLabel,
    required this.settledLabel,
    this.initiallyExpanded = false,
    super.key,
  });

  final String text;
  final bool streaming;
  final String liveLabel; // "thinking"
  final String settledLabel; // "thought for 12s"
  final bool initiallyExpanded;

  @override
  State<ChatThinking> createState() => _ChatThinkingState();
}

class _ChatThinkingState extends State<ChatThinking> {
  late bool _expanded = widget.initiallyExpanded;
  late bool _bodyOpen; // BORN driver (streaming window opens) 诞生:窗展开
  bool _settling = false; // keep the flow-window child while the settle-collapse plays 融解时保持流窗内容
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    _bodyOpen = !widget.streaming && widget.initiallyExpanded; // streaming is born CLOSED then opens 流式生而关、随后开
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
    super.dispose();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  // Thinking is CONTENT the person reads — the 15 reading rung like the answer beside it; the quiet
  // secondary voice comes from inkMuted COLOUR alone (size+colour double-demotion over-suppressed it).
  // The label ('thinking'/'thought for Ns') is content-tier metadata → label 13, never meta 12 inside
  // the content column. thinking=人读的内容:与答案同 15 阅读档,「安静次要声」只靠 inkMuted 颜色降权
  // (字号+颜色双重压制过了);标签=内容内元数据 → label 13(内容列内不用 12)。
  TextStyle _prose(AnColors c) => AnText.reading.copyWith(color: c.inkMuted);
  TextStyle _label(AnColors c) => AnText.label.copyWith(color: c.inkFaint);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    final headH = _lineHeight(_label(c));
    final bodyOpen = widget.streaming ? _bodyOpen : _expanded;
    // STREAMING: the family's bare prose face — bottom-pinned clamp (the newest words stay visible),
    // top fade only on real overflow. C-004 dies on BOTH counts: the TextPainter probe is gone AND
    // the head slices its own O(tail) before layout (a long thought no longer re-shapes in full
    // every delta frame). 流式=族六 prose 无框脸:贴底钳(最新字恒可见)+真溢出顶渐隐。C-004 两半皆灭:
    // TextPainter 探针没了,且族头先切尾再排版(长思考不再每 delta 全文重排)。
    final bodyChild = (widget.streaming || _settling)
        ? AnLiveTail(widget.text, style: AnLiveTailStyle.prose, bare: true)
        : Text(widget.text, style: _prose(c));

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
              padding: const EdgeInsets.only(left: AnIndent.dot),
              child: AnExpandReveal(open: bodyOpen, child: SizedBox(width: double.infinity, child: bodyChild)),
            ),
          ],
        ),
        // The rail: a hairline under the dot's centre, spanning ONLY the body — so its height IS the body's
        // live height (streaming: grows to the prose clamp; expanded: the full thought; collapsed: gone).
        // 旁白细线:圆点正下,仅贯穿正文→高度=正文实时高(流式长到 prose 钳;展开=全文;收起=无)。
        if (railVisible)
          Positioned(
            left: 0,
            top: headH + AnSpace.s6,
            bottom: 0,
            // Centred structurally inside the dot's slot — no /2 arithmetic. 结构化居中于点槽,无除法算术。
            child: SizedBox(
              width: AnSize.dot,
              child: Center(child: Container(width: AnSize.hairline, color: c.line)),
            ),
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

  double _lineHeight(TextStyle s) =>
      // A single-glyph paint for the label's line box — O(1) per build, NOT the C-004 whole-text path.
      // 单字形量行盒,O(1)/build,非 C-004 全文路径。
      measureText(TextSpan(text: 'x', style: s), read: (tp) => tp.preferredLineHeight);
}
