import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/touchpoint.dart';
import '../../../core/sse/frame.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';

/// One CAST row — the R-2 entity aggregation over the physical per-(item,VERB) ledger rows (WRK-061):
/// the island shows ONE row per touched thing, fronted by its freshest verb, with the other verbs as a
/// micro-badge sequence. mcp rows are keyed by NAME (the backend's id is three-pathed: install=mcp_ id,
/// uninstall/dynamic=short name — the name converges). Any `deleted` row tombstones the whole entity
/// (GET is banned on it; the row renders as a tombstone).
///
/// 演员表一行——R-2 实体聚合(物理行是每 (物,动词) 一条):每个被碰之物一行,主显最新动词,余动词渲微徽序列。
/// mcp 按名归一(后端 id 三径不收敛、名收敛)。任一 deleted 行到达即整实体墓碑化(封禁 GET)。
class CastEntity {
  const CastEntity({required this.kind, required this.key, required this.byVerb});

  final String kind;

  /// The aggregation key: itemId, except mcp which normalizes to the (converging) name. 聚合键。
  final String key;

  /// Freshest physical row per verb. 每动词最新物理行。
  final Map<TouchpointVerb, Touchpoint> byVerb;

  /// The row whose verb fronts the entity — freshest lastAt wins. 主显行(lastAt 最新)。
  Touchpoint get primary => byVerb.values.reduce((a, b) => b.lastAt.isAfter(a.lastAt) ? b : a);

  /// The entity sort key = max(lastAt) over its verb rows (R-2). 实体排序键。
  DateTime get lastAt => primary.lastAt;

  bool get tombstoned => byVerb.containsKey(TouchpointVerb.deleted);

  /// Newest non-empty name snapshot across rows (client-side 兄弟借名), else the raw key. 显示名。
  String get displayName {
    Touchpoint? named;
    for (final r in byVerb.values) {
      if (r.itemName.isEmpty) continue;
      if (named == null || r.lastAt.isAfter(named.lastAt)) named = r;
    }
    return named?.itemName ?? key;
  }

  /// Non-primary verbs for the micro-badge sequence, freshest first. 微徽序列(除主显外,新→旧)。
  List<Touchpoint> get secondary {
    final p = primary;
    final rest = byVerb.values.where((r) => !identical(r, p)).toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return rest;
  }
}

/// The ledger's loaded window + its keyset coordinates. [rows] is the id-keyed loaded region;
/// [entities] is the R-2 aggregation, sorted freshest-first — derived once per mutation, not per build.
/// 已载窗口 + keyset 坐标。rows 按行 id;entities 是 R-2 聚合(新→旧),变更时派生一次、非每 build。
class TouchpointLedgerState {
  const TouchpointLedgerState({
    this.rows = const {},
    this.entities = const [],
    this.nextCursor,
    this.hasMore = false,
    this.hydrated = false,
    this.loading = false,
    this.failed = false,
  });

  final Map<String, Touchpoint> rows;
  final List<CastEntity> entities;
  final String? nextCursor;
  final bool hasMore;

  /// First page landed at least once (empty ledger ≠ still loading). 首页已到(空台账≠加载中)。
  final bool hydrated;
  final bool loading;

  /// The initial hydration failed (retry affordance); later page/signal errors stay silent-degrade.
  /// 首拉失败(给重试口);后续翻页/信号错误静默降级。
  final bool failed;

  bool get isEmpty => hydrated && rows.isEmpty;
}

/// One conversation's touchpoint ledger — REST keyset hydration ⊕ the durable `touchpoint` Signal
/// (messages stream, payload = the full row) upserted STRAIGHT into this cache (never through
/// CoalescingNotifier — that seam is EPHEMERAL-ONLY, W0 §5-5). Cursor discipline (§5-9): rows are
/// deduped by id keeping the newer lastAt; a row that jumped INTO the loaded region (mutable sort key)
/// is delivered by its own signal, so server cursors stay valid. A 410 resync refetches the FIRST page
/// and merges — anything touched during the gap has a fresh lastAt, so page one covers the loss.
///
/// 一个会话的触点台账:REST keyset 水化 ⊕ durable touchpoint 信号直 patch 本缓存(绝不过
/// CoalescingNotifier——那条缝 EPHEMERAL-ONLY,W0 §5-5)。游标纪律(§5-9):按行 id 去重、lastAt 新者胜;
/// 升区行由自身信号送达,服务端游标仍有效。410 重同步=重拉首页并入——缺口期被碰过的行 lastAt 必新,
/// 首页即覆盖损失。
class TouchpointLedgerController extends Notifier<TouchpointLedgerState> {
  TouchpointLedgerController(this.conversationId);

  final String conversationId;

  late ChatRepository _repo;
  StreamSubscription<StreamEnvelope>? _sub;
  StreamSubscription<void>? _resyncSub;

  @override
  TouchpointLedgerState build() {
    _repo = ref.watch(chatRepositoryProvider);
    // Subscribe BEFORE hydration so a signal landing mid-fetch is never lost (newer-lastAt merge keeps
    // it over the stale page row). 订阅先于水化:取窗内信号不丢(lastAt 新者胜)。
    _sub = _repo.conversationFrames(conversationId).listen(_onFrame);
    _resyncSub = _repo.transcriptResync().listen((_) => unawaited(_hydrate(merge: true)));
    ref.onDispose(() {
      _sub?.cancel();
      _resyncSub?.cancel();
    });
    unawaited(_hydrate());
    return const TouchpointLedgerState(loading: true);
  }

