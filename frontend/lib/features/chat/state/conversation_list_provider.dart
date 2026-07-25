import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/conversation.dart';
import '../../../core/shell/oceans.dart';
import '../../../core/state/bool_pref.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../data/conversation_signal.dart';
import '../data/turn_signal.dart';
import 'conversation_list_state.dart';
import 'title_reveals.dart';

/// The conversation list sort — a transient view preference (activity / created / name), held in its
/// own provider so the list notifier can `watch` it and re-page from the top whenever it changes (a
/// keyset cursor is meaningless across sorts, so switching MUST reset pagination — `build` re-running
/// gives that for free). Drives the rail's ⚙ sort menu.
///
/// 对话列表排序——瞬时视图偏好(activity/created/name),独立 provider,使 list notifier 可 watch 它、变即从顶重翻
/// (跨 sort 游标无意义,切换必须重置分页——build 重跑天然给到)。驱动 rail 的 ⚙ 排序菜单。
class ConversationSortController extends Notifier<ConvSort> {
  @override
  ConvSort build() => ConvSort.activity;

  void set(ConvSort sort) {
    if (sort != state) state = sort;
  }
}

final conversationSortProvider =
    NotifierProvider<ConversationSortController, ConvSort>(
      ConversationSortController.new,
    );

/// Whether the rail shows archived threads too — the ⚙ "show archived" toggle. false → active-only
/// (ConvArchive.active); true → active + archived together (ConvArchive.all, archived rows carrying
/// archived=true for the gray dot). Watched by the list notifier (toggling re-pages from the top).
///
/// rail 是否也显归档——⚙「显示已归档」开关。false → 仅活跃;true → 活跃+归档同列(归档行带 archived=true 供灰点)。
/// 被 list notifier watch(切换即从顶重翻)。
final showArchivedProvider = NotifierProvider<BoolPrefNotifier, bool>(
  () => BoolPrefNotifier(false),
);

/// Whether the rail shows the per-section count (置顶 ··· 1) — the ⚙ "show counts" toggle, default ON.
/// rail 是否显分节计数(置顶···1)——⚙「显示分组计数」开关,默认开。
final showGroupCountProvider = NotifierProvider<BoolPrefNotifier, bool>(
  () => BoolPrefNotifier(true),
);

/// Whether each row shows its relative-time meta (10 分钟前) — the ⚙ "show time" toggle, default ON.
/// rail 每行是否显相对时间(10 分钟前)——⚙「显示时间」开关,默认开。
final showTimeProvider = NotifierProvider<BoolPrefNotifier, bool>(
  () => BoolPrefNotifier(true),
);

/// The conversation rail search query — a transient view state in its own provider so the list notifier
/// can `watch` it and re-page from the top whenever it changes. Server-side `?search`: a keyset cursor
/// minted under one query is meaningless under another, so switching MUST reset pagination — `build`
/// re-running gives that for free, exactly like sort/archived. `set` trims + no-ops on no change;
/// keystroke debouncing lives at the rail's search-box input edge, so this provider updates immediately
/// and stays trivially testable.
///
/// 对话列表搜索词——瞬时视图态,独立 provider,使 list notifier watch 它、变即从顶重翻。服务端 `?search`:一种查询下
/// 铸的游标在另一种下无意义,切换必须重置分页——build 重跑天然给到,与 sort/archived 一致。`set` trim + 无变化 no-op;
/// 逐键防抖在 rail 搜索框输入边,故此 provider 立即更新、保持易测。
class ConversationSearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) {
    final q = query.trim();
    if (q != state) state = q;
  }
}

final conversationSearchProvider =
    NotifierProvider<ConversationSearchController, String>(
      ConversationSearchController.new,
    );

/// The paging-axis key prefix for a residency group. The rail's fold key, its `onLoadMore` key and this
/// notifier's axis key are all THE SAME string, so a group's identity never has to be re-derived from a
/// label (which is localized and can collide) — see [ConversationListNotifier.loadMoreAxis].
///
/// 一个驻地组的分页轴键前缀。rail 的折叠键、它的 `onLoadMore` 键、与本 notifier 的轴键是**同一个**字符串,故一个组
/// 的身份永不必从标签反推(标签会本地化、也会撞名)——见 [ConversationListNotifier.loadMoreAxis]。
const String workDirAxisPrefix = 'wd:';

