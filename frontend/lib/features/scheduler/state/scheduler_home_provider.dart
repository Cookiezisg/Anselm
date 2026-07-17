import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/scheduler_matrix.dart';
import '../../../core/contract/retention.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/model/time_range.dart';
import '../../../core/runtime.dart';
import '../../../core/sse/frame.dart';
import '../../../core/sse/sse_gateway.dart';
import '../data/scheduler_repository.dart';
import '../scheduler_windows.dart';
import '../ui/scheduler_home_model.dart';
import 'scheduler_rail_provider.dart';

// The workflow operations home's server-state (WRK-069 §4 S3) — three providers over the ONE rail
// pulse: the workflow detail (graph + lifecycle truth), the run big table (keyset-paged, filtered,
// pill-guarded) and the linked pane's full run composite. 活性军规 holds throughout: ticks never
// reach any of these; run_started only bumps the pill (never a row); run_terminal patches loaded
// rows IN PLACE from a single-run reconcile read (geometry only moves on durable ledger events or
// user action). 运营主页状态:详情/大表/联动格三 provider 同吃 rail 节拍;tick 永不达,run_started
// 只加 pill 不插行,run_terminal 单 run 对账读原位补行。

/// The full workflow entity (name/lifecycle truth + the active version's graph for the linked
/// pane). Rides the rail's durable pulse — refetches exactly when the rail does.
/// 全量 workflow 实体(健康头+联动格图);随 rail durable 节拍重取。
final schedulerWorkflowProvider =
    FutureProvider.autoDispose.family<WorkflowEntity, String>((ref, id) async {
  await ref.watch(schedulerRailProvider.future);
  return ref.watch(schedulerRepositoryProvider).getWorkflow(id);
}, retry: (_, _) => null);

/// The page-level time range (主页重建拍板 0717) — ONE capsule governs the matrix AND the run
/// table, so the two zones can never disagree about «when». Presets are LIVE expressions (each
/// fetch resolves against a fresh now); deliberately NOT autoDispose and NOT in the URL (§11:
/// 过滤器不入 URL) — the lens survives switching workflows within a session.
/// 页级时间范围:一颗胶囊治矩阵+大表,两区对「何时」永不打架。预设是活表达式(每次取数现解析);刻意
/// 不 autoDispose、不入 URL(§11 过滤器不入 URL)——镜头在会话内跨 workflow 存活。
class SchedulerTimeRange extends Notifier<AnTimeRange> {
  @override
  AnTimeRange build() => const AnPresetRange(AnTimePreset.d7);

  void set(AnTimeRange range) => state = range;
}

final schedulerTimeRangeProvider =
    NotifierProvider<SchedulerTimeRange, AnTimeRange>(SchedulerTimeRange.new);

/// The inline peek card's run composite — the run header + ALL node rows (gantt/graph need the
/// complete set). Rides the rail pulse: a durable terminal reconciles the card; ticks never reach
/// it (the live-growing gantt is S4's). 行内速览卡 run 复合(全量节点);随 rail 节拍对账,tick 不达。
final schedulerLinkedRunProvider =
    FutureProvider.autoDispose.family<FlowrunComposite, String>((ref, frId) async {
  await ref.watch(schedulerRailProvider.future);
  return ref.watch(schedulerRepositoryProvider).getRunFull(frId);
}, retry: (_, _) => null);

/// The top-of-page matrix window (工单⑩, 主页重建拍板 0717): pages of runs inside the page-level
/// time range, each page's grid fetched as ONE `flowrun-matrix?flowrunIds=` batch and MERGED —
/// cols accumulate newest→oldest, rows stay the first-appearance union (pages arrive newest-first,
/// so the scan order matches the backend's own law), cells pile up sparsely. Sliding toward the
/// oldest edge calls [SchedulerMatrixWindowController.loadOlder]. Rebuilds when the range changes
/// and rides the rail's durable pulse (new runs/terminals re-anchor the window — geometry moves on
/// ledger events, 军规-legal); ticks never reach it.
/// 页顶矩阵窗:按页级时间范围翻 run 页,每页格阵一次 flowrunIds 批查并**归并**——列新→旧累积、行守
/// 首次出现并集(页新→旧到达,扫描序即后端自身之律)、格稀疏堆积。滑近最旧缘调 loadOlder。范围变即重
/// 建,吃 rail durable 节拍(新 run/终态重新锚窗——几何随落账动,军规合法);tick 永不达。
class MatrixWindowState {
  const MatrixWindowState({
    required this.matrix,
    this.nextCursor,
    this.hasMore = false,
    this.loadingOlder = false,
  });

  final FlowrunMatrix matrix;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingOlder;

