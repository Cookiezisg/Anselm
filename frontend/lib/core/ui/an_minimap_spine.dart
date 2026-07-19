import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The DOCUMENT SPINE (WRK-061 §7-8) — a thin vertical minimap on the prose stage's left edge: the
/// whole document as a strip, INKED up to the writing frontier (an accent tick), paragraph boundaries
/// as faint ruling. One CustomPainter, no per-paragraph widgets (§5-10). The fast-forwarded common
/// prefix (R-5) paints muted — already-true content is visibly distinct from freshly-dictated ink.
/// Tap = freeze-read that segment (the host pins the camera and jumps its scroll).
///
/// 文档书脊:散文幕左缘细竖条——整篇是一条带,着墨到写入前沿(accent 刻度),段界渲淡线。单 CustomPainter
/// 零逐段 widget。前缀快进段渲 muted(旧真部分与新听写可分)。点=冻结静读该段(宿主 pin+跳滚)。
class AnMinimapSpine extends StatelessWidget {
  const AnMinimapSpine({
    required this.totalUnits,
    required this.inkedUnits,
    this.prefixUnits = 0,
    this.paragraphOffsets = const [],
    this.onTapFraction,
    this.width = 6,
    super.key,
  });

  /// The strip's denominator — max(baseline length, current length) so the strip doesn't jump.
  /// 分母(基线与当前取大,条不跳)。
  final int totalUnits;

  /// The writing frontier (chars dictated so far). 写入前沿。
  final int inkedUnits;

  /// The fast-forwarded common prefix (R-5) — painted muted, not accent. 快进前缀段(muted)。
  final int prefixUnits;

  /// Paragraph boundary offsets (append-only, §5-10). 段界偏移(只增)。
  final List<int> paragraphOffsets;

  final void Function(double fraction)? onTapFraction;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: onTapFraction == null
          ? null
          : (d) {
              final h = (context.findRenderObject() as RenderBox?)?.size.height ?? 0;
              if (h > 0) onTapFraction!((d.localPosition.dy / h).clamp(0.0, 1.0));
            },
      child: SizedBox(
        width: width + AnSpace.s4,
        child: CustomPaint(
          painter: _SpinePainter(
            total: totalUnits <= 0 ? 1 : totalUnits,
            inked: inkedUnits,
            prefix: prefixUnits,
            paragraphs: paragraphOffsets,
            inkColor: c.inkFaint,
            prefixColor: c.line,
            frontierColor: c.accent,
            railColor: c.surfaceSunken,
          ),
          size: Size(width, double.infinity),
        ),
      ),
    );
  }
}

class _SpinePainter extends CustomPainter {
  const _SpinePainter({
    required this.total,
    required this.inked,
    required this.prefix,
    required this.paragraphs,
    required this.inkColor,
    required this.prefixColor,
    required this.frontierColor,
    required this.railColor,
  });

  final int total;
  final int inked;
  final int prefix;
  final List<int> paragraphs;
  final Color inkColor;
  final Color prefixColor;
  final Color frontierColor;
  final Color railColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = railColor);

    double yOf(int units) => (units / total).clamp(0.0, 1.0) * size.height;

    // The fast-forwarded prefix: known-true, muted. 快进前缀:旧真,muted。
    final prefixY = yOf(prefix.clamp(0, inked));
    if (prefixY > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, prefixY), const Radius.circular(3)),
        Paint()..color = prefixColor,
      );
    }
    // Freshly dictated ink. 新听写着墨。
    final inkY = yOf(inked);
    if (inkY > prefixY) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, prefixY, w, inkY - prefixY), const Radius.circular(3)),
        Paint()..color = inkColor,
      );
    }
    // Paragraph ruling. 段界细线。
    final rule = Paint()
      ..color = railColor
      ..strokeWidth = 1;
    for (final off in paragraphs) {
      final y = yOf(off);
      if (y > 0 && y < size.height) canvas.drawLine(Offset(0, y), Offset(w, y), rule);
    }
    // The writing frontier. 写入前沿。
    if (inked > 0 && inked < total) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-1, (inkY - 1.5).clamp(0.0, size.height - 3), w + 2, 3),
            const Radius.circular(1.5)),
        Paint()..color = frontierColor,
      );
    }
  }

  @override
  bool shouldRepaint(_SpinePainter old) =>
      old.total != total ||
      old.inked != inked ||
      old.prefix != prefix ||
      old.paragraphs.length != paragraphs.length;
}
