import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_editor_stylesheet.dart';

/// The An caret: CONTENT-SIZED, ink-coloured — replaces super_editor's [DefaultCaretOverlayBuilder]
/// (hardcoded 2px `Colors.black` at the FULL LINE-BOX height).
///
/// WHY: the default caret height comes from `getFullHeightForCaret` = fontSize × TextStyle.height — the
/// whole leaded line box. Under the An reading rhythm that's 24.0px for 15px body, 24.3px for 18px H2,
/// 28.6px for 22px H1: four tiers squeezed into 22.5–28.6px while their font sizes differ by 47% — a caret
/// that reads "huge and never follows the content". The standard answer (browsers/Notion: the caret spans
/// the GLYPH box, seated on the baseline, so H1's caret is visibly taller than the body's) is what
/// [AnCaretOverlay] paints: the tight character box at the caret, measured through the PUBLIC
/// [DocumentLayout.getRectForSelection] (document coords, default tight boxes), with the line box only as
/// the fallback frame. Colour rides [AnColors.ink] (the black default is invisible-hostile in dark mode).
///
/// An 光标:内容尺寸+ink 色,替换上游默认(写死 2px 纯黑、整行盒高)。默认高度=fontSize×height 整行盒——阅读
/// 节奏下正文 24.0/H2 24.3/H1 28.6,字号差 47% 的四档全挤在 22.5–28.6px,读作「雷霆大且不随内容变」。标准答案
/// (浏览器/Notion:光标=字形盒、坐基线,H1 光标明显高于正文)即本层所画:经公开 getRectForSelection 量光标处
/// 字符的 tight 盒(文档坐标),行盒仅作兜底框;色走 ink(纯黑在暗色主题不可见)。
class AnCaretOverlayBuilder implements SuperEditorLayerBuilder {
  const AnCaretOverlayBuilder();

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editContext) {
    return AnCaretOverlay(
      composer: editContext.composer,
      document: editContext.document,
      documentLayoutResolver: () => editContext.documentLayout,
      caretStyle: CaretStyle(width: AnSize.caret, color: context.colors.ink),
    );
  }
}

class AnCaretOverlay extends CaretDocumentOverlay {
  const AnCaretOverlay({
    super.key,
    required super.composer,
    required this.document,
    required super.documentLayoutResolver,
    super.caretStyle,
  });

  /// Read-only access to the document, to fetch the extent node's text length + block tier for the caret
  /// probes. 只读文档(取 extent 节点文本长度与块档)。
  final Document document;

  @override
  // The upstream state class is public-but-test-visible; the subclass reuse is deliberate (see the note on
  // _AnCaretOverlayState). 上游 State 公开但标测试可见;此复用是刻意的(见 _AnCaretOverlayState 注)。
  // ignore: invalid_use_of_visible_for_testing_member
  CaretDocumentOverlayState createState() => _AnCaretOverlayState();
}

// Extending the upstream overlay STATE reuses its whole blink/lifecycle machinery and overrides ONLY the
// caret-rect computation — the alternative is vendoring the full ~230-line overlay, a fork that drifts. The
// state class is public but marked test-visible upstream; this is a deliberate, minimal reuse.
// 继承上游 overlay State 复用整套闪烁/生命周期,只覆写矩形计算——否则要整份 vendor(会漂移)。上游把该类标为
// 测试可见,此处是刻意的最小复用。
// ignore: invalid_use_of_visible_for_testing_member
class _AnCaretOverlayState extends CaretDocumentOverlayState {
  @override
  Rect? computeLayoutDataWithDocumentLayout(
      BuildContext contentLayersContext, BuildContext documentContext, DocumentLayout documentLayout) {
    // The upstream rect: correct x/line frame, full line-box height. 上游矩形:x/行框对、高=整行盒。
    final full = super.computeLayoutDataWithDocumentLayout(contentLayersContext, documentContext, documentLayout);
    if (full == null) return null;

    final extent = widget.composer.selection?.extent;
    final nodePosition = extent?.nodePosition;
    // A caret BESIDE an atomic block (arrowing onto a code block / table / image, whose only positions are
    // the block's upstream + downstream edges) keeps upstream's BLOCK-TALL bar: it isn't sitting on text, it
    // is saying "you are beside this whole block", and the height IS that statement (user 0716). Only text
    // positions get the glyph band. 原子块**旁**的光标(方向键落到码块/表格/图上,它们只有块前/块后两个位置)
    // 保持上游的**整块高**竖条:它不坐在文字上,而是在说「你在这一整块旁边」,高度就是这句话本身(用户 0716 定)。
    // 只有文本位置才走字形带。
    if (extent == null || nodePosition is! TextNodePosition) return full;
    final node = (widget as AnCaretOverlay).document.getNodeById(extent.nodeId);
    if (node is! TextNode) return full;

    // Probe the character AT the caret (or the one before, at text end) for its tight glyph box —
    // getRectForSelection over a single character returns the DEFAULT (tight) boxes in document coordinates,
    // so both position and height are exact and no component internals are touched.
    // 探光标处字符(文末取前一个)的 tight 字形盒——单字符 getRectForSelection 返回文档坐标的紧盒,位置高度皆准。
    final length = node.text.length;
    Rect? glyph;
    if (length > 0) {
      final offset = nodePosition.offset;
      final (start, end) = offset < length ? (offset, offset + 1) : (offset - 1, offset);
      glyph = documentLayout.getRectForSelection(
        DocumentPosition(nodeId: extent.nodeId, nodePosition: TextNodePosition(offset: start)),
        DocumentPosition(nodeId: extent.nodeId, nodePosition: TextNodePosition(offset: end)),
      );
    }
    final band = anCaretBand(
      glyph: glyph,
      lineTop: full.top,
      lineHeight: full.height,
      fontSize: anBlockBaseStyle(node).fontSize ?? AnText.reading.fontSize!,
    );
    return Rect.fromLTWH(full.left, band.top, full.width, band.height);
  }
}

