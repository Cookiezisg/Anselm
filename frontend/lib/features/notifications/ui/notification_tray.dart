import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/notification.dart';
import '../../../core/design/tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/notification_feed_provider.dart';
import '../state/unread_count_provider.dart';
import 'notification_copy.dart';
import 'notification_row.dart';

/// The bell-takeover tray, rebuilt on the left-island rail architecture (0719) — a persistent
/// [AnRailFilterField] (search + a ⚙ display menu) over a scroll body of COLLAPSIBLE groups: an injected
/// [approvalsBand] as the top «待你处理» group, then the notification feed time-bucketed into 今天/昨天/更早
/// [AnGroupHead]s, each with a ⋯ menu (mark-all-read). The retired chrome — the "Notifications" title, the
/// divider, the top "Mark all read" button — is gone; its function moved into the group ⋯ menus.
///
/// The approvals band is injected (not imported) because it belongs to the ENTITIES feature — the app shell
/// composes it in, keeping features independent. Search filters the FEED content (the band hides while a
/// query is active — approvals aren't "notification content"). "Unread only" is the ⚙ display toggle.
///
/// 铃托盘,照左岛 rail 架构重造(0719):常驻 AnRailFilterField(搜索 + ⚙ 显示菜单)+ 可折叠组滚动体:注入的
/// approvalsBand 作顶「待你处理」组,下接通知 feed 按今天/昨天/更早分成 AnGroupHead 组、各带 ⋯ 菜单(全部已读)。
/// 退役 chrome(「通知」标题 / 分割线 / 顶「全部已读」钮)全去,功能并入组 ⋯ 菜单。approvalsBand 注入(非 import)——
/// 它属 entities feature,app 壳组合,features 保持独立。搜索过滤 feed 内容(有 query 时藏 band);⚙ = 仅显示未读。
class NotificationTray extends ConsumerStatefulWidget {
  const NotificationTray({this.approvalsBand, super.key});

  /// The "Needs you" approval band (an entities-feature widget), rendered as the top group. Null → no band
  /// (gallery / tests). 顶「待你处理」审批带(entities 件),作首组;null=无带(gallery/测试)。
  final Widget? approvalsBand;

  @override
  ConsumerState<NotificationTray> createState() => _NotificationTrayState();
}

