import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_status_dot.dart';

/// One signature field on either side of the box: name + type chip, plus an optional live [value]
/// caption (an actual run argument/result). Plain value object so core stays contract-free — the
/// entities feature maps its DTO `Field` in.
///
/// 变换盒两侧的一个签名字段:名 + 类型 chip + 可选活值 caption(真实运行实参/结果)。纯值对象,
/// core 不碰契约层——entities feature 自己把 DTO Field 映射进来。
class AnTransformField {
  const AnTransformField(this.name, this.type, {this.value});

  final String name;
  final String type;
  final String? value;
}

/// Lifecycle phase of the box — drives connector/border emphasis (idle hairline; running = input
/// side + box accent; done = output side lit; failed = box turns danger).
/// 变换盒生命周期相——驱动连线/边框强调(闲置细线;运行=输入侧+盒强调;完成=输出侧点亮;失败=盒转红)。
enum AnTransformPhase { idle, running, done, failed }

/// The function hero — `inputs → [box] → outputs` drawn as one picture: a field column on each
/// side, horizontal-tangent cubic-bezier hairline connectors (the same edge language the workflow
/// graph will use), and a centre card carrying the name + a status line + a meta caption. An empty
/// side renders a dashed empty slot ([emptyInputsLabel]/[emptyOutputsLabel] — the "void" of a
/// signature is information too, not hidden). All strings are caller-supplied (i18n stays in the
/// feature). Field rows sit at a fixed tile height so connector endpoints are computed, not measured.
///
/// function 页 hero——把 `inputs → [盒] → outputs` 画成一张图:两侧字段列 + 水平切线三次贝塞尔
/// hairline 连线(与未来 workflow 图同一套边语言)+ 中心卡(名 + 状态行 + meta caption)。空侧渲染
/// 虚线空槽(签名的「空」也是信息、不藏)。文案全由调用方传入(i18n 留在 feature)。字段行定高,
/// 连线端点靠算、不靠测。
class AnTransformBox extends StatelessWidget {
  const AnTransformBox({
    required this.title,
    this.icon,
    this.inputs = const [],
    this.outputs = const [],
    this.phase = AnTransformPhase.idle,
    this.status,
    this.statusLabel,
    this.meta,
    this.emptyInputsLabel = '',
    this.emptyOutputsLabel = '',
    super.key,
  });

  final String title;
  final IconData? icon;
  final List<AnTransformField> inputs;
  final List<AnTransformField> outputs;
  final AnTransformPhase phase;

  /// Status dot + caption inside the box (e.g. env readiness). 盒内状态点 + 短语(如 env 就绪度)。
  final AnStatus? status;
  final String? statusLabel;

  /// Meta caption under the status line (e.g. `Python 3.12 · 2 deps`). 状态行下的 meta 小字。
  final String? meta;

  final String emptyInputsLabel;
  final String emptyOutputsLabel;

  // Any live value present → all tiles adopt the taller two-line height (uniform tiles keep the
  // connector y-math exact). 任一活值出现 → 全部字段行统一换两行高(定高让连线 y 坐标可精确计算)。
  bool get _hasValues =>
      inputs.any((f) => f.value != null) || outputs.any((f) => f.value != null);