/// **The ONE caret-height rule**, shared by every An caret (the document overlay AND [AnFieldCaret]) so a
/// caret is measured the same way wherever it lands — the law's "hug the style" made literal:
///  • there is a glyph under/next to the caret → sit on its MEASURED tight box, so the caret automatically
///    follows the run it's on (mono 13 inside prose 15, a heading, a table cell) with no formula to drift;
///  • nothing to measure (empty text) → the house formula, [fontSize] + [AnSize.caretRise], centred in the
///    line box (and never taller than it).
/// Pure → the rule is unit-testable without a layout. 唯一光标高规则,全部 An 光标共用(文档层与字段层),故光标
/// 落在哪都按同一套量:①光标处/旁有字形 → 坐它**实测**的 tight 盒,于是自动随所在 run 走(正文 15 里的 mono 13、
/// 标题、表格格),无公式可漂;②无字形可量(空文本)→ 房内公式 fontSize+caretRise、行盒内居中(且绝不高过行盒)。
/// 纯函数 → 规则可脱布局单测。
({double top, double height}) anCaretBand({
  required Rect? glyph,
  required double lineTop,
  required double lineHeight,
  required double fontSize,
}) {
  if (glyph != null && glyph.height > 0) return (top: glyph.top, height: glyph.height);
  final height = math.min(lineHeight, fontSize + AnSize.caretRise);
  return (top: lineTop + (lineHeight - height) / 2, height: height);
}

/// The An caret for a [SuperTextField] — the ONE way to give a package field the house caret height.
///
/// WHY a whole layer: `SuperTextField` paints its caret through super_text_layout's `TextLayoutCaret`,
/// whose height is `textLayout.getHeightForCaret()` = the full leaded LINE BOX (measured 24.0 for the
/// reading 15/1.6 tier — a third taller than the law's 18), and [CaretStyle] has NO height slot while the
/// field exposes no caret-layer hook. So the built-in caret is hidden (transparent) and this paints ours
/// over the field, reading the field's own PUBLIC [SuperTextFieldState.textLayout] for the offset.
///
/// The geometry is read at PAINT time (the same move the inline-code background painter makes): paint runs
/// after the field's layout in the SAME frame, so the caret never lags a frame behind the text — which a
/// post-frame `setState` would cost on every keystroke.
///
/// SuperTextField 的 An 光标——给包内字段套上房内光标高的唯一办法。为何要整层:SuperTextField 的光标经
/// super_text_layout 的 TextLayoutCaret 画,高=getHeightForCaret=**整行盒**(reading 15/1.6 档实测 24.0,
/// 比法定 18 高三分之一),而 CaretStyle **无 height 槽**、字段也不暴露 caret 层钩子。故:内建光标透明藏掉,
/// 本层叠在字段上自画,位置读字段自己**公开**的 SuperTextFieldState.textLayout。几何在**绘制期**取(与行内
/// 代码背景 painter 同招):绘制在同帧的字段布局之后跑,故光标绝不落后一帧——而 post-frame setState 会让每
/// 次按键都付这一帧。
class AnFieldCaret extends StatefulWidget {
  const AnFieldCaret({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    required this.color,
  });

