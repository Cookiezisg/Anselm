import '../../../core/contract/conversation.dart';
import '../../../core/model/sidebar_model.dart';
import '../../../core/model/status_state.dart';

/// Project the loaded conversations onto a flat [SidebarModel] for [AnSidebarList] — one group (label
/// null → flattens) holding one headless type (label+icon null → rows at depth 0), one [SidebarRow] per
/// conversation {id, title, lead dot}. Single-domain, so unlike the entities rail there is NO per-kind
/// section AND NO client-side sort: the server already orders the rows (ConvSort → ?sort=), so they are
/// emitted in arrival order. Time-bucket grouping (Pinned / Today / Yesterday / …) is a later slice.
///
/// 把已加载对话投影成扁平 SidebarModel 喂 AnSidebarList——一个 group(label 空→扁平)持一个 headless type(label+icon 空→
/// 行在 depth 0)、每对话一个 SidebarRow{id, 标题, 前导点}。单域,故不像 entities rail 有 per-kind 分节、也无客户端排序:
/// 服务端已排好(ConvSort→?sort=),按到达序发出。时间分桶(置顶/今天/昨天/…)是后续片。
SidebarModel buildConversationRailModel(
  List<Conversation> rows, {
  required String newLabel,
  required String filter,
}) =>
    SidebarModel(
      newLabel: newLabel,
      filterPlaceholder: filter,
      groups: [
        SidebarGroup(types: [
          SidebarType(rows: [
            for (final c in rows) SidebarRow(id: c.id, label: c.title, dot: conversationDot(c)),
          ]),
        ]),
      ],
    );

/// The lead status dot for a conversation rail row — or null for a plain active thread (no dot, the
/// common case). Precedence, highest first:
///   generating (blue, the only animated/breathing dot) > awaiting input (amber "needs you") >
///   unread (green "answered while you were away") > archived (gray marker) > none.
/// The first three are the live activity signals (mutually exclusive in practice — a thread is
/// generating, or blocked on you, or has a fresh reply); the archived gray dot is a static "this is
/// archived" marker that only ever shows when the rail is set to include archived threads.
///
/// 会话 rail 行的前导状态点——普通活跃线程返 null(无点,常态)。优先级(高→低):生成中(蓝、唯一呼吸)>等你输入
/// (琥珀「等你」)>未读(绿「你不在时答完了」)>已归档(灰标记)>无。前三是活态信号(实际互斥);归档灰点是静态
/// 「这是归档」标记,仅当 rail 设为含归档时才出现。
AnStatus? conversationDot(Conversation c) {
  if (c.isGenerating) return AnStatus.run;
  if (c.awaitingInput) return AnStatus.wait;
  if (c.hasUnread) return AnStatus.done;
  if (c.archived) return AnStatus.idle;
  return null;
}
