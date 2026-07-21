import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'icons.dart';

/// The ONE small indeterminate spinner (WRK-066 批7, B-071) — a faint adaptive ring at an icon-tier
/// size. Owns the two things every hand-rolled copy kept forgetting: the a11y gate (a decorative
/// loop, so [AnMotionPref.reducedOrAssistive] freezes it to the still [AnIcons.spin] glyph) and the
/// geometry (strokeWidth 2 — the ring reads hairline-adjacent at these sizes). Row/list feet and
/// panel loading all consume this; full placeholder states stay with [AnState].
///
/// 唯一小型不定转圈(批7 B-071)——icon 档淡环。收口两件手搓副本总忘的事:a11y 门(装饰循环,
/// reducedOrAssistive 冻成静态 spin 字形)与几何(strokeWidth 2)。行脚/面板加载用它;整面占位归 AnState。
class AnSpinner extends StatelessWidget {
  const AnSpinner({this.size = AnSize.icon, this.semanticLabel, super.key});

  final double size;

  /// Screen-reader label. REQUIRED when the spinner stands alone (a list foot, a bare loading
  /// arm) — the frozen assistive face is otherwise zero-information; omit when a sibling text
  /// (AnState title) already carries the state (批7 复审). 读屏标签:裸站必填(冻结面对读屏零信息),
  /// 旁有文本(AnState title)时省略。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Widget core;
    if (AnMotionPref.reducedOrAssistive(context)) {
      core = Icon(AnIcons.spin, size: size, color: c.inkFaint);
    } else {
      core = SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator.adaptive(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(c.inkFaint),
        ),
      );
    }
    if (semanticLabel == null) return core;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: core),
    );
  }
}
