import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The keycap's three faces. 键帽三态。
enum AnKeycapState { idle, recording, error }

/// A KEYCAP (WRK-066 批5c, A-027; compact tier 0719) — the shortcut-chord control face. Two forms:
///
///   • **Idle = per-key caps**: each key of the chord gets its own compact plate (`[⌘][B]`,
///     [AnSize.keycap] 20 high, mono 12, s2 gaps) — the resting face reads like real keycaps and
///     keeps the settings row at its 32 rhythm. Pass the fragments via [keys]; with no [keys] the
///     whole [label] renders as one cap (legacy/gallery fallback).
///   • **Recording / error = the wide plate**: the big bordered form is the RECORDING-dedicated
///     face (accent while capturing, danger on conflict) — a state banner, not a resting control.
///
/// Deliberately NOT an [AnChip] (a chip is a passive small label; a keycap is a button-grade input
/// control with its own state machine) and deliberately NOT focusable — it renders NO
/// Focus/AnInteractive node: the HOST owns the keyboard (the shortcuts panel's recording Focus must
/// not compete for focus — the settings campaign's focus-order lesson). Pointer only: hover cursor
/// + tap.
///
/// 键帽(批5c;0719 紧凑档)——快捷键弦控件脸,两形:**静息=逐键小帽**([keys] 逐键一板,
/// 20 高 mono 12、s2 间距,像真键帽、settings 行回 32 节律;无 [keys] 则整个 [label] 一帽兜底);
/// **录制/冲突=宽板**(大块形态归录制态专属:录制 accent、冲突 danger——状态横幅,非静息控件)。
/// 刻意**不进 AnChip**(芯片=被动小标签,键帽=带状态机的按钮级输入控件)、刻意**不可聚焦**——
/// 不渲 Focus/AnInteractive:键盘归宿主(录制 Focus 不容抢焦,settings 战役焦点序教训)。
/// 仅指针:hover 手型 + 点击。
class AnKeycap extends StatelessWidget {
  const AnKeycap(
    this.label, {
    this.keys,
    this.state = AnKeycapState.idle,
    this.onTap,
    super.key,
  });

  /// The whole-chord text — the plate face (recording/error), and the single-cap fallback when no
  /// [keys] are given. Always the semantic identity. 整弦文本:宽板脸(录制/冲突)+无 [keys] 时的
  /// 单帽兜底;恒为语义身份。
  final String label;

  /// Per-key display fragments (⌘ / ⌥ / ⇧ / B) for the idle per-cap face. 静息逐键片段。
  final List<String>? keys;

  final AnKeycapState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = state == AnKeycapState.idle ? _caps(c) : _plate(c);
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // ONE semantics node speaking the whole chord — the per-key caps are typography, not four
        // separate stops for a screen reader. 单语义节点读整弦;逐键帽是排版,不是四个读屏站点。
        child: MergeSemantics(
          child: Semantics(
            label: label,
            child: ExcludeSemantics(child: child),
          ),
        ),
      ),
    );
  }

  /// The resting face: one compact cap per key. 静息脸:逐键小帽。
  Widget _caps(AnColors c) {
    final frags = (keys == null || keys!.isEmpty) ? [label] : keys!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < frags.length; i++) ...[
          if (i > 0) const SizedBox(width: AnSpace.s2),
          Container(
            height: AnSize.keycap,
            constraints: const BoxConstraints(minWidth: AnSize.keycap),
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceHover,
              borderRadius: BorderRadius.circular(AnRadius.tag),
              border: Border.all(color: c.line, width: AnSize.hairline),
            ),
            // Code rung (mono 12) with a solid line-height so the glyph centres in the 20 box.
            // 代码档(mono 12),实高行盒使字形在 20 帽内居中。
            child: Text(
              frags[i],
              style: AnText.code.copyWith(color: c.ink, height: 1),
            ),
          ),
        ],
      ],
    );
  }

  /// The recording/conflict banner plate. 录制/冲突宽板。
  Widget _plate(AnColors c) {
    final recording = state == AnKeycapState.recording;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnSpace.s12,
        vertical: AnSpace.s6,
      ),
      decoration: BoxDecoration(
        color: recording ? c.accentSoft : c.surfaceHover,
        borderRadius: BorderRadius.circular(AnRadius.button),
        border: Border.all(
          color: state == AnKeycapState.error ? c.danger : c.accent,
          width: AnSize.hairline,
        ),
      ),
      child: Text(
        label,
        style: AnText.mono.copyWith(color: recording ? c.accent : c.ink),
      ),
    );
  }
}
