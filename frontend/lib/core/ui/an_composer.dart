import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'text_measure.dart';

/// The composer CHROME primitive (the demo `an-composer` evolving input) — a text box that is a rounded
/// PILL on one line and morphs to a CARD as the text wraps to ≥2 lines, reflowing from a single
/// `[lead · edit · tail]` row to a ChatGPT-style stack (edit on top, the [lead]/[trailing] actions dropped
/// to a row below). It owns ONLY the visual shell + the typed [TextField] + a decoupled accent focus halo;
/// ALL behaviour — send/stop, @-mention typeahead, attachment uploads, key handling — stays with the host,
/// injected as the [lead] actions, the [trailing] morph, and an optional [attachments] strip.
///
/// Motion (every transition animated, no hard cuts; all gated to instant under reduced-motion):
/// - SHAPE MORPH pill↔card + every height change (reflow, attachments) ride ONE [AnimatedSize] + the
///   [AnimatedContainer] radius, co-timed at [AnMotion.slow]/`spring` so corners round AS the box grows.
/// - The FOCUS halo is a DECOUPLED accent layer that fades at [AnMotion.fast] (an affordance mustn't ride the
///   slow shape morph); the base border stays neutral [AnColors.line].
/// - The TRAILING slot is an [AnimatedSwitcher] (scale+fade, [AnMotion.mid]) so the send button appears on
///   first keystroke and swaps to stop while generating in ONE place. **The host must KEY its trailing
///   widgets** (`ValueKey('send')` / `ValueKey('stop')`) so they cross-fade rather than snap, AND size
///   them the SAME control tier as [lead] — the single row is height-maxed across its children, so a
///   taller trailing popping in grows the whole box by the tier delta (the "field suddenly gets taller
///   on the first keystroke" bug).
///
/// composer chrome 原语。演变输入:单行药丸 ↔ 多行卡片 + reflow。只拥视觉壳 + TextField + 解耦聚焦光环;行为留宿主。
/// 动效(每个转移都动、无硬切、reduced 即时):① 形变+一切高度变化(reflow/附件)走一个 AnimatedSize + 半径
/// AnimatedContainer,slow/spring 同时——圆角随盒长大;② 聚焦光环=解耦 accent 覆层、fast 淡入(反馈不该骑 slow
/// 形变),基础边恒中性 line;③ trailing 是 AnimatedSwitcher(scale+fade,mid),send 首键出现、生成时换 stop 一处
/// 搞定——**宿主须给 trailing 加 key**(ValueKey('send')/('stop'))才交叉淡、不硬切,**且与 lead 同控件档**——
/// 单行高取子件 max,更高档的 trailing 首键出现会把整盒撑高一档(「首键突长高」bug)。可复用。
class AnComposer extends StatefulWidget {
  const AnComposer({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    this.lead = const [],
    this.trailing,
    this.attachments,
    this.floating = false,
    this.readOnly = false,
    this.focusHalo = true,
    this.accentHalo = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;

  /// Leading actions (e.g. @ mention, 📎 attach). 左侧动作(@/📎)。
  final List<Widget> lead;

  /// Trailing action — the send↔stop morph; null = none (empty input). KEY it for the cross-fade. 右侧动作。
  final Widget? trailing;

  /// An optional strip ABOVE the input (e.g. attachment chips). 输入上方的条(附件 chip)。
  final Widget? attachments;

  /// Landing (New-chat) variant: lift the box with a float shadow. 落地态:浮起阴影。
  final bool floating;

  /// Keeps the visual shell in place while its host is completing an action. 宿主动作落定前只读。
  final bool readOnly;

  /// Whether ordinary field focus lights the accent halo. 一般输入焦点是否点亮 accent 光环。
  final bool focusHalo;

  /// Host-driven accent moment, independent of focus (for commit/activation transitions).
  /// 宿主驱动的 accent 时刻,独立于焦点(提交/激活过渡)。
  final bool accentHalo;

  @override
  State<AnComposer> createState() => _AnComposerState();
}

class _AnComposerState extends State<AnComposer> {
  // Reserve for the single-line lead + tail + gaps, used to count wrapped lines AGAINST A FIXED width (so the
  // multiline decision can't oscillate with the layout it drives). It derives from the actual number of
  // lead actions plus the trailing slot, so a leadless host doesn't inherit Chat's two phantom controls;
  // Chat's two-lead + one-tail threshold remains unchanged.
  // 单行 lead/tail/间距留位(固定参考宽防判定抖)。按实际 lead 数 + trailing 槽推导:无 lead 宿主不继承
  // Chat 的两个幽灵控件位,而 Chat 的双 lead + 单 tail 阈值原样不动。
  double get _singleLineReserve =>
      (widget.lead.length + 1) * AnSize.row +
      (widget.lead.isEmpty ? AnSpace.s0 : AnSpace.s4) +
      AnSpace.s8 +
      2 * AnSpace.s12 +
      AnSpace.s24;

  // Left inset for the wrapped-text line so its optical left edge lands flush with the lead icon glyph on the
  // row below — derived from the md control-box / glyph pair the lead actually uses; a leadless host
  // disables it entirely. 换行文字左内距,使其光学左缘与下排图标字形齐平;派生自 lead 实际使用的 md
  // 控件盒/字形配对;无 lead 宿主直接归零。
  static const double _wrapTextInset =
      (AnSize.control - AnSize.icon) / 2 - AnSize.hairline;

  // Internal scroll cap for the edit field — 7 reading lines (the 15/1.6 = 24px line box), then scroll.
  // 编辑区滚动上限:7 个阅读行盒(24px),超则内滚。
  static final double _editMaxHeight =
      AnText.reading.fontSize! * AnText.reading.height! * 7;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AnComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onChange() =>
      setState(() {}); // re-evaluate the pill↔card line count 重算行数
  void _onFocus() => setState(() {}); // re-fade the focus halo 聚焦光环重淡

  /// The ONE TextField identity across the pill↔card morph. The single-line and multiline rows are
  /// DIFFERENT subtrees; without a GlobalKey the reflow would destroy and rebuild EditableText's
  /// State — dropping focus, caret and the live IME session on the very first wrap (用户 0719 真机:
  /// 「变多行光标就丢、点半天回不来」的根因). GlobalKey reparenting moves the element — state intact.
  /// pill↔card 两棵子树里同一把 GlobalKey:无它则跨行即销毁重建 EditableText State——焦点/光标/IME
  /// 会话全丢(用户 0719 真机根因);有它则 element 整体搬家、状态原样。
  final GlobalKey _editKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final haloVisible =
        widget.accentHalo || (widget.focusHalo && widget.focusNode.hasFocus);
    final reduced = AnMotionPref.reduced(context);
    final shape = reduced
        ? Duration.zero
        : AnMotion.slow; // box morph + height 形变+高度
    final feedback = reduced ? Duration.zero : AnMotion.fast; // focus 反馈

    return LayoutBuilder(
      builder: (context, constraints) {
        final editWidth = (constraints.maxWidth - _singleLineReserve).clamp(
          80.0,
          double.infinity,
        );
        // multiline = TEXT wraps ≥2 lines (drives the reflow); tall = box is taller than one line for ANY
        // reason (wrap OR attachments) → card radius. 换行→reflow;高于一行(换行或附件)→卡片圆角。
        final multiline =
            _countLines(widget.controller.text, AnText.reading, editWidth) >= 2;
        final tall = multiline || widget.attachments != null;
        final radius = BorderRadius.circular(
          tall ? AnRadius.card : AnRadius.pill,
        );

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.attachments != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AnSpace.s8,
                  left: AnSpace.s4,
                ),
                // Keep the attachment strip as a native AX boundary. Flutter's macOS bridge can
                // otherwise prune compact chips nested below AnimatedSize/Wrap while the pixels remain
                // visible; this wrapper has no paint or layout of its own.
                // 附件条固定成原生 AX 边界。否则 macOS 桥可能在 AnimatedSize/Wrap 下裁掉紧凑 chip,虽然像素仍在;
                // 该包装不产生绘制或布局。
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: widget.attachments!,
                ),
              ),
            multiline ? _multilineRow(context, c) : _singleRow(context, c),
          ],
        );

        // A decoupled focus layer (fades FAST — an affordance mustn't ride the slow shape morph). The glow
        // sits BEHIND the white box so its interior is covered (only the outer ring shows, NO blue fill); the
        // accent border sits ON TOP so it reads on the edge. 解耦聚焦层(fast 淡入):辉光在白盒**背后**(内部被盖、
        // 只露外圈、无蓝内填),accent 描边在**上面**(只在边缘)。
        Widget focusLayer({
          required Key opacityKey,
          required BoxDecoration decoration,
        }) => Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              key: opacityKey,
              opacity: haloVisible ? 1 : 0,
              duration: feedback,
              curve: AnMotion.easeOut,
              child: AnimatedContainer(
                duration: shape,
                curve: AnMotion.spring,
                decoration: decoration,
              ),
            ),
          ),
        );
        // Keep one explicit native boundary around the complete composer subtree. The macOS
        // embedder may otherwise prune the attachment strip below Stack/AnimatedSize even though
        // the editable field survives. This wrapper has no paint or layout of its own.
        // 整个 composer 子树固定一个原生语义边界。macOS embedder 可能裁掉 Stack/AnimatedSize 下的附件条,
        // 但保留输入框;该包装不产生绘制或布局。
        return Semantics(
          container: true,
          explicitChildNodes: true,
          child: Stack(
            children: [
              // 0 — the soft outer glow, BEHIND (interior gets covered by the box). 辉光在后。
              focusLayer(
                opacityKey: const ValueKey('composer-halo-glow'),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: c.accentSoft,
                      spreadRadius: AnSpace.s2,
                      blurRadius: AnSpace.s4,
                    ),
                  ],
                ),
              ),
              // 1 — the box itself (opaque white covers the glow's interior). 白盒盖住辉光内部。
              AnimatedContainer(
                duration: shape,
                curve: AnMotion.spring,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: radius,
                  border: Border.all(
                    color: c.line,
                    width: AnSize.hairline,
                  ), // base border neutral 基础边中性
                  boxShadow: widget.floating ? c.shadowFloat : null,
                ),
                // 12 horizontal / 8 vertical — the 15-input proportion (modern chat composers run
                // 12-16h/10-12v; with the 28 md controls the single-line pill lands inside
                // the 44-52 industry band). 横 12 纵 8:15 号输入的配比(单行药丸高 50,业界 44-52)。
                padding: const EdgeInsets.symmetric(
                  horizontal: AnSpace.s12,
                  vertical: AnSpace.s8,
                ),
                // ONE size animation for the reflow / attachments height delta; radius co-times above. 一 size 动画。
                child: AnimatedSize(
                  duration: shape,
                  curve: AnMotion.spring,
                  alignment: Alignment.topCenter,
                  child: content,
                ),
              ),
              // 2 — the accent ring, ON TOP (edge only, no fill, no shadow). accent 描边在上、仅边缘。
              focusLayer(
                opacityKey: const ValueKey('composer-halo-ring'),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: c.accentLine,
                    width: AnSize.hairline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Keep the action groups as explicit semantics containers. Flutter's macOS bridge can otherwise
  // flatten icon-only children of a Row into the visual shell while retaining the TextField, which
  // leaves a mouse-visible composer action absent from AX. The wrapper has no paint or layout of its
  // own; it only preserves the child buttons as independently actionable nodes.
  // 动作组显式保留为语义容器。否则 Flutter 的 macOS bridge 可能把 Row 里的纯图标子项压进视觉壳、只留下
  // TextField,导致眼睛看得到、AX 却找不到。该包装不改变绘制或布局,只保留独立可操作的子按钮节点。
  Widget _leadSemantics() => Semantics(
    container: true,
    explicitChildNodes: true,
    child: Row(mainAxisSize: MainAxisSize.min, children: widget.lead),
  );

  Widget _trailingSemantics() =>
      Semantics(container: true, explicitChildNodes: true, child: _trailing());

  // Single line: [lead · edit · tail]. 单行。
  Widget _singleRow(BuildContext context, AnColors c) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _leadSemantics(),
      if (widget.lead.isNotEmpty) const SizedBox(width: AnSpace.s4),
      Expanded(child: _editField(context, c)),
      const SizedBox(width: AnSpace.s8),
      _trailingSemantics(),
    ],
  );

  // Multiline: edit on top, actions dropped to a row below. 多行:edit 占整行 + 钮组下移。
  Widget _multilineRow(BuildContext context, AnColors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.only(
          left: widget.lead.isEmpty ? AnSpace.s0 : _wrapTextInset,
          right: AnSpace.s6,
        ),
        child: _editField(context, c),
      ),
      const SizedBox(height: AnSpace.s4),
      Row(children: [_leadSemantics(), const Spacer(), _trailingSemantics()]),
    ],
  );

  // The trailing slot: send appears on first keystroke, swaps to stop while generating — scale+fade in ONE
  // switcher. `none` is a keyed empty box so the switch is a real cross-fade. 右侧:一个 switcher 管出现+send↔stop。
  Widget _trailing() => AnimatedSwitcher(
    duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid,
    transitionBuilder: (child, anim) => ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1).animate(anim),
      child: FadeTransition(opacity: anim, child: child),
    ),
    child: widget.trailing ?? const SizedBox.shrink(key: ValueKey('none')),
  );

  Widget _editField(BuildContext context, AnColors c) => KeyedSubtree(
    key:
        _editKey, // reparent, never rebuild, across the pill↔card subtree swap 跨形变搬家不重建
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: _editMaxHeight,
      ), // 7 reading lines then internal scroll 7 行后内滚
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        enableInteractiveSelection: !widget.readOnly,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        // The composer is a PROSE surface — the message a person writes reads on the 15 reading rung,
        // matching the assistant bubble (AnMarkdown) it will sit beside. composer 是 prose 面:人写的
        // 消息走 15 阅读档,与旁边的助手泡(AnMarkdown)同档。
        style: AnText.reading.copyWith(color: c.ink),
        cursorColor: c.ink,
        cursorWidth: AnSize.caret,
        // Hug the 15 glyphs (same fontSize+caretRise derivation as AnInput) — the default fills
        // the whole 24px reading line box. 光标贴 15 字形(同 AnInput 推导),默认会顶满 24px 行盒。
        cursorHeight: AnText.reading.fontSize! + AnSize.caretRise,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.placeholder,
          hintStyle: AnText.reading.copyWith(color: c.inkFaint),
        ),
        onTapOutside:
            (_) {}, // desktop: keep focus when clicking elsewhere 桌面:点外不失焦
      ),
    ),
  );

  // Count the lines the text wraps to at [maxWidth] (soft-wrap aware) — drives the single↔multiline morph.
  // 行数估算驱动演变。
  static int _countLines(String text, TextStyle style, double maxWidth) {
    if (text.trim().isEmpty) return 1;
    return measureText(
      TextSpan(text: text, style: style),
      maxWidth: maxWidth,
      read: (tp) => tp.computeLineMetrics().length,
    );
  }
}
