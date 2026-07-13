import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../../i18n/strings.g.dart';
import 'an_interactive.dart';
import 'an_status_dot.dart';
import 'icons.dart';

/// One parallel activity in the strip. 频道条一项。
class AnChannel {
  const AnChannel({
    required this.id,
    required this.kind,
    this.unread = 0,
    this.live = true,
    this.failed = false,
  });

  final String id;
  final String kind;
  final int unread;
  final bool live;
  final bool failed;
}

/// The CHANNEL STRIP (WRK-061 §6-①, Flight Deck graft): the row of parallel-activity mini-tabs under
/// the stage head — kind glyph + status dot (live accent / failed danger / settled ok) + unread count.
/// Appears only with ≥1 channels (the caller gates). Caps at [maxTabs]; overflow renders a «+N» stub.
/// Tapping a tab = the user taking the camera (the director flips to pinned).
///
/// 频道条(Flight Deck 嫁接):舞台头下并行活动 mini-tab 排——kind 字形+状态点(live 蓝/failed 红/落定绿)
/// +未读数。有并行才现(调用方把门);cap 满渲「+N」;点 tab=用户持镜(导演器翻 pinned)。
class AnChannelStrip extends StatelessWidget {
  const AnChannelStrip({
    required this.channels,
    this.activeId,
    this.onTap,
    this.maxTabs = 4,
    super.key,
  });

  final List<AnChannel> channels;

  /// The on-stage subject's id (its tab renders selected). 台上主角 id(其 tab 渲选中)。
  final String? activeId;

  final void Function(String id)? onTap;
  final int maxTabs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final shown = channels.take(maxTabs).toList();
    final overflow = channels.length - shown.length;
    return Row(children: [
      for (final ch in shown)
        Padding(
          padding: const EdgeInsets.only(right: AnSpace.s4),
          child: _tab(context, c, ch),
        ),
      if (overflow > 0)
        Text(t.feedback.cast.moreChannels(n: overflow), style: AnText.meta.copyWith(color: c.inkFaint)),
    ]);
  }

  Widget _tab(BuildContext context, AnColors c, AnChannel ch) {
    final selected = ch.id == activeId;
    final dot = ch.failed
        ? c.danger
        : ch.live
            ? c.accent
            : c.ok;
    return AnInteractive(
      onTap: onTap == null ? null : () => onTap!(ch.id),
      builder: (ctx, states) => Container(
        height: AnSize.controlSm,
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6),
        decoration: BoxDecoration(
          color: selected || states.isActive ? c.surfaceHover : null,
          border: Border.all(color: c.line.whenActive(selected), width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.chip),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(AnIcons.entityKindGlyph(ch.kind), size: AnSize.iconSm, color: c.inkMuted),
          const SizedBox(width: AnSpace.s4),
          AnStatusDot.raw(dot, size: AnSize.dotSm),
          if (ch.unread > 0) ...[
            const SizedBox(width: AnSpace.s4),
            Text('${ch.unread > 99 ? '99+' : ch.unread}',
                style: AnText.meta.copyWith(color: c.inkMuted)),
          ],
        ]),
      ),
    );
  }
}
