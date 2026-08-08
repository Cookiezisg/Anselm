import 'dart:async';

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
    final p = await _repo.listActivations(
      arg.triggerId,
      firedOnly: arg.firedOnly,
      limit: _pageSize,
    );
    return LogListState(
      rows: p.items.map(_row).toList(),
      nextCursor: p.nextCursor,
      hasMore: p.hasMore,
    );
  }

  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(
    LogListState s,
  ) => (
    hasMore: s.hasMore,
    loadingMore: s.loadingMore,
    nextCursor: s.nextCursor,
  );
  @override
  Future<({List<LogRow> rows, String? next, bool more})> fetchNextPage(
    String cursor,
  ) async {
    final p = await _repo.listActivations(
      arg.triggerId,
      firedOnly: arg.firedOnly,
      cursor: cursor,
      limit: _pageSize,
    );
    return (
      rows: p.items.map(_row).toList(),
      next: p.nextCursor,
      more: p.hasMore,
    );
  }

  @override
  LogListState stateWithLoadingMore(LogListState s, bool loading) =>
      s.copyWith(loadingMore: loading);
  @override
  LogListState stateWithAppended(
    LogListState s,
    List<LogRow> rows,
    String? next,
    bool more,
  ) => s.copyWith(
    rows: [...s.rows, ...rows],
    nextCursor: next,
    hasMore: more,
    loadingMore: false,
  );

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
      label:
          '${a.kind.name} · ${a.fired ? tt.trigger.fired : tt.trigger.notFired}',
      meta: a.fired ? tt.trigger.fanout(n: a.firingCount) : null,
      hint: fmtTime(a.createdAt),
      detailRows: [
        (tt.kv.id, a.id),
        (tt.trigger.fired, a.fired ? tt.val.yes : tt.val.no),
        if (a.detail.isNotEmpty) (tt.trigger.detail, a.detail),
        if (a.error.isNotEmpty) (tt.kv.error, a.error),
        if (a.returnValue.isNotEmpty)
          (tt.trigger.returnValue, prettyJson(a.returnValue)),
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
  Timer? _pendingPoll;

  @override
  Future<LogListState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    ref.onDispose(() => _pendingPoll?.cancel());
    final p = await _repo.listFirings(
      arg.triggerId,
      status: arg.status,
      limit: _pageSize,
    );
    _armPendingPoll(p.items);
    return LogListState(
      rows: p.items.map(_row).toList(),
      nextCursor: p.nextCursor,
      hasMore: p.hasMore,
    );
  }

  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(
    LogListState s,
  ) => (
    hasMore: s.hasMore,
    loadingMore: s.loadingMore,
    nextCursor: s.nextCursor,
  );
  @override
  Future<({List<LogRow> rows, String? next, bool more})> fetchNextPage(
    String cursor,
  ) async {
    final p = await _repo.listFirings(
      arg.triggerId,
      status: arg.status,
      cursor: cursor,
      limit: _pageSize,
    );
    return (
      rows: p.items.map(_row).toList(),
      next: p.nextCursor,
      more: p.hasMore,
    );
  }

  @override
  LogListState stateWithLoadingMore(LogListState s, bool loading) =>
      s.copyWith(loadingMore: loading);
  @override
  LogListState stateWithAppended(
    LogListState s,
    List<LogRow> rows,
    String? next,
    bool more,
  ) => s.copyWith(
    rows: [...s.rows, ...rows],
    nextCursor: next,
    hasMore: more,
    loadingMore: false,
  );

  /// A firing is written pending before the scheduler claims it, so the first REST read after `:fire`
  /// can legitimately precede the final disposition. Reconcile only while the current page contains
  /// pending rows; once every row is terminal, the timer is gone. This is a bounded durable-row poll,
  /// not a second history source, and covers scheduler paths that settle rows without a trigger-scoped
  /// frame (skip/shed/buffer policies as well as the normal claim).
  ///
  /// `:fire` 后首次 REST 读取可能先于 scheduler claim，故先看到 pending 是合法中间态。仅当当前页仍有
  /// pending 行时短轮询；所有行落到终态后立即停表。它是有界的 durable 行对账，不是第二份历史来源，
  /// 同时覆盖没有 trigger scope 帧的 skip/shed/buffer 策略与普通 claim。
  void _armPendingPoll(List<Firing> firings) {
    _pendingPoll?.cancel();
    _pendingPoll = null;
    if (!ref.mounted || !firings.any((f) => f.status == FiringStatus.pending)) {
      return;
    }
    _schedulePendingPoll();
  }

  void _schedulePendingPoll() {
    if (!ref.mounted) return;
    _pendingPoll?.cancel();
    _pendingPoll = Timer(const Duration(milliseconds: 500), () {
      _pendingPoll = null;
      unawaited(_reconcilePending());
    });
  }

  Future<void> _reconcilePending() async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    try {
      final p = await _repo.listFirings(
        arg.triggerId,
        status: arg.status,
        limit: _pageSize,
      );
      if (!ref.mounted) return;
      final latest = state.value;
      if (latest == null) return;

      final fresh = {for (final firing in p.items) firing.id: _row(firing)};
      final rows = arg.status == FiringStatus.pending.name
          ? [
              for (final row in latest.rows)
                if (fresh.containsKey(row.id)) fresh[row.id]!,
            ]
          : [
              for (final row in latest.rows) fresh[row.id] ?? row,
              for (final row in p.items.map(_row))
                if (!latest.rows.any((existing) => existing.id == row.id)) row,
            ];
      state = AsyncData(latest.copyWith(rows: rows));
      _armPendingPoll(p.items);
    } catch (_) {
      // Keep the last-known-good rows and retry while a pending disposition remains visible.
      // 短暂重取失败保留最近可信行，只要仍可能有 pending 就继续对账。
      if (current.rows.any(
        (row) => row.label.startsWith('${FiringStatus.pending.name} ·'),
      )) {
        _schedulePendingPoll();
      }
    }
  }

  void toggle(String id) {
    final cur = state.value;
    if (cur == null) return;
    final next = {...cur.openIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = AsyncData(cur.copyWith(openIds: next));
  }

  LogRow _row(Firing f) {
    final tt = t.entities.detail;
    final workflowName = f.workflowName.trim();
    final workflowLabel = workflowName.isEmpty ? f.workflowId : workflowName;
    return LogRow(
      dot: firingDot(f.status),
      id: f.id,
      label: '${firingStatusWord(t, f.status)} · $workflowLabel',
      meta: f.flowrunId.isNotEmpty ? f.flowrunId : null,
      hint: fmtTime(f.createdAt),
      detailRows: [
        (tt.kv.id, f.id),
        (tt.kv.status, firingStatusWord(t, f.status)),
        (tt.kv.workflow, workflowLabel),
        if (workflowName.isNotEmpty) (tt.kv.workflowId, f.workflowId),
        (tt.trigger.activation, f.activationId),
        (tt.kv.flowrunId, f.flowrunId.isEmpty ? '—' : f.flowrunId),
        if (f.payload.isNotEmpty) (tt.trigger.payload, prettyJson(f.payload)),
        (tt.kv.time, fmtTime(f.createdAt)),
      ],
    );
  }
}

