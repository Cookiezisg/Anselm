import 'package:flutter/painting.dart';

/// Measures text off-screen and hands the laid-out [TextPainter] to [read], then disposes it —
/// even if [read] throws. A [TextPainter] owns a native `ui.Paragraph`; that memory is released ONLY
/// by `dispose()` (otherwise it lingers until the GC finalizer runs, which back-pressure never
/// triggers because the Dart shell is tiny). Every measure site (label/gutter widths, wrapped line
/// counts, line heights) shared the same new→layout→read scaffold but hand-rolled the dispose, so 3 of
/// 4 forgot it (leak-hunt T6). Owning the lifecycle here makes forgetting structurally impossible.
///
/// Defaults mirror [TextPainter]'s own constructor/`layout` defaults so routing an existing site through
/// this helper is behaviour-preserving: pass only what that site set explicitly.
///
/// 离屏量文本:布局后把 [TextPainter] 交给 [read] 读指标,读完(哪怕抛异常也)必 dispose。TextPainter 持有原生
/// paragraph,只有 dispose 释放(否则等 GC finalizer 兜底,而 Dart 壳极小、背压永远感受不到 → 原生内存延迟释放)。
/// 各量测站(标签/行号列宽、折行行数、行高)本是同一套 new→layout→read 骨架却各自手搓 dispose,4 站漏 3(T6);
/// 生命周期收归此处,漏 dispose 从此不可能。默认值逐一对齐 TextPainter 原生默认 → 路由既有站点零行为变化。
T measureText<T>(
  InlineSpan text, {
  required T Function(TextPainter painter) read,
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  int? maxLines,
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: text,
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: maxLines,
  )..layout(maxWidth: maxWidth);
  try {
    return read(painter);
  } finally {
    painter.dispose();
  }
}
