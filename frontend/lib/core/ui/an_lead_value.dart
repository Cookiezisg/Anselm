import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// Dynamic label/value row geometry: [leading] (the key/label) hugs its content on the left, [trailing]
/// (the value) fills ALL the remaining width and is flush-RIGHT, ellipsizing only when it grows back to
/// meet the leading — value-fills-to-key, the demo's `[.k][.grow][.v]` behaviour.
///
/// Implemented as a custom slotted render layout, NOT a Row, because RenderFlex cannot express this:
///   • a middle `Expanded` "grow" can't push a content-sized value flush-right — RenderFlex pre-partitions
///     free space per flex child by flex factor and never reclaims a loose sibling's unused remainder
///     (WRK-038 / Scott Stoll), so three flex children park the value at ~⅔;
///   • a `LayoutBuilder` cap (a first attempt) crashes under ANY intrinsic pass (IntrinsicHeight/Width,
///     baseline) — _RenderLayoutBuilder throws "does not support returning intrinsic dimensions";
///   • a non-flex capped leading doesn't YIELD under pressure, so in a narrow editing row the value zone
///     can't shrink enough and the ✓✕ buttons overflow off-panel.
/// This render object measures directly: the leading takes min(content, [leadingMaxFraction]·avail) so the
/// value keeps ≥(1−fraction)·avail (key-priority + anti-starve + buttons always fit); the value owns the
/// true remainder, flush-right. It implements intrinsics (safe under IntrinsicHeight/Width) and degrades to
/// content width under unbounded constraints. [afterLeading] (an edit pencil) sits just right of the
/// leading; [afterValue] (✓ / ✕) pins to the far right past the value. [wrap] fills + wraps the value
/// left-aligned (multi-line) instead of single-line right-ellipsis.
///
/// 动态键值行:leading 贴内容靠左,value 吃尽「行宽 − leading」全部余量、贴右,长到撞回 leading 才省略。自研槽式渲染
/// 布局而非 Row——RenderFlex 做不到(中间 grow 推不动内容宽的 value;LayoutBuilder 封顶在 intrinsic 下崩;非 flex 封顶
/// 不让位、窄编辑行 ✓✕ 溢出)。本渲染对象直接测算:leading 取 min(内容, 0.6·avail) 让 value 留 ≥0.4·avail(键优先 +
/// 防饿死 + ✓✕ 永远在),value 拿真实剩余贴右;实现 intrinsic(IntrinsicHeight/Width 安全)、无界约束降级为内容宽。
class AnLeadValue extends SlottedMultiChildRenderObjectWidget<AnLeadValueSlot, RenderBox> {
  const AnLeadValue({
    required this.leading,
    required this.trailing,
    this.afterLeading,
    this.afterValue,
    this.wrap = false,
    this.leadingMaxFraction = 0.6,
    super.key,
  });

  /// Left zone (a key / label [Text], or a label + hint column). 左区。
  final Widget leading;

  /// The value — fills the remainder, flush-right (or filling + wrapping left when [wrap]). 值。
  final Widget trailing;

  /// Optional widget pinned just right of [leading] (e.g. an edit pencil). leading 右侧附件(铅笔)。
  final Widget? afterLeading;

  /// Optional widget pinned to the far right past the value (e.g. ✓ / ✕). value 右侧最右附件(✓✕)。
  final Widget? afterValue;

  /// Value wraps left-aligned (multi-line) instead of single-line right ellipsis. 值换行。
  final bool wrap;

  /// Starvation rail: the leading takes at most this fraction of the key/value width before it ellipsizes,
  /// so the value keeps ≥(1−fraction) and a pathological-long leading can't squeeze it to nothing. NOT a
  /// visual token — a layout ratio. 防饿死闸(布局比率、非视觉令牌)。
  final double leadingMaxFraction;

  @override
  Iterable<AnLeadValueSlot> get slots => AnLeadValueSlot.values;

