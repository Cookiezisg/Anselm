import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/keyset_paging.dart';
import '../../../../core/contract/entities/agent.dart';
import '../../../../core/contract/entities/common.dart';
import '../../../../core/contract/entities/function.dart';
import '../../../../core/contract/entities/handler.dart';
import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/model/status_state.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
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

  @override
  Future<LogListState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
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
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(LogListState s) =>
      (hasMore: s.hasMore, loadingMore: s.loadingMore, nextCursor: s.nextCursor);

  @override
  Future<({List<LogRow> rows, String? next, bool more})> fetchNextPage(String cursor) async {
    final page = await _fetch(cursor);
    return (rows: page.rows, next: page.next, more: page.more);
  }

  @override
  LogListState stateWithLoadingMore(LogListState s, bool loading) => s.copyWith(loadingMore: loading);

  @override
  LogListState stateWithAppended(LogListState s, List<LogRow> rows, String? next, bool more) =>
      s.copyWith(rows: [...s.rows, ...rows], nextCursor: next, hasMore: more, loadingMore: false);

  /// Toggle a row's expansion; for a workflow flowrun, lazily fetch its node list on first open.
  /// 展开/收起一行;workflow flowrun 首次展开时懒取节点列表。
  Future<void> toggle(String id) async {
    final cur = state.value;
    if (cur == null) return;
    final opening = !cur.openIds.contains(id);
    final nextOpen = {...cur.openIds};
    opening ? nextOpen.add(id) : nextOpen.remove(id);
    state = AsyncData(cur.copyWith(openIds: nextOpen));

    if (opening && entityRef.kind == EntityKind.workflow && !cur.flowruns.containsKey(id)) {
      try {
        final comp = await _repo.getFlowrun(id);
        if (!ref.mounted) return; // autoDispose: left the entity mid-fetch 已离开实体则不写
        final now = state.value ?? cur;
        state = AsyncData(now.copyWith(flowruns: {...now.flowruns, id: comp}));
      } catch (_) {
        // leave the row expanded with summary rows only — the node list just won't appear
      }
    }
  }

  Future<({List<LogRow> rows, ExecutionAggregates? agg, String? next, bool more})> _fetch(
      String? cursor) async {
    switch (entityRef.kind) {
      // Support kinds have no generic 日志 tab — control/approval have no execution; trigger's history is
      // its OWN observability tabs (活动/派发), not this one. 支撑 kind 无通用日志(trigger 走自己的观测面)。
      case EntityKind.control:
      case EntityKind.approval:
      case EntityKind.trigger:
        return (rows: const <LogRow>[], agg: null, next: null, more: false);
      case EntityKind.function:
        final p =
            await _repo.listFunctionExecutions(entityRef.id, cursor: cursor, limit: _pageSize);
        return (rows: p.items.map(_functionRow).toList(), agg: p.aggregate, next: p.nextCursor, more: p.hasMore);
      case EntityKind.handler:
        final p = await _repo.listHandlerCalls(entityRef.id, cursor: cursor, limit: _pageSize);
        return (rows: p.items.map(_handlerRow).toList(), agg: p.aggregate, next: p.nextCursor, more: p.hasMore);
      case EntityKind.agent:
        final p = await _repo.listAgentExecutions(entityRef.id, cursor: cursor, limit: _pageSize);
        return (rows: p.items.map(_agentRow).toList(), agg: p.aggregate, next: p.nextCursor, more: p.hasMore);
      case EntityKind.workflow:
        final p =
            await _repo.listFlowruns(workflowId: entityRef.id, cursor: cursor, limit: _pageSize);
        return (rows: p.items.map(_flowrunRow).toList(), agg: null, next: p.nextCursor, more: p.hasMore);
    }
    // unreachable — the switch is exhaustive over EntityKind
  }

  LogRow _functionRow(FunctionExecution e) {
    final kv = t.entities.detail.kv;
    return LogRow(
      id: e.id,
      dot: AnStatus.fromRaw(e.status),
      label: '${e.triggeredBy} · ${e.status}',
      meta: '${e.elapsedMs}ms',
      hint: fmtTime(e.startedAt ?? e.createdAt),
      detailRows: [
        (kv.id, e.id),
        (kv.triggeredBy, e.triggeredBy),
        (kv.version, e.versionId),
        (kv.input, prettyJson(e.input)),
        (kv.output, prettyJson(e.output)),
        (kv.error, e.errorMessage ?? '—'),
        (kv.elapsed, '${e.elapsedMs}ms'),
        (kv.time, fmtTime(e.createdAt)),
      ],
    );
  }

  LogRow _handlerRow(HandlerCall c) {
    final kv = t.entities.detail.kv;
    return LogRow(
      id: c.id,
      dot: AnStatus.fromRaw(c.status),
      label: '${c.method} · ${c.status}',
      meta: '${c.elapsedMs}ms',
      hint: fmtTime(c.startedAt ?? c.createdAt),
      detailRows: [
        (kv.id, c.id),
        (kv.method, c.method),
        (kv.instanceId, c.instanceId ?? '—'),
        (kv.input, prettyJson(c.input)),
        (kv.output, prettyJson(c.output)),
        (kv.error, c.errorMessage ?? '—'),
        (kv.elapsed, '${c.elapsedMs}ms'),
        (kv.time, fmtTime(c.createdAt)),
      ],
    );
  }

  LogRow _agentRow(AgentExecution e) {
    final kv = t.entities.detail.kv;
    return LogRow(
      id: e.id,
      dot: AnStatus.fromRaw(e.status),
      label: '${e.triggeredBy} · ${e.status}',
      meta: '${e.status} · ${e.elapsedMs}ms',
      hint: fmtTime(e.startedAt ?? e.createdAt),
      detailRows: [
        (kv.id, e.id),
        (kv.triggeredBy, e.triggeredBy),
        (kv.provider, e.provider ?? '—'),
        (kv.model, e.modelId ?? '—'),
        (kv.input, prettyJson(e.input)),
        (kv.output, prettyJson(e.output)),
        (kv.error, e.errorMessage ?? '—'),
        (kv.time, fmtTime(e.createdAt)),
      ],
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
final logListProvider =
    AsyncNotifierProvider.autoDispose.family<LogListNotifier, LogListState, EntityRef>(
  LogListNotifier.new,
  retry: (_, _) => null,
);
