import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/conversation.dart';
import '../../../core/design/tokens.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/platform/open_in_system.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_rail_states.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../core/ui/an_typewriter.dart';
import '../../../core/ui/icons.dart';
import '../../../core/ui/an_time_pulse.dart';
import '../../../i18n/strings.g.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../data/conversation_signal.dart';
import '../state/chat_drafts.dart';
import '../state/conversation_list_provider.dart';
import '../state/conversation_list_state.dart';
import '../state/fork_conversation.dart';
import '../state/pending_attachments.dart';
import '../state/selected_conversation.dart';
import '../state/title_reveals.dart';
import 'conversation_rail_model.dart';

/// The left-island conversation navigator. Watches [conversationListProvider] (one live list AsyncValue)
/// + [selectedConversationProvider], resolves ONE of four screens — loading skeleton / error+retry /
/// empty / the [AnSidebarList] of conversations grouped Pinned + Recents — and wires selection back
/// through the URL (`context.go(conversationLocation(id))`, the single source of truth). Mirrors
/// EntityRail, minus the per-kind machinery: ONE async to resolve, the row id IS the conversation id (no
/// kindForId), and the server sorts (no client sortRows). The ⚙ sliders menu offers Sort (activity /
/// created / name) + Display toggles (show archived / show counts / show time).
///
/// Each row carries a hover-revealed ⋯ menu (STEP 7) collecting all per-thread actions: rename (in-place,
/// via [AnSidebarList.editingRowId] → the reused [AnInlineEdit]), pin/unpin, archive/unarchive, and delete
/// (a danger item behind a confirm dialog). Writes hit the repository and the authoritative response is
/// folded into the list optimistically ([ConversationListNotifier.applyUpdate]/`applyDelete`) — the
/// initiator never waits on the SSE echo. `_editingId` is transient widget state (which row is mid-rename).
///
/// **The rail is grouped by RESIDENCY (WRK-077 WD1.5)**: Pinned, then one 📁 section per working directory,
/// then Recents (only the threads that live in no directory). Each residency section head carries its own ⋯
/// menu — «archive all conversations» / «delete all conversations» (danger, behind a confirm dialog that
/// inventories exactly how many threads move) and «reveal in Finder».
///
/// ⚠️ **The wording of those two items is load-bearing, not cosmetic.** «Delete the directory» — or any
/// phrasing containing the word *directory* — would be read as deleting the real folder on disk, with the
/// user's actual work inside it. The action deletes CONVERSATIONS: not the folder, not one file, not one
/// message row. So the menu says «delete all conversations», the confirm dialog states the count and says in
/// so many words that nothing on disk is deleted, and the word «directory» appears in neither. «Reveal in
/// Finder» sits in the same menu on purpose — it is the item that demonstrates the folder is something we
/// merely point at. A guard test asserts the absence of that word (see conversation_rail_test).
///
/// 左岛对话导航。watch list + selected,解出四态之一(骨架/错+重试/空/AnSidebarList),选择经 URL 写回(唯一真相源)。
/// 镜像 EntityRail,去掉 per-kind。每行 hover 显 ⋯ 菜单收齐逐线程动作:就地改名(经 editingRowId → 复用 AnInlineEdit)、
/// 置顶/取消、归档/取消、删除(danger + 确认框)。写打到 repository,权威响应乐观折进列表(不等 SSE 回声)。
/// _editingId 是瞬时 widget 态(哪行在改名中)。
///
/// **rail 按驻地分组(WRK-077 WD1.5)**:置顶、每个工作目录一个 📁 段、最后是「最近」(仅不住在任何目录里的线程)。每个
/// 驻地段的**组头**带它自己的 ⋯ 菜单——「归档全部对话」/「删除全部对话」(danger,确认框**逐条盘点**有几条线程会动)
/// 与「在访达中显示」。
///
/// ⚠️ **那两个菜单项的措辞是承重的、不是装饰。**「删除目录」——或任何含「目录」字样的说法——会被读成删掉磁盘上那个
/// 真文件夹、连里面用户真正的活一起。该动作删的是**对话**:不是文件夹、不是任何一个文件、也不是任何一条消息行。故菜单
/// 写「删除全部对话」,确认框报出数目并**明说**磁盘上什么都不会被删,而「目录」二字**两处都不出现**。「在访达中显示」
/// 刻意同处一菜单——它正是那个演示「文件夹只是我们指着的东西」的项。守卫测试断言那两个字的缺席(见 conversation_rail_test)。
class ConversationRail extends ConsumerStatefulWidget {
  const ConversationRail({super.key});