  /// The field this caret belongs to — its [SuperTextFieldState.textLayout] gives the caret offset.
  final GlobalKey<SuperTextFieldState> fieldKey;
  final AttributedTextEditingController controller;
  final FocusNode focusNode;

  /// The field's effective font size — the caret is [fontSize] + [AnSize.caretRise] tall (the house law).
  final double fontSize;
  final Color color;

  @override
  State<AnFieldCaret> createState() => _AnFieldCaretState();
}

class _AnFieldCaretState extends State<AnFieldCaret> with SingleTickerProviderStateMixin {
  late final BlinkController _blink;

  @override
  void initState() {
    super.initState();
    _blink = BlinkController(tickerProvider: this);
    widget.controller.addListener(_onCaretMoved);
    widget.focusNode.addListener(_onCaretMoved);
    _syncBlink();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCaretMoved);
    widget.focusNode.removeListener(_onCaretMoved);
    _blink.dispose();
    super.dispose();
  }

  // Restart the blink opaque whenever the caret moves (the platform behaviour every editor has: you never
  // lose the caret mid-keystroke). 光标一动就重置为不透明(平台通行:打字中绝不丢光标)。
  void _onCaretMoved() {
    _blink.jumpToOpaque();
    _syncBlink();
  }

  void _syncBlink() {
    final wants = widget.focusNode.hasFocus && widget.controller.selection.isCollapsed;
    if (wants && !_blink.isBlinking) {
      _blink.startBlinking();
    } else if (!wants && _blink.isBlinking) {
      _blink.stopBlinking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _AnFieldCaretPainter(
          fieldKey: widget.fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          blink: _blink,
          fontSize: widget.fontSize,
          color: widget.color,
        ),
      ),
    );
  }
}

class _AnFieldCaretPainter extends CustomPainter {
  _AnFieldCaretPainter({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.blink,
    required this.fontSize,
    required this.color,
  }) : super(repaint: Listenable.merge([controller, focusNode, blink]));

  final GlobalKey<SuperTextFieldState> fieldKey;
  final AttributedTextEditingController controller;
  final FocusNode focusNode;
  final BlinkController blink;
  final double fontSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (!focusNode.hasFocus) return;
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return; // expanded → the band shows it, no caret 有选区不画
    // SuperTextFieldState.textLayout is public API but marked test-visible upstream; it is the ONLY seam
    // that gives a field's caret geometry, and reading it is exactly what this layer exists for.
    // 该 getter 上游标了测试可见,但它是取字段光标几何的唯一缝——本层的存在理由即此。
    // ignore: invalid_use_of_visible_for_testing_member
    final layout = fieldKey.currentState?.textLayout;
    if (layout == null) return; // not laid out yet — the next paint has it 尚未布局,下帧即有

    final position = TextPosition(offset: selection.extentOffset, affinity: selection.affinity);
    final offset = layout.getOffsetForCaret(position); // caret TOP-left within its line box 行盒内的光标左上
    final lineHeight = layout.getHeightForCaret(position) ?? layout.getLineHeightAtPosition(position);
    // The SAME probe the document caret makes: the character at the caret (or the one before, at text end),
    // tight box (getBoxesForSelection defaults to BoxHeightStyle.tight). 与文档光标**同一个**探针:光标处字符
    // (文末取前一个)的 tight 盒(getBoxesForSelection 默认即 tight)。
    final length = controller.text.length;
    Rect? glyph;
    if (length > 0) {
      final at = selection.extentOffset;
      final (start, end) = at < length ? (at, at + 1) : (at - 1, at);
      final boxes = layout.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end));
      if (boxes.isNotEmpty) glyph = boxes.last.toRect();
    }
    final band = anCaretBand(glyph: glyph, lineTop: offset.dy, lineHeight: lineHeight, fontSize: fontSize);
    canvas.drawRect(
      Rect.fromLTWH(offset.dx - AnSize.caret / 2, band.top, AnSize.caret, band.height),
      Paint()..color = color.withValues(alpha: blink.opacity),
    );
  }

  @override
  bool shouldRepaint(_AnFieldCaretPainter old) =>
      old.fontSize != fontSize || old.color != color || old.controller != controller || old.focusNode != focusNode;
}

