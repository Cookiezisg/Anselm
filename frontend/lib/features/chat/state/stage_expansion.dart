import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sidestage accordion's EXPANDED row set (WRK-064) — externalized so it stays STICKY across the
/// list's virtualization (a scrolled-away row's State is disposed, but its open/closed truth lives here).
/// rowId = `'<kind>:<key>'` (the CastEntity id), or `'todo'` for the pinned task row. A row opened by the
/// user — OR auto-opened by follow when a live activity enters — stays open until it's explicitly toggled
/// again; nothing auto-collapses it (accordion心智 = 同屏可见, WRK-064 §8-3).
///
/// 侧幕手风琴的展开行集(外置)——粘性跨列表虚拟化(滚走行 State 被 dispose,开合真相在此)。rowId=
/// `'<kind>:<key>'`(CastEntity id)或置顶 todo 行 `'todo'`。用户(或 live 入场时 follow 自动)展开的行
/// 一直开,只有再次 toggle 才收——绝不自动折叠。
class StageExpansionController extends Notifier<Set<String>> {
  StageExpansionController(this.conversationId);

  final String conversationId;

  @override
  Set<String> build() => const <String>{};

  /// Flip one row. 翻转一行。
  void toggle(String rowId) =>
      state = state.contains(rowId) ? ({...state}..remove(rowId)) : {...state, rowId};

  /// Open a row (idempotent) — the auto-follow path. 展开(幂等),自动跟随用。
  void open(String rowId) {
    if (!state.contains(rowId)) state = {...state, rowId};
  }

  /// Collapse a row (idempotent). 收起(幂等)。
  void close(String rowId) {
    if (state.contains(rowId)) state = {...state}..remove(rowId);
  }

  /// Open every row in [rowIds] — the head's «展开全部». 展开全部。
  void expandAll(Iterable<String> rowIds) => state = {...state, ...rowIds};

  /// Collapse everything — the head's «收起全部» (explicit, so it wins over sticky). 收起全部(显式,压过粘性)。
  void collapseAll() => state = const <String>{};
}

/// One conversation's accordion expansion set. autoDispose family — leaving the thread frees it.
/// 会话手风琴展开集;切走即释放。
final stageExpansionProvider = NotifierProvider.autoDispose
    .family<StageExpansionController, Set<String>, String>(StageExpansionController.new);