  @override
  Widget? childForSlot(AnLeadValueSlot slot) => switch (slot) {
        AnLeadValueSlot.leading => leading,
        AnLeadValueSlot.afterLeading => afterLeading,
        AnLeadValueSlot.value => trailing,
        AnLeadValueSlot.afterValue => afterValue,
      };

  @override
  SlottedContainerRenderObjectMixin<AnLeadValueSlot, RenderBox> createRenderObject(BuildContext context) =>
      _RenderLeadValue(wrap: wrap, leadingMaxFraction: leadingMaxFraction);

  @override
  void updateRenderObject(
      BuildContext context, SlottedContainerRenderObjectMixin<AnLeadValueSlot, RenderBox> renderObject) {
    (renderObject as _RenderLeadValue)
      ..wrap = wrap
      ..leadingMaxFraction = leadingMaxFraction;
  }
}

enum AnLeadValueSlot { leading, afterLeading, value, afterValue }

class _RenderLeadValue extends RenderBox with SlottedContainerRenderObjectMixin<AnLeadValueSlot, RenderBox> {
  _RenderLeadValue({required bool wrap, required double leadingMaxFraction})
      : _wrap = wrap,
        _leadingMaxFraction = leadingMaxFraction;

  static const double _gapMid = AnSpace.s8; // leading ↔ value gap 键值间距
  static const double _gapFlank = AnSpace.s6; // around a pencil / ✓✕ 附件间距

  bool _wrap;
  set wrap(bool v) {
    if (v == _wrap) return;
    _wrap = v;
    markNeedsLayout();
  }