/// The Pinned / Recents axis keys — literal ids so the rail's fold + paging keys stay locale-independent.
/// 置顶 / 最近 的轴键——字面 id,使 rail 的折叠键与分页键与语言无关。
const String pinnedAxisKey = 'pinned';
const String recentsAxisKey = 'recents';

/// The residency path an axis key names, or null when the key is not a group axis.
/// 一个轴键所点出的驻地路径;键不是组轴时返 null。
String? workDirOfAxis(String axisKey) => axisKey.startsWith(workDirAxisPrefix)
    ? axisKey.substring(workDirAxisPrefix.length)
    : null;

/// The axis key for a residency. 某驻地的轴键。
String workDirAxisKey(String workDir) => '$workDirAxisPrefix$workDir';

/// The conversation rail's FOUR sections in one notifier — Pinned, the residency groups, and Recents — each
/// fed by its own server query, plus the `workdir-groups` projection that supplies the group heads.
///
/// **Why one notifier and not a provider per section**: the sections are not independent. A rename patches
/// whichever section holds the row; pinning MOVES a row between sections; mounting a residency moves it from
/// Recents into a group (and may CREATE that group); deleting the last unpinned thread of a group makes the
/// group vanish. All of that is one reconciliation, and splitting it across providers would mean every write
/// reaching into its siblings. The live wiring (lifecycle signals, the turn pulse, the 410 resync) is
/// likewise one subscription set, not 2+N.
///
/// **Why the grouping comes from the server**: the rail pages forever. Grouping the loaded window
/// client-side would make a group's membership and count DRIFT as the user scrolls — the head would state a
/// number that changes while nothing about the workspace changed. So counts and order come from the
/// projection, and each group's rows come from `?workDir=<path>` paged on its own.
///
/// It `watch`es the sort / show-archived / search providers, so changing any of them re-runs build → fresh
/// first pages everywhere (the cursor-reset-on-query-switch rule, free). Auto-retry is disabled so a failed
/// load surfaces the rail's explicit retry instead of oscillating back into a spinner.
///
/// 对话 rail 的**四段**在一个 notifier 里——置顶、驻地组、最近——各由自己的服务端查询喂养,加上供给组头的
/// `workdir-groups` 投影。
///
/// **为何一个 notifier 而非每段一个**:各段并不独立。改名要 patch 持有该行的那一段;置顶会把一行**移**到别段;挂驻地
/// 把它从「最近」移进某组(还可能**创建**那个组);删掉一个组最后一条未置顶线程会让组消失。这些全是**同一次**对账,
/// 拆成多个 provider 意味着每次写都要伸手进兄弟里。实时接线(生命周期信号、回合脉冲、410 resync)同样是**一套**订阅、
/// 不是 2+N 套。
///
/// **为何分组来自服务端**:rail 无限翻页。在客户端对已加载窗分组会让一个组的成员与计数随滚动**漂移**——组头会报出一个
/// 在 workspace 什么都没变时自己会变的数。故计数与顺序来自投影,而每个组的行来自各自翻页的 `?workDir=<path>`。
class ConversationListNotifier extends AsyncNotifier<ConversationListState> {
  late ChatRepository _repo;
  ConvSort _sort = ConvSort.activity;
  ConvArchive _archive = ConvArchive.active;
  String _search = '';

  // The server caps pages anyway; we request an explicit window so loadMore is exercised.
  // 服务端本就有页上限;此处显式请求一窗,使 loadMore 真正生效。
  static const int _pageSize = 30;

  // A query switch re-runs build WITHOUT disposing the notifier, so an in-flight page must be droppable:
  // every axis fetch captures this counter and discards its result when build has moved on.
  // 查询切换会重跑 build 而**不**释放 notifier,故在途页必须可丢弃:每次轴取数捕获本计数器、build 已前进时丢结果。
  int _generation = 0;

