import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../../i18n/strings.g.dart';
import 'icons.dart';

/// What the ribbon is being honest about (WRK-061 §6-① 铁律: a live stage ALWAYS wears one). W1 ships
/// the three core triggers; «全量替换» and «真相仍是 vN» variants join with their stages (W2+).
/// 丝带在诚实什么(铁律:live 全程佩戴)。W1 三触发;「全量替换/真相仍是 vN」随各舞台落。
enum AnHonesty {
  /// Streaming — what you see is dictation, the settle will follow the truth. 实时听写中。
  live,

  /// The stream had a gap (SSE reconnect) — growth is frozen, trust the record. 流有缺口。
  gap,

  /// The draft failed to save — the truth is still the previous version. 草稿未保存。
  failed,
}

/// The HONESTY RIBBON — a hairline banner above the stage window that never lets a live painting be
/// mistaken for the saved truth. Neutral while live; warn on a gap; danger on failure. Static (no
/// animation — honesty doesn't blink).
///
/// 诚实丝带——舞台窗上沿的发丝横条,绝不让「正在画的」被误认成「已保存的真相」。live 中性/缺口警示/
/// 失败红。静态(诚实不闪烁)。
class AnHonestyRibbon extends StatelessWidget {
  const AnHonestyRibbon(this.honesty, {super.key});

  final AnHonesty honesty;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final (tone, soft, text) = switch (honesty) {
      AnHonesty.live => (c.inkFaint, c.surfaceSunken, t.chat.stage.ribbonLive),
      AnHonesty.gap => (c.warn, c.warnSoft, t.chat.stage.ribbonGap),
      AnHonesty.failed => (c.danger, c.dangerSoft, t.chat.stage.ribbonFailed),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s2),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AnRadius.tag),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (honesty != AnHonesty.live) ...[
          Icon(AnIcons.error, size: AnSize.iconSm - 2, color: tone),
          const SizedBox(width: AnSpace.s4),
        ],
        Flexible(
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: tone)),
        ),
      ]),
    );
  }
}