  MatrixWindowState copyWith({
    FlowrunMatrix? matrix,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? loadingOlder,
  }) =>
      MatrixWindowState(
        matrix: matrix ?? this.matrix,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        hasMore: hasMore ?? this.hasMore,
        loadingOlder: loadingOlder ?? this.loadingOlder,
      );
}

class SchedulerMatrixWindowController extends AsyncNotifier<MatrixWindowState> {
  SchedulerMatrixWindowController(this.workflowId);

  final String workflowId;

  @override
  Future<MatrixWindowState> build() async {
    final range = ref.watch(schedulerTimeRangeProvider);
    await ref.watch(schedulerRailProvider.future);
    final repo = ref.watch(schedulerRepositoryProvider);
    final r = resolveTimeRange(range, DateTime.now());
    final page = await repo.listFlowruns(
      workflowId: workflowId,
      startedAfter: r.from,
      startedBefore: r.to,
      limit: SchedulerWindows.matrixPageSize,
    );
    if (page.items.isEmpty) {
      return const MatrixWindowState(matrix: FlowrunMatrix());
    }
    final matrix = await repo.runMatrix([for (final run in page.items) run.id]);
    final next = page.isLastPage ? null : page.nextCursor;
    return MatrixWindowState(matrix: matrix, nextCursor: next, hasMore: page.hasMore);
  }

  /// Pull ONE older page into the window (the oldest-edge slide). Merge, never rebuild: prepended
  /// history must not blink the whole grid. 向窗里拉一页更旧的(最旧缘滑动)。归并绝不重建——前插的
  /// 历史不许闪整张格阵。
  Future<void> loadOlder() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingOlder || s.nextCursor == null) return;
    state = AsyncData(s.copyWith(loadingOlder: true));
    final repo = ref.read(schedulerRepositoryProvider);
    final range = ref.read(schedulerTimeRangeProvider);
    final r = resolveTimeRange(range, DateTime.now());
    try {
      final page = await repo.listFlowruns(
        workflowId: workflowId,
        startedAfter: r.from,
        startedBefore: r.to,
        cursor: s.nextCursor,
        limit: SchedulerWindows.matrixPageSize,
      );
      final older = page.items.isEmpty
          ? const FlowrunMatrix()
          : await repo.runMatrix([for (final run in page.items) run.id]);
      if (!ref.mounted) return;
      final cur = state.value ?? s;
      final merged = _merge(cur.matrix, older);
      final next = page.isLastPage ? null : page.nextCursor;
      state = AsyncData(cur.copyWith(
        matrix: merged,
        nextCursor: next,
        clearCursor: next == null,
        hasMore: page.hasMore,
        loadingOlder: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      // An older page is optional history — keep the window standing, drop the busy flag.
      // 旧页是可选历史——窗照旧站着,只收 busy 旗。
      state = AsyncData((state.value ?? s).copyWith(loadingOlder: false));
    }
  }

  /// Append an OLDER page under the newest-first canonical order: cols concat (ours are newer by
  /// keyset construction), rows union first-seen (kind keeps its newest occurrence), cells concat
  /// (disjoint run sets). 归并更旧一页:列相接(keyset 保证我方更新)、行首见并集(kind 守最新一次出现)、
  /// 格相接(run 集不相交)。
  static FlowrunMatrix _merge(FlowrunMatrix newer, FlowrunMatrix older) {
    final seen = {for (final r in newer.rows) r.nodeId};
    return FlowrunMatrix(
      cols: [...newer.cols, ...older.cols],
      rows: [
        ...newer.rows,
        for (final r in older.rows)
          if (seen.add(r.nodeId)) r,
      ],
      cells: [...newer.cells, ...older.cells],
    );
  }
}

final schedulerMatrixWindowProvider = AsyncNotifierProvider.autoDispose
    .family<SchedulerMatrixWindowController, MatrixWindowState, String>(
  SchedulerMatrixWindowController.new,
  retry: (_, _) => null,
);

/// The machine-level retention line, READ-ONLY (工单⑬) — the run table's tombstone reads it to say why
/// the history ends. Deliberately NOT `autoDispose`: it is one tiny machine-wide value that the user
/// changes at most once in a while, and re-fetching it on every table scroll would be noise. Editing
/// lives in the settings storage panel (which parses the same wire itself — features 互不依赖).
/// 机器级保留线,**只读**(⑬):大表墓碑读它来说明历史为何在此结束。**刻意不 autoDispose**:它是一个极小的
/// 全机值、用户偶尔才改一次,每次滚表都重取纯属噪声。编辑归设置存储面板(它自行解同一条线缆——features 互不依赖)。
final schedulerRetentionProvider = FutureProvider<RetentionConfig>(
    (ref) => ref.watch(schedulerRepositoryProvider).retention());