  @override
  Future<ConversationListState> build() async {
    _generation++;
    _repo = ref.watch(chatRepositoryProvider);
    _sort = ref.watch(conversationSortProvider);
    _archive = ref.watch(showArchivedProvider)
        ? ConvArchive.all
        : ConvArchive.active;
    _search = ref.watch(conversationSearchProvider);
    // Live lifecycle: the notifications stream reconciles the rail for changes this client didn't originate
    // (auto-title after the first message, or another window's create/rename/archive/pin/residency/delete).
    // Re-run on a query switch cancels + re-subscribes (onDispose). 实时生命周期:据非自身发起的变更重排。
    final sub = _repo.lifecycleSignals().listen(_onSignal);
    ref.onDispose(sub.cancel);
    // ACTIVITY-DOT INFRASTRUCTURE: turn lifecycle rides the messages stream (the backend emits NO
    // notifications event at turn terminals — this is the ONLY realtime path for isGenerating /
    // awaitingInput / hasUnread). Each signal debounces into ONE row re-read (DB row is truth); all
    // merge paths (optimistic PATCH folds, :seen local squash, lifecycle re-reads) stay idempotent.
    // A messages-stream 410 resync re-pages the whole list (durable dots may have moved arbitrarily).
    // **活态点基建**:回合生命周期骑 messages 流(后端回合终态不发 notifications——这是三点唯一实时
    // 通路)。信号防抖成单行重读(DB 行为真相);与乐观折入/:seen 本地压/生命周期重读全幂等。messages
    // 流 410 resync → 整列重翻(点可能任意漂移)。
    final turnSub = _repo.turnSignals().listen(_onTurnSignal);
    ref.onDispose(turnSub.cancel);
    final resyncSub = _repo.transcriptResync().listen(
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(resyncSub.cancel);
    ref.onDispose(_cancelRefreshTimers);
    ref.onDispose(() => _groupsRefresh?.cancel());

    // The three reads the rail needs before it can paint its structure: the two flat axes and the group
    // heads. They fail as ONE — the rail's error+retry screen is the honest surface for "the rail could not
    // load", and a half-rail that silently omits every mounted thread would be worse than a retry button.
    // 画出结构所需的三次读:两个平轴 + 组头。它们**作为一体**失败——「rail 加载不出来」的诚实表面就是它的
    // 错误+重试屏,而一个静默漏掉每条已挂线程的半个 rail 比一个重试按钮更糟。
    // SEARCHING REPLACES THE STRUCTURE, it does not filter it. A search has to be able to find a thread that
    // lives inside a FOLDED folder, and a folded folder deliberately fetches nothing — so a grouped rail that
    // merely narrowed each section would silently answer "no matches" for every conversation the user had not
    // already scrolled into view. That is a worse answer than no search at all. So while there is a query, the
    // rail becomes ONE flat result list over the whole workspace (residency-blind, pin-blind), which is also
    // the honest reading of the question: "which conversations match", not "which folders match".
    //
    // **搜索是替换结构、不是过滤结构**。一次搜索必须能找到住在**收起**的文件夹里的线程,而收起的文件夹刻意什么都
    // 不取——于是一个只是把各段收窄的分组 rail 会对每一条用户尚未滚进视野的对话静默答「没有匹配」。那比根本没有
    // 搜索更糟。故有查询词时,rail 变成对整个 workspace 的**一条平结果列表**(对驻地盲、对置顶盲),而那也正是这个
    // 问题的诚实读法:「哪些**对话**匹配」、不是「哪些**文件夹**匹配」。
    if (_search.isNotEmpty) {
      return ConversationListState(
        searching: true,
        recents: await _fetchAxis(ConvWorkDir.any, ConvPin.any, null),
      );
    }
    final (recents, pinned, groups) = await (
      _fetchAxis(ConvWorkDir.unmounted, ConvPin.unpinnedOnly, null),
      _fetchAxis(ConvWorkDir.any, ConvPin.pinnedOnly, null),
      _repo.workdirGroups(),
    ).wait;
    return ConversationListState(
      recents: recents,
      pinned: pinned,
      groups: groups,
    );
  }

  // ── axis fetching 轴取数 ──

  Future<ConvAxis> _fetchAxis(
    ConvWorkDir workDir,
    ConvPin pinned,
    String? cursor,
  ) async {
    final page = await _repo.listConversations(
      cursor: cursor,
      limit: _pageSize,
      sort: _sort,
      archive: _archive,
      search: _search.isEmpty ? null : _search,
      workDir: workDir,
      pinned: pinned,
    );
    return ConvAxis(
      rows: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      loaded: true,
    );
  }

  /// The axis a key names, in the shape the rail's tail sentinel needs. A group axis that has never been
  /// fetched reports `hasMore: true` so the sentinel exists and fires — that is how a group's first page
  /// loads only when the section is expanded AND scrolled into view, with no "fetch on expand" callback
  /// anywhere.
  ///
  /// 某个键所点出的轴,以 rail 尾哨兵所需的形状给出。一个**从未取过**的组轴报 `hasMore: true`,使哨兵存在并触发
  /// ——这正是一个组的第一页**仅在**该段被展开且滚进视野时才加载的方式,任何地方都没有「展开时取数」回调。
  ConvAxis axisFor(String axisKey) {
    final s = state.value;
    if (s == null) return const ConvAxis();
    if (axisKey == recentsAxisKey) return s.recents;
    if (axisKey == pinnedAxisKey) return s.pinned;
    final dir = workDirOfAxis(axisKey);
    if (dir == null) return const ConvAxis();
    return s.groupAxes[dir] ?? const ConvAxis(hasMore: true);
  }

  ConversationListState _withAxis(
    ConversationListState s,
    String axisKey,
    ConvAxis axis,
  ) {
    if (axisKey == recentsAxisKey) return s.copyWith(recents: axis);
    if (axisKey == pinnedAxisKey) return s.copyWith(pinned: axis);
    final dir = workDirOfAxis(axisKey);
    if (dir == null) return s;
    return s.copyWith(groupAxes: {...s.groupAxes, dir: axis});
  }

  /// Fetch one axis's next page and append. Also serves a group axis's FIRST page (its cursor is null and it
  /// is not `loaded` yet) — one code path for "there is more of this axis to get", whether that means page
  /// one or page five. No-op while a page is in flight or the axis is exhausted; a failure raises the axis's
  /// own [ConvAxis.loadFailed] (the M9 contract: a manual retry row, never an auto-refire storm).
  ///
  /// 取某轴的下一页并追加。它同时服务一个组轴的**第一页**(其游标为 null 且尚未 `loaded`)——「这个轴还有可取的」
  /// 只有一条代码路径,无论那意味着第一页还是第五页。在途或已取尽时 no-op;失败置该轴自己的 [ConvAxis.loadFailed]
  /// (M9 契约:手动重试行、绝不自动重触发风暴)。
  Future<void> loadMoreAxis(String axisKey) async {
    final cur = state.value;
    if (cur == null) return;
    final axis = axisFor(axisKey);
    if (axis.loadingMore || !axis.hasMore) return;
    if (axis.loaded && axis.nextCursor == null) return;
    // The axis key IS the query it pages: an unrecognized key names no axis and must not fall back to some
    // other section's filter (that would page the wrong rows into it).
    // 轴键**就是**它所翻的那次查询:一个认不出的键点不出任何轴,且绝不能回落到别段的过滤(那会把不对的行翻进它里)。
    final dir = workDirOfAxis(axisKey);
    if (dir == null && axisKey != pinnedAxisKey && axisKey != recentsAxisKey) {
      return;
    }
    // While a query is active the rail is ONE flat result list (see build) — the Recents axis carries it, so
    // its tail must page the same residency-blind, pin-blind query it was filled from.
    // 有查询词时 rail 是**一条平结果列表**(见 build)——它由「最近」轴承载,故它的尾必须翻与它被填充时同一次
    // 对驻地盲、对置顶盲的查询。
    final (workDir, pinned) = switch (axisKey) {
      _ when cur.searching => (ConvWorkDir.any, ConvPin.any),
      pinnedAxisKey => (ConvWorkDir.any, ConvPin.pinnedOnly),
      recentsAxisKey => (ConvWorkDir.unmounted, ConvPin.unpinnedOnly),
      _ => (ConvWorkDir.of(dir!), ConvPin.unpinnedOnly),
    };
    final gen = _generation;
    state = AsyncData(
      _withAxis(
        cur,
        axisKey,
        axis.copyWith(loadingMore: true, loadFailed: false),
      ),
    );
    try {
      final page = await _fetchAxis(workDir, pinned, axis.nextCursor);
      if (gen != _generation) return; // build re-ran mid-await — stale query
      final now = state.value;
      if (now == null) return;
      state = AsyncData(
        _withAxis(
          now,
          axisKey,
          axisFor(axisKey).copyWith(
            rows: [...axisFor(axisKey).rows, ...page.rows],
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
            loadingMore: false,
            loaded: true,
          ),
        ),
      );
    } catch (_) {
      if (gen != _generation) return;
      final now = state.value;
      if (now == null) return;
      state = AsyncData(
        _withAxis(
          now,
          axisKey,
          axisFor(axisKey).copyWith(loadingMore: false, loadFailed: true),
        ),
      );
    }
  }

  /// The Recents axis's tail — kept as `loadMore()` because that is the rail's historical entry point and the
  /// name every existing caller and test uses. 「最近」轴的尾——沿用 `loadMore()` 这个历史入口名。
  Future<void> loadMore() => loadMoreAxis(recentsAxisKey);

  // ── the residency projection 驻地投影 ──

  // 批7 立法1 豁免锚:state 层合帧节流,非视觉动效。exempt: state-layer coalescing, not visual motion.
  static const _groupsDebounce = Duration(milliseconds: 400);
  Timer? _groupsRefresh;

  /// Re-read the group heads, coalesced. Every lifecycle change can move a group's count, its order, or its
  /// existence (mount / unmount / archive / delete / a new turn bumping recency), and the counts are the one
  /// thing the client must NOT compute for itself — so the projection is re-asked rather than patched. A
  /// burst of signals (a bulk action emits one echo per row) collapses into one read.
  ///
  /// 重读组头,合帧。每次生命周期变更都可能移动一个组的计数、顺序或存在性(挂/退/归档/删/新回合刷 recency),而计数
  /// 正是客户端**绝不该**自己算的那一样东西——故投影是**重问**、不是 patch。一串信号(批量动作逐行发一条回声)塌成
  /// 一次读。
  void _scheduleGroupsRefresh() {
    _groupsRefresh?.cancel();
    _groupsRefresh = Timer(_groupsDebounce, () {
      _groupsRefresh = null;
      _refreshGroups();
    });
  }

  Future<void> _refreshGroups() async {
    if (state.value == null) return;
    final gen = _generation;
    List<WorkDirGroup> groups;
    try {
      groups = await _repo.workdirGroups();
    } catch (_) {
      return; // the heads we have stay; the next signal re-asks 保留现有组头;下次信号再问
    }
    if (gen != _generation) return;
    final cur = state.value;
    if (cur == null) return;
    // Drop the row axes of groups that no longer exist, so a residency the user emptied does not keep its
    // loaded rows around waiting to reappear. 丢掉已不存在的组的行轴,使被清空的驻地不留着已加载行等着复现。
    final live = {for (final g in groups) g.workDir};
    state = AsyncData(
      cur.copyWith(
        groups: groups,
        groupAxes: {
          for (final e in cur.groupAxes.entries)
            if (live.contains(e.key)) e.key: e.value,
        },
      ),
    );
  }

  // ── activity-dot turn pulse 活态点回合脉冲 ──

  // 批7 立法1 豁免锚:state 层合帧节流,非视觉动效。exempt: state-layer coalescing, not visual motion.
  static const _turnDebounce = Duration(milliseconds: 300);
  final Map<String, Timer> _refreshTimers = {};

  void _cancelRefreshTimers() {
    for (final t in _refreshTimers.values) {
      t.cancel();
    }
    _refreshTimers.clear();
  }

  // Debounce per conversation: a turn boundary bursts frames (user echo close + assistant open land
  // together) — one re-read serves the burst. 按会话防抖:回合边界帧成簇,一次重读即够。
  void _onTurnSignal(TurnSignal signal) {
    final id = signal.conversationId;
    _refreshTimers[id]?.cancel();
    _refreshTimers[id] = Timer(_turnDebounce, () {
      _refreshTimers.remove(id);
      _refreshRow(id);
    });
  }

  Future<void> _refreshRow(String id) async {
    if (state.value == null) return;
    try {
      final c = await _repo.getConversation(id);
      if (ref.mounted) applyUpdate(c);
    } catch (_) {
      // Gone between signal and read (deleted) — the lifecycle deleted signal handles the drop.
      // 信号与读之间被删——删除交由生命周期信号处理。
    }
  }

  /// Locally squash the unread flag after a successful `:seen` — closes the race where the turn
  /// pulse re-read lands BEFORE the server processed :seen (the row would flash-and-stick green:
  /// nothing re-reads after the 204). Idempotent with every other merge path.
  /// `:seen` 成功后本地压未读——封「脉冲重读先于 :seen 落库」的竞态(行会绿住:204 后没人再读)。
  void markSeenLocal(String id) {
    final cur = state.value;
    if (cur == null) return;
    final row = _find(cur, id);
    if (row == null || !row.hasUnread) return;
    applyUpdate(row.copyWith(hasUnread: false));
  }

  Conversation? _find(ConversationListState s, String id) {
    for (final c in s.allRows) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Which section a conversation belongs to, by the rail's own rules: PINNED WINS (a pinned thread lives in
  /// the Pinned section whatever its residency, so it is never duplicated in a group), then its residency
  /// group, else Recents. This one function is why a pin, a residency switch and an unmount all reconcile the
  /// same way — they change the answer, and the row moves.
  ///
  /// 一条对话属于哪一段,按 rail 自己的规则:**置顶赢**(置顶线程无论驻地如何都住在置顶段,故绝不在组里重复)、再是
  /// 它的驻地组、否则「最近」。这一个函数正是「置顶 / 切驻地 / 退驻地」三者对账方式相同的原因——它们改变的是这个
  /// 答案,于是行**移动**。
  String _axisOf(Conversation c) {
    if (c.pinned) return pinnedAxisKey;
    if (c.workDir.isEmpty) return recentsAxisKey;
    return workDirAxisKey(c.workDir);
  }

  /// Fold an authoritative conversation (a PATCH response, a signal re-read) into the rail: replace it in
  /// place if it is already in the section it belongs to, otherwise MOVE it there, and DROP it entirely when
  /// it just got archived while the rail isn't showing archived (it left the visible workspace).
  ///
  /// Moving is the whole reason this is not a simple in-place patch: pinning a thread must lift it out of its
  /// residency group and into Pinned, leaving a thread's directory must drop it back into Recents, and either
  /// one leaving a group behind empty must make that group vanish. The projection re-read (coalesced) settles
  /// the counts and the group list; this method settles the ROWS.
  ///
  /// A group axis that has not been fetched yet is deliberately NOT seeded with the arriving row: an axis
  /// holding one row out of nine would render as if that were the group's content. It stays unloaded, and its
  /// tail sentinel fetches the real first page when the user opens it.
  ///
  /// This is the initiator's own path (it has the response) and it is idempotent, so a later SSE echo of the
  /// same change (notifications carry no echo suppression) re-applies safely.
  ///
  /// 把一条权威对话(PATCH 响应、信号重读)折进 rail:若它已在它该在的那一段就**就地替换**,否则把它**移**过去;而若它
  /// 刚被归档且 rail 不显归档,则整个**移出**(它离开了可见的 workspace)。
  ///
  /// **移动**正是这里不能只做就地 patch 的全部理由:置顶一条线程必须把它从驻地组**提**进置顶段、退出目录必须把它**落
  /// 回**「最近」,而两者之一若把一个组留空,那个组必须消失。投影重读(合帧)结算**计数与组列表**;本方法结算**行**。
  ///
  /// 一个**尚未取过**的组轴**刻意不**被到来的这一行播种:一个九条里只装了一条的轴会渲成好像那就是该组的内容。它保持
  /// 未加载,其尾哨兵会在用户打开它时取回真正的第一页。
  ///
  /// 这是发起端自己的路径(它已有响应)且**幂等**,故同一变更稍后的 SSE 回声(通知无回声抑制)可安全重放。
  void applyUpdate(Conversation c) {
    final cur = state.value;
    if (cur == null) return;
    final before = _find(cur, c.id);
    // A FRESH auto-title (empty→non-empty + autoTitled; a user rename never matches — the renamed row
    // already had a title and rename responses carry autoTitled=false) → queue the one-shot typewriter
    // for the rail row + head. 新自动命名(空→非空 + autoTitled;改名不命中)→ 入打字机队列(rail+头同播)。
    // Gate on the chat ocean being active: a title landing while another ocean is open must appear
    // static on return (the "first appearance" moment has passed) — else the reveal id lingers unplayed
    // and the typewriter fires LATE when you come back. 仅 chat 海洋活跃时入队,否则回来即静态(不迟播)。
    if (before != null &&
        before.title.trim().isEmpty &&
        c.title.trim().isNotEmpty &&
        c.autoTitled &&
        ref.read(selectedOceanProvider) == OceanKind.chat) {
      ref.read(titleRevealsProvider.notifier).add(c.id);
    }
    final hidden = c.archived && !ref.read(showArchivedProvider);
    // Absent and invisible → idempotent no-op. 已不在且不可见 → 幂等 no-op。
    if (before == null && hidden) return;
    // Where it sits TODAY in the section it belongs to — so a plain in-place update (a dot flip, a rename)
    // keeps its position and only a real section change moves the row.
    // 它**今天**在它该在的那一段里的位次——故一次纯就地更新(点翻转、改名)保住位次,只有真正的换段才移动行。
    final axisKey = _axisOf(c);
    final at = _indexIn(cur, axisKey, c.id);
    var next = _removeEverywhere(cur, c.id);
    if (!hidden) next = _insertInto(next, axisKey, c, at);
    state = AsyncData(next);
    // A group's count, its order or its very existence may have moved — and only the server knows the new
    // numbers, so re-ask rather than guess. Gated on the row TOUCHING a residency (before or after): if the
    // thread lives in no directory and did not come from one, no group's number can possibly have changed,
    // and asking anyway would put the rail on a refetch treadmill for every dot flip in Recents.
    // 一个组的计数、顺序、乃至它的存在性都可能变了——而只有服务端知道新的数,故**重问**、不猜。闸在「该行**碰到**
    // 驻地」(变更前或后):若这条线程不住在任何目录里、也不是从某个目录来的,那不可能有任何组的数变了,而照问不误会让
    // rail 为「最近」里每一次点翻转都踩一遍重取的跑步机。
    //
    // «Could have belonged» is doing real work in the third clause: a thread that just LEFT a residency
    // arrives with an empty `workDir`, and if its group was never expanded we never held the row — so
    // `before` is null and its old folder is unknowable from here. Falling back to "are there any folders at
    // all" catches exactly that case while still sparing a workspace that has none (where nothing this
    // function does could possibly move a count).
    //
    // 第三个子句里的「**可能曾**属于」在做实事:一条刚**离开**驻地的线程带着空 `workDir` 到来,而若它那个组从未被
    // 展开、我们就从未持有过那一行——于是 `before` 为 null、它的旧文件夹在此不可知。回落到「到底有没有文件夹」恰好
    // 抓住这一种情形,同时仍然放过一个根本没有文件夹的 workspace(那里本函数做什么都不可能移动任何计数)。
    final couldMoveAGroupCount =
        c.workDir.isNotEmpty ||
        (before?.workDir.isNotEmpty ?? cur.groups.isNotEmpty);
    if (couldMoveAGroupCount &&
        (before == null ||
            before.pinned != c.pinned ||
            before.workDir != c.workDir ||
            before.archived != c.archived ||
            hidden)) {
      _scheduleGroupsRefresh();
    }
  }

  ConversationListState _removeEverywhere(ConversationListState s, String id) {
    ConvAxis strip(ConvAxis a) => a.rows.any((r) => r.id == id)
        ? a.copyWith(
            rows: a.rows.where((r) => r.id != id).toList(growable: false),
          )
        : a;
    return s.copyWith(
      recents: strip(s.recents),
      pinned: strip(s.pinned),
      groupAxes: {for (final e in s.groupAxes.entries) e.key: strip(e.value)},
    );
  }

  // The row's current index inside one axis, or -1 when it is not there. 该行在某轴内的现位次;不在则 -1。
  int _indexIn(ConversationListState s, String axisKey, String id) {
    final dir = workDirOfAxis(axisKey);
    final axis = axisKey == pinnedAxisKey
        ? s.pinned
        : axisKey == recentsAxisKey
        ? s.recents
        : s.groupAxes[dir];
    return axis?.rows.indexWhere((r) => r.id == id) ?? -1;
  }

  // Insert into the section the row belongs to: back at [at] when it was already there (a dot flip, a rename
  // — the position must not move), else at the axis HEAD, which is where activity/created sort puts a
  // freshly-touched thread anyway. Under ?sort=name the head is approximate and self-heals on the next full
  // page, so a rename under name-sort re-sorts the axis locally, mirroring the backend's collation — leaving
  // the row parked at its old letter would make the list lie about its own ordering. An UNLOADED group axis
  // is left alone (see applyUpdate: one row out of nine would render as if it were the group).
  //
  // 插进该行所属的段:它本就在那儿就插回 [at](点翻转、改名——位次不该动),否则插**轴首**,那也正是 activity/created
  // 排序会把一条刚被碰过的线程放的地方。?sort=name 下轴首是近似的、下一整页自愈,故 name 排序下的改名在本地重排该轴、
  // 镜像后端 collation——把行停在旧字母位会让列表对自身排序撒谎。**未加载**的组轴不动(见 applyUpdate:九条里一条会
  // 渲成好像那就是整个组)。
  ConversationListState _insertInto(
    ConversationListState s,
    String axisKey,
    Conversation c,
    int at,
  ) {
    final dir = workDirOfAxis(axisKey);
    if (dir != null && !(s.groupAxes[dir]?.loaded ?? false)) return s;
    final axis = axisKey == pinnedAxisKey
        ? s.pinned
        : axisKey == recentsAxisKey
        ? s.recents
        : s.groupAxes[dir]!;
    final rows = [...axis.rows];
    rows.insert(at >= 0 && at <= rows.length ? at : 0, c);
    if (ref.read(conversationSortProvider) == ConvSort.name) {
      rows.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      });
    }
    return _withAxis(s, axisKey, axis.copyWith(rows: rows));
  }

