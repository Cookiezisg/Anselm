import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/contract/notification.dart';

part 'notification_feed_state.freezed.dart';

/// The loaded state of the notification feed: rows so far (newest-first) + the keyset paging cursor + an
/// in-flight loadMore flag. Wrapped in an AsyncValue by the notifier; `loadingMore` lives inside the data
/// so appending a page never flips the whole feed back to a spinner. Mirrors [ConversationListState].
///
/// 通知 feed 的已加载态:已得行(最新优先)+ keyset 游标 + loadMore 在途标志。loadingMore 在 data 内,
/// 故翻页不打回 spinner。镜像 ConversationListState。
@freezed
abstract class NotificationFeedState with _$NotificationFeedState {
  const factory NotificationFeedState({
    @Default(<NotificationItem>[]) List<NotificationItem> rows,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
  }) = _NotificationFeedState;
}
