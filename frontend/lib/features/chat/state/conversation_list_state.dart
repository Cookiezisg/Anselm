import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/contract/conversation.dart';

part 'conversation_list_state.freezed.dart';

/// ONE paginated axis of the conversation rail: the rows loaded so far + its keyset cursor + the tail's
/// in-flight / failed flags. `loadingMore` lives INSIDE the data so appending a page never flips the axis
/// back to a spinner; `loadFailed` (WRK-059 M9) swaps the auto-firing tail sentinel for a manual retry row,
/// because a persistent server error must not become a per-RTT retry storm.
///
/// The rail has 2 + N of these (Pinned, Recents, and one per residency group). They are separate axes rather
/// than one list sliced client-side because each is its own SERVER query — that is what keeps a group's
/// membership from drifting as the user scrolls.
///
/// 对话 rail 的**一个**分页轴:已得行 + 它的 keyset 游标 + 尾部在途/失败标志。`loadingMore` 在 data 内,故翻页不会
/// 把该轴打回 spinner;`loadFailed`(M9)把自动触发的尾哨兵换成手动重试行——持久服务端错误绝不该成 per-RTT 风暴。
///
/// rail 有 2 + N 个这样的轴(置顶、最近、每个驻地组一个)。它们是**分开的轴**、而不是一个列表在客户端切片,因为每个
/// 都是它自己的**服务端**查询——正是这一点让一个组的成员不随用户滚动而漂移。
@freezed
abstract class ConvAxis with _$ConvAxis {
  const factory ConvAxis({
    @Default(<Conversation>[]) List<Conversation> rows,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
    @Default(false) bool loadFailed,

    /// Whether this axis has EVER resolved a page. A group axis starts unloaded with `hasMore: true` so the
    /// rail renders its tail sentinel and fetches page one only when the section is actually expanded and
    /// scrolled into view — lazy by construction, not by a special "fetch on expand" callback.
    ///
    /// 本轴是否**曾**解出过一页。组轴以「未加载 + hasMore: true」起步,使 rail 渲出它的尾哨兵、并**仅在**该段真被
    /// 展开且滚进视野时才取第一页——惰性是**构造出来的**、不靠一个特设的「展开时取数」回调。
    @Default(false) bool loaded,
  }) = _ConvAxis;
}

/// The loaded state of the whole conversation rail — FOUR sections, each server-authoritative:
///
///   1. [pinned] — every pinned thread, across residencies. Pinned WINS: a pinned thread renders here and
///      NOT in its residency group, so it appears exactly once.
///   2. [groups] — the residency grouping (`GET /workdir-groups`): the group heads with their authoritative
///      counts and their order. Heads only; a group's ROWS live in [groupAxes], fetched per group.
///   3. [groupAxes] — one paginated axis per residency, keyed by the residency path. A key absent means "not
///      fetched yet".
///   4. [recents] — the threads that live in NO directory. Kept under the legacy field names
///      ([rows] / [hasMore] / …) because it is the same axis the rail always had, now narrowed by
///      `?workDir=` to the unmounted threads.
///
/// freezed for cheap `==` (the rail rebuilds only on real change).
///
/// 整个对话 rail 的已加载态——**四段**、每段都由服务端权威:①[pinned] 所有置顶线程(跨驻地。**置顶赢**:置顶线程渲在
/// 这里、**不**在它的驻地组里,故恰好出现一次)②[groups] 驻地分组(`GET /workdir-groups`:组头 + 它们的权威计数与顺序;
/// **只有头**,组的**行**在 [groupAxes]、逐组取)③[groupAxes] 每个驻地一个分页轴、按驻地路径键(键缺席=还没取)
/// ④[recents] 不住在任何目录里的线程(沿用旧字段名 [rows]/[hasMore]/…,因为它就是 rail 一直有的那个轴、现在被
/// `?workDir=` 收窄到未挂的那些)。
@freezed
abstract class ConversationListState with _$ConversationListState {
  // freezed requires the private constructor for a class that adds its own getters (below).
  // 一个自带 getter 的 freezed 类需要这个私有构造。
  const ConversationListState._();

  const factory ConversationListState({
    @Default(ConvAxis()) ConvAxis recents,
    @Default(ConvAxis()) ConvAxis pinned,
    @Default(<WorkDirGroup>[]) List<WorkDirGroup> groups,
    @Default(<String, ConvAxis>{}) Map<String, ConvAxis> groupAxes,

    /// A query is active, so this state is NOT the four-section rail: it is ONE flat result list over the
    /// whole workspace, carried by [recents], with no pinned section and no groups.
    ///
    /// Searching REPLACES the structure rather than filtering it, because a folded folder fetches nothing —
    /// a rail that merely narrowed each section would answer "no matches" for every thread the user had not
    /// already scrolled into view. And it is the honest reading of the question: which CONVERSATIONS match,
    /// not which folders do.
    ///
    /// 有查询词,故本态**不是**四段 rail:它是对整个 workspace 的**一条平结果列表**、由 [recents] 承载,无置顶段、
    /// 无组。
    ///
    /// 搜索是**替换**结构、不是过滤结构,因为收起的文件夹什么都不取——一个只是把各段收窄的 rail 会对每一条用户
    /// 尚未滚进视野的线程答「没有匹配」。而这也是这个问题的诚实读法:哪些**对话**匹配、不是哪些文件夹匹配。
    @Default(false) bool searching,
  }) = _ConversationListState;

  /// The Recents axis under its historical names — the rail, the ocean and the tests all read `rows`.
  /// 「最近」轴的历史名字——rail、海洋与测试都读 `rows`。
  List<Conversation> get rows => recents.rows;
  String? get nextCursor => recents.nextCursor;
  bool get hasMore => recents.hasMore;
  bool get loadingMore => recents.loadingMore;
  bool get loadMoreFailed => recents.loadFailed;

  /// Every loaded row across all four sections, in section order — what a "find this conversation in the
  /// rail" read wants (a merge fold, the selection lookup, the id→row map the ⋯ menus key on).
  ///
  /// 四段中所有已加载行、按段序——一次「在 rail 里找这条对话」的读所要的东西(合并折入、选区查找、⋯ 菜单据以取
  /// 现态的 id→行 表)。
  List<Conversation> get allRows => [
    ...pinned.rows,
    for (final g in groups) ...?groupAxes[g.workDir]?.rows,
    ...recents.rows,
  ];
}
