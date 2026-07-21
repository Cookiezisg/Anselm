import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/state/keyset_paging.dart';
import '../../data/entity_format.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../selected_entity.dart';
import 'entity_detail_provider.dart';
import 'run_cockpit_state.dart';

/// The workflow 运行 tab cockpit (family over the workflow [EntityRef]). Pages the flowrun history,
/// keeps ONE run selected (its full node composite paged through — the same newest-first / one-page-≠
/// -whole-run trap W3 hit), keeps ONE node selected (inline debug), and drives the observability
/// actions: `:replay` a failed run, `:kill` the workflow, `:decide` a parked approval — each
/// re-reads truth (the backend walk is the source, never optimistic). Same paging discipline as the
/// other detail lists (hold on error, re-read after await, auto-retry off).
///
/// workflow 运行 tab 驾驶舱(按 workflow [EntityRef] family)。分页 flowrun 历史,选中一个 run(其完整
/// 节点 composite 翻页拉全——同 W3 踩的最新在前/一页非全量坑),选中一个节点(内联调试),并驱动观测
/// 动作:`:replay` 失败 run / `:kill` workflow / `:decide` parked 审批——每个都重取真相(后端 walk 为源,
/// 不乐观)。分页纪律同其它详情列表。
class RunCockpitNotifier extends AsyncNotifier<RunCockpitState>
    with KeysetScopedPaging<RunCockpitState, dynamic> {
  RunCockpitNotifier(this.entityRef);

  final EntityRef entityRef;
  late EntityRepository _repo;
  static const int _pageSize = 20;

  @override
  Future<RunCockpitState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final page = await _repo.listFlowruns(
      workflowId: entityRef.id,
      limit: _pageSize,
    );
    final firstId = page.items.isEmpty ? null : page.items.first.id;
    FlowrunComposite? selected;
    if (firstId != null) {
      selected = await _fetchFull(firstId);
    }
    return RunCockpitState(
      runs: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      selectedRunId: firstId,
      selected: selected,
    );
  }

  Future<FlowrunComposite> _fetchFull(String id) =>
      fetchFlowrunFull(_repo.getFlowrun, id);

  // ── paging (run list) ──
  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(
    RunCockpitState s,
  ) => (
    hasMore: s.hasMore,
    loadingMore: s.loadingMore,
    nextCursor: s.nextCursor,
  );

  @override
  Future<({List<dynamic> rows, String? next, bool more})> fetchNextPage(
    String cursor,
  ) async {
    final page = await _repo.listFlowruns(
      workflowId: entityRef.id,
      cursor: cursor,
      limit: _pageSize,
    );
    return (rows: page.items, next: page.nextCursor, more: page.hasMore);
  }

  @override
  RunCockpitState stateWithLoadingMore(RunCockpitState s, bool loading) =>
      s.copyWith(loadingMore: loading);

  @override
  RunCockpitState stateWithAppended(
    RunCockpitState s,
    List<dynamic> rows,
    String? next,
    bool more,
  ) => s.copyWith(
    runs: [...s.runs, ...rows.cast()],
    nextCursor: next,
    hasMore: more,
    loadingMore: false,
  );

  /// Select a run → fetch its full node composite; clears the node selection. Early-return only when
  /// THIS run's composite is already loaded (so a failed fetch can be retried by re-clicking); a new
  /// selection clears the stale composite so the panel never shows another run's nodes.
  /// 选 run → 拉全节点。仅当该 run composite 已加载才早退(失败可重点重试);换选区先清陈旧 composite,
  /// 面板不会显示别的 run 的节点。
  Future<void> selectRun(String id) async {
    final cur = state.value;
    if (cur == null) return;
    if (cur.selectedRunId == id &&
        cur.selected?.flowrun.id == id &&
        !cur.loadingRun) {
      return;
    }
    state = AsyncData(
      cur.copyWith(
        selectedRunId: id,
        selectedNodeId: null,
        selected: null,
        loadingRun: true,
      ),
    );
    try {
      final comp = await _fetchFull(id);
      final now = state.value;
      if (now == null || now.selectedRunId != id) return; // superseded 选区已变
      state = AsyncData(now.copyWith(selected: comp, loadingRun: false));
    } catch (_) {
      final now = state.value;
      if (now != null && now.selectedRunId == id) {
        state = AsyncData(
          now.copyWith(loadingRun: false),
        ); // stays retryable (selected is null) 可重试
      }
    }
  }

  void selectNode(String? id) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(
      cur.copyWith(selectedNodeId: cur.selectedNodeId == id ? null : id),
    );
  }

  /// Re-read the selected run from truth (after a mutation). ALWAYS clears [busy] — including the
  /// superseded/empty early-out (an action set busy=true; if the user switched runs mid-refresh, the
  /// guard must still release busy or the action buttons lock forever). 从真相重取选中 run。**任何**
  /// 出口都清 busy——含 superseded/空早退(动作置了 busy;refresh 中途换 run 若不释放,按钮永久锁死)。
  Future<void> _refreshSelected() async {
    final cur = state.value;
    final id = cur?.selectedRunId;
    if (cur == null || id == null) {
      if (cur != null && cur.busy) state = AsyncData(cur.copyWith(busy: false));
      return;
    }
    try {
      final comp = await _fetchFull(id);
      final now = state.value;
      if (now == null) return;
      if (now.selectedRunId != id) {
        if (now.busy) {
          state = AsyncData(
            now.copyWith(busy: false),
          ); // release, the new run owns display 释放
        }
        return;
      }
      // Reconcile the run's header row in the list too (status may have changed). 列表头行同步。
      state = AsyncData(
        now.copyWith(
          selected: comp,
          runs: [for (final r in now.runs) r.id == id ? comp.flowrun : r],
          busy: false,
        ),
      );
    } catch (_) {
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(busy: false));
    }
  }

  /// `:replay` the (failed) selected run, then re-read truth. 重跑选中失败 run。
  Future<void> replaySelected() async {
    final cur = state.value;
    final id = cur?.selectedRunId;
    if (cur == null || id == null || cur.busy) return;
    state = AsyncData(cur.copyWith(busy: true));
    try {
      await _repo.replayFlowrun(id);
    } catch (_) {
      /* fall through to reconcile — truth wins */
    }
    await _refreshSelected();
  }

  /// `:decide` a parked approval on the selected run, then re-read truth. 决断选中 run 的 parked 审批。
  Future<void> decide(String nodeId, String decision) async {
    final cur = state.value;
    final id = cur?.selectedRunId;
    if (cur == null || id == null || cur.busy) return;
    state = AsyncData(cur.copyWith(busy: true));
    try {
      await _repo.decideApproval(id, nodeId, decision: decision);
    } catch (_) {
      /* first-wins loss / transient → reconcile 输了/瞬态→对账 */
    }
    await _refreshSelected();
  }

  /// `:kill` the workflow (hard-stop all in-flight runs), then re-read the list + selection. 终止。
  Future<void> kill() async {
    final cur = state.value;
    if (cur == null || cur.busy) return;
    state = AsyncData(cur.copyWith(busy: true));
    try {
      await _repo.killWorkflow(entityRef.id);
      ref.invalidate(
        entityDetailProvider(entityRef),
      ); // header lifecycle badge reconciles
    } catch (_) {
      /* reconcile below */
    }
    final page = await _safeList();
    final now = state.value;
    if (now == null) return;
    // Re-init the list to the FRESH first page — reset the paging cursor too (replacing runs with
    // page-1 while keeping a stale nextCursor would drop the middle + skip on the next loadMore).
    // 用新首页重置列表 + 分页游标(只换 runs 而留旧 cursor 会丢中段 + 下次 loadMore 跳号)。
    state = AsyncData(
      page == null
          ? now.copyWith(busy: false)
          : now.copyWith(
              runs: page.items,
              nextCursor: page.nextCursor,
              hasMore: page.hasMore,
              busy: false,
            ),
    );
    await _refreshSelected();
  }

  Future<({List<Flowrun> items, String? nextCursor, bool hasMore})?>
  _safeList() async {
    try {
      final p = await _repo.listFlowruns(
        workflowId: entityRef.id,
        limit: _pageSize,
      );
      return (items: p.items, nextCursor: p.nextCursor, hasMore: p.hasMore);
    } catch (_) {
      return null;
    }
  }
}

/// autoDispose: a sub-resource of the workflow detail (only while viewing the 运行 tab). 详情子资源。
final runCockpitProvider = AsyncNotifierProvider.autoDispose
    .family<RunCockpitNotifier, RunCockpitState, EntityRef>(
      RunCockpitNotifier.new,
      retry: (_, _) => null,
    );