/// The run big table's whole state. [failedCount] is the count strip's failed number — probed
/// through the SAME `GET /flowruns` grammar the table uses (window + origin apply), one page of 50;
/// [failedCountCapped] = the probe hit its page bound (render «50+», never a fake exact number).
/// [newRuns] is the follow pill (§0 军规:新 run 绝不插行). 大表状态;失败计数=同文法探针(≤50 封顶
/// 诚实);newRuns=pill。
class RunTableState {
  const RunTableState({
    this.rows = const [],
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
    this.filter = RunStatusFilter.all,
    this.origin,
    this.failedCount = 0,
    this.failedCountCapped = false,
    this.newRuns = 0,
  });

  final List<Flowrun> rows;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;
  final RunStatusFilter filter;
  final String? origin;
  final int failedCount;
  final bool failedCountCapped;
  final int newRuns;

  RunTableState copyWith({
    List<Flowrun>? rows,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? loadingMore,
    RunStatusFilter? filter,
    String? origin,
    bool clearOrigin = false,
    int? failedCount,
    bool? failedCountCapped,
    int? newRuns,
  }) =>
      RunTableState(
        rows: rows ?? this.rows,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        filter: filter ?? this.filter,
        origin: clearOrigin ? null : (origin ?? this.origin),
        failedCount: failedCount ?? this.failedCount,
        failedCountCapped: failedCountCapped ?? this.failedCountCapped,
        newRuns: newRuns ?? this.newRuns,
      );
}

class SchedulerRunTableController extends AsyncNotifier<RunTableState> {
  SchedulerRunTableController(this.workflowId);

  final String workflowId;

  static const pageSize = 25;

  /// The failed-count probe's page bound — beyond it the strip says «50+». 探针页界,越界渲 50+。
  static const probeCap = 50;

  @override
  Future<RunTableState> build() async {
    // The page-level range governs this table too — a range change rebuilds page 1 (主页重建拍板
    // 0717). 页级范围同治大表:范围一变即回第一页重建。
    ref.watch(schedulerTimeRangeProvider);
    final gateway = ref.watch(sseGatewayProvider);
    if (gateway != null) {
      final sub =
          gateway.kindStream(StreamName.entities, 'workflow').listen(_onFrame);
      ref.onDispose(sub.cancel);
    }
    return _fetch(const RunTableState());
  }

  // ── durable frames (活性军规) ──────────────────────────────────────────────

  /// The frame seam, exposed for the liveness batteries (a real gateway would need a live socket;
  /// the RULE under test is this fold). 帧缝测试出口:待测的是折叠规则本身,不必起真 socket。
  @visibleForTesting
  void onFrameForTest(StreamEnvelope env) => _onFrame(env);

  void _onFrame(StreamEnvelope env) {
    // Ephemeral ticks never reach the table; other workflows' ledgers are not ours. tick 不达。
    if (!env.durable || env.scope.id != workflowId) return;
    final frame = env.frame;
    if (frame is! FrameSignal) return;
    switch (frame.node.type) {
      case 'run_started':
        // A new run NEVER inserts a row — the pill counts it, the user pulls it in (§0 军规).
        // 新 run 绝不插行——pill 计数,用户点击归位。
        final s = state.value;
        if (s != null) state = AsyncData(s.copyWith(newRuns: s.newRuns + 1));
      case 'run_terminal':
        final frId = frame.node.content?['flowrunId'] as String?;
        if (frId != null) unawaited(_reconcileRun(frId));
    }
  }

  /// A durable terminal landed — re-read THAT run (DB row is the truth, the frame only triggers the
  /// read) and settle it in place: patch the loaded row, or drop it when the new status left the
  /// current filter; refresh the failed probe (a failure may just have landed). Loaded pagination is
  /// deliberately preserved — a full top-reset would trash the user's scrolled context (记裁量).
  /// terminal 落账:单 run 对账读原位落定(补行/滤出即收行)+ 失败探针刷新;保住已翻页上下文。
  Future<void> _reconcileRun(String frId) async {
    final repo = ref.read(schedulerRepositoryProvider);
    try {
      final run = await repo.getRun(frId);
      if (!ref.mounted) return;
      final s = state.value;
      if (s == null) return;
      final f = runListFilter(
          filter: s.filter,
          origin: s.origin,
          range: ref.read(schedulerTimeRangeProvider),
          now: DateTime.now());
      final stillMatches = f.status == null || run.status == f.status;
      final rows = [
        for (final r in s.rows)
          if (r.id != frId) r else if (stillMatches) run,
      ];
      final probe = await _failedProbe(s);
      if (!ref.mounted) return;
      final cur = state.value ?? s;
      state = AsyncData(cur.copyWith(
        rows: rows,
        failedCount: probe.$1,
        failedCountCapped: probe.$2,
      ));
    } catch (_) {
      // A reconcile read is best-effort — the row keeps its last durable truth. 对账尽力而为。
    }
  }

