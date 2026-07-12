import 'package:flutter/widgets.dart';

import '../../../core/contract/notification.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_status_dot.dart';
import '../../../core/ui/an_interactive.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import 'notification_copy.dart';

/// ONE notification-center row — a pure presentational widget (no ref): [item] in, tap/mark-read out.
/// Anatomy (WRK-058 §D.1): `[unread dot] [tone icon] {kind}「{name}」{verb}  {relative time}`, with an
/// optional muted second line (an error / a dependency count). UNREAD → the object name is emphasized
/// (w400 ink) and a dot leads; READ → the whole row grays to inkFaint (a read row stays in the list as
/// an audit trail, just quiet). On hover the time swaps for a "mark read" affordance (unread only).
///
/// 一条通知行——纯展示(无 ref):item 进,tap/mark-read 出。解剖(§D.1):未读点·tone 图标·{类}「{名}」{动词}·
/// 相对时间,可选灰第二行。未读→宾语名 w400 ink + 行首点;已读→整行灰(留列表作审计流,只是安静)。
/// hover 时时间换成 mark-read(仅未读)。
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    required this.item,
    this.now,
    this.onTap,
    this.onMarkRead,
    super.key,
  });

  final NotificationItem item;

  /// Injected clock for the relative time (tests pin it; null = wall clock). 注入时钟(测试钉;null=墙钟)。
  final DateTime? now;

  /// Deep-link to the source object (and, by the tray's convention, mark it read). 深链到源对象。
  final VoidCallback? onTap;

  /// Explicit mark-read (the hover affordance) — null when the row is already read. 显式已读(hover);已读则 null。
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.t;
    final line = notificationLine(item, t);
    final unread = item.isUnread;
    final iconColor = _toneColor(line.tone, c, unread: unread);

    return AnInteractive(
      onTap: onTap,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          color: hovered ? c.surfaceHover : null,
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread dot column (fixed width so read/unread rows align). 未读点列(定宽,读/未读对齐)。
              SizedBox(
                width: AnSpace.s8,
                child: unread
                    ? Padding(
                        padding: const EdgeInsets.only(top: AnSpace.s6),
                        child: AnStatusDot.raw( _toneColor(line.tone, c, unread: true)),
                      )
                    : null,
              ),
              const SizedBox(width: AnSpace.s6),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(line.icon, size: AnSize.icon, color: iconColor),
              ),
              const SizedBox(width: AnSpace.s8),
              Expanded(child: _body(context, line, unread: unread)),
              const SizedBox(width: AnSpace.s8),
              // Time, or the mark-read affordance on hover (unread only). 时间;hover 换 mark-read(仅未读)。
              _trailing(context, hovered: hovered, unread: unread),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, NotificationLine line, {required bool unread}) {
    final c = context.colors;
    // READ rows gray out entirely; UNREAD rows keep the muted lead/trail + an emphasized ink name.
    // 已读整行灰;未读=灰 lead/trail + 强调 ink 名。
    final mutedColor = unread ? c.inkMuted : c.inkFaint;
    final nameColor = unread ? c.ink : c.inkFaint;
    final muted = AnText.body.copyWith(color: mutedColor);
    final name = AnText.body
        .copyWith(color: nameColor)
        .weight(unread ? AnText.emphasisWeight : AnText.bodyWeight);

    final spans = <InlineSpan>[
      if (line.lead != null && line.lead!.isNotEmpty) TextSpan(text: '${line.lead!} ', style: muted),
      if (line.name != null && line.name!.isNotEmpty) TextSpan(text: '「${line.name!}」', style: name),
      TextSpan(text: line.name != null && line.name!.isNotEmpty ? ' ${line.trail}' : line.trail, style: muted),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(children: spans), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (line.detail != null && line.detail!.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s2),
          Text(
            line.detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
        ],
      ],
    );
  }

  Widget _trailing(BuildContext context, {required bool hovered, required bool unread}) {
    final c = context.colors;
    if (hovered && unread && onMarkRead != null) {
      return AnButton.iconOnly(
        AnIcons.check,
        size: AnButtonSize.sm,
        semanticLabel: context.t.notifications.markRead,
        onPressed: onMarkRead,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Text(
        fmtWaitedSince(item.createdAt, now: now),
        style: AnText.meta.copyWith(color: c.inkFaint),
      ),
    );
  }

  static Color _toneColor(NotificationTone tone, AnColors c, {required bool unread}) => switch (tone) {
        // A read row's icon dims to inkFaint regardless of tone (the row is quiet); unread keeps its tone.
        // 已读图标一律 inkFaint(安静);未读保留 tone。
        NotificationTone.neutral => unread ? c.inkMuted : c.inkFaint,
        NotificationTone.warn => unread ? c.warn : c.inkFaint,
        NotificationTone.danger => unread ? c.danger : c.inkFaint,
      };
}