  double get _tileH => _hasValues ? 46 : AnSize.row;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inActive = phase == AnTransformPhase.running;
    final outActive = phase == AnTransformPhase.done;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _fieldColumn(c, inputs, emptyInputsLabel, lit: inActive || outActive, alignEnd: true)),
          _connector(c, inputs.length, active: inActive),
          _centreBox(context, c),
          _connector(c, outputs.length, active: outActive),
          Expanded(child: _fieldColumn(c, outputs, emptyOutputsLabel, lit: outActive, alignEnd: false)),
        ],
      ),
    );
  }

  // Inputs hug their connector's left endpoints (align end); outputs hug theirs (align start) —
  // both columns read as attached to the wire, not floating at the page edge.
  // 输入列贴连线右缘(尾对齐)、输出列贴左缘(头对齐)——字段挂在线上,不飘在页缘。
  Widget _fieldColumn(AnColors c, List<AnTransformField> fields, String emptyLabel,
      {required bool lit, required bool alignEnd}) {
    if (fields.isEmpty) {
      return Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: _EmptySlot(label: emptyLabel),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final f in fields) _FieldTile(field: f, height: _tileH, lit: lit, alignEnd: alignEnd)],
    );
  }

  Widget _connector(AnColors c, int count, {required bool active}) {
    return SizedBox(
      width: AnSpace.s48,
      child: CustomPaint(
        painter: _ConnectorPainter(
          count: count,
          tileHeight: _tileH,
          color: active ? c.accent : c.line,
          dashed: count == 0,
        ),
      ),
    );
  }

  Widget _centreBox(BuildContext context, AnColors c) {
    final border = switch (phase) {
      AnTransformPhase.failed => c.danger,
      AnTransformPhase.running => c.accentLine,
      _ => c.line,
    };
    return Center(
      child: Container(
        // Width band: floor keeps a tiny signature from collapsing the box; ceiling forces a long
        // name into ellipsis instead of starving the field columns. 宽度带:下限防塌、上限逼省略。
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s16, vertical: AnSpace.s12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: border, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: AnSize.icon, color: c.inkMuted),
                const SizedBox(width: AnSpace.s6),
              ],
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.body.copyWith(color: c.ink, fontWeight: AnText.emphasisWeight),
                ),
              ),
            ]),
            if (status != null || phase == AnTransformPhase.running) ...[
              const SizedBox(height: AnSpace.s6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                // A running box borrows the breathing run-dot; otherwise the caller's status.
                // 运行中的盒借用呼吸 run 点;否则用调用方给的状态。
                AnStatusDot(phase == AnTransformPhase.running ? AnStatus.run : status!),
                if ((statusLabel ?? '').isNotEmpty) ...[
                  const SizedBox(width: AnSpace.s6),
                  Text(statusLabel!, style: AnText.meta.copyWith(color: c.inkMuted)),
                ],
              ]),
            ],
            if ((meta ?? '').isNotEmpty) ...[
              const SizedBox(height: AnSpace.s4),
              Text(meta!, style: AnText.meta.copyWith(color: c.inkFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.field, required this.height, required this.lit, required this.alignEnd});

  final AnTransformField field;
  final double height;
  final bool lit;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  field.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.mono.copyWith(color: lit && field.value != null ? c.ink : c.inkMuted),
                ),
              ),
              const SizedBox(width: AnSpace.s6),
              Flexible(child: _TypeChip(type: field.type)),
            ],
          ),
          if (field.value != null)
            Text(
              field.value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AnText.meta.copyWith(color: lit ? c.accent : c.inkFaint),
            ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6, vertical: AnSpace.s2),
      decoration: BoxDecoration(
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.tag),
      ),
      child: Text(type, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkFaint)),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomPaint(
      painter: _DashedBorderPainter(color: c.line),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s6),
        child: Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
      ),
    );
  }
}

/// Horizontal-tangent cubic beziers from each field tile centre to the box's vertical middle —
/// `cubicTo(midX, y1, midX, y2, x2, y2)` (the n8n edge). Endpoint dots instead of arrows (direction
/// is self-evident left→right); a 0-field side paints one dashed centre line into the void slot.
/// 每字段行中心 → 盒纵向中点的水平切线三次贝塞尔(n8n 边)。端点用小圆点、不用箭头(左→右方向自明);
/// 0 字段侧画一条虚线中线接空槽。
class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.count,
    required this.tileHeight,
    required this.color,
    required this.dashed,
  });

  final int count;
  final double tileHeight;
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AnSize.hairline
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    if (count == 0) {
      final p = Path()
        ..moveTo(0, midY)
        ..lineTo(size.width, midY);
      canvas.drawPath(_dash(p), stroke);
      return;
    }
    final top = midY - count * tileHeight / 2;
    final dot = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final y = top + i * tileHeight + tileHeight / 2;
      final p = Path()
        ..moveTo(0, y)
        ..cubicTo(size.width / 2, y, size.width / 2, midY, size.width, midY);
      canvas.drawPath(dashed ? _dash(p) : p, stroke);
      canvas.drawCircle(Offset(0, y), 1.5, dot);
    }
    canvas.drawCircle(Offset(size.width, midY), 1.5, dot);
  }

  Path _dash(Path source) {
    final out = Path();
    for (final PathMetric m in source.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, (d + 3).clamp(0, m.length)), Offset.zero);
        d += 6;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.count != count || old.tileHeight != tileHeight || old.color != color || old.dashed != dashed;
}

/// Hairline dashed rounded-rect border (the empty signature slot). 虚线圆角边框(空签名槽)。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AnRadius.button));
    final source = Path()..addRRect(rrect);
    final out = Path();
    for (final PathMetric m in source.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, (d + 3).clamp(0, m.length)), Offset.zero);
        d += 6;
      }
    }
    canvas.drawPath(
      out,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AnSize.hairline,
    );
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
