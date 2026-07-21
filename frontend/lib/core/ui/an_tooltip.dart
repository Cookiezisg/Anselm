import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The kit tooltip — Flutter's [Tooltip] machinery (timers, hover/long-press triggers, semantics
/// merge, overlay lifecycle: mature, not hand-rolled — principle #8) wearing the design system's
/// skin: island surface + hairline border + pop shadow + the 12 meta rung, [AnMotion.dwell] reveal
/// (the one hover-dwell tier) so casual mouse travel never flashes labels. Restraint on purpose
/// (enterprise calm): no arrow, no rich body — a rich variant is a later need, not a default.
///
/// kit 提示条——Flutter [Tooltip] 机制(计时/悬停/长按/语义合并/overlay 生命周期:成熟件不手搓,
/// 原则 #8)穿设计系统的皮:岛面+发丝边+pop 影+12 meta 档,驻留满 [AnMotion.dwell] 才现——鼠标路过绝不闪标签。
/// 克制是有意的(企业级的静):无箭头、无富文本体——富变体等真需要再立,不做默认。
class AnTooltip extends StatelessWidget {
  const AnTooltip({required this.message, required this.child, super.key});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: message,
      waitDuration: AnMotion.dwell,
      verticalOffset: AnSpace.s16,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.button),
        boxShadow: c.shadowPop,
      ),
      textStyle: AnText.meta.copyWith(color: c.ink),
      padding: const EdgeInsets.symmetric(
        horizontal: AnSpace.s8,
        vertical: AnSpace.s4,
      ),
      child: child,
    );
  }
}
