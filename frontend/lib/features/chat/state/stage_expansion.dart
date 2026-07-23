import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sidestage accordion's EXPANDED row set (WRK-064) — externalized so it stays STICKY across the
/// list's virtualization (a scrolled-away row's State is disposed, but its open/closed truth lives here).
/// rowId = `'<kind>:<key>'` (the CastEntity id), or `'todo'` for the pinned task row. A row the USER opened
/// stays open until it's explicitly toggled again. A row FOLLOW auto-opened when a live activity entered is
/// auto-COLLAPSED when the director curtains that activity (缺口B, 0719: settle → breath → the stage animates
/// back to a ledger row); pinned / failed holds and user-opened rows are exempt (the curtain-collapse in
/// [StagePanel]'s `_onDirector` only closes the exact row it auto-opened).
///
/// 侧幕手风琴的展开行集(外置)——粘性跨列表虚拟化(滚走行 State 被 dispose,开合真相在此)。rowId=
/// `'<kind>:<key>'`(CastEntity id)或置顶 todo 行 `'todo'`。用户展开的行一直开、只有再次 toggle 才收;follow
/// 在 live 入场时自动展开的行,导演器谢幕该活动时自动收起(缺口B:落定→停拍→动画收回台账行),pinned/失败定格
/// 与用户自展的行豁免(谢幕收起只关它自己自动展开的那行)。
class StageExpansionController extends Notifier<Set<String>> {
  StageExpansionController(this.conversationId);

  final String conversationId;

  /// Rows opened by the SYSTEM (director follow / deep-jump) — the tier force-open reads THIS set,
  /// never the whole expansion set (G11/A2-13: a user-opened row must not lock its tier unfoldable,
  /// and its later close must not slam the tier shut through a stale collapse token). Any close —
  /// user or curtain — ends a row's auto-show. 系统展开集(导演器跟随/深跳)——档强制展开只读它:
  /// 用户自展不锁档、其后收行也不引发档突然合拢;任何 close 都终结该行的自动展示期。
  final Set<String> _auto = {};
  Set<String> get autoOpened => _auto;

  @override
  Set<String> build() => const <String>{};

  /// Flip one row — the USER path. 翻转一行(用户径)。
  void toggle(String rowId) {
    if (state.contains(rowId)) {
      _auto.remove(rowId);
      state = {...state}..remove(rowId);
    } else {
      state = {...state, rowId};
    }
  }

  /// Open a row (idempotent) — the AUTO path (director follow / deep-jump). 展开(幂等,自动径)。
  void open(String rowId) {
    _auto.add(rowId);
    if (!state.contains(rowId)) state = {...state, rowId};
  }

  /// Collapse a row (idempotent). 收起(幂等)。
  void close(String rowId) {
    _auto.remove(rowId);
    if (state.contains(rowId)) state = {...state}..remove(rowId);
  }

  /// Open every row in [rowIds] — the head's «展开全部» (a USER bulk action). 展开全部(用户径)。
  void expandAll(Iterable<String> rowIds) => state = {...state, ...rowIds};

  /// Collapse everything — the head's «收起全部» (explicit, so it wins over sticky). 收起全部(显式,压过粘性)。
  void collapseAll() {
    _auto.clear();
    state = const <String>{};
  }
}

/// One conversation's accordion expansion set. autoDispose family — leaving the thread frees it.
/// 会话手风琴展开集;切走即释放。
final stageExpansionProvider = NotifierProvider.autoDispose
    .family<StageExpansionController, Set<String>, String>(
      StageExpansionController.new,
    );