  /// Drop a (soft-)deleted conversation from every section. Idempotent. 从每一段移除已删行;幂等。
  void applyDelete(String id) {
    final cur = state.value;
    final gone = _find(cur ?? const ConversationListState(), id);
    if (cur == null || gone == null) return;
    state = AsyncData(_removeEverywhere(cur, id));
    // Only a residency thread's departure can move a group's count (or empty the group out of existence).
    // 只有一条**驻地**线程的离去能移动某个组的计数(或把组清空到不存在)。
    if (gone.workDir.isNotEmpty) _scheduleGroupsRefresh();
  }

  /// A whole residency group just changed on the server (`:archive-workdir` / `:delete-workdir`). The rail
  /// holds at most one page of it, so there is nothing honest to patch row by row: drop the group's own axis
  /// and re-ask the projection. The initiator gets the truth in one read instead of N echoes it would have to
  /// merge, and the group vanishing (all its unpinned threads gone) falls out for free.
  ///
  /// 服务端上一整个驻地组刚变了(`:archive-workdir` / `:delete-workdir`)。rail 手上最多只有它的一页,故没有什么可
  /// 诚实地逐行 patch:丢掉该组自己的轴、重问投影。发起方一次读拿到真相、而不是 N 条要自己合的回声,而组的消失(它的
  /// 未置顶线程全没了)顺带就有了。
  Future<void> applyWorkDirGroupChanged(String workDir) async {
    final cur = state.value;
    if (cur == null) return;
    final axes = {...cur.groupAxes}..remove(workDir);
    state = AsyncData(cur.copyWith(groupAxes: axes));
    _groupsRefresh?.cancel();
    _groupsRefresh = null;
    await _refreshGroups();
  }

