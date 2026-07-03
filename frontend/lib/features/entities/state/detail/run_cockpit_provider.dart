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
    final page = await _repo.listFlowruns(workflowId: entityRef.id, limit: _pageSize);
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

  Future<FlowrunComposite> _fetchFull(String id) => fetchFlowrunFull(_repo.getFlowrun, id);

  // ── paging (run list) ──
  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(RunCockpitState s) =>
      (hasMore: s.hasMore, loadingMore: s.loadingMore, nextCursor: s.nextCursor);

  @override
  Future<({List<dynamic> rows, String? next, bool more})> fetchNextPage(String cursor) async {
    final page = await _repo.listFlowruns(workflowId: entityRef.id, cursor: cursor, limit: _pageSize);
    return (rows: page.items, next: page.nextCursor, more: page.hasMore);
  }

  @override
  RunCockpitState stateWithLoadingMore(RunCockpitState s, bool loading) =>
      s.copyWith(loadingMore: loading);

  @override
  RunCockpitState stateWithAppended(RunCockpitState s, List<dynamic> rows, String? next, bool more) =>
      s.copyWith(runs: [...s.runs, ...rows.cast()], nextCursor: next, hasMore: more, loadingMore: false);

  /// Select a run → fetch its full node composite; clears the node selection. 选 run → 拉全节点。
  Future<void> selectRun(String id) async {
    final cur = state.value;
    if (cur == null || cur.selectedRunId == id) return;
    state = AsyncData(cur.copyWith(selectedRunId: id, selectedNodeId: null, loadingRun: true));
    try {
      final comp = await _fetchFull(id);
      final now = state.value;
      if (now == null || now.selectedRunId != id) return; // superseded 选区已变
      state = AsyncData(now.copyWith(selected: comp, loadingRun: false));
    } catch (_) {
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(loadingRun: false));
    }
  }

  void selectNode(String? id) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(selectedNodeId: cur.selectedNodeId == id ? null : id));
  }

  /// Re-read the selected run from truth (after a mutation). 从真相重取选中 run。
  Future<void> _refreshSelected() async {
    final cur = state.value;
    final id = cur?.selectedRunId;
    if (cur == null || id == null) return;
    try {
      final comp = await _fetchFull(id);
      final now = state.value;
      if (now == null || now.selectedRunId != id) return;
      // Reconcile the run's header row in the list too (status may have changed). 列表头行同步。
      state = AsyncData(now.copyWith(
        selected: comp,
        runs: [for (final r in now.runs) r.id == id ? comp.flowrun : r],
        busy: false,
      ));
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
    } catch (_) {/* fall through to reconcile — truth wins */}
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
    } catch (_) {/* first-wins loss / transient → reconcile 输了/瞬态→对账 */}
    await _refreshSelected();
  }

  /// `:kill` the workflow (hard-stop all in-flight runs), then re-read the list + selection. 终止。
  Future<void> kill() async {
    final cur = state.value;
    if (cur == null || cur.busy) return;
    state = AsyncData(cur.copyWith(busy: true));
    try {
      await _repo.killWorkflow(entityRef.id);
      ref.invalidate(entityDetailProvider(entityRef)); // header lifecycle badge reconciles
    } catch (_) {/* reconcile below */}
    final page = await _safeList();
    final now = state.value;
    if (now == null) return;
    state = AsyncData(now.copyWith(
      runs: page ?? now.runs,
      busy: false,
    ));
    await _refreshSelected();
  }

  Future<List<Flowrun>?> _safeList() async {
    try {
      final p = await _repo.listFlowruns(workflowId: entityRef.id, limit: _pageSize);
      return p.items;
    } catch (_) {
      return null;
    }
  }
}

/// autoDispose: a sub-resource of the workflow detail (only while viewing the 运行 tab). 详情子资源。
final runCockpitProvider =
    AsyncNotifierProvider.autoDispose.family<RunCockpitNotifier, RunCockpitState, EntityRef>(
  RunCockpitNotifier.new,
  retry: (_, _) => null,
);