/// A user-facing word for every known firing disposition. The wire enum remains the filter value;
/// the detail surface must not leak it when a localized domain word already exists. 每个派发处置的
/// 用户词;筛选仍发送线缆枚举,详情不把已有的本地化域词漏成裸 status。
String firingStatusWord(Translations t, FiringStatus status) =>
    switch (status) {
      FiringStatus.pending => t.chat.tool.firingPending,
      FiringStatus.claimed => t.chat.tool.firingClaimed,
      FiringStatus.started => t.chat.tool.firingStarted,
      FiringStatus.skipped => t.chat.tool.firingSkipped,
      FiringStatus.superseded => t.chat.tool.firingSuperseded,
      FiringStatus.shed => t.chat.tool.firingShed,
      FiringStatus.missed => t.chat.tool.firingMissed,
      FiringStatus.unknown => status.name,
    };

/// A firing status → status-dot fold — [AnStatus.fromRaw] carries started/claimed now (批7 B-037), so
/// the explicit parallel switch retired value-identical: started = ran (done); pending/claimed =
/// in-flight (wait); the drops (skipped/superseded/shed) and unknown fold to idle.
/// firing 状态→点:并入 fromRaw(别名齐后逐值恒等;被丢/未知折 idle)。
AnStatus firingDot(FiringStatus s) => AnStatus.fromRaw(s.name);

final activationListProvider = AsyncNotifierProvider.autoDispose
    .family<
      ActivationListNotifier,
      LogListState,
      ({String triggerId, bool firedOnly})
    >(ActivationListNotifier.new, retry: (_, _) => null);

final firingListProvider = AsyncNotifierProvider.autoDispose
    .family<
      FiringListNotifier,
      LogListState,
      ({String triggerId, String? status})
    >(FiringListNotifier.new, retry: (_, _) => null);
