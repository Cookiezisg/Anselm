import 'package:flutter_riverpod/flutter_riverpod.dart';

/// «刚刚» window (三段式文法 §3, 用户 0719) — the current-turn proxy. The transcript's turn nodes carry NO
/// timestamp (`hydrateTurn` drops `createdAt`, BlockNode has none), so the R-14 turn boundary isn't derivable
/// from the accordion's data; per the sanctioned fallback the current turn is a fixed 10-min window off `now`.
/// 回合锚在 ledger/transcript 节点上取不到时间 → 用固定 10 分钟窗代「本回合」。
const stageJustNowWindow = Duration(minutes: 10);

/// The ordered time-tier fold tokens the settled Cast buckets into (三段式文法 §3): 刚刚 → 早些时候 → 更早.
/// 落定 Cast 三时间档令牌(有序)。
const stageTierOrder = ['just', 'today', 'earlier'];

/// Bucket a Cast row's last-touched time into a tier token: `just` (within the current-turn window) / `today`
/// (earlier the same calendar day) / `earlier` (a past day). PURE — the window compare is absolute-instant
/// (tz-safe), the day split is local calendar day; unit-tested deterministically with injected [now].
/// 按最后触碰时间分档(纯函数,注入 now 可定测):刚刚/早些时候/更早。
String sidestageTierKey(DateTime lastAt, DateTime now) {
  if (!lastAt.isBefore(now.subtract(stageJustNowWindow))) return 'just';
  final l = lastAt.toLocal();
  final n = now.toLocal();
  final sameDay = l.year == n.year && l.month == n.month && l.day == n.day;
  return sameDay ? 'today' : 'earlier';
}

/// The sidestage's COLLAPSED top-level GROUP set (三段式文法 §3, 0719) — a NEW top-level fold axis ORTHOGONAL
/// to the row-level [stageExpansionProvider] (the sticky accordion managing each row's IN-PLACE expansion).
/// A group key = the TIME-TIER token (`just` · `today` · `earlier` — the settled Cast buckets by last-touched
/// time). Default: nothing collapsed (every tier open — the fold is opt-in, never hides content by default).
/// Externalized like the row expansion set so it stays STICKY across the list's virtualization; a conversation
/// switch frees it (autoDispose family). A tier with a LIVE / auto-expanded row force-opens at render (never
/// hides live work) — that override lives in the list, not here; this notifier only tracks the user's explicit
/// folds.
///
/// 侧幕顶层折叠组集——与行级展开(粘性手风琴管每行就地展开)正交的新折叠轴;组键=时间档令牌(just/today/earlier,
/// 落定 Cast 按最后触碰时间分档);默认全展开(组折叠是 opt-in,绝不默认藏内容);外置粘性跨虚拟化,切会话即释放。
/// 含 live/自动展开行的档渲染时强制展开(绝不藏 live 活)——那条覆盖在列表里、不在此;本 notifier 只记用户显式折叠。
class StageGroupCollapseController extends Notifier<Set<String>> {
  StageGroupCollapseController(this.conversationId);

  final String conversationId;

  @override
  Set<String> build() => const <String>{};

  /// Flip one group's fold. 翻转一组折叠。
  void toggle(String kind) =>
      state = state.contains(kind) ? ({...state}..remove(kind)) : {...state, kind};

  /// Reveal every group — the head ⋯ «展开全部» clears the fold so no settled row hides behind a collapsed
  /// head while its row expands. 全部展开顺手掀开所有组(免行展开却藏在折叠组后)。
  void openAll() {
    if (state.isNotEmpty) state = const <String>{};
  }
}

/// One conversation's sidestage group-fold set. autoDispose family — leaving the thread frees it.
/// 会话侧幕组折叠集;切走即释放。
final stageGroupCollapseProvider = NotifierProvider.autoDispose
    .family<StageGroupCollapseController, Set<String>, String>(StageGroupCollapseController.new);
