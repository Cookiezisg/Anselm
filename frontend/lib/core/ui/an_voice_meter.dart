import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A compact voice-capture status strip for composers: status label + elapsed time + live level bars.
/// It owns the decoration and wave geometry as a UI-kit primitive, so feature code only supplies
/// state (label/duration/level). Reduced motion keeps the level readable but removes height animation.
///
/// 语音捕获状态条:状态标签 + 已录时长 + 实时电平条。装饰与波形几何归 UI kit 原语所有,feature 只传状态。
/// reduced motion 保留电平可读性,去掉条高动画。
class AnVoiceMeter extends StatelessWidget {
  const AnVoiceMeter({
    required this.label,
    required this.duration,
    required this.level,
    this.active = true,
    this.finalizing = false,
    super.key,
  });

  final String label;
  final Duration duration;

  /// 0..1 normalized microphone level. 归一化麦克风电平。
  final double level;

  /// False keeps the strip visible with a muted wave, used for finalizing. false=保留条但波形静默。
  final bool active;
  final bool finalizing;

  static const _weights = <double>[
    0.32,
    0.56,
    0.40,
    0.76,
    0.48,
    0.92,
    0.62,
    1.00,
    0.58,
    0.82,
    0.44,
    0.68,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final durationText = _formatDuration(duration);
    return Semantics(
      label: '$label $durationText',
      child: Container(
        key: const ValueKey('voice-status'),
        padding: const EdgeInsets.symmetric(
          horizontal: AnSpace.s8,
          vertical: AnSpace.s6,
        ),
        decoration: BoxDecoration(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(AnRadius.pill),
          border: Border.all(color: c.line, width: AnSize.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: AnSpace.s6,
              height: AnSpace.s6,
              decoration: BoxDecoration(
                color: finalizing ? c.warn : c.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AnSpace.s6),
            Text(label, style: AnText.meta.copyWith(color: c.inkMuted)),
            const SizedBox(width: AnSpace.s8),
            Text(
              durationText,
              key: const ValueKey('voice-duration'),
              style: AnText.mono.copyWith(color: c.inkFaint),
            ),
            const SizedBox(width: AnSpace.s8),
            Expanded(child: _wave(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _wave(BuildContext context, AnColors c) {
    final reduced = AnMotionPref.reduced(context);
    final normalized = active ? level.clamp(0.0, 1.0).toDouble() : 0.18;
    return SizedBox(
      key: const ValueKey('voice-wave'),
      height: AnSpace.s16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final weight in _weights) ...[
            AnimatedContainer(
              duration: reduced ? Duration.zero : AnMotion.fast,
              curve: AnMotion.easeOut,
              width: AnSpace.s2,
              height:
                  AnSpace.s2 +
                  ((0.16 + normalized * weight).clamp(0.16, 1.0) * AnSpace.s12),
              decoration: BoxDecoration(
                color: active ? c.accent : c.inkFaint,
                borderRadius: BorderRadius.circular(AnRadius.pill),
              ),
            ),
            const SizedBox(width: AnSpace.s2),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }
}
