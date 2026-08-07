import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/state/keyset_paging.dart';
import '../../../../core/contract/entities/agent.dart';
import '../../../../core/contract/entities/common.dart';
import '../../../../core/contract/entities/function.dart';
import '../../../../core/contract/entities/handler.dart';
import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/messages/transcript_hydration.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/sse/frame.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../run/recent_runs_provider.dart';
import '../selected_entity.dart';
import 'log_list_state.dart';

/// The logs tab (family over [EntityRef]) — the 日志 history: function executions / handler calls /
/// agent executions / workflow flowruns. Pages with load-more (keeps rows on error), carries the
/// ok/failed aggregate (function/handler/agent only), expands rows in place, and — for workflow only —
/// lazily fetches the [FlowrunComposite] (node list) on first expand. Detail-row labels use slang's
/// global `t` (no BuildContext in state). Auto-retry off. 日志 tab(按 EntityRef family)。
class LogListNotifier extends AsyncNotifier<LogListState>
    with KeysetScopedPaging<LogListState, LogRow> {
  LogListNotifier(this.entityRef);

  final EntityRef entityRef;
  late EntityRepository _repo;
  static const int _pageSize = 20;
  StreamSubscription<StreamEnvelope>? _panelSub;
  Timer? _refreshDebounce;
  int _refreshGeneration = 0;

  @override
  Future<LogListState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    if (entityRef.kind.executable) {
      _panelSub = _repo
          .panelSignals(entityRef.kind.scope(entityRef.id))
          .listen(_onPanel);
      ref.onDispose(() {
        _refreshDebounce?.cancel();
        unawaited(_panelSub?.cancel());
      });
    }
    final page = await _fetch(null);
    return LogListState(
      rows: page.rows,
      aggregates: page.agg ?? const ExecutionAggregates(),
      hasAggregate: page.agg != null,
      nextCursor: page.next,
      hasMore: page.more,
    );
  }

  // KeysetScopedPaging hooks. The aggregate is a build-only header (unchanged by loadMore), so the paging
  // fetch drops it. 分页钩子:聚合是仅 build 的表头、loadMore 不变,故分页 fetch 丢弃它。
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
    final page = await _fetch(cursor);
    return (rows: page.rows, next: page.next, more: page.more);
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

  /// Toggle a row's expansion; workflow flowruns and function executions fetch their expensive detail
  /// only on first open. 展开/收起一行;workflow flowrun 与 function execution 的重详情首次展开才懒取。
  Future<void> toggle(String id) async {
    final cur = state.value;
    if (cur == null) return;
    final opening = !cur.openIds.contains(id);
    final nextOpen = {...cur.openIds};
    opening ? nextOpen.add(id) : nextOpen.remove(id);
    state = AsyncData(cur.copyWith(openIds: nextOpen));

    if (opening &&
        entityRef.kind == EntityKind.workflow &&
        !cur.flowruns.containsKey(id)) {
      try {
        final comp = await _repo.getFlowrun(id);
        if (!ref.mounted) {
          return; // autoDispose: left the entity mid-fetch 已离开实体则不写
        }
        final now = state.value ?? cur;
        state = AsyncData(now.copyWith(flowruns: {...now.flowruns, id: comp}));
      } catch (_) {
        // leave the row expanded with summary rows only — the node list just won't appear
      }
    }

    if (opening && entityRef.kind == EntityKind.function) {
      final row = (state.value ?? cur).rows
          .where((r) => r.id == id)
          .firstOrNull;
      if (row != null && !row.detailsLoaded && !row.detailsLoading) {
        await _loadFunctionDetails(id);
      }
    }

    if (opening && entityRef.kind == EntityKind.handler) {
      final row = (state.value ?? cur).rows
          .where((r) => r.id == id)
          .firstOrNull;
      if (row != null && !row.detailsLoaded && !row.detailsLoading) {
        await _loadHandlerDetails(id);
      }
    }

    if (opening && entityRef.kind == EntityKind.agent) {
      final row = (state.value ?? cur).rows
          .where((r) => r.id == id)
          .firstOrNull;
      if (row != null && !row.detailsLoaded && !row.detailsLoading) {
        await _loadAgentDetails(id);
      }
    }
  }

  /// Retry a failed single-record fetch without collapsing the row. 保持行展开,只重试单条详情。
  Future<void> retryDetails(String id) async {
    if (entityRef.kind != EntityKind.function &&
        entityRef.kind != EntityKind.handler &&
        entityRef.kind != EntityKind.agent) {
      return;
    }
    final row = state.value?.rows.where((r) => r.id == id).firstOrNull;
    if (row == null || row.detailsLoading) return;
    if (entityRef.kind == EntityKind.function) {
      await _loadFunctionDetails(id);
    } else if (entityRef.kind == EntityKind.handler) {
      await _loadHandlerDetails(id);
    } else {
      await _loadAgentDetails(id);
    }
  }

  /// A durable panel close means that an execution may have landed, but the frame is not the history
  /// itself. Re-read the ledger and keep the current expanded rows so the archive catches up without a
  /// loading flash or a collapsed detail the user is inspecting. durable close 只是一张重取提示,日志历史
  /// 仍以 REST 台账为真相;重取不闪屏且不折叠用户正在看的行。
  void _onPanel(StreamEnvelope env) {
    if (!env.durable || env.frame is! FrameClose) return;
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 120), () {
      if (ref.mounted) unawaited(_refreshFromLedger());
    });
  }

  Future<void> _refreshFromLedger() async {
    final cur = state.value;
    if (cur == null) return;
    final generation = ++_refreshGeneration;
    // Re-fetch the whole visible window so load-more rows do not disappear when a newer execution
    // arrives. The server clamps this to its normal 200-row maximum. 重取当前可见窗口,避免新执行到来
    // 时用户已经翻出的行凭空消失;服务端会把它钳在正常 200 行上限内。
    final limit = cur.rows.length > _pageSize ? cur.rows.length : _pageSize;
    try {
      final page = await _fetch(null, limit: limit);
      if (!ref.mounted || generation != _refreshGeneration) return;
      final latest = state.value;
      if (latest == null) return;
      if (latest.loadingMore) {
        // Keyset load-more owns its cursor until it settles. Retry after it has appended instead of
        // replacing the state underneath it. 分页加载持有游标期间不覆盖状态,等它追加完再重取。
        _scheduleRefresh();
        return;
      }
      final previous = {
        for (final row in latest.rows)
          if (row.detailsLoaded) row.id: row,
      };
      final refreshedRows = [
        for (final row in page.rows) previous[row.id] ?? row,
      ];
      final ids = refreshedRows.map((row) => row.id).toSet();
      state = AsyncData(
        latest.copyWith(
          rows: refreshedRows,
          aggregates: page.agg ?? latest.aggregates,
          hasAggregate: page.agg != null || latest.hasAggregate,
          nextCursor: page.next,
          hasMore: page.more,
          openIds: latest.openIds.intersection(ids),
        ),
      );
    } catch (_) {
      // A transient refresh failure must not replace the last-known-good archive. The tab's explicit
      // retry remains the visible recovery path. 短暂重取失败不覆盖最近可信快照,由页面重试恢复。
    }
  }

  Future<void> _loadFunctionDetails(String id) async {
    _updateRow(
      id,
      (row) => row.copyWith(detailsLoading: true, detailsError: null),
    );
    try {
      final execution = await _repo.getFunctionExecution(id);
      if (!ref.mounted) return;
      _replaceRow(id, _functionRow(execution, detailsLoaded: true));
    } catch (error) {
      if (!ref.mounted) return;
      final message = error is ApiException ? error.message : '$error';
      _updateRow(
        id,
        (row) => row.copyWith(detailsLoading: false, detailsError: message),
      );
    }
  }

  Future<void> _loadHandlerDetails(String id) async {
    _updateRow(
      id,
      (row) => row.copyWith(detailsLoading: true, detailsError: null),
    );
    try {
      final call = await _repo.getHandlerCall(id);
      if (!ref.mounted) return;
      _replaceRow(id, _handlerRow(call, detailsLoaded: true));
    } catch (error) {
      if (!ref.mounted) return;
      final message = error is ApiException ? error.message : '$error';
      _updateRow(
        id,
        (row) => row.copyWith(detailsLoading: false, detailsError: message),
      );
    }
  }

  Future<void> _loadAgentDetails(String id) async {
    _updateRow(
      id,
      (row) => row.copyWith(detailsLoading: true, detailsError: null),
    );
    try {
      final execution = await _repo.getAgentExecution(id);
      if (!ref.mounted) return;
      _replaceRow(id, _agentRow(execution, detailsLoaded: true));
    } catch (error) {
      if (!ref.mounted) return;
      final message = error is ApiException ? error.message : '$error';
      _updateRow(
        id,
        (row) => row.copyWith(detailsLoading: false, detailsError: message),
      );
    }
  }

  void _updateRow(String id, LogRow Function(LogRow) update) {
    final cur = state.value;
    if (cur == null) return;
    final i = cur.rows.indexWhere((row) => row.id == id);
    if (i < 0) return;
    final rows = [...cur.rows]..[i] = update(cur.rows[i]);
    state = AsyncData(cur.copyWith(rows: rows));
  }

  void _replaceRow(String id, LogRow replacement) =>
      _updateRow(id, (_) => replacement);

  Future<
    ({List<LogRow> rows, ExecutionAggregates? agg, String? next, bool more})
  >
  _fetch(String? cursor, {int? limit}) async {
    final pageLimit = limit ?? _pageSize;
    switch (entityRef.kind) {
      // Support kinds have no generic 日志 tab — control/approval have no execution; trigger's history is
      // its OWN observability tabs (活动/派发), not this one. 支撑 kind 无通用日志(trigger 走自己的观测面)。
      case EntityKind.control:
      case EntityKind.approval:
      case EntityKind.trigger:
        return (rows: const <LogRow>[], agg: null, next: null, more: false);
      case EntityKind.function:
        final p = await _repo.listFunctionExecutions(
          entityRef.id,
          cursor: cursor,
          limit: pageLimit,
        );
        return (
          rows: p.items.map(_functionRow).toList(),
          agg: p.aggregate,
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.handler:
        final p = await _repo.listHandlerCalls(
          entityRef.id,
          cursor: cursor,
          limit: pageLimit,
        );
        return (
          rows: p.items.map(_handlerRow).toList(),
          agg: p.aggregate,
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.agent:
        final p = await _repo.listAgentExecutions(
          entityRef.id,
          cursor: cursor,
          limit: pageLimit,
        );
        return (
          rows: p.items.map(_agentRow).toList(),
          agg: p.aggregate,
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.workflow:
        final p = await _repo.listFlowruns(
          workflowId: entityRef.id,
          cursor: cursor,
          limit: pageLimit,
        );
        return (
          rows: p.items.map(_flowrunRow).toList(),
          agg: null,
          next: p.nextCursor,
          more: p.hasMore,
        );
    }
    // unreachable — the switch is exhaustive over EntityKind
  }

  LogRow _functionRow(FunctionExecution e, {bool detailsLoaded = false}) {
    final kv = t.entities.detail.kv;
    return LogRow(
      id: e.id,
      dot: AnStatus.fromRaw(e.status),
      label: '${e.triggeredBy} · ${e.status}',
      meta: '${e.elapsedMs}ms',
      hint: fmtTime(e.startedAt ?? e.createdAt),
      run: RecentRun(
        id: e.id,
        status: e.status,
        startedAt: e.startedAt,
        elapsedMs: e.elapsedMs,
        triggeredBy: e.triggeredBy,
        input: e.input,
        output: e.output,
      ),
      detailRows: [
        (kv.id, e.id),
        (kv.triggeredBy, e.triggeredBy),
        (kv.version, e.versionId),
        (kv.input, prettyJson(e.input)),
        (kv.output, prettyJson(e.output)),
        (kv.error, e.errorMessage ?? '—'),
        if (detailsLoaded) (kv.logs, e.logs ?? '—'),
        (kv.elapsed, '${e.elapsedMs}ms'),
        (kv.time, fmtTime(e.createdAt)),
      ],
      detailsLoaded: detailsLoaded,
    );
  }

  LogRow _handlerRow(HandlerCall c, {bool detailsLoaded = false}) {
    final kv = t.entities.detail.kv;
    return LogRow(
      id: c.id,
      dot: AnStatus.fromRaw(c.status),
      label: '${c.method} · ${c.status}',
      meta: '${c.elapsedMs}ms',
      hint: fmtTime(c.startedAt ?? c.createdAt),
      run: RecentRun(
        id: c.id,
        status: c.status,
        startedAt: c.startedAt,
        elapsedMs: c.elapsedMs,
        triggeredBy: c.triggeredBy,
        input: c.input,
        output: c.output,
        method: c.method,
      ),
      detailRows: [
        (kv.id, c.id),
        (kv.method, c.method),
        (kv.instanceId, c.instanceId ?? '—'),
        (kv.input, prettyJson(c.input)),
        (kv.output, prettyJson(c.output)),
        (kv.error, c.errorMessage ?? '—'),
        if (detailsLoaded) (kv.logs, c.logs ?? '—'),
        (kv.elapsed, '${c.elapsedMs}ms'),
        (kv.time, fmtTime(c.createdAt)),
      ],
      detailsLoaded: detailsLoaded,
    );
  }

  LogRow _agentRow(AgentExecution e, {bool detailsLoaded = false}) {
    final kv = t.entities.detail.kv;
    final transcript = e.transcript is List
        ? List<dynamic>.from(e.transcript as List)
        : const <dynamic>[];
    final roots = detailsLoaded
        ? hydrateTranscriptTree(
            transcript,
            scopeId: e.conversationId?.isNotEmpty == true
                ? e.conversationId!
                : e.id,
          )
        : const <BlockNode>[];
    return LogRow(
      id: e.id,
      dot: AnStatus.fromRaw(e.status),
      label: '${e.triggeredBy} · ${e.status}',
      meta: '${e.status} · ${e.elapsedMs}ms',
      hint: fmtTime(e.startedAt ?? e.createdAt),
      run: RecentRun(
        id: e.id,
        status: e.status,
        startedAt: e.startedAt,
        elapsedMs: e.elapsedMs,
        triggeredBy: e.triggeredBy,
        input: e.input,
        output: e.output,
      ),
      detailRows: [
        (kv.id, e.id),
        (kv.triggeredBy, e.triggeredBy),
        (kv.provider, e.provider ?? '—'),
        (kv.model, e.modelId ?? '—'),
        (kv.input, prettyJson(e.input)),
        (kv.output, prettyJson(e.output)),
        (kv.error, e.errorMessage ?? '—'),
        if (detailsLoaded) (kv.version, e.versionId),
        if (detailsLoaded) (kv.elapsed, '${e.elapsedMs}ms'),
        if (detailsLoaded) (kv.startedAt, fmtTime(e.startedAt)),
        if (detailsLoaded) (kv.completedAt, fmtTime(e.endedAt)),
        (kv.time, fmtTime(e.createdAt)),
      ],
      detailsLoaded: detailsLoaded,
      transcriptRoots: roots,
      transcriptBlockCount: detailsLoaded ? transcript.length : 0,
    );
  }

  LogRow _flowrunRow(Flowrun f) {
    final kv = t.entities.detail.kv;
    return LogRow(
      id: f.id,
      dot: AnStatus.fromRaw(f.status),
      label: f.id,
      meta: f.status,
      hint: fmtTime(f.startedAt ?? f.updatedAt),
      // Flowrun DTO projects no payload — reproduce restores the SOURCE only (与「最近」条同一打折点).
      run: RecentRun(
        id: f.id,
        status: f.status,
        startedAt: f.startedAt,
        triggeredBy: f.origin ?? '',
        triggerId: f.triggerId,
      ),
      detailRows: [
        (kv.flowrunId, f.id),
        (kv.workflow, f.workflowId),
        (kv.version, f.versionId),
        (kv.trigger, f.triggerId ?? '—'),
        (kv.status, f.status),
        (kv.replay, '${f.replayCount}'),
        (kv.error, f.error ?? '—'),
        (kv.startedAt, fmtTime(f.startedAt)),
        (kv.completedAt, fmtTime(f.completedAt)),
      ],
    );
  }
}

/// autoDispose: a sub-resource of the detail (only relevant while viewing the entity) — released on leave.
/// autoDispose:详情的子资源(仅查看时相关),离开即释放。
final logListProvider = AsyncNotifierProvider.autoDispose
    .family<LogListNotifier, LogListState, EntityRef>(
      LogListNotifier.new,
      retry: (_, _) => null,
    );
