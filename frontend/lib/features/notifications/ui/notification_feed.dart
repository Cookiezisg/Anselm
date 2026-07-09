import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/notification.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_divider.dart';
import '../../../core/ui/an_interactive.dart';
import '../../../core/ui/an_rail_skeleton.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../state/notification_feed_provider.dart';
import '../state/unread_count_provider.dart';
import 'notification_copy.dart';
import 'notification_row.dart';

/// The "Notifications" feed section of the bell tray — the newest-first inbox, time-grouped
/// (Today/Yesterday/Earlier), each row tapping through to its source (and marking itself read). A
/// "Mark all read" sits in the section header. Empty → the caught-up state. Infinite scroll via the
/// feed notifier's loadMore. The actionable "Needs you" section is composed ABOVE this by the app shell
/// (it owns the cross-feature FlowrunInbox); this widget is the feed alone.
///
/// 铃托盘的「通知」feed 段——最新优先的收件箱,按时间分组(今天/昨天/更早),点行深链到源对象(并顺手已读)。
/// 段头带「全部已读」。空→都处理完了。无限下滑经 feed notifier 的 loadMore。上方「待你处理」段由 app 壳组合
/// (它持跨 feature 的 FlowrunInbox);本件只是 feed。
class NotificationFeed extends ConsumerStatefulWidget {
  const NotificationFeed({super.key});

  @override
  ConsumerState<NotificationFeed> createState() => _NotificationFeedState();
}

class _NotificationFeedState extends ConsumerState<NotificationFeed> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      ref.read(notificationFeedProvider.notifier).loadMore();
    }
  }

  void _open(NotificationItem n) {
    // Mark read whether or not it navigates (an inert-kind row still clears on tap). 无论是否深链都顺手已读。
    ref.read(notificationFeedProvider.notifier).markRead(n.id);
    final loc = notificationLocation(n);
    if (loc != null && context.mounted) context.go(loc);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.notifications;
    final async = ref.watch(notificationFeedProvider);
    final hasUnread = ref.watch(unreadCountProvider).value != null &&
        ref.watch(unreadCountProvider).value! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: t.feed, showMarkAll: hasUnread, onMarkAll: () => ref.read(notificationFeedProvider.notifier).markAllRead()),
        const AnDivider(),
        Expanded(
          child: async.when(
            loading: () => const AnDeferredLoading(child: AnRailSkeleton()),
            error: (_, _) => AnState(
              kind: AnStateKind.error,
              size: AnStateSize.inset,
              title: context.t.notifications.errorTitle,
              action: AnButton(
                label: context.t.notifications.retry,
                onPressed: () => ref.invalidate(notificationFeedProvider),
              ),
            ),
            data: (s) => s.rows.isEmpty
                ? AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: t.emptyTitle, hint: t.emptyHint)
                : _list(context, s.rows),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, List<NotificationItem> rows) {
    final items = _grouped(rows, context.t);
    return ScrollConfiguration(
      behavior: const AnScrollBehavior(),
      child: ListView.builder(
        controller: _scroll,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          return switch (it) {
            _GroupHeader(:final label) => _SectionLabel(label),
            _RowItem(:final item) => NotificationRow(
                item: item,
                onTap: () => _open(item),
                onMarkRead: () => ref.read(notificationFeedProvider.notifier).markRead(item.id),
              ),
          };
        },
      ),
    );
  }
}

/// Group rows into Today / Yesterday / Earlier buckets by LOCAL calendar day (a flat item list with
/// header markers, so one ListView renders both). 按本地日历日分桶(扁平项列表 + 头标记,一 ListView 通渲)。
List<_FeedItem> _grouped(List<NotificationItem> rows, Translations tr) {
  final t = tr.notifications;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  int bucket(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (!day.isBefore(today)) return 0;
    if (!day.isBefore(yesterday)) return 1;
    return 2;
  }

  final out = <_FeedItem>[];
  int? last;
  for (final r in rows) {
    final b = bucket(r.createdAt.toLocal());
    if (b != last) {
      out.add(_GroupHeader(switch (b) { 0 => t.today, 1 => t.yesterday, _ => t.earlier }));
      last = b;
    }
    out.add(_RowItem(r));
  }
  return out;
}

sealed class _FeedItem {
  const _FeedItem();
}

class _GroupHeader extends _FeedItem {
  const _GroupHeader(this.label);
  final String label;
}

class _RowItem extends _FeedItem {
  const _RowItem(this.item);
  final NotificationItem item;
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.showMarkAll, required this.onMarkAll});
  final String title;
  final bool showMarkAll;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AnSpace.s12, AnSpace.s12, AnSpace.s8, AnSpace.s8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AnText.label.copyWith(color: c.ink).weight(AnText.emphasisWeight))),
          if (showMarkAll)
            AnInteractive(
              onTap: onMarkAll,
              builder: (context, states) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6, vertical: AnSpace.s2),
                child: Text(
                  context.t.notifications.markAllRead,
                  style: AnText.meta.copyWith(color: states.isActive ? c.accentHover : c.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AnSpace.s12, AnSpace.s12, AnSpace.s12, AnSpace.s4),
      child: Text(label, style: AnText.meta.copyWith(color: c.inkFaint).weight(AnText.emphasisWeight)),
    );
  }
}
