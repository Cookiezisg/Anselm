import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/conversation.dart';
import '../../../core/design/tokens.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_rail_states.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../core/ui/an_typewriter.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../state/conversation_list_provider.dart';
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
/// 左岛对话导航。watch list + selected,解出四态之一(骨架/错+重试/空/AnSidebarList,置顶 + 最近两组),选择经 URL 写回
/// (唯一真相源)。镜像 EntityRail,去掉 per-kind。每行 hover 显 ⋯ 菜单(STEP 7)收齐逐线程动作:就地改名(经 editingRowId
/// → 复用 AnInlineEdit)、置顶/取消、归档/取消、删除(danger + 确认框)。写打到 repository,权威响应乐观折进列表(不等 SSE 回声)。
/// _editingId 是瞬时 widget 态(哪行在改名中)。
class ConversationRail extends ConsumerStatefulWidget {
  const ConversationRail({super.key});

  @override
  ConsumerState<ConversationRail> createState() => _ConversationRailState();
}

class _ConversationRailState extends ConsumerState<ConversationRail> {
  // Which row is mid-rename (its label slot becomes an AnInlineEdit). null = none. 哪行在改名中。
  String? _editingId;
  final _debounce = Debouncer(AnMotion.searchDebounce);

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  ConversationListNotifier get _list => ref.read(conversationListProvider.notifier);

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
    final rows = async.value?.rows ?? const <Conversation>[];
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
        // id → conversation, so the per-row ⋯ menu can read the current pin/archive state for its labels.
        // id→对话,供逐行 ⋯ 菜单按现态出置顶/归档标签。
        final byId = {for (final c in rows) c.id: c};
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
            rows,
            now: DateTime.now(),
            showCount: showCount,
            showTime: showTime,
            hasMore: async.value?.hasMore ?? false,
            loadingMore: async.value?.loadingMore ?? false,
            loadMoreFailed: async.value?.loadMoreFailed ?? false,
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
          onNew: () => context.go('/'),
          menuEntries: _menu(t, sort, archived, showCount, showTime),
          // The row id IS the conversation id — navigate straight to it (route is the source of truth).
          onSelect: (id) => context.go(conversationLocation(id)),
          onFilterChanged: _onFilter,
          onLoadMore: (_) => _list.loadMore(), // the recents tail pages the conversation list 最近段尾翻列表
          onRetryLoad: (_) => _list.loadMore(),
          editingRowId: _editingId,
          onRenameCommit: _rename,
          onRenameCancel: () => setState(() => _editingId = null),
          rowActionsBuilder: (id) {
            final c = byId[id];
            if (c == null) return const [];
            return [_rowMenu(t, c)];
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

  /// The per-row ⋯ menu (hover-revealed) — every per-thread action in one place: rename / pin·unpin /
  /// archive·unarchive / delete. Pin & archive labels flip on the row's current state; delete is a danger
  /// item that opens a confirm dialog. ⋯ 行菜单:改名/置顶/归档/删除(置顶·归档按现态翻标签;删除 danger + 确认)。
  Widget _rowMenu(Translations t, Conversation c) {
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
        AnIcons.more,
        size: AnButtonSize.sm,
        semanticLabel: t.a11y.moreActions,
        onPressed: toggle,
      ),
      entries: [
        AnMenuItem(label: t.chat.rename, icon: AnIcons.edit, onTap: () => setState(() => _editingId = c.id)),
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
        AnMenuItem(label: t.action.delete, icon: AnIcons.trash, danger: true, onTap: () => _confirmDelete(c)),
      ],
    );
  }

  /// The ⚙ sliders menu: a single-select Sort section (activity / created / name → the server `?sort=`)
  /// and a Display section of toggles (show archived → re-fetches all; show counts / show time → pure
  /// view prefs). 排序单选(server sort) + 显示开关(归档重取 / 计数·时间视图偏好,keepOpen 多切不收)。
  List<AnMenuEntry> _menu(Translations t, ConvSort sort, bool archived, bool showCount, bool showTime) {
    void setSort(ConvSort s) => ref.read(conversationSortProvider.notifier).set(s);
    return [
      AnMenuSection(t.chat.sortLabel),
      AnMenuItem(label: t.chat.sortActivity, checked: sort == ConvSort.activity, onTap: () => setSort(ConvSort.activity)),
      AnMenuItem(label: t.chat.sortCreated, checked: sort == ConvSort.created, onTap: () => setSort(ConvSort.created)),
      AnMenuItem(label: t.chat.sortName, checked: sort == ConvSort.name, onTap: () => setSort(ConvSort.name)),
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

  // Commit a rename: trim, and treat empty-or-unchanged as a cancel (no PATCH). Clearing _editingId first
  // reverts the row to its display widget immediately. 提交改名:trim,空或未变即当取消(不 PATCH);先清编辑态回展示件。
  Future<void> _rename(String id, String value) async {
    final next = value.trim();
    // A row racing out of the list mid-edit → current is null → an empty new value still cancels (isEmpty),
    // a non-empty one still PATCHes (null != next). 编辑途中行被移除→current 为 null:空值仍取消、非空值仍 PATCH。
    final current =
        ref.read(conversationListProvider).value?.rows.where((c) => c.id == id).firstOrNull?.title;
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
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.chat.deleteTitle,
          message: t.chat.deleteBody(title: c.title.trim().isEmpty ? '…' : c.title),
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

  void _noticeFail() {
    if (!mounted) return;
    ref.read(noticeCenterProvider.notifier).show(context.t.chat.actionFailed, tone: AnTone.danger);
  }
}
