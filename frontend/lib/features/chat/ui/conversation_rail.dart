import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../data/chat_repository.dart';
import '../state/conversation_list_provider.dart';
import '../state/selected_conversation.dart';
import 'conversation_rail_model.dart';

/// The left-island conversation navigator. Watches [conversationListProvider] (one live list AsyncValue)
/// + [selectedConversationProvider], resolves ONE of four screens — loading skeleton / error+retry /
/// empty / the [AnSidebarList] of conversations grouped Pinned + Recents — and wires selection back
/// through the URL (`context.go(conversationLocation(id))`, the single source of truth). Mirrors
/// EntityRail, minus the per-kind machinery: ONE async to resolve, the row id IS the conversation id (no
/// kindForId), and the server sorts (no client sortRows). The ⚙ sliders menu offers Sort (activity /
/// created / name) + Display toggles (show archived / show counts / show time). Lazy New rides the chat
/// ocean's composer (a later phase).
///
/// 左岛对话导航。watch conversationListProvider(单 list AsyncValue) + selectedConversationProvider,解出四态之一
/// (骨架/错+重试/空/AnSidebarList,置顶 + 最近两组),并把选择经 URL 写回(`context.go`,唯一真相源)。镜像 EntityRail,
/// 去掉 per-kind:一个 async、行 id 即对话 id(无 kindForId)、服务端排序(无客户端 sortRows)。⚙ sliders 菜单:排序(activity/created/name)
/// + 显示开关(显示已归档 / 显示分组计数 / 显示时间)。懒建 New 走聊天 ocean 的 composer(后续相)。
class ConversationRail extends ConsumerWidget {
  const ConversationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationListProvider);
    final selected = ref.watch(selectedConversationProvider);
    // The ⚙ menu's state: sort + archived drive the list (the notifier re-fetches on change); count +
    // time are pure view prefs applied at render. Watched here so the menu's checkmarks + the model
    // rebuild on toggle. ⚙ 菜单态:sort/archived 驱动列表(notifier 变即重取),count/time 是渲染时视图偏好。
    final sort = ref.watch(conversationSortProvider);
    final archived = ref.watch(showArchivedProvider);
    final showCount = ref.watch(showGroupCountProvider);
    final showTime = ref.watch(showTimeProvider);
    final t = context.t;

    // Loading: nothing resolved yet → a shaped skeleton (deferred so a fast load never flashes it).
    if (async.isLoading && !async.hasValue) {
      return const AnDeferredLoading(child: _RailSkeleton());
    }

    // Error with nothing loaded → retry refetches the list (the provider disables auto-retry).
    if (async.hasError && !async.hasValue) {
      return AnState(
        kind: AnStateKind.error,
        title: t.chat.errorTitle,
        hint: t.chat.errorHint,
        action: AnButton(
          label: t.chat.retry,
          onPressed: () => ref.invalidate(conversationListProvider),
        ),
      );
    }

    final rows = async.value?.rows ?? const [];
    if (rows.isEmpty) {
      return AnState(kind: AnStateKind.empty, title: t.chat.emptyTitle, hint: t.chat.emptyHint);
    }

    final model = buildConversationRailModel(
      rows,
      now: DateTime.now(),
      showCount: showCount,
      showTime: showTime,
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
    );

    return AnSidebarList(
      model: model,
      selectedId: selected?.id,
      showNew: false, // lazy New-chat is a later slice; the rail is read+select only here
      menuEntries: _menu(ref, t, sort, archived, showCount, showTime),
      // The row id IS the conversation id — navigate straight to it (the route is the source of truth;
      // the rail never imports the ocean, it just changes the URL). 行 id 即对话 id,直接导航(路由为真相)。
      onSelect: (id) => context.go(conversationLocation(id)),
    );
  }

  /// The ⚙ sliders menu: a single-select Sort section (activity / created / name → the server `?sort=`)
  /// and a Display section of toggles (show archived → re-fetches all; show counts / show time → pure
  /// view prefs). Display toggles keepOpen so several can be flipped without reopening; picking a sort
  /// closes (it is a radio). 排序单选(server sort) + 显示开关(归档重取 / 计数·时间视图偏好,keepOpen 多切不收)。
  List<AnMenuEntry> _menu(
    WidgetRef ref,
    Translations t,
    ConvSort sort,
    bool archived,
    bool showCount,
    bool showTime,
  ) {
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
}

/// The first-load placeholder — a few bone rows under the chrome zone (copied from EntityRail).
/// 首载占位:数行骨架(抄自 EntityRail)。
class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
        ],
      ),
    );
  }
}
