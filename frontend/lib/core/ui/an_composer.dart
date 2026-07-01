import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The composer CHROME primitive (the demo `an-composer` evolving input) — a text box that is a rounded
/// PILL on one line and morphs to a CARD as the text wraps to ≥2 lines, reflowing from a single
/// `[lead · edit · tail]` row to a ChatGPT-style stack (edit on top, the [lead]/[trailing] actions dropped
/// to a row below). It owns ONLY the visual shell + the typed [TextField] (driven by the injected
/// [controller]/[focusNode]) + a small accent focus halo; ALL behaviour — send/stop, @-mention typeahead,
/// attachment uploads, key handling — stays with the host, injected as the [lead] actions, the [trailing]
/// morph, and an optional [attachments] strip. The send button is the host's concern too: pass `trailing:
/// null` to hide it (empty input), the send glyph when there's content, the stop glyph while generating.
/// Reusable: any future composer (a doc-comment box, a search-with-actions) gets the same evolving shell.
///
/// composer chrome 原语(demo an-composer 演变输入):单行=药丸、≥2 行→card 并 reflow(单行 [lead·edit·tail] →
/// ChatGPT 式 edit 占整行 + lead/tail 行下移)。只拥有视觉壳 + 类型化 TextField(由注入的 controller/focusNode
/// 驱动)+ 一圈轻 accent 聚焦光环;所有行为(send/stop、@提及、附件、键)留宿主,经 lead/trailing/attachments 注入。
/// 发送钮也归宿主:trailing=null 藏(空输入)、给 send 字形(有内容)、给 stop 字形(生成中)。可复用。
class AnComposer extends StatefulWidget {
  const AnComposer({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    this.lead = const [],
    this.trailing,
    this.attachments,
    this.floating = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;

  /// Leading actions (e.g. @ mention, 📎 attach) — left of the edit (single line) or the bottom-left
  /// action row (multiline). 左侧动作(@/📎)。
  final List<Widget> lead;

  /// Trailing action (e.g. the send↔stop morph) — right of the edit / bottom-right; null = none. 右侧动作。
  final Widget? trailing;

  /// An optional strip ABOVE the input (e.g. attachment chips). 输入上方的条(附件 chip)。
  final Widget? attachments;

  /// Landing (New-chat) variant: lift the box with a float shadow (demo `:host([pill])`). Docked = false.
  /// 落地(新对话)态:给盒加浮起阴影;停靠态=false。
  final bool floating;

  @override
  State<AnComposer> createState() => _AnComposerState();
}

class _AnComposerState extends State<AnComposer> {
  // Reserve for the single-line lead + tail + gaps, used to count wrapped lines AGAINST A FIXED width (so the
  // multiline decision can't oscillate with the layout it drives). 单行 lead/tail/间距留位(固定参考宽防判定抖)。
  static const double _singleLineReserve = 124;

  // Left inset for the wrapped-text line so its optical left edge lands flush with the lead icon glyph on the
  // row below. The glyph is centered in the (square, `control`-wide) icon button, so its box sits at
  // (control − icon)/2 from the button's left; pull in ONE hairline more so the text — whose left bearing
  // (CJK especially) reads a touch heavier than the icon glyph — sits pixel-flush with it (measured). Derived
  // from the button geometry so it self-heals if the control/icon sizes retune.
  // 换行文字的左内距,使其光学左缘与下排图标字形齐平:字形在方形(control 宽)图标钮内居中→盒在 (control−icon)/2 处;
  // 再收一个 hairline,让左内切略重的文字(尤 CJK)与图标像素级贴齐(实测)。派生自按钮几何,尺寸重调时自愈。
  static const double _wrapTextInset = (AnSize.control - AnSize.icon) / 2 - AnSize.hairline;

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

  void _onChange() => setState(() {}); // re-evaluate the pill↔card line count 重算行数
  void _onFocus() => setState(() {}); // re-tint the focus halo 聚焦光环重绘

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final focused = widget.focusNode.hasFocus;
    return LayoutBuilder(
      builder: (context, constraints) {
        final editWidth = (constraints.maxWidth - _singleLineReserve).clamp(80.0, double.infinity);
        // `multiline` = the TEXT wraps to ≥2 lines → drives the ROW reflow (edit on top, actions below).
        // `tall` = the box is taller than one line for ANY reason (wrapped text OR an attachment strip) →
        // drives the CARD radius: a full pill is only for a genuine single line with nothing above it, so a
        // chip strip settles the corners to card even while the input itself stays one row.
        // multiline=文字换行(驱动钮组下移 reflow);tall=盒子高于一行的任何情形(换行 或 附件条)→驱动卡片圆角:
        // 全药丸只留给「单行且上方无物」,附件条即便输入仍单行也把圆角落到卡片。
        final multiline = _countLines(widget.controller.text, AnText.body, editWidth) >= 2;
        final tall = multiline || widget.attachments != null;
        final shadows = <BoxShadow>[
          if (widget.floating) ...c.shadowFloat,
          // A little accent halo on focus — a soft, low-alpha accent glow (demo .box:focus-within).
          // 聚焦一圈轻 accent 光环(低透明柔光)。
          if (focused) BoxShadow(color: c.accentSoft, spreadRadius: AnSpace.s2, blurRadius: AnSpace.s4),
        ];
        return AnimatedContainer(
          // The pill→card morph is a functional reflow (mirrors the wrap); gate it under reduced-motion.
          // 药丸→卡片演变是功能性 reflow;reduced-motion 下不动。
          duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.slow,
          curve: AnMotion.spring,
          decoration: BoxDecoration(
            color: c.surface,
            // radius evolves pill → card the moment the box is taller than one line. 半径随「高于一行」落卡片。
            borderRadius: BorderRadius.circular(tall ? AnRadius.card : AnRadius.pill),
            // Focus halo: accent inset border + the soft accent ring above. 聚焦:accent 边 + 上方柔光环。
            border: Border.all(color: focused ? c.accentLine : c.line, width: AnSize.hairline),
            boxShadow: shadows.isEmpty ? null : shadows,
          ),
          padding: const EdgeInsets.all(AnSpace.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.attachments != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AnSpace.s8, left: AnSpace.s4),
                  child: widget.attachments!,
                ),
              if (multiline)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // edit's optical left edge aligns to the lead icon glyph on the row below (see _wrapTextInset).
                    // 文字光学左缘对齐下排图标字形(见 _wrapTextInset)。
                    Padding(
                      padding: const EdgeInsets.fromLTRB(_wrapTextInset, 0, AnSpace.s6, 0),
                      child: _editField(context, c),
                    ),
                    const SizedBox(height: AnSpace.s4),
                    Row(children: [
                      ...widget.lead,
                      const Spacer(),
                      if (widget.trailing != null) widget.trailing!,
                    ]),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ...widget.lead,
                    const SizedBox(width: AnSpace.s4),
                    Expanded(child: _editField(context, c)),
                    const SizedBox(width: AnSpace.s8),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _editField(BuildContext context, AnColors c) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: AnSize.row * 6 - AnSpace.s8 * 2), // ~6 lines then internal scroll
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          minLines: 1,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: AnText.body.copyWith(color: c.ink),
          cursorColor: c.ink,
          cursorWidth: AnSize.caret,
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: widget.placeholder,
            hintStyle: AnText.body.copyWith(color: c.inkFaint),
          ),
          onTapOutside: (_) {}, // desktop: keep focus when clicking elsewhere 桌面:点外不失焦
        ),
      );

  // Count the lines the text wraps to at [maxWidth] (soft-wrap aware) — drives the single↔multiline morph.
  // Pills render as their @label runs (same-ish width), so plain text is a close enough proxy. 行数估算驱动演变。
  static int _countLines(String text, TextStyle style, double maxWidth) {
    if (text.trim().isEmpty) return 1;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return tp.computeLineMetrics().length;
  }
}
