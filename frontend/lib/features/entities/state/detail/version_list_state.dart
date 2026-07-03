import 'package:freezed_annotation/freezed_annotation.dart';

part 'version_list_state.freezed.dart';

/// A kind-erased version row so the versions tab + [AnVersionDiff] are kind-agnostic: `src` is the
/// comparable source text (function code / handler class / agent prompt / workflow graph json), `lang`
/// its highlight key, `active` flags the entity's current active version, `summary` holds the
/// structured (non-text) deltas vs the next-older version. A freezed value type so equal content →
/// equal state (rebuilding rows never spuriously invalidates). 版本行(kind 无关):src=可比源文本;值类型结构相等。
@freezed
abstract class VersionRow with _$VersionRow {
  const factory VersionRow({
    required int version,
    required bool active,
    required DateTime createdAt,
    required String src,
    required String lang,
    String? changeReason,
    @Default(<String>[]) List<String> summary,
  }) = _VersionRow;
}

/// The versions tab state: the loaded (newest-first) version page + keyset paging + which row is
/// selected for the diff (defaults to newest = index 0) + which version's set-active is in flight
/// ([activatingVersion], null = none — drives the button's pending/disabled state + re-entry guard).
/// 版本 tab 态:版本页 + 分页 + diff 选中行 + 设为活跃进行中的版本号(驱动按钮 pending + 防重入)。
@freezed
abstract class VersionListState with _$VersionListState {
  const factory VersionListState({
    @Default(<VersionRow>[]) List<VersionRow> versions,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
    @Default(0) int selectedIndex,
    int? activatingVersion,
  }) = _VersionListState;
}