  // ── fetch ─────────────────────────────────────────────────────────────────

  Future<(int, bool)> _failedProbe(RunTableState s) async {
    final repo = ref.read(schedulerRepositoryProvider);
    final f = runListFilter(
        filter: RunStatusFilter.failed,
        origin: s.origin,
        range: ref.read(schedulerTimeRangeProvider),
        now: DateTime.now());
    final page = await repo.listFlowruns(
      workflowId: workflowId,
      status: f.status,
      origin: f.origin,
      startedAfter: f.startedAfter,
      startedBefore: f.startedBefore,
      limit: probeCap,
    );
    return (page.items.length, page.hasMore);
  }

  Future<RunTableState> _fetch(RunTableState s) async {
    final repo = ref.read(schedulerRepositoryProvider);
    final f = runListFilter(
        filter: s.filter,
        origin: s.origin,
        range: ref.read(schedulerTimeRangeProvider),
        now: DateTime.now());

    List<Flowrun> rows;
    String? next;
    var more = false;
    if (s.filter == RunStatusFilter.waiting) {
      // «等人» = the running fetch intersected with the workflow's inbox runs — bounded by the inbox
      // (a handful), so it never paginates. 等人=running∩inbox,天然有界不分页。
      final rail = await ref.read(schedulerRailProvider.future);
      final waiting = waitingRunIds(rail.inbox, workflowId).toSet();
      final page = await repo.listFlowruns(
          workflowId: workflowId,
          status: f.status,
          origin: f.origin,
          startedAfter: f.startedAfter,
          startedBefore: f.startedBefore,
          limit: probeCap);
      rows = [for (final r in page.items) if (waiting.contains(r.id)) r];
      next = null;
    } else {
      final page = await repo.listFlowruns(
          workflowId: workflowId,
          status: f.status,
          origin: f.origin,
          startedAfter: f.startedAfter,
          startedBefore: f.startedBefore,
          limit: pageSize);
      rows = page.items;
      next = page.isLastPage ? null : page.nextCursor;
      more = page.hasMore;
    }

    final probe = await _failedProbe(s);
    return s.copyWith(
      rows: rows,
      nextCursor: next,
      clearCursor: next == null,
      hasMore: more,
      loadingMore: false,
      failedCount: probe.$1,
      failedCountCapped: probe.$2,
    );
  }

  /// Re-fetch page 1 under the given (or current) filters — the pill tap, filter picks and post-op
  /// settles all land here. USER-driven geometry (军规-legal). 回第一页重取:pill/换滤/操作后都走这。
  Future<void> refetchTop({RunStatusFilter? filter, String? origin, bool clearOrigin = false}) async {
    final s = state.value ?? const RunTableState();
    final base = s.copyWith(
      filter: filter,
      origin: origin,
      clearOrigin: clearOrigin,
      newRuns: 0,
      rows: s.rows, // keep the last good rows on screen during the await (no empty flash) 重取不闪空
    );
    state = AsyncData(base);
    final next = await AsyncValue.guard(() => _fetch(base));
    if (!ref.mounted) return;
    // A failed refetch keeps the previous truth (first-load errors surface via build). 失败留旧真相。
    if (next.hasValue) state = next;
  }

  /// Keyset next page (photo run_cockpit's loadMore discipline). keyset 下一页。
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore || s.nextCursor == null) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    final repo = ref.read(schedulerRepositoryProvider);
    final f = runListFilter(
        filter: s.filter,
        origin: s.origin,
        range: ref.read(schedulerTimeRangeProvider),
        now: DateTime.now());
    try {
      final page = await repo.listFlowruns(
          workflowId: workflowId,
          status: f.status,
          origin: f.origin,
          startedAfter: f.startedAfter,
          startedBefore: f.startedBefore,
          cursor: s.nextCursor,
          limit: pageSize);
      if (!ref.mounted) return;
      final cur = state.value ?? s;
      final next = page.isLastPage ? null : page.nextCursor;
      state = AsyncData(cur.copyWith(
        rows: [...cur.rows, ...page.items],
        nextCursor: next,
        clearCursor: next == null,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? s).copyWith(loadingMore: false));
    }
  }
}

final schedulerRunTableProvider = AsyncNotifierProvider.autoDispose
    .family<SchedulerRunTableController, RunTableState, String>(
  SchedulerRunTableController.new,
  retry: (_, _) => null,
);
