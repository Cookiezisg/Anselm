import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../state/conversation_list_provider.dart';
import '../state/selected_conversation.dart';
import 'conversation_rail_model.dart';

/// The left-island conversation navigator (Chat STEP 4). Watches [conversationListProvider] (one live
/// list AsyncValue) + [selectedConversationProvider], resolves ONE of four screens — loading skeleton /
/// error+retry / empty / the [AnSidebarList] of conversations — and wires selection back through the
/// URL (`context.go(conversationLocation(id))`, the single source of truth). Mirrors EntityRail, minus
/// the per-kind machinery: ONE async to resolve, the row id IS the conversation id (no kindForId), and
/// the server sorts (no client sortRows). The ⚙ sort/show-archived menu + lazy New are later slices;
/// time-bucket grouping too — here the list is flat, in server order.
///
/// 左岛对话导航(Chat STEP 4)。watch conversationListProvider(单 list AsyncValue) + selectedConversationProvider,
/// 解出四态之一(骨架/错+重试/空/AnSidebarList),并把选择经 URL 写回(`context.go`,唯一真相源)。镜像 EntityRail,
/// 去掉 per-kind:一个 async、行 id 即对话 id(无 kindForId)、服务端排序(无客户端 sortRows)。⚙ 菜单 + 懒建 New 与时间分桶为后续片;此处扁平、按服务端序。
class ConversationRail extends ConsumerWidget {
  const ConversationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationListProvider);
    final selected = ref.watch(selectedConversationProvider);
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
      // The row id IS the conversation id — navigate straight to it (the route is the source of truth;
      // the rail never imports the ocean, it just changes the URL). 行 id 即对话 id,直接导航(路由为真相)。
      onSelect: (id) => context.go(conversationLocation(id)),
    );
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
