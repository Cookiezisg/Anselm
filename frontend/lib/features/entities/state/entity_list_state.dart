import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/entity_row.dart';

part 'entity_list_state.freezed.dart';

/// The loaded state of one kind's rail list: the rows so far + the keyset paging cursor + an in-flight
/// flag for the loadMore tail. Wrapped in an AsyncValue by the notifier (AsyncLoading on first load,
/// AsyncData(this) after); `loadingMore` lives INSIDE the data so appending a page never flips the whole
/// list back to a spinner. freezed for cheap `==` (so the rail rebuilds only on real change).
///
/// 单 kind rail 列表的已加载态:已得行 + keyset 游标 + loadMore 在途标志。由 notifier 包进 AsyncValue;
/// `loadingMore` 在 data 内,故翻页不会把整列表打回 spinner。freezed 提供廉价 `==`。
@freezed
abstract class EntityListState with _$EntityListState {
  const factory EntityListState({
    @Default(<EntityRow>[]) List<EntityRow> rows,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
  }) = _EntityListState;
}