  double _leadingMaxFraction;
  set leadingMaxFraction(double v) {
    if (v == _leadingMaxFraction) return;
    _leadingMaxFraction = v;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(AnLeadValueSlot.leading);
  RenderBox? get _afterLeading => childForSlot(AnLeadValueSlot.afterLeading);
  RenderBox? get _value => childForSlot(AnLeadValueSlot.value);
  RenderBox? get _afterValue => childForSlot(AnLeadValueSlot.afterValue);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  BoxParentData _pd(RenderBox child) => child.parentData! as BoxParentData;

  // ── Intrinsics: sum of widths (+ gaps), max of heights — delegated to children, so an intrinsic pass
  //    (IntrinsicHeight/Width, baseline) is SAFE (unlike LayoutBuilder). 求 intrinsic、不崩。
  double _intrinsicWidth(double Function(RenderBox) f) {
    var w = 0.0;
    final leading = _leading, value = _value, aL = _afterLeading, aV = _afterValue;
    if (leading != null) w += f(leading);
    if (aL != null) w += _gapFlank + f(aL);
    w += _gapMid;
    if (value != null) w += f(value);
    if (aV != null) w += _gapFlank + f(aV);
    return w;
  }

  double _intrinsicHeight(double Function(RenderBox) f) {
    var h = 0.0;
    for (final slot in AnLeadValueSlot.values) {
      final ch = childForSlot(slot);
      if (ch != null) h = math.max(h, f(ch));
    }
    return h;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth((c) => c.getMinIntrinsicWidth(height));
  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth((c) => c.getMaxIntrinsicWidth(height));
  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight((c) => c.getMinIntrinsicHeight(double.infinity));
  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight((c) => c.getMaxIntrinsicHeight(double.infinity));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final w = constraints.hasBoundedWidth ? constraints.maxWidth : computeMaxIntrinsicWidth(double.infinity);
    // Height from intrinsics (never getDryLayout on children — an editing field may not support it). 用 intrinsic 求高。
    final h = _intrinsicHeight((c) => c.getMaxIntrinsicHeight(double.infinity));
    return constraints.constrain(Size(w, h));
  }

  @override
  void performLayout() {
    final c = constraints;
    final leading = _leading, value = _value, aL = _afterLeading, aV = _afterValue;
    final hMax = c.maxHeight;

    // Unbounded width → degrade: natural widths laid left-to-right, size to content (no fill / no right
    // anchor — there is no right edge). 无界宽降级:自然宽左起排、贴内容,不填不右锚。
    if (!c.hasBoundedWidth) {
      final order = <(RenderBox, double)>[
        if (leading != null) (leading, 0),
        if (aL != null) (aL, _gapFlank),
        if (value != null) (value, _gapMid),
        if (aV != null) (aV, _gapFlank),
      ];
      var width = 0.0, height = 0.0;
      for (final (ch, gap) in order) {
        ch.layout(BoxConstraints(maxHeight: hMax), parentUsesSize: true);
        width += gap + ch.size.width;
        height = math.max(height, ch.size.height);
      }
      size = c.constrain(Size(width, height));
      var cx = 0.0;
      for (final (ch, gap) in order) {
        cx += gap;
        _pd(ch).offset = Offset(cx, (size.height - ch.size.height) / 2);
        cx += ch.size.width;
      }
      return;
    }

    final w = c.maxWidth;
    // Flanks first (fixed, natural width). 附件先布(固定自然宽)。
    var aLW = 0.0, aVW = 0.0;
    if (aL != null) {
      aL.layout(BoxConstraints(maxWidth: w, maxHeight: hMax), parentUsesSize: true);
      aLW = aL.size.width;
    }
    if (aV != null) {
      aV.layout(BoxConstraints(maxWidth: w, maxHeight: hMax), parentUsesSize: true);
      aVW = aV.size.width;
    }
    final gapL = aL != null ? _gapFlank : 0.0;
    final gapV = aV != null ? _gapFlank : 0.0;
    final avail = math.max(0.0, w - aLW - aVW - gapL - gapV - _gapMid);

    // leading hugs content, capped at fraction·avail (so value keeps ≥(1−fraction)·avail — key-priority,
    // anti-starve, ✓✕ always fit). leading 贴内容、封顶 fraction·avail。
    var leadW = 0.0;
    if (leading != null) {
      leading.layout(BoxConstraints(maxWidth: avail * _leadingMaxFraction, maxHeight: hMax), parentUsesSize: true);
      leadW = leading.size.width;
    }
    final valueMax = math.max(0.0, avail - leadW); // value owns the true remainder 值拿真实剩余
    var valW = 0.0;
    if (value != null) {
      value.layout(
        _wrap
            ? BoxConstraints(minWidth: valueMax, maxWidth: valueMax, maxHeight: hMax) // fill + wrap 填满换行
            : BoxConstraints(maxWidth: valueMax, maxHeight: hMax), // content width, flush-right 内容宽贴右
        parentUsesSize: true,
      );
      valW = value.size.width;
    }

    var height = 0.0;
    for (final ch in [leading, aL, value, aV]) {
      if (ch != null) height = math.max(height, ch.size.height);
    }
    size = c.constrain(Size(w, height));
    double centerY(RenderBox ch) => (size.height - ch.size.height) / 2;

    // leading at 0 (top when wrap); afterLeading just right; value flush-right (or left when wrap);
    // afterValue far right. 左起 leading、铅笔随后、value 贴右(wrap 则左)、✓✕ 最右。
    if (leading != null) _pd(leading).offset = Offset(0, _wrap ? 0 : centerY(leading));
    if (aL != null) _pd(aL).offset = Offset(leadW + gapL, centerY(aL));
    if (value != null) {
      final vx = _wrap ? (leadW + gapL + aLW + _gapMid) : (w - aVW - gapV - valW);
      _pd(value).offset = Offset(vx, _wrap ? 0 : centerY(value));
    }
    if (aV != null) _pd(aV).offset = Offset(w - aVW, centerY(aV));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final ch in children) {
      context.paintChild(ch, offset + _pd(ch).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final ch in children) {
      final pd = _pd(ch);
      final hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (r, transformed) => ch.hitTest(r, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
