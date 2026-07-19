import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/contract/conversation.dart';

part 'conversation_list_state.freezed.dart';

/// The loaded state of the conversation rail list: the rows so far + the keyset paging cursor + an
/// in-flight flag for the loadMore tail. Wrapped in an AsyncValue by the notifier (AsyncLoading on
/// first load, AsyncData(this) after); `loadingMore` lives INSIDE the data so appending a page never
/// flips the whole list back to a spinner. freezed for cheap `==` (so the rail rebuilds only on real
/// change). Mirrors EntityListState.
///
/// 对话 rail 列表的已加载态:已得行 + keyset 游标 + loadMore 在途标志。由 notifier 包进 AsyncValue;`loadingMore`
/// 在 data 内,故翻页不会把整列表打回 spinner。freezed 提供廉价 `==`。镜像 EntityListState。
@freezed
abstract class ConversationListState with _$ConversationListState {
  const factory ConversationListState({
    @Default(<Conversation>[]) List<Conversation> rows,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
    // The loadMore tail FAILED (WRK-059 M9): the rail swaps the auto-firing sentinel for a manual
    // retry row — a persistent server error must not become a per-RTT retry storm.
    // loadMore 尾部失败(M9):rail 把自动触发哨兵换成手动重试行——持久服务端错误绝不成 per-RTT 风暴。
    @Default(false) bool loadMoreFailed,
  }) = _ConversationListState;
}