  @override
  ConsumerState<ConversationRail> createState() => _ConversationRailState();
}

class _ConversationRailState extends ConsumerState<ConversationRail> {
  // Which row is mid-rename (its label slot becomes an AnInlineEdit). null = none. 哪行在改名中。
  String? _editingId;
  final _debounce = Debouncer(AnMotion.searchDebounce);
  StreamSubscription<ConversationSignal>? _lifecycleSub;
  StreamSubscription<void>? _lifecycleResyncSub;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(chatRepositoryProvider);
    _lifecycleSub = repo.lifecycleSignals().listen(_onLifecycleSignal);
    // A notifications-stream gap can hide a deletion just as it can hide a rename. Re-read the open
    // row on the same stream's resync and leave the deep link only when the server proves it is gone.
    // notifications 流缺口可能吞掉删除,也可能吞掉改名。该流 resync 时重读当前行,只有服务端明确 404 才离开深链。
    _lifecycleResyncSub = repo.lifecycleResync().listen((_) {
      _verifySelectedConversation();
    });
  }

  @override
  void dispose() {
    _lifecycleSub?.cancel();
    _lifecycleResyncSub?.cancel();
    _debounce.dispose();
    super.dispose();
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  ConversationListNotifier get _list =>
      ref.read(conversationListProvider.notifier);

  void _onLifecycleSignal(ConversationSignal signal) {
    if (!signal.durable || signal.action != ConversationAction.deleted) return;
    _navigateIfSelected(signal.id);
  }

  void _navigateIfSelected(String id) {
    if (!mounted || ref.read(selectedConversationProvider)?.id != id) return;
    // The URL is the selection source of truth. A deletion from another window must not leave a dead
    // transcript mounted while the rail has already removed its row.
    // URL 是选区唯一真相。另一个窗口删除后,rail 已去行时不能让死 transcript 继续挂着。
    context.go('/');
  }

  Future<void> _verifySelectedConversation() async {
    final id = ref.read(selectedConversationProvider)?.id;
    if (id == null) return;
    try {
      await _repo.getConversation(id);
    } on ApiException catch (error) {
      if (error.isNotFound) _navigateIfSelected(id);
    }
  }

  void _newChat() {
    // New chat is an explicit discard boundary. Route navigation alone does not remount the landing
    // when the user is already there, so clear both local payload stores and bump the landing key.
    // 「新对话」是明确丢弃边界。用户已在 landing 时单靠导航不会重挂，故同时清文本/附件并 bump key。
    ref.read(chatDraftsProvider).clear(ChatDrafts.landingKey);
    ref
        .read(pendingAttachmentsProvider(ChatDrafts.landingKey).notifier)
        .clear();
    ref.read(chatLandingResetProvider.notifier).bump();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationListProvider);
    final selected = ref.watch(selectedConversationProvider);
    // The ⚙ menu's state: sort + archived drive the list (the notifier re-fetches on change); count +
    // time are pure view prefs applied at render. ⚙ 菜单态:sort/archived 驱动列表,count/time 渲染时视图偏好。
    final sort = ref.watch(conversationSortProvider);
    final archived = ref.watch(showArchivedProvider);
    final showCount = ref.watch(showGroupCountProvider);
    final showTime = ref.watch(showTimeProvider);
    final t = context.t;

    // The two placeholder states over the ONE list AsyncValue: loading = nothing resolved yet; error =
    // failed with nothing loaded. Zero rows is NOT a state — the list renders its chrome + empty Pinned /
    // Recents heads (满态收起的形状). 两占位态基于单个列表 AsyncValue;零行不是态,直落列表(渲 chrome + 空组头)。
    return AnRailStates(
      loading: async.isLoading && !async.hasValue,
      error: async.hasError && !async.hasValue,
      strings: AnRailStrings(
        errorTitle: t.chat.errorTitle,
        errorHint: t.chat.errorHint,
        retry: t.chat.retry,
      ),
      onRetry: () => ref.invalidate(conversationListProvider),
      builder: () {
        // The loaded state, or an empty one while the very first page is in flight (AnRailStates already owns
        // the skeleton; this keeps the builder total). 已加载态;首页在途时给空态(骨架归 AnRailStates,此处保持全函数)。
        final data = async.value ?? const ConversationListState();
        // id → conversation ACROSS ALL FOUR SECTIONS, so the per-row ⋯ menu can read the current
        // pin/archive/residency state for its labels wherever that row happens to live.
        // id→对话、**跨全部四段**,使逐行 ⋯ 菜单无论该行住在哪一段都能按现态出标签。
        final byId = {for (final c in data.allRows) c.id: c};
        final reveals = ref.watch(titleRevealsProvider);
        return AnSidebarList(
          // A fresh auto-title lands as a one-shot typewriter in its row (the head plays the same title
          // in sync); done → back to the static label. 新自动命名在行内一次性打字机落地(头同播);完→静态。
          labelWidgetFor: (id) {
            final title = byId[id]?.title ?? '';
            if (!reveals.contains(id) || title.trim().isEmpty) return null;
            return AnTypewriter(
              [title],
              loop: false,
              showCaret: false,
              onDone: () => ref.read(titleRevealsProvider.notifier).remove(id),
            );
          },
          model: buildConversationRailModel(
            data,
            now: AnTimePulse.quantizedNow, // 同拍同刻,模型相等性记忆化不被破(S8)
            showCount: showCount,
            showTime: showTime,
            showArchived: archived,
            labels: ConvRailLabels(
              newLabel: t.chat.kNew,
              filter: t.chat.filter,
              pinned: t.chat.bucket.pinned,
              recents: t.chat.bucket.recents,
              time: ConvTimeStrings(
                justNow: t.chat.time.justNow,
                yesterday: t.chat.time.yesterday,
                minutesAgo: (n) => t.chat.time.minutesAgo(n: n),
                hoursAgo: (n) => t.chat.time.hoursAgo(n: n),
                daysAgo: (n) => t.chat.time.daysAgo(n: n),
              ),
            ),
          ),
          selectedId: selected?.id,
          // New chat = the landing at '/' (no selection; the FIRST SEND creates the thread — nothing is
          // minted by the click itself). 新对话=回 '/' landing(首发才建线程,点击本身不铸)。
          onNew: _newChat,
          menuEntries: _menu(t, sort, archived, showCount, showTime),
          // A sort/archive change replaces the server query axis. Keep ordinary row/SSE updates from
          // moving the reader, but make the first frame of a new axis start at its semantic head.
          // 排序/归档改变会替换服务端查询轴;普通行/SSE 更新不打断阅读,新轴首帧从语义头开始。
          scrollResetKey: Object.hash(sort, archived),
          // The row id IS the conversation id — navigate straight to it (route is the source of truth).
          onSelect: (id) => context.go(conversationLocation(id)),
          onFilterChanged: _onFilter,
          // Every section is its own paginated axis and the pageKey IS the axis key — Pinned, Recents, and
          // one per residency. A residency section's FIRST page rides the same sentinel, so a folded group
          // fetches nothing and an expanded one fetches only when scrolled into view.
          // 每段都是自己的分页轴、pageKey **就是**轴键——置顶、最近、每驻地一个。驻地段的**第一页**走同一个哨兵,
          // 故收起的组什么都不取、展开的也只在滚进视野时才取。
          onLoadMore: _list.loadMoreAxis,
          onRetryLoad: _list.loadMoreAxis,
          editingRowId: _editingId,
          onRenameCommit: _rename,
          onRenameCancel: () => setState(() => _editingId = null),
          rowActionsBuilder: (id) {
            final c = byId[id];
            if (c == null) return const [];
            return [_rowMenu(t, c)];
          },
          // The residency section heads get the ⋯ menu; Pinned / Recents get none — they are not folders and
          // have nothing folder-wide to do. Reuses the LR batch's typeHeadActionsBuilder seam verbatim.
          // 驻地段头拿 ⋯ 菜单;置顶 / 最近没有——它们不是文件夹、也没有目录级的事可做。逐字复用 LR 批的
          // typeHeadActionsBuilder 地基。
          typeHeadActionsBuilder: (typeId) {
            final dir = workDirOfAxis(typeId);
            if (dir == null) return const [];
            final group = data.groups
                .where((g) => g.workDir == dir)
                .firstOrNull;
            if (group == null) return const [];
            return [_groupMenu(t, group)];
          },
        );
      },
    );
  }

  // Debounce keystrokes before the server-side ?search (the provider re-pages from the top on change;
  // firing per key would storm the backend). 逐键防抖再打服务端 ?search(每键一请求会打爆后端)。
  void _onFilter(String v) => _debounce.run(() {
    if (mounted) ref.read(conversationSearchProvider.notifier).set(v);
  });

  /// The per-row ⋯ menu (hover-revealed) — every per-thread action in one place: rename / fork / pin·unpin /
  /// archive·unarchive / delete. Pin & archive labels flip on the row's current state; delete is a danger
  /// item that opens a confirm dialog. Fork sits here because the rail is where you act on a thread you are
  /// NOT reading — from here it can only mean "from the latest", which is exactly what the endpoint does
  /// with an omitted atMessageId (a rail row holds no message id, and asking the rail to fetch one just to
  /// name the thread's own tip would be a round-trip for nothing).
  /// ⋯ 行菜单:改名/**分叉**/置顶/归档/删除(置顶·归档按现态翻标签;删除 danger + 确认)。分叉在此,因为 rail 是你
  /// 对**没在读**的线程动手的地方——从这里它只能意为「从最新处」,而那正是端点在 atMessageId 缺省时做的事(rail 行
  /// 手上没有 message id,让它先取一个只为说出线程自己的末端,是一趟白跑的往返)。
  Widget _rowMenu(Translations t, Conversation c) {
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
        AnIcons.more,
        size: AnButtonSize.sm,
        semanticLabel: t.a11y.moreActions,
        onPressed: toggle,
      ),
      entries: [
        AnMenuItem(
          label: t.chat.rename,
          icon: AnIcons.edit,
          onTap: () => setState(() => _editingId = c.id),
        ),
        AnMenuItem(
          label: t.chat.fork,
          icon: AnIcons.control,
          onTap: () => _fork(c.id),
        ),
        AnMenuItem(
          label: c.pinned ? t.chat.unpin : t.chat.pin,
          icon: AnIcons.pin,
          onTap: () => _setPinned(c.id, !c.pinned),
        ),
        AnMenuItem(
          label: c.archived ? t.chat.unarchive : t.chat.archive,
          icon: AnIcons.archive,
          onTap: () => _setArchived(c.id, !c.archived),
        ),
        AnMenuItem(
          label: t.action.delete,
          icon: AnIcons.trash,
          danger: true,
          onTap: () => _confirmDelete(c),
        ),
      ],
    );
  }

  /// The ⋯ menu on a RESIDENCY section head — the folder-wide actions, and the single most sensitive piece of
  /// wording in this batch.
  ///
  /// Three items: «archive all conversations», «delete all conversations» (danger), and «reveal in Finder».
  /// The first two say **conversations** because that is what they touch; a label mentioning the directory
  /// would be read as an offer to delete the real folder on disk — the user's actual work — which nothing here
  /// does or could do. «Reveal in Finder» belongs in the same menu for exactly that reason: it is the item
  /// that shows the folder is something we point at, never something we own.
  ///
  /// The head's own count is what the confirm dialog inventories, and it can be that number because the
  /// action's scope IS the group's scope (that residency, unpinned) — see the backend contract.
  ///
  /// **驻地**段头上的 ⋯ 菜单——目录级动作,以及本批**最敏感**的一处措辞。
  ///
  /// 三项:「归档全部对话」、「删除全部对话」(danger)、「在访达中显示」。前两项说的是**对话**,因为它们碰的就是对话;
  /// 一个提到目录的标签会被读成「提议删掉磁盘上那个真文件夹」——用户真正的活——而这里没有任何东西在做、也做不到那件事。
  /// 「在访达中显示」正因如此属于同一个菜单:它是那个表明「文件夹是我们指着的东西、绝不是我们拥有的东西」的项。
  ///
  /// 组头**自己的**计数就是确认框盘点的那个数,而它之所以能是那个数,是因为动作的范围**就是**组的范围(该驻地、未置顶)
  /// ——见后端契约。
  Widget _groupMenu(Translations t, WorkDirGroup g) {
    final w = t.chat.workDir;
    // The inventory is the WHOLE group, both archive states — the actions are deliberately blind to the
    // "show archived" toggle (a destructive action must not depend on a view preference), so the number the
    // dialog states must be blind to it too.
    // 盘点是**整个**组、两种归档态——动作刻意对「显示已归档」开关盲(破坏性动作不该取决于视图偏好),故确认框报出的数
    // 也必须对它盲。
    final total = g.activeCount + g.archivedCount;
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
        AnIcons.more,
        size: AnButtonSize.sm,
        semanticLabel: t.a11y.moreActions,
        onPressed: toggle,
      ),
      entries: [
        AnMenuItem(
          label: w.groupArchiveAll,
          icon: AnIcons.archive,
          onTap: () => _confirmGroupArchive(g, total),
        ),
        AnMenuItem(
          label: w.groupDeleteAll,
          icon: AnIcons.trash,
          danger: true,
          onTap: () => _confirmGroupDelete(g, total),
        ),
        AnMenuItem(
          label: w.revealFinder,
          icon: AnIcons.folder,
          onTap: () => _reveal(g.workDir),
        ),
      ],
    );
  }

  /// The ⚙ sliders menu: a single-select Sort section (activity / created / name → the server `?sort=`)
  /// and a Display section of toggles (show archived → re-fetches all; show counts / show time → pure
  /// view prefs). 排序单选(server sort) + 显示开关(归档重取 / 计数·时间视图偏好,keepOpen 多切不收)。
  List<AnMenuEntry> _menu(
    Translations t,
    ConvSort sort,
    bool archived,
    bool showCount,
    bool showTime,
  ) {
    void setSort(ConvSort s) =>
        ref.read(conversationSortProvider.notifier).set(s);
    return [
      AnMenuSection(t.chat.sortLabel),
      AnMenuItem(
        label: t.chat.sortActivity,
        checked: sort == ConvSort.activity,
        onTap: () => setSort(ConvSort.activity),
      ),
      AnMenuItem(
        label: t.chat.sortCreated,
        checked: sort == ConvSort.created,
        onTap: () => setSort(ConvSort.created),
      ),
      AnMenuItem(
        label: t.chat.sortName,
        checked: sort == ConvSort.name,
        onTap: () => setSort(ConvSort.name),
      ),
      AnMenuSection(t.chat.displayLabel),
      AnMenuItem(
        label: t.chat.showArchived,
        checked: archived,
        keepOpen: true,
        onTap: () => ref.read(showArchivedProvider.notifier).toggle(),
      ),
      AnMenuItem(
        label: t.chat.showCount,
        checked: showCount,
        keepOpen: true,
        onTap: () => ref.read(showGroupCountProvider.notifier).toggle(),
      ),
      AnMenuItem(
        label: t.chat.showTime,
        checked: showTime,
        keepOpen: true,
        onTap: () => ref.read(showTimeProvider.notifier).toggle(),
      ),
    ];
  }

  // ── action handlers (optimistic: write → fold the authoritative result; toast on failure) ──

  Future<void> _setPinned(String id, bool pinned) async {
    try {
      _list.applyUpdate(await _repo.setPinned(id, pinned));
    } catch (_) {
      _noticeFail();
    }
  }

  Future<void> _setArchived(String id, bool archived) async {
    try {
      _list.applyUpdate(await _repo.setArchived(id, archived));
    } catch (_) {
      _noticeFail();
    }
  }

  // Fork from the LATEST message (no atMessageId) and open the new thread — a fork you cannot see is a
  // fork you have to go find, so the rail entry navigates like selecting a row does. The list fold
  // happens inside the shared helper.
  // 从**最新**消息处分叉(不给 atMessageId)并打开新线程——看不见的分叉是还得自己去找的分叉,故 rail 入口
  // 像选行一样导航过去。列表折入在共用 helper 里做。
  Future<void> _fork(String id) async {
    try {
      final result = await ref.read(forkConversationProvider)(id);
      if (mounted) context.go(conversationLocation(result.conversationId));
    } catch (_) {
      _noticeFail();
    }
  }

  // Commit a rename: trim, and treat empty-or-unchanged as a cancel (no PATCH). Clearing _editingId first
  // reverts the row to its display widget immediately. 提交改名:trim,空或未变即当取消(不 PATCH);先清编辑态回展示件。
  Future<void> _rename(String id, String value) async {
    final next = value.trim();
    // A row racing out of the list mid-edit → current is null → an empty new value still cancels (isEmpty),
    // a non-empty one still PATCHes (null != next). 编辑途中行被移除→current 为 null:空值仍取消、非空值仍 PATCH。
    final current = ref
        .read(conversationListProvider)
        .value
        ?.rows
        .where((c) => c.id == id)
        .firstOrNull
        ?.title;
    setState(() => _editingId = null);
    if (next.isEmpty || next == current) return;
    try {
      _list.applyUpdate(await _repo.renameConversation(id, next));
    } catch (_) {
      _noticeFail();
    }
  }

  Future<void> _confirmDelete(Conversation c) async {
    final t = context.t;
    final ok = await ref
        .read(overlayProvider.notifier)
        .confirm(
          title: t.chat.deleteTitle,
          message: t.chat.deleteBody(
            title: c.title.trim().isEmpty ? '…' : c.title,
          ),
          confirmLabel: t.chat.deleteConfirm,
          cancelLabel: t.action.cancel,
          barrierLabel: t.feedback.dialogBarrier,
        );
    if (!ok) return;
    try {
      await _repo.deleteConversation(c.id);
      _list.applyDelete(c.id);
      // Deleting the open thread leaves a dead detail — clear the selection (route is the truth). 删选中即清选区。
      if (!mounted) return;
      if (ref.read(selectedConversationProvider)?.id == c.id) context.go('/');
    } catch (_) {
      _noticeFail();
    }
  }

  // ── residency-group actions (one request each, never a loop of N) 驻地组动作(各一次请求、绝不循环 N 次) ──

  Future<void> _confirmGroupArchive(WorkDirGroup g, int total) async {
    final w = context.t.chat.workDir;
    final ok = await _confirmGroup(
      title: w.groupArchiveTitle,
      message: w.groupArchiveBody(count: total, name: _folderName(g.workDir)),
      confirmLabel: w.groupArchiveConfirm,
    );
    if (!ok) return;
    try {
      await _repo.archiveWorkDir(g.workDir);
      await _list.applyWorkDirGroupChanged(g.workDir);
    } catch (_) {
      _noticeFail();
    }
  }

  Future<void> _confirmGroupDelete(WorkDirGroup g, int total) async {
    final w = context.t.chat.workDir;
    final ok = await _confirmGroup(
      title: w.groupDeleteTitle,
      message: w.groupDeleteBody(count: total, name: _folderName(g.workDir)),
      confirmLabel: w.groupDeleteConfirm,
    );
    if (!ok) return;
    // The open thread may have been one of them — the route is the truth, so clear the selection before the
    // rail's rows go. 打开着的那条可能正在其中——路由是真相,故在 rail 的行消失之前先清选区。
    final open = ref.read(selectedConversationProvider)?.id;
    final openWasHere =
        open != null &&
        ref
                .read(conversationListProvider)
                .value
                ?.allRows
                .where((c) => c.id == open)
                .firstOrNull
                ?.workDir ==
            g.workDir;
    try {
      await _repo.deleteWorkDir(g.workDir);
      await _list.applyWorkDirGroupChanged(g.workDir);
      if (!mounted) return;
      if (openWasHere) context.go('/');
    } catch (_) {
      _noticeFail();
    }
  }

  Future<bool> _confirmGroup({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    final t = context.t;
    return ref
        .read(overlayProvider.notifier)
        .confirm(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: t.action.cancel,
          barrierLabel: t.feedback.dialogBarrier,
        );
  }

  Future<void> _reveal(String path) async {
    if (await revealInSystem(path)) return;
    if (!mounted) return;
    ref
        .read(noticeCenterProvider.notifier)
        .show(context.t.chat.workDir.openFailed, tone: AnTone.warn);
  }

  // The folder's own name — the same thing the group head shows, so the dialog names what the user clicked.
  // A trailing separator degrades to the full path rather than to an empty name.
  // 文件夹自己的名字——与组头显示的同一样东西,故确认框点出的正是用户点的那个。末尾带分隔符时退化成完整路径、而非空名。
  static String _folderName(String path) {
    final trimmed =
        path.length > 1 && (path.endsWith('/') || path.endsWith(r'\'))
        ? path.substring(0, path.length - 1)
        : path;
    final i = trimmed.lastIndexOf(RegExp(r'[/\\]'));
    final name = i < 0 ? trimmed : trimmed.substring(i + 1);
    return name.isEmpty ? path : name;
  }

  void _noticeFail() {
    if (!mounted) return;
    ref
        .read(noticeCenterProvider.notifier)
        .show(context.t.chat.actionFailed, tone: AnTone.danger);
  }
}
