import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_interactive.dart';

/// The boolean toggle — the kit's ONE switch (no Material Switch anywhere). A quiet 30×18 pill:
/// sunken track with a hairline when off, accent fill when on; a white knob glides across
/// ([AnMotion.fast], jumps under reduced motion). Sized for a 32px settings row's trailing slot.
/// Semantics = toggled switch; the LABEL belongs to the host row ([AnSettingRow] wraps the pair),
/// so the control itself stays label-less.
///
/// 布尔开关——kit 唯一正统(全库禁 Material Switch)。安静的 30×18 药丸:off=凹底+发丝线,on=accent
/// 填充;白色旋钮滑动(fast,reduced 直跳)。为 32px 设置行的行尾槽定尺。语义=toggled switch;标签归
/// 宿主行(AnSettingRow 包对),控件本体不带字。
class AnSwitch extends StatelessWidget {
  const AnSwitch({
    required this.value,
    this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;

  /// null = disabled (read-only fact, dimmed). null=禁用(只读事实,压暗)。
  final ValueChanged<bool>? onChanged;

  /// Standalone use only — inside [AnSettingRow] the row carries the label. 独立使用才传;行内归行。
  final String? semanticLabel;

  static const double _trackW = 30;
  static const double _trackH = 18;
  static const double _knob = 14;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    final reduced = AnMotionPref.reduced(context);
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: enabled,
      child: AnInteractive(
        enabled: enabled,
        onTap: enabled ? () => onChanged!(!value) : null,
        builder: (context, states) {
          final hovered = states.contains(WidgetState.hovered);
          return Opacity(
            opacity: enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : AnMotion.fast,
              width: _trackW,
              height: _trackH,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value
                    ? (hovered ? c.accent.withValues(alpha: 0.9) : c.accent)
                    : (hovered ? c.surfaceHover : c.surfaceSunken),
                borderRadius: BorderRadius.circular(_trackH / 2),
                border: value ? null : Border.all(color: c.line, width: AnSize.hairline),
              ),
              child: AnimatedAlign(
                duration: reduced ? Duration.zero : AnMotion.fast,
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x33000000),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
