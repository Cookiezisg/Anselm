import 'package:freezed_annotation/freezed_annotation.dart';

part 'version_list_state.freezed.dart';

/// A kind-erased version row so the versions tab + [AnVersionDiff] are kind-agnostic: `src` is the
/// comparable source text (function code / handler class / agent prompt / workflow graph json), `lang`
/// its highlight key, `active` flags the entity's current active version. 版本行(kind 无关):src=可比源文本。
class VersionRow {
  const VersionRow({
    required this.version,
    required this.active,
    required this.createdAt,
    required this.src,
    required this.lang,
    this.changeReason,
    this.summary = const [],
  });

  final int version;
  final bool active;
  final DateTime createdAt;
  final String src;
  final String lang;
  final String? changeReason;

  /// Structured non-text deltas vs the next-older version, as short chips (`+ units` / `− dep pydantic`
  /// / `py 3.11→3.12`) — the text diff below only covers `src`. 相对上版的结构化(非文本)变化小签。
  final List<String> summary;
}

/// The versions tab state: the loaded (newest-first) version page + keyset paging + which row is
/// selected for the diff (defaults to newest = index 0). 版本 tab 态:版本页 + 分页 + diff 选中行。
@freezed
abstract class VersionListState with _$VersionListState {
  const factory VersionListState({
    @Default(<VersionRow>[]) List<VersionRow> versions,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
    @Default(0) int selectedIndex,
  }) = _VersionListState;
}