  Future<void> _hydrate({bool merge = false}) async {
    // Yield one microtask FIRST: build() calls this before its initial state is assigned, and a
    // repository that throws synchronously would otherwise run the catch's `state=` inside build()
    // (uninitialized-state throw). 先让一拍:build 内调用时初始 state 尚未赋值,同步抛错的 repo 会让
    // catch 在 build 未返回前写 state(未初始化即抛)。
    await null;
    try {
      final page = await _repo.listTouchpoints(conversationId);
      if (!ref.mounted) return;
      final rows = merge ? {...state.rows} : <String, Touchpoint>{};
      for (final r in page.items) {
        _mergeRow(rows, r);
      }
      state = _emit(
        rows,
        // A merge resync keeps the deeper cursor (the loaded window survives); a cold hydrate restarts.
        // 重同步保留更深游标(已载窗口存续);冷水化重开。
        nextCursor: merge ? state.nextCursor : page.nextCursor,
        hasMore: merge ? state.hasMore : page.hasMore,
      );
    } catch (_) {
      if (!ref.mounted) return;
      if (!state.hydrated) {
        state = const TouchpointLedgerState(failed: true, hydrated: false);
      }
      // Post-hydration resync failures degrade silently — signals still flow. 已水化后的失败静默降级。
    }
  }

  /// Retry the failed initial hydration. 首拉失败重试。
  Future<void> retry() async {
    state = const TouchpointLedgerState(loading: true);
    await _hydrate();
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (state.loading || !state.hasMore || cursor == null) return;
    state = _emit(state.rows, nextCursor: cursor, hasMore: state.hasMore, loading: true);
    try {
      final page = await _repo.listTouchpoints(conversationId, cursor: cursor);
      if (!ref.mounted) return;
      final rows = {...state.rows};
      for (final r in page.items) {
        _mergeRow(rows, r);
      }
      state = _emit(rows, nextCursor: page.nextCursor, hasMore: page.hasMore);
    } catch (_) {
      if (!ref.mounted) return;
      // Keep the window; drop the spinner — the affordance can retry. 保窗口、去转圈,可重试。
      state = _emit(state.rows, nextCursor: cursor, hasMore: state.hasMore);
    }
  }

  void _onFrame(StreamEnvelope env) {
    final frame = env.frame;
    if (frame is! FrameSignal || frame.node.type != 'touchpoint') return;
    // DB row is truth; only durable signals patch the cache (an ephemeral echo never mutates it).
    // DB 行是真相:只有 durable 信号 patch 缓存(ephemeral 回声不动它)。
    if (!env.durable) return;
    final content = frame.node.content;
    if (content == null) return;
    final row = Touchpoint.fromJson(content);
    if (row.id.isEmpty) return;
    final rows = {...state.rows};
    _mergeRow(rows, row);
    state = _emit(rows, nextCursor: state.nextCursor, hasMore: state.hasMore, loading: state.loading);
  }

  // Upsert keeping the newer lastAt (a stale page copy never clobbers a fresher signal). 新者胜。
  static void _mergeRow(Map<String, Touchpoint> rows, Touchpoint row) {
    final existing = rows[row.id];
    if (existing == null || !row.lastAt.isBefore(existing.lastAt)) rows[row.id] = row;
  }

  TouchpointLedgerState _emit(
    Map<String, Touchpoint> rows, {
    String? nextCursor,
    required bool hasMore,
    bool loading = false,
  }) =>
      TouchpointLedgerState(
        rows: rows,
        entities: aggregate(rows.values),
        nextCursor: nextCursor,
        hasMore: hasMore,
        hydrated: true,
        loading: loading,
      );

  /// The R-2 aggregation: physical per-(item,verb) rows → entity rows keyed by (kind, itemId — mcp
  /// normalized to name), sorted freshest-first. Pure + static for direct unit testing.
  /// R-2 聚合:物理行 → 实体行((kind,itemId),mcp 按名归一),新→旧。纯静态便于单测。
  static List<CastEntity> aggregate(Iterable<Touchpoint> rows) {
    final byEntity = <String, Map<TouchpointVerb, Touchpoint>>{};
    final keys = <String, ({String kind, String key})>{};
    for (final row in rows) {
      final key = row.itemKind == 'mcp'
          ? (row.itemName.isNotEmpty ? row.itemName : row.itemId)
          : row.itemId;
      final mapKey = '${row.itemKind} $key';
      keys[mapKey] = (kind: row.itemKind, key: key);
      final verbs = byEntity[mapKey] ??= {};
      final existing = verbs[row.verb];
      if (existing == null || !row.lastAt.isBefore(existing.lastAt)) verbs[row.verb] = row;
    }
    final out = [
      for (final e in byEntity.entries)
        CastEntity(kind: keys[e.key]!.kind, key: keys[e.key]!.key, byVerb: e.value),
    ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return out;
  }
}

/// One conversation's touchpoint ledger (Cast data source). autoDispose family — leaving the thread
/// frees the subscription. 会话触点台账(演员表数据源);切走即释放。
final touchpointLedgerProvider = NotifierProvider.autoDispose
    .family<TouchpointLedgerController, TouchpointLedgerState, String>(
        TouchpointLedgerController.new);
