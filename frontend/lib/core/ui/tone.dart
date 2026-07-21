import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../model/status_state.dart';

/// Binds a semantic [AnTone] (a meaning) to token colours (the look) — the single place tone →
/// colour happens, so badge / callout / state / dot never re-derive it. `none` is neutral chrome.
/// 把语义 tone 绑到 token 色——tone→色 的唯一处,徽章/callout/state/点都不再各写;none=中性 chrome。
extension AnToneColors on AnTone {
  /// Foreground / solid colour. 前景/实色。
  Color fg(AnColors c) => switch (this) {
    AnTone.ok => c.ok,
    AnTone.warn => c.warn,
    AnTone.danger => c.danger,
    AnTone.accent => c.accent,
    AnTone.none => c.inkMuted,
  };

  /// Soft tinted background. 柔色底。
  Color softBg(AnColors c) => switch (this) {
    AnTone.ok => c.okSoft,
    AnTone.warn => c.warnSoft,
    AnTone.danger => c.dangerSoft,
    AnTone.accent => c.accentSoft,
    AnTone.none => c.surfaceHover,
  };
}
