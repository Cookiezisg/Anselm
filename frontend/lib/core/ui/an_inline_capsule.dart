import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'tone.dart';

/// The INLINE CAPSULE (WRK-066 批5, A-041/042) — the ONE baseline-hugging in-text pill shell. Lives
/// inside a [WidgetSpan] in running text: soft tone fill, tag radius, hair insets ([AnSize.capsulePadY]
/// vertical + the same 1px breathing margin), the host line's text style with `height: 1.0` so the
/// capsule never inflates the line box. Collapses the hand-rolled in-text pills ({{CEL}} amber
/// capsule, [[id]] pilled prose; the editor mention rides it via AnRefPill.inline). DISPLAY-ONLY:
/// interactivity belongs to the host text engine.
///
/// 行内药囊(批5)——唯一贴基线文内壳。住 WidgetSpan:软 tone 底+tag 圆角+发丝内距(capsulePadY 竖距+
/// 同 1px 呼吸边距)+宿主字体(height 1.0 不撑行盒)。收编手搓文内伪药丸({{CEL}} 琥珀囊/[[id]] 散文
/// 药丸;编辑器提及经 AnRefPill.inline 骑它)。**仅展示**:交互归宿主文本引擎。
class AnInlineCapsule extends StatelessWidget {
  const AnInlineCapsule(
    this.label, {
    this.tone = AnTone.accent,
    this.icon,
    this.textStyle,
    super.key,
  });

  final String label;
  final AnTone tone;

  /// Optional leading glyph (the ref-pill preset feeds the kind glyph). 可选前导字形(kind 字形)。
  final IconData? icon;

  /// The host line's text style (defaults to the meta tier). 宿主行字体(缺省 meta 档)。
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = tone.fg(c);
    final style = (textStyle ?? AnText.meta).copyWith(color: ink, height: 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AnSize.capsulePadY),
      padding: const EdgeInsets.symmetric(
        horizontal: AnSpace.s4,
        vertical: AnSize.capsulePadY,
      ),
      decoration: BoxDecoration(
        color: tone.softBg(c),
        borderRadius: BorderRadius.circular(AnRadius.tag),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AnSize.iconSm, color: ink),
            const SizedBox(width: AnGap.inlineHair),
          ],
          // The label WRAPS (the hand-rolled pills it absorbs did) — an inline value may be a long
          // CEL expression or document name and there is no hover escape in running text (复审:
          // 截断回归). 标签可换行(被收编的手搓药丸本可换行;行内无 hover 逃生口,禁截断)。
          Flexible(child: Text(label, style: style)),
        ],
      ),
    );
  }
}
