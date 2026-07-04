import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/trigger.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/state/keyset_paging.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import 'log_list_state.dart';

/// The trigger detail's TWO observability streams (活动 = activations, 派发 = firings), each a keyset-paged
/// list of expandable [LogRow]s — the SAME row shape + paging machinery the 日志 tab uses (reused, not
/// re-invented), so the observability tabs render exactly like a log tab (`AnRowDetail` + load-more).
/// Both are autoDispose families keyed by (triggerId + filter): flipping the filter re-watches a fresh
/// instance (clean keyset refetch, old one torn down). Detail-row labels use slang's global `t` (no
/// BuildContext in state). trigger 的两条观测面(活动/派发),复用日志 tab 的行+分页;按 (id+过滤) family。

/// Activation list — one row per action (fired or not); `firedOnly` narrows to the fired ones.
class ActivationListNotifier extends AsyncNotifier<LogListState>
    with KeysetScopedPaging<LogListState, LogRow> {
  ActivationListNotifier(this.arg);

  final ({String triggerId, bool firedOnly}) arg;
  late EntityRepository _repo;
  static const int _pageSize = 20;

  @override
  Future<LogListState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final p = await _repo.listActivations(arg.triggerId, firedOnly: arg.firedOnly, limit: _pageSize);
    return LogListState(
        rows: p.items.map(_row).toList(), nextCursor: p.nextCursor, hasMore: p.hasMore);
  }

  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(LogListState s) =>
      (hasMore: s.hasMore, loadingMore: s.loadingMore, nextCursor: s.nextCursor);
  @override
  Future<({List<LogRow> rows, String? next, bool more})> fetchNextPage(String cursor) async {
    final p = await _repo.listActivations(arg.triggerId,
        firedOnly: arg.firedOnly, cursor: cursor, limit: _pageSize);
    return (rows: p.items.map(_row).toList(), next: p.nextCursor, more: p.hasMore);
  }

  @override
  LogListState stateWithLoadingMore(LogListState s, bool loading) => s.copyWith(loadingMore: loading);
  @override
  LogListState stateWithAppended(LogListState s, List<LogRow> rows, String? next, bool more) =>
      s.copyWith(rows: [...s.rows, ...rows], nextCursor: next, hasMore: more, loadingMore: false);

  void toggle(String id) {
    final cur = state.value;
    if (cur == null) return;
    final next = {...cur.openIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = AsyncData(cur.copyWith(openIds: next));
  }

  LogRow _row(Activation a) {
    final tt = t.entities.detail;
    return LogRow(
      // Fired → an ok dot; a non-fired probe (sensor condition false) → idle. 触发=绿点,未触发探测=灰。
      dot: a.fired ? AnStatus.done : AnStatus.idle,
      id: a.id,
      label: '${a.kind.name} · ${a.fired ? tt.trigger.fired : tt.trigger.notFired}',
      meta: a.fired ? tt.trigger.fanout(n: a.firingCount) : null,
      hint: fmtTime(a.createdAt),
      detailRows: [
        (tt.kv.id, a.id),
        (tt.trigger.fired, a.fired ? tt.val.yes : tt.val.no),
        if (a.detail.isNotEmpty) (tt.trigger.detail, a.detail),
        if (a.error.isNotEmpty) (tt.kv.error, a.error),
        if (a.returnValue.isNotEmpty) (tt.trigger.returnValue, prettyJson(a.returnValue)),
        if (a.payload.isNotEmpty) (tt.trigger.payload, prettyJson(a.payload)),
        (tt.trigger.fanoutLabel, '${a.firingCount}'),
        (tt.kv.time, fmtTime(a.createdAt)),
      ],
    );
  }
}

/// Firing list — one row per fired→listener dispatch; `status` narrows to a disposition.
class FiringListNotifier extends AsyncNotifier<LogListState>
    with KeysetScopedPaging<LogListState, LogRow> {
  FiringListNotifier(this.arg);

  final ({String triggerId, String? status}) arg;
  late EntityRepository _repo;
  static const int _pageSize = 20;

  @override
  Future<LogListState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final p = await _repo.listFirings(arg.triggerId, status: arg.status, limit: _pageSize);
    return LogListState(
        rows: p.items.map(_row).toList(), nextCursor: p.nextCursor, hasMore: p.hasMore);
  }

  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(LogListState s) =>
      (hasMore: s.hasMore, loadingMore: s.loadingMore, nextCursor: s.nextCursor);
  @override
  Future<({List<LogRow> rows, String? next, bool more})> fetchNextPage(String cursor) async {
    final p = await _repo.listFirings(arg.triggerId, status: arg.status, cursor: cursor, limit: _pageSize);
    return (rows: p.items.map(_row).toList(), next: p.nextCursor, more: p.hasMore);
  }

  @override
  LogListState stateWithLoadingMore(LogListState s, bool loading) => s.copyWith(loadingMore: loading);
  @override
  LogListState stateWithAppended(LogListState s, List<LogRow> rows, String? next, bool more) =>
      s.copyWith(rows: [...s.rows, ...rows], nextCursor: next, hasMore: more, loadingMore: false);

  void toggle(String id) {
    final cur = state.value;
    if (cur == null) return;
    final next = {...cur.openIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = AsyncData(cur.copyWith(openIds: next));
  }

  LogRow _row(Firing f) {
    final tt = t.entities.detail;
    return LogRow(
      dot: firingDot(f.status),
      id: f.id,
      label: '${f.status.name} · ${f.workflowId}',
      meta: f.flowrunId.isNotEmpty ? f.flowrunId : null,
      hint: fmtTime(f.createdAt),
      detailRows: [
        (tt.kv.id, f.id),
        (tt.kv.status, f.status.name),
        (tt.kv.workflow, f.workflowId),
        (tt.trigger.activation, f.activationId),
        (tt.kv.flowrunId, f.flowrunId.isEmpty ? '—' : f.flowrunId),
        if (f.payload.isNotEmpty) (tt.trigger.payload, prettyJson(f.payload)),
        (tt.kv.time, fmtTime(f.createdAt)),
      ],
    );
  }
}

/// A firing status → status-dot mapping (the 6 sealed dispositions aren't in [AnStatus.fromRaw]'s alias
/// table, so map them explicitly): started = ran (ok); pending/claimed = in-flight (wait); the drops
/// (skipped/superseded/shed) = idle. firing 状态→点:started 绿、在途黄、被丢灰。
AnStatus firingDot(FiringStatus s) => switch (s) {
      FiringStatus.started => AnStatus.done,
      FiringStatus.pending || FiringStatus.claimed => AnStatus.wait,
      FiringStatus.skipped || FiringStatus.superseded || FiringStatus.shed => AnStatus.idle,
      FiringStatus.unknown => AnStatus.idle,
    };

final activationListProvider = AsyncNotifierProvider.autoDispose
    .family<ActivationListNotifier, LogListState, ({String triggerId, bool firedOnly})>(
  ActivationListNotifier.new,
  retry: (_, _) => null,
);

final firingListProvider = AsyncNotifierProvider.autoDispose
    .family<FiringListNotifier, LogListState, ({String triggerId, String? status})>(
  FiringListNotifier.new,
  retry: (_, _) => null,
);