  // Reconcile one lifecycle signal into the rail. Only durable frames patch (DB-row-is-truth);
  // deleted drops, created inserts, everything else re-reads that one row. 据一条生命周期信号重排。
  Future<void> _onSignal(ConversationSignal s) async {
    if (!s.durable || state.value == null) return;
    switch (s.action) {
      case ConversationAction.deleted:
        applyDelete(s.id);
      case ConversationAction.created:
        await _insertNew(s.id);
      case ConversationAction.updated:
        final c = await _fetch(s.id);
        if (c != null) applyUpdate(c);
      case ConversationAction.unknown:
        return;
    }
  }

  // A created thread this client didn't originate (another window, or an AI-edit :iterate) → fetch it and
  // place it in whichever section it belongs to, if visible under the current archive scope and not already
  // loaded. A thread created straight into a residency shows up as a group-count bump (and possibly a NEW
  // group) rather than a row, because its group's rows may not be loaded — the projection refresh inside
  // applyUpdate covers that.
  // 非自身发起的新对话→取回并放进它该在的那一段(当前归档范围可见、且未在窗内)。直接建在某驻地里的线程会表现为
  // 组计数上涨(乃至一个**新组**)而不是一行,因为它那个组的行可能还没加载——applyUpdate 里的投影刷新覆盖这一点。
  Future<void> _insertNew(String id) async {
    final cur = state.value;
    if (cur == null || _find(cur, id) != null) return; // dedup
    final c = await _fetch(id);
    if (c == null || (c.archived && _archive == ConvArchive.active)) {
      return; // gone, or not in this scope
    }
    final now = state.value;
    if (now == null || _find(now, id) != null) {
      return; // re-check after the await
    }
    applyUpdate(c);
  }

  Future<Conversation?> _fetch(String id) async {
    try {
      return await _repo.getConversation(id);
    } catch (_) {
      return null; // vanished between signal and fetch — let the list be
    }
  }
}

final conversationListProvider =
    AsyncNotifierProvider<ConversationListNotifier, ConversationListState>(
      ConversationListNotifier.new,
      retry: (_, _) => null,
    );
