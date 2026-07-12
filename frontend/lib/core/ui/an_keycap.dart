import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The keycap's three faces. 键帽三态。
enum AnKeycapState { idle, recording, error }

/// A KEYCAP (WRK-066 批5c, A-027) — the shortcut-chord control face: a mono kbd plate with an
/// idle / recording / error (conflict) tri-state. Deliberately NOT an [AnChip] (a chip is a passive
/// small label; a keycap is a button-grade input control with its own state machine) and
/// deliberately NOT focusable — it renders NO Focus/AnInteractive node: the HOST owns the keyboard
/// (the shortcuts panel's recording Focus must not compete for focus — the settings campaign's
/// focus-order lesson). Pointer only: hover cursor + tap.
///
/// 键帽(批5c)——快捷键弦控件脸:mono kbd 板 + 静息/录制/冲突三态。刻意**不进 AnChip**(芯片=被动
/// 小标签,键帽=带状态机的按钮级输入控件)、刻意**不可聚焦**——不渲 Focus/AnInteractive:键盘归宿主
/// (快捷键面板的录制 Focus 不容抢焦,settings 战役焦点序教训)。仅指针:hover 手型 + 点击。
class AnKeycap extends StatelessWidget {
  const AnKeycap(this.label, {this.state = AnKeycapState.idle, this.onTap, super.key});

  final String label;
  final AnKeycapState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final recording = state == AnKeycapState.recording;
    final border = switch (state) {
      AnKeycapState.error => c.danger,
      AnKeycapState.recording => c.accent,
      AnKeycapState.idle => c.line,
    };
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s6),
          decoration: BoxDecoration(
            color: recording ? c.accentSoft : c.surfaceHover,
            borderRadius: BorderRadius.circular(AnRadius.button),
            border: Border.all(color: border, width: AnSize.hairline),
          ),
          child: Text(label, style: AnText.mono.copyWith(color: recording ? c.accent : c.ink)),
        ),
      ),
    );
  }
}
