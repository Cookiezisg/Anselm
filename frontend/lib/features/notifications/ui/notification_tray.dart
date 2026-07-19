import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/notification.dart';
import '../../../core/design/tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/notification_repository.dart';
import '../state/notification_feed_provider.dart';
import 'notification_copy.dart';
import 'notification_row.dart';

/// The bell-takeover tray, rebuilt 1:1 on the left-island rail row (0719) — a persistent
/// [AnRailFilterField] (search + a ⚙ display menu) over a scroll body of COLLAPSIBLE groups: an injected
/// [approvalsBand] as the top «待你处理» group, then the notification feed time-bucketed into 今天/昨天/更早
/// heads. Every head is an [AnRow] — EXACTLY the chat rail's Pinned/Recents head (a permanent lead chevron,
/// count meta that swaps to a hover ⋯ bulk menu, a rounded hover block, whole-row toggle), rendered BARE (no
/// outer padding) so it obeys the SAME rail geometry as the search field + rows: the hover block fills the
/// island inner width and the content column sits at the rail's +s8 content inset — one vertical line for the
/// search magnifier, every head chevron, and every row icon. The head ⋯ carries mark-all-read /
/// mark-all-unread scoped to THAT time-group's window (clearing «今天» leaves the «更早» backlog untouched —
/// a `[after, before)` window derived from the SAME day boundaries the bucketing uses, [NotificationDayBuckets]).
/// The retired chrome — the "Notifications" title, the divider, the top
/// "Mark all read" button — is gone; its function moved into the head ⋯ menus.
///
/// **Collapse/expand rides the SAME rail mechanism as [AnSidebarList]** (0719 user follow-up: "the slide
/// effect was lost"): the feed heads+rows are held in [_flat] locked to a [SliverAnimatedList] (GlobalKey).
/// A user TOGGLE remove/inserts that bucket's contiguous row range with a [SizeTransition] (`axisAlignment
/// -1`, top-anchored) over [AnMotion.mid] (reduced → instant) — a real slide, never an instant jump; while
/// a DATA/filter change (feed refresh / loadMore / mark-read / search / unread-only) re-flattens fresh under
/// a NEW key with no insert/remove animation (the tween is only for user toggles). The «待你处理» band is a
/// SEPARATE leading sliver — its own [AnExpandReveal] animates independently and its state survives feed
/// churn (it is not inside the re-keyed animated list).
///
/// The approvals band is injected (not imported) because it belongs to the ENTITIES feature — the app shell
/// composes it in, keeping features independent. Search filters the FEED content (the band hides while a
/// query is active — approvals aren't "notification content"). "Unread only" is the ⚙ display toggle.
///
/// 铃托盘,1:1 照左岛 rail 行重造(0719):常驻 AnRailFilterField(搜索 + ⚙ 显示菜单)+ 可折叠组滚动体:注入的
/// approvalsBand 作顶「待你处理」组,下接通知 feed 按今天/昨天/更早分组。每个组头就是 AnRow——与 chat rail 的
/// 置顶/最近头一模一样(常驻箭头 lead + 数字 meta↔hover ⋯ 批量菜单 + 圆角 hover 块 + 整行折叠),**裸放**(无外距)
/// 遵 rail 几何律:hover 块吃满岛内宽、内容列落 +s8——搜索放大镜/每个组头 chevron/每行图标同一竖线。组头 ⋯ 带
/// 全部已读/全部未读、**限该时间组窗口**(清「今天」不动「更早」的积压——窗口 `[after, before)` 与分桶共用同一日界
/// NotificationDayBuckets)。退役 chrome(「通知」标题 / 分割线 / 顶「全部已读」钮)
/// 全去,功能并入组头 ⋯。**折叠/展开与 AnSidebarList 同一套 rail 机制**(0719 用户复验「展开收起的效果丢了」):
/// feed 头+行持在 `_flat`、与 `SliverAnimatedList`(GlobalKey)锁步;**用户 toggle** 按同配方对该组连续行区间
/// remove/insert(SizeTransition 顶锚,AnMotion.mid,reduced 即时)——真滑动、非瞬跳;**数据/过滤变**(刷新/loadMore/
/// 已读/搜索/仅未读)换新 key 整重建、不插删动画。「待你处理」band 是独立首 sliver——自带 AnExpandReveal 动画、
/// 状态不随 feed churn 重置(不在被换 key 的动画列表里)。approvalsBand 注入(非 import)——它属 entities feature,
/// app 壳组合,features 保持独立。搜索过滤 feed 内容(有 query 时藏 band);⚙ = 仅显示未读。
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

  // The FEED flat (heads + rows, band excluded — the band is its own leading sliver) held in lock-step with
  // the SliverAnimatedList: a user toggle animates a precise sub-range; a data/filter change rebuilds it
  // fresh under a new key. 展平 feed(头+行,不含 band)与 AnimatedList 锁步:toggle 动画精确子区间、数据变换 key 整重建。
  late List<_TrayEntry> _flat;
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _flat = <_TrayEntry>[];
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

  List<NotificationItem> _rowsFromProvider() =>
      ref.read(notificationFeedProvider).value?.rows ?? const <NotificationItem>[];

  // Re-flatten the FEED every build (a bounded feed — cheap, same as the pre-animation tray) and compare
  // STRUCTURALLY to the held _flat. A real content change (a new/removed row, a mark-read flipping isUnread,
  // search / unread-only) re-keys the SliverAnimatedList fresh → an instant rebuild, NO insert/remove tween
  // (the tween is only for user toggles). An equal re-flatten leaves the animated list + its key untouched so
  // a toggle's slide plays to completion. The compare is STRUCTURAL (not list-identity) on purpose: the feed
  // provider hands new-but-equal `rows` lists (a post-settle emission), and an identity check false-re-keys
  // mid-slide → the collapse would snap instead of sliding.
  // 每 build 重展平(有界 feed、廉价,同动画前的托盘)并与 _flat **结构比对**:真内容变(增删行 / mark-read 翻 isUnread /
  // 搜索 / 仅未读)换 key 整重建(即时、无插删动画,补间只给 toggle);等价重展平不动 key、让 toggle 滑动播完。用**结构比对**
  // (非身份):feed provider 递「新身份、等价内容」的 rows,身份比对会误换 key 打断滑动→折叠变瞬跳。
  void _syncFlat(List<NotificationItem> rows) {
    final next = _feedEntries(rows, context.t);
    if (listEquals(next, _flat)) return;
    _flat = next;
    _listKey = GlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.notifications;
    final async = ref.watch(notificationFeedProvider);
    _syncFlat(async.value?.rows ?? const <NotificationItem>[]);
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
        Expanded(child: _body(context, async)),
      ],
    );
  }

  Widget _body(BuildContext context, AsyncValue<dynamic> async) {
    final t = context.t.notifications;
    // First-screen outcomes ride the ONE rail resolver (same face as the conversation / entity rails); an
    // empty feed is not a state — it resolves to the (empty) list, no tombstone. 首屏态走唯一 rail 件,空 feed 直落空列表。
    return AnRailStates(
      loading: async.isLoading && !async.hasValue,
      error: async.hasError && !async.hasValue,
      strings: AnRailStrings(errorTitle: t.errorTitle, errorHint: t.errorHint, retry: t.retry),
      onRetry: () => ref.invalidate(notificationFeedProvider),
      builder: () => _list(context),
    );
  }

  Widget _list(BuildContext context) {
    // The band shows only when NOT searching (approvals aren't notification content); it is a SEPARATE
    // leading sliver so its own AnExpandReveal + state survive the feed's re-key rebuilds. 搜索时藏 band;band 独立首 sliver。
    final showBand = widget.approvalsBand != null && _query.trim().isEmpty;
    return ScrollConfiguration(
      behavior: const AnScrollBehavior(),
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          if (showBand) SliverToBoxAdapter(child: widget.approvalsBand!),
          SliverAnimatedList(
            key: _listKey,
            initialItemCount: _flat.length,
            itemBuilder: (context, index, animation) => _animatedEntry(context, _flat[index], animation),
          ),
          SliverToBoxAdapter(child: _tail(context)),
        ],
      ),
    );
  }

  // Wraps an entry in the SliverAnimatedList's size tween so a collapse/expand slides its height (the rows
  // slide up under their head; axisAlignment -1 anchors to the top — the rail slide). 折叠补间:行高滑动(-1 顶锚)。
  Widget _animatedEntry(BuildContext context, _TrayEntry entry, Animation<double> animation) =>
      SizeTransition(sizeFactor: animation, axisAlignment: -1, child: _entryWidget(context, entry));

  Widget _entryWidget(BuildContext context, _TrayEntry entry) => switch (entry) {
        // The time-bucket head is the SAME primitive as the chat rail's Pinned/Recents head, rendered EXACTLY
        // like it: a BARE AnRow (no outer padding). The island already gives the s12 gutter, so AnRow's hover
        // block fills the island inner width (block edge on the island edge) and its chevron/count sit at the
        // rail's s8 content inset (+8) — one column with the search field + notification rows. 组头=裸 AnRow(无外距):
        // 岛已给 s12 沟,hover 块吃满岛内宽、chevron/数字落 s8 内容列——与搜索框/通知行同一竖线。
        _HeadEntry(:final bucket, :final label, :final count) => AnRow(
            collapsible: true,
            open: _bucketOpen(bucket),
            label: label,
            meta: '$count',
            onSelect: () => _toggleBucket(bucket),
            onToggle: () => _toggleBucket(bucket),
            actions: _markAllActions(context, bucket),
          ),
        _RowEntry(:final item) => NotificationRow(
            item: item,
            onTap: () => _open(item),
            onMarkRead: () => ref.read(notificationFeedProvider.notifier).markRead(item.id),
          ),
      };

  // The pagination tail (below the animated list): a dim spinner while a page lands (the loadMore itself is
  // driven by the scroll listener) + the bottom breathing room off the last row. 分页尾 + 底部留白。
  Widget _tail(BuildContext context) {
    final loadingMore = ref.watch(notificationFeedProvider.select((a) => a.value?.loadingMore ?? false));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loadingMore)
          SizedBox(
            height: AnSize.row,
            child: Center(child: AnSpinner(size: AnSize.iconSm, semanticLabel: context.t.a11y.loading)),
          ),
        const SizedBox(height: AnSpace.s8),
      ],
    );
  }

  // Fold/unfold a time bucket — the SAME recipe as AnSidebarList._toggle: the head + its rows are a
  // contiguous range in _flat; a collapse remove-animates that range (reverse order so indices stay valid),
  // an expand re-flattens + insert-animates the new rows — keeping _flat and the SliverAnimatedList in
  // lock-step. Duration is reduced-gated. 折叠/展开时段=AnSidebarList._toggle 同配方;时长 reduced 门控。
  void _toggleBucket(int bucket) {
    final headIdx = _flat.indexWhere((e) => e is _HeadEntry && e.bucket == bucket);
    if (headIdx < 0) return;
    final state = _listKey.currentState;
    final dur = AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid;
    final collapsing = !_collapsed.contains(bucket);
    if (collapsing) {
      _collapsed.add(bucket);
    } else {
      _collapsed.remove(bucket);
    }
    final newFlat = _feedEntries(_rowsFromProvider(), context.t);
    if (collapsing) {
      final removedCount = _flat.length - newFlat.length;
      final removed = _flat.sublist(headIdx + 1, headIdx + 1 + removedCount);
      _flat = newFlat;
      for (var i = headIdx + removedCount; i > headIdx; i--) {
        final entry = removed[i - headIdx - 1];
        state?.removeItem(i, (context, animation) => _animatedEntry(context, entry, animation), duration: dur);
      }
    } else {
      final insertCount = newFlat.length - _flat.length;
      _flat = newFlat;
      for (var i = headIdx + 1; i <= headIdx + insertCount; i++) {
        state?.insertItem(i, duration: dur);
      }
    }
    setState(() {}); // refresh the toggled head's chevron (rotates over AnMotion.mid alongside the slide) 头箭头旋转
  }

  /// The head's hover-revealed bulk menu (rides AnRow's meta↔actions swap — count at rest, ⋯ on hover):
  /// mark THIS TIME-GROUP read / unread (user 0720: «全部已读» on a group clears only that group — clearing
  /// «今天» must leave the «更早» backlog untouched). The action carries the bucket's `[after, before)` window,
  /// computed from [NotificationDayBuckets] — the SAME day boundaries the bucketing uses, so a row's group and
  /// the window its ⋯ sweeps can never disagree at a day edge. `now` is read INSIDE the tap (freshest — the
  /// tray may sit open across midnight) rather than captured at build. The menu text stays «全部已读/未读» —
  /// self-evident under the group head. Both items are ALWAYS present and idempotent: the loaded feed window
  /// can't authoritatively answer "does any read row exist" across the paginated ledger, so gating an item
  /// would risk lying; a degenerate click is a harmless no-op.
  /// 组头 hover ⋯:标**该时间组**已读/未读(0720:组上的「全部已读」只清该组、清「今天」不动「更早」);动作带该组
  /// `[after,before)` 窗口(NotificationDayBuckets——与分桶同一日界,行组与窗口在日界处绝不打架);now 在**点击时**读
  /// (最新——托盘可能跨午夜常驻)。菜单文案仍「全部已读/未读」(组语境自明)。两项恒在且幂等(退化态=无害 no-op)。
  List<Widget> _markAllActions(BuildContext context, int bucket) {
    final t = context.t;
    return [
      AnMenu(
        entries: [
          AnMenuItem(
            label: t.notifications.markAllRead,
            icon: AnIcons.check,
            onTap: () => ref
                .read(notificationFeedProvider.notifier)
                .markAllRead(window: NotificationDayBuckets(DateTime.now()).windowOf(bucket)),
          ),
          AnMenuItem(
            label: t.notifications.markAllUnread,
            icon: AnIcons.undo,
            onTap: () => ref
                .read(notificationFeedProvider.notifier)
                .markAllUnread(window: NotificationDayBuckets(DateTime.now()).windowOf(bucket)),
          ),
        ],
        anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(AnIcons.more,
            size: AnButtonSize.sm, semanticLabel: t.a11y.moreActions, onPressed: toggle),
      ),
    ];
  }

  /// Flatten the FEED (band excluded) into collapsible time-bucket groups, honoring the search query + the
  /// "unread only" filter. A collapsed bucket contributes only its head (its rows are omitted). 展平 feed 时段组。
  List<_TrayEntry> _feedEntries(List<NotificationItem> rows, Translations tr) {
    final t = tr.notifications;
    final out = <_TrayEntry>[];
    final q = _query.trim().toLowerCase();
    Iterable<NotificationItem> visible = rows;
    if (_unreadOnly) visible = visible.where((r) => r.isUnread);
    if (q.isNotEmpty) visible = visible.where((r) => _matches(r, tr, q));

    // The SAME day boundaries the bulk-mark windows derive from ([NotificationDayBuckets]) — one分界源, so a
    // row's bucket and the window its head's ⋯ sweeps can never disagree. 与批量标记窗口同一日界源。
    final days = NotificationDayBuckets(DateTime.now());
    final buckets = <int, List<NotificationItem>>{};
    for (final r in visible) {
      buckets.putIfAbsent(days.bucketOf(r.createdAt.toLocal()), () => []).add(r);
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

}

/// The LOCAL day boundaries that split the notification feed into today (0) / yesterday (1) / earlier (2) —
/// the SINGLE source both the tray's time-bucketing ([bucketOf]) and each group's bulk-mark WINDOW ([windowOf])
/// derive from, so a row's bucket and the window that bucket's ⋯ action sweeps can never disagree at a day
/// edge. [now] is injected so the boundaries are unit-testable across time zones / day edges. The window
/// bounds are the local midnights converted to their UTC instants (the wire + `createdAt` are UTC), matching
/// the backend's `[after, before)` `created_at` comparison.
///
/// 把通知 feed 切成今天(0)/昨天(1)/更早(2)的**本地**日界——分桶(bucketOf)与每组批量标记窗口(windowOf)**共用的唯一**
/// 源,故行的组与该组 ⋯ 扫的窗口在日界处绝不打架。now 注入→分界可单测(跨时区/跨日界)。窗口界=本地零点换成 UTC
/// 时刻(线缆与 createdAt 皆 UTC),对齐后端 `[after, before)` 的 created_at 比较。
@visibleForTesting
class NotificationDayBuckets {
  NotificationDayBuckets(DateTime now) : todayStart = DateTime(now.year, now.month, now.day);

  /// Local midnight, start of today. 本地今日零点。
  final DateTime todayStart;

  /// Local midnight, start of yesterday. 本地昨日零点。
  DateTime get yesterdayStart => todayStart.subtract(const Duration(days: 1));

  /// Which bucket a LOCAL createdAt falls in (0 today / 1 yesterday / 2 earlier). 本地时间的时段归属。
  int bucketOf(DateTime localCreatedAt) {
    final day = DateTime(localCreatedAt.year, localCreatedAt.month, localCreatedAt.day);
    if (!day.isBefore(todayStart)) return 0;
    if (!day.isBefore(yesterdayStart)) return 1;
    return 2;
  }

  /// The half-open UTC window a bucket's bulk-mark sweeps: today = `[今日零点, ∞)`, yesterday =
  /// `[昨日零点, 今日零点)`, earlier = `(-∞, 昨日零点)` (null bound = unbounded). 组的批量标记窗口(UTC 半开)。
  MarkWindow windowOf(int bucket) => switch (bucket) {
        0 => MarkWindow(after: todayStart.toUtc()),
        1 => MarkWindow(after: yesterdayStart.toUtc(), before: todayStart.toUtc()),
        _ => MarkWindow(before: yesterdayStart.toUtc()),
      };
}

sealed class _TrayEntry {
  const _TrayEntry();
}

class _HeadEntry extends _TrayEntry {
  const _HeadEntry(this.bucket, this.label, this.count);
  final int bucket;
  final String label;
  final int count;

  // Value equality so _syncFlat's structural listEquals detects a real count/label change (re-key) vs an
  // equal re-flatten (keep the animated list). 值相等,让 listEquals 区分真变化与等价重展平。
  @override
  bool operator ==(Object other) =>
      other is _HeadEntry && other.bucket == bucket && other.label == label && other.count == count;

  @override
  int get hashCode => Object.hash(bucket, label, count);
}

class _RowEntry extends _TrayEntry {
  const _RowEntry(this.item);
  final NotificationItem item;

  // Value equality on the (freezed) item — a mark-read flips readAt → not equal → a re-key refreshes the row.
  // 值相等(freezed item):mark-read 翻 readAt→不等→换 key 刷新该行。
  @override
  bool operator ==(Object other) => other is _RowEntry && other.item == item;

  @override
  int get hashCode => item.hashCode;
}