class _NotificationTrayState extends ConsumerState<NotificationTray> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  bool _unreadOnly = false;
  final Set<int> _collapsed = {}; // collapsed time buckets (0 today / 1 yesterday / 2 earlier) 折叠时段

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      ref.read(notificationFeedProvider.notifier).loadMore();
    }
  }

  // A live query force-opens every bucket (matches hide behind their heads otherwise). query 强制展开每组。
  bool _bucketOpen(int b) => _query.trim().isNotEmpty || !_collapsed.contains(b);

  void _open(NotificationItem n) {
    // Mark read whether or not it navigates (an inert-kind row still clears on tap). 无论是否深链都顺手已读。
    ref.read(notificationFeedProvider.notifier).markRead(n.id);
    final loc = notificationLocation(n);
    if (loc != null && context.mounted) context.go(loc);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.notifications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnRailFilterField(
          controller: _search,
          placeholder: t.searchPlaceholder,
          onChanged: (v) => setState(() => _query = v),
          menuSemanticLabel: context.t.a11y.displayOptions,
          menuEntries: [
            AnMenuSection(t.displayOptions),
            AnMenuItem(
              label: t.unreadOnly,
              checked: _unreadOnly,
              keepOpen: true,
              onTap: () => setState(() => _unreadOnly = !_unreadOnly),
            ),
          ],
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final t = context.t.notifications;
    final async = ref.watch(notificationFeedProvider);
    final rows = async.value?.rows ?? const <NotificationItem>[];
    // First-screen outcomes ride the ONE rail resolver (same face as the conversation / entity rails); an
    // empty feed is not a state — it resolves to the (empty) list, no tombstone. 首屏态走唯一 rail 件,空 feed 直落空列表。
    return AnRailStates(
      loading: async.isLoading && !async.hasValue,
      error: async.hasError && !async.hasValue,
      strings: AnRailStrings(errorTitle: t.errorTitle, errorHint: t.errorHint, retry: t.retry),
      onRetry: () => ref.invalidate(notificationFeedProvider),
      builder: () => _list(context, rows),
    );
  }

  Widget _list(BuildContext context, List<NotificationItem> rows) {
    final tr = context.t;
    final hasMore = ref.watch(notificationFeedProvider.select((a) => a.value?.hasMore ?? false));
    final loadingMore = ref.watch(notificationFeedProvider.select((a) => a.value?.loadingMore ?? false));
    final items = _entries(rows, tr);
    return ScrollConfiguration(
      behavior: const AnScrollBehavior(),
      child: ListView.builder(
        controller: _scroll,
        // Keep the bottom breathing room off the last card / row. 底部留白。
        padding: const EdgeInsets.only(bottom: AnSpace.s8),
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= items.length) {
            // loadMore tail (fires via the scroll listener); a dim spinner while a page lands. 分页尾。
            return SizedBox(
              height: AnSize.row,
              child: loadingMore
                  ? Center(child: AnSpinner(size: AnSize.iconSm, semanticLabel: context.t.a11y.loading))
                  : const SizedBox.shrink(),
            );
          }
          return switch (items[i]) {
            _BandEntry() => widget.approvalsBand ?? const SizedBox.shrink(),
            _HeadEntry(:final bucket, :final label, :final count) => AnGroupHead(
                label: label,
                count: count,
                open: _bucketOpen(bucket),
                onToggle: () => setState(() =>
                    _collapsed.contains(bucket) ? _collapsed.remove(bucket) : _collapsed.add(bucket)),
                // 12-left single source — heads / rows / cards / the band all share one edge. 左缘单源 12。
                padding: const EdgeInsetsDirectional.only(start: AnSpace.s12, end: AnSpace.s12),
                // The retired top "Mark all read" button lives here now (acts on ALL notifications — one
                // ledger, per-group already-read reads odd; user 0719 lean). Only when there's unread.
                // 退役的顶「全部已读」钮现住这:作用于全部通知(一本账),仅有未读时显。
                trailing: _markAllTrailing(context),
              ),
            _RowEntry(:final item) => NotificationRow(
                item: item,
                onTap: () => _open(item),
                onMarkRead: () => ref.read(notificationFeedProvider.notifier).markRead(item.id),
              ),
          };
        },
      ),
    );
  }

  Widget? _markAllTrailing(BuildContext context) {
    final hasUnread = (ref.watch(unreadCountProvider).value ?? 0) > 0;
    if (!hasUnread) return null;
    return AnMenu(
      entries: [
        AnMenuItem(
          label: context.t.notifications.markAllRead,
          icon: AnIcons.check,
          onTap: () => ref.read(notificationFeedProvider.notifier).markAllRead(),
        ),
      ],
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(AnIcons.more,
          size: AnButtonSize.sm, semanticLabel: context.t.a11y.moreActions, onPressed: toggle),
    );
  }

  /// Flatten the feed into (band?) + collapsible time-bucket groups, honoring the search query + the
  /// "unread only" filter. A collapsed bucket contributes only its head (its rows are omitted — instant
  /// collapse, virtualization preserved). 展平成 (band?) + 可折叠时段组,尊重搜索 + 仅未读;折叠组只留头。
  List<_TrayEntry> _entries(List<NotificationItem> rows, Translations tr) {
    final t = tr.notifications;
    final out = <_TrayEntry>[];
    // The band shows only when NOT searching (approvals aren't notification content). 搜索时藏 band。
    if (widget.approvalsBand != null && _query.trim().isEmpty) out.add(const _BandEntry());

    final q = _query.trim().toLowerCase();
    Iterable<NotificationItem> visible = rows;
    if (_unreadOnly) visible = visible.where((r) => r.isUnread);
    if (q.isNotEmpty) visible = visible.where((r) => _matches(r, tr, q));

    final now = DateTime.now();
    final buckets = <int, List<NotificationItem>>{};
    for (final r in visible) {
      buckets.putIfAbsent(_bucket(r.createdAt.toLocal(), now), () => []).add(r);
    }
    for (final b in const [0, 1, 2]) {
      final bucketRows = buckets[b];
      if (bucketRows == null || bucketRows.isEmpty) continue;
      out.add(_HeadEntry(b, switch (b) { 0 => t.today, 1 => t.yesterday, _ => t.earlier }, bucketRows.length));
      if (_bucketOpen(b)) {
        for (final r in bucketRows) {
          out.add(_RowEntry(r));
        }
      }
    }
    return out;
  }

  // Search over the rendered line (lead + name + trail + detail) — the frontend owns the copy, so the query
  // matches what the user SEES, not the raw type/payload. 搜索匹配渲染后的行文本(前端拥有文案)。
  bool _matches(NotificationItem n, Translations tr, String q) {
    final line = notificationLine(n, tr);
    final hay = [line.lead, line.name, line.trail, line.detail].whereType<String>().join(' ').toLowerCase();
    return hay.contains(q);
  }

  int _bucket(DateTime d, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);
    if (!day.isBefore(today)) return 0;
    if (!day.isBefore(yesterday)) return 1;
    return 2;
  }
}

sealed class _TrayEntry {
  const _TrayEntry();
}

class _BandEntry extends _TrayEntry {
  const _BandEntry();
}

class _HeadEntry extends _TrayEntry {
  const _HeadEntry(this.bucket, this.label, this.count);
  final int bucket;
  final String label;
  final int count;
}

class _RowEntry extends _TrayEntry {
  const _RowEntry(this.item);
  final NotificationItem item;
}
