import 'package:freezed_annotation/freezed_annotation.dart';

part 'version_list_state.freezed.dart';

/// A kind-erased version row so the versions tab + [AnVersionDiff] are kind-agnostic: `src` is the
/// comparable source text (function code / handler class / agent prompt / workflow graph json), `lang`
/// its highlight key, `active` flags the entity's current active version, `summary` holds the
/// structured (non-text) deltas vs the next-older version, and [added]/[removed] are that version's
/// line counts against the next-older LOADED row (null = no neighbour to count against: the earliest
/// version, or a page-boundary row — the same honest degrade `summary` takes). A freezed value type so
/// equal content → equal state (rebuilding rows never spuriously invalidates).
/// 版本行(kind 无关):src=可比源文本;added/removed=对下一更旧「已载入」行的行计数(null=无邻可比:最早版本
/// 或页边界行,与 summary 同一诚实降级);值类型结构相等。
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
    int? added,
    int? removed,
  }) = _VersionRow;
}

/// The versions tab state: the loaded (newest-first) version page + keyset paging + the ACCORDION's two
/// open sets + which version's set-active is in flight.
///
/// [expanded] = the version numbers whose diff card is open, [fullSource] = those showing the WHOLE
/// text instead of the changed hunks. Both are keyed by VERSION NUMBER (the row's stable identity
/// across paging and rebuilds) and both live HERE, outside the widgets — the sidestage accordion's
/// discipline: a row's open/folded truth must not die with the State of a widget that scrolled away,
/// and a second entrance (the row's ⋯ menu) has to drive the very same truth as the row itself.
/// [activatingVersion] (null = none) drives the menu item's pending/disabled state + the re-entry guard.
///
/// 版本 tab 态:版本页 + 分页 + 手风琴两个开合集 + 设为活跃进行中的版本号。expanded=已展开 diff 的版本号,
/// fullSource=显整份文本(而非变更块)的版本号;都按**版本号**记键(跨分页/重建的稳定身份)、都外置于 widget
/// (侧幕手风琴纪律:滚走的行 State 一死不能带走开合真相;⋯ 菜单作为第二入口必须驱动同一份真相)。
@freezed
abstract class VersionListState with _$VersionListState {
  const factory VersionListState({
    @Default(<VersionRow>[]) List<VersionRow> versions,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
    @Default(<int>{}) Set<int> expanded,
    @Default(<int>{}) Set<int> fullSource,
    int? activatingVersion,
  }) = _VersionListState;
}
