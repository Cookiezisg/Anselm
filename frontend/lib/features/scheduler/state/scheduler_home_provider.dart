import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/scheduler_matrix.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
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
final schedulerWorkflowProvider = FutureProvider.autoDispose
    .family<WorkflowEntity, String>((ref, id) async {
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
final schedulerLinkedRunProvider = FutureProvider.autoDispose
    .family<FlowrunComposite, String>((ref, frId) async {
      await ref.watch(schedulerRailProvider.future);
      return ref.watch(schedulerRepositoryProvider).getRunFull(frId);
    }, retry: (_, _) => null);

/// The health sentence's stats, FOLLOWING the page-level range (需求② 0717-晚): one bounded
/// 1-id batch per (workflow, range), windows mapped by [statsWindowOf] (presets = live durations,
/// absolute = RFC3339 pair with `until`). The rail's own 7d batch keeps feeding the rail dots —
/// this page's sentence stops quoting a window the capsule doesn't govern.
///
/// The answer is STAMPED with the range it was computed for (复审 0717-晚): on a capsule switch,
/// Riverpod's reload keeps the PREVIOUS value in flight — the widget must not pair the new window
/// word with those old numbers, and the stamp is how it tells. A same-range rail-pulse reload keeps
/// its stamp, so the sentence never blinks on ordinary ledger beats.
/// 健康句统计**跟随页级范围**:每 (workflow, 范围) 一次 1-id 批查,窗按 statsWindowOf 映射(预设=活
/// 时长/绝对=RFC3339 对带 until)。rail 自己的 7d 批照旧喂点。**答案盖范围章**:换胶囊时 Riverpod
/// reload 在飞期间保留旧值——widget 绝不许把新窗口词配旧数字,凭章分辨;同范围的 rail 节拍重载章
/// 不变,句子在寻常落账节拍上不闪。
final schedulerRangeStatsProvider = FutureProvider.autoDispose
    .family<({AnTimeRange range, WorkflowRunStats? stats}), String>((
      ref,
      workflowId,
    ) async {
      final range = ref.watch(schedulerTimeRangeProvider);
      await ref.watch(schedulerRailProvider.future);
      final w = statsWindowOf(range, DateTime.now());
      final s = await ref
          .watch(schedulerRepositoryProvider)
          .stats([workflowId], since: w.since, until: w.until);
      return (
        range: range,
        stats: s.byWorkflow.isEmpty ? null : s.byWorkflow.first,
      );
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
    this.runsById = const {},
    this.nextCursor,
    this.hasMore = false,
    this.loadingOlder = false,
  });

  final FlowrunMatrix matrix;

  /// The window's run headers by id — the humane words (source phrase / trigger join) the grid's
  /// tooltips and a11y sentences speak instead of bare ids (需求⑤). 窗内 run 头按 id——格阵 tooltip
  /// 与读屏句用的人话来源(不再念裸 id)。
  final Map<String, Flowrun> runsById;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingOlder;

  MatrixWindowState copyWith({
    FlowrunMatrix? matrix,
    Map<String, Flowrun>? runsById,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? loadingOlder,
  }) => MatrixWindowState(
    matrix: matrix ?? this.matrix,
    runsById: runsById ?? this.runsById,
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
    return MatrixWindowState(
      matrix: matrix,
      runsById: {for (final run in page.items) run.id: run},
      nextCursor: next,
      hasMore: page.hasMore,
    );
  }

  /// Pull ONE older page into the window (the oldest-edge slide). Merge, never rebuild: prepended
  /// history must not blink the whole grid. 向窗里拉一页更旧的(最旧缘滑动)。归并绝不重建——前插的
  /// 历史不许闪整张格阵。
  Future<void> loadOlder() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingOlder || s.nextCursor == null) {
      return;
    }
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
      final curAsync = state;
      final cur = curAsync.value;
      // Merge ONLY onto the exact, SETTLED window this fetch left from (复审 [4], 探针实测定罪):
      //  · `identical(matrix)` rejects a window already REPLACED by a finished rebuild;
      //  · `isLoading` rejects a rebuild still IN FLIGHT — measured: assigning state mid-rebuild
      //    makes Riverpod DISCARD the pending build result, so the old-range merge would not just
      //    mix histories, it would throw the new range's page 1 away entirely.
      // 只归并到出发时那扇**已落定**的窗:identical 拒「重建已落地换过窗」;isLoading 拒「重建仍在飞」
      // ——实测:重建在飞时手动赋值会让 Riverpod **作废**在飞的 build 结果,旧范围归并不止混史,还会把
      // 新范围的首页整个扔掉。
      if (cur == null ||
          curAsync.isLoading ||
          !identical(cur.matrix, s.matrix)) {
        return;
      }
      final merged = _merge(cur.matrix, older);
      final next = page.isLastPage ? null : page.nextCursor;
      state = AsyncData(
        cur.copyWith(
          matrix: merged,
          runsById: {
            ...cur.runsById,
            for (final run in page.items) run.id: run,
          },
          nextCursor: next,
          clearCursor: next == null,
          hasMore: page.hasMore,
          loadingOlder: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      // An older page is optional history — keep the window standing, drop the busy flag. Same
      // settled-window guard as the merge: touching state mid-rebuild discards the pending build.
      // 旧页是可选历史——窗照旧站着,只收 busy 旗;同款落定窗守卫(重建在飞时碰 state 会作废其结果)。
      final curAsync = state;
      final cur = curAsync.value;
      if (cur == null ||
          curAsync.isLoading ||
          !identical(cur.matrix, s.matrix)) {
        return;
      }
      state = AsyncData(cur.copyWith(loadingOlder: false));
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

/// The run big table's whole state. [failedCount] is the count strip's failed number — probed
/// through the SAME `GET /flowruns` grammar the table uses (window + origin apply), one page of 50;
/// [failedCountCapped] = the probe hit its page bound (render «50+», never a fake exact number).
/// [newRuns] is the follow pill (§0 军规:新 run 绝不插行). 大表状态;失败计数=同文法探针(≤50 封顶
/// 诚实);newRuns=pill。
class RunTableState {
  const RunTableState({
    this.rows = const [],
    this.page = 1,
    this.total = 0,
    this.filter = RunStatusFilter.all,
    this.origin,
    this.failedCount = 0,
    this.failedCountCapped = false,
    this.runningCount = 0,
    this.runningCountCapped = false,
    this.waitingCount = 0,
    this.newRuns = 0,
  });

  final List<Flowrun> rows;

  /// Page-number pagination (WRK-070 B4 用户拍板:每页 10 条+标准翻页器,弃 loadMore 哨兵):
  /// [page] 1-based, [total] = the offset wire's whole-filtered-set count. 页码分页;total=同过滤全集数。
  final int page;
  final int total;
  final RunStatusFilter filter;
  final String? origin;
  final int failedCount;
  final bool failedCountCapped;

  /// Range-scoped running/waiting badge numbers, probed through the SAME `GET /flowruns` grammar
  /// the rows use (复审 [5] 口径同源:牌与列表必须是同一个事实——stats.running 是「此刻」的全史数,
  /// 而行按 started_at 落在页级时间范围里,两者在窗口边缘会打架成「牌上写 3、点开列表显示 4」)。
  /// waiting = 范围内 running 探针行 ∩ rail 收件箱 run id(与等人过滤的成员集同源)。
  final int runningCount;
  final bool runningCountCapped;
  final int waitingCount;
  final int newRuns;

  RunTableState copyWith({
    List<Flowrun>? rows,
    int? page,
    int? total,
    RunStatusFilter? filter,
    String? origin,
    bool clearOrigin = false,
    int? failedCount,
    bool? failedCountCapped,
    int? runningCount,
    bool? runningCountCapped,
    int? waitingCount,
    int? newRuns,
  }) => RunTableState(
    rows: rows ?? this.rows,
    page: page ?? this.page,
    total: total ?? this.total,
    filter: filter ?? this.filter,
    origin: clearOrigin ? null : (origin ?? this.origin),
    failedCount: failedCount ?? this.failedCount,
    failedCountCapped: failedCountCapped ?? this.failedCountCapped,
    runningCount: runningCount ?? this.runningCount,
    runningCountCapped: runningCountCapped ?? this.runningCountCapped,
    waitingCount: waitingCount ?? this.waitingCount,
    newRuns: newRuns ?? this.newRuns,
  );
}

class SchedulerRunTableController extends AsyncNotifier<RunTableState> {
  SchedulerRunTableController(this.workflowId);

  final String workflowId;

  /// 10 per page (WRK-070 B4 用户拍板:「时间范围内的最近10条+翻页器」). 每页 10 条。
  static const pageSize = 10;

  /// The failed-count probe's page bound — beyond it the strip says «50+». 探针页界,越界渲 50+。
  static const probeCap = 50;

  /// A monotonic request generation (WRK-070 复审 [2]): setPage/refetchTop are fire-and-forget on the
  /// SAME notifier and the table stays interactive during the ~3-await _fetch, so a stale in-flight
  /// page fetch could clobber a newer filter pick (last-write-wins). Each user-driven fetch stamps a
  /// gen and only writes state if it is still the latest — same discipline as _reconcileRun's
  /// state re-read. 请求代号:用户动作各盖代号,过时的在飞取数绝不回写(否则旧页覆盖新滤)。
  int _gen = 0;

  @override
  Future<RunTableState> build() async {
    // The page-level range governs this table too — a range change rebuilds page 1 (主页重建拍板
    // 0717). The user's OTHER picks survive the rebuild: filter/origin ride over from the previous
    // state (复审 [6] — a lens change must not silently wipe the status/origin filters; on the very
    // first build there is no previous and the defaults stand).
    // 页级范围同治大表:范围一变即回第一页重建;但用户的**另两个**选择跨重建存活——filter/origin 从上一
    // 状态带过(复审 [6]:换镜头不许悄悄清掉状态/来源过滤;首建无前态,走默认)。
    ref.watch(schedulerTimeRangeProvider);
    final prev = state.value;
    final gateway = ref.watch(sseGatewayProvider);
    if (gateway != null) {
      final sub = gateway
          .kindStream(StreamName.entities, 'workflow')
          .listen(_onFrame);
      ref.onDispose(sub.cancel);
    }
    return _fetch(
      RunTableState(
        filter: prev?.filter ?? RunStatusFilter.all,
        origin: prev?.origin,
      ),
    );
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
      final probes = await _probes(s);
      if (!ref.mounted) return;
      // Patch rows off the state AS IT IS NOW — every await above yields, and a loadMore/filter
      // change that landed meanwhile must not be overwritten by a pre-await snapshot (复审 [3]:
      // 旧快照回写会吞掉并发落地的一页/别的终态补丁).
      // 行补丁基于**现在**的 state——上面的每个 await 都让出执行权,期间落地的翻页/换滤不许被旧快照回写。
      final cur = state.value;
      if (cur == null) return;
      final f = runListFilter(
        filter: cur.filter,
        origin: cur.origin,
        range: ref.read(schedulerTimeRangeProvider),
        now: DateTime.now(),
      );
      final stillMatches = f.status == null || run.status == f.status;
      final rows = [
        for (final r in cur.rows)
          if (r.id != frId) r else if (stillMatches) run,
      ];
      state = AsyncData(
        cur.copyWith(
          rows: rows,
          failedCount: probes.failedCount,
          failedCountCapped: probes.failedCapped,
          runningCount: probes.runningCount,
          runningCountCapped: probes.runningCapped,
          waitingCount: probes.waitingCount,
        ),
      );
    } catch (_) {
      // A reconcile read is best-effort — the row keeps its last durable truth. 对账尽力而为。
    }
  }

  // ── fetch ─────────────────────────────────────────────────────────────────

  /// The count strip's numbers, probed through the SAME grammar as the rows (复审 [5] 口径同源):
  /// failed + running each one range-scoped page (≤probeCap, capped renders «50+»); waiting =
  /// running-probe rows ∩ the rail inbox's run ids (the same membership set the waiting filter
  /// lists). 计数条数字与行同文法探针;等人=范围内 running 探针 ∩ 收件箱 id(与等人过滤成员集同源)。
  Future<
    ({
      int failedCount,
      bool failedCapped,
      int runningCount,
      bool runningCapped,
      int waitingCount,
    })
  >
  _probes(RunTableState s) async {
    final repo = ref.read(schedulerRepositoryProvider);
    final range = ref.read(schedulerTimeRangeProvider);
    final failed = runListFilter(
      filter: RunStatusFilter.failed,
      origin: s.origin,
      range: range,
      now: DateTime.now(),
    );
    final running = runListFilter(
      filter: RunStatusFilter.running,
      origin: s.origin,
      range: range,
      now: DateTime.now(),
    );
    final failedPage = await repo.listFlowruns(
      workflowId: workflowId,
      status: failed.status,
      origin: failed.origin,
      startedAfter: failed.startedAfter,
      startedBefore: failed.startedBefore,
      limit: probeCap,
    );
    final runningPage = await repo.listFlowruns(
      workflowId: workflowId,
      status: running.status,
      origin: running.origin,
      startedAfter: running.startedAfter,
      startedBefore: running.startedBefore,
      limit: probeCap,
    );
    final rail = await ref.read(schedulerRailProvider.future);
    final waiting = waitingRunIds(rail.inbox, workflowId).toSet();
    final waitingCount = runningPage.items
        .where((r) => waiting.contains(r.id))
        .length;
    return (
      failedCount: failedPage.items.length,
      failedCapped: failedPage.hasMore,
      runningCount: runningPage.items.length,
      runningCapped: runningPage.hasMore,
      waitingCount: waitingCount,
    );
  }

  Future<RunTableState> _fetch(RunTableState s) async {
    final repo = ref.read(schedulerRepositoryProvider);
    final f = runListFilter(
      filter: s.filter,
      origin: s.origin,
      range: ref.read(schedulerTimeRangeProvider),
      now: DateTime.now(),
    );

    List<Flowrun> rows;
    int total;
    if (s.filter == RunStatusFilter.waiting) {
      // «等人» = the running fetch intersected with the workflow's inbox runs — bounded by the inbox
      // (a handful), so it never paginates (pager hides at one page). 等人=running∩inbox,有界单页。
      final rail = await ref.read(schedulerRailProvider.future);
      final waiting = waitingRunIds(rail.inbox, workflowId).toSet();
      final page = await repo.listFlowruns(
        workflowId: workflowId,
        status: f.status,
        origin: f.origin,
        startedAfter: f.startedAfter,
        startedBefore: f.startedBefore,
        limit: probeCap,
      );
      rows = [
        for (final r in page.items)
          if (waiting.contains(r.id)) r,
      ];
      total = rows.length;
    } else {
      // Page-number mode (B4): the offset wire answers rows AND the filtered-set total — the pager's
      // page count is server truth, never a client guess. 页码模式:offset 线缆答行+全集数,页数=服务端真相。
      final page = await repo.listFlowrunsPage(
        workflowId: workflowId,
        status: f.status,
        origin: f.origin,
        startedAfter: f.startedAfter,
        startedBefore: f.startedBefore,
        offset: (s.page - 1) * pageSize,
        limit: pageSize,
      );
      rows = page.items;
      total = page.total;
    }

    final probes = await _probes(s);
    return s.copyWith(
      rows: rows,
      total: total,
      failedCount: probes.failedCount,
      failedCountCapped: probes.failedCapped,
      runningCount: probes.runningCount,
      runningCountCapped: probes.runningCapped,
      waitingCount: probes.waitingCount,
    );
  }

  /// Re-fetch page 1 under the given (or current) filters — the pill tap, filter picks and post-op
  /// settles all land here. USER-driven geometry (军规-legal). 回第一页重取:pill/换滤/操作后都走这。
  Future<void> refetchTop({
    RunStatusFilter? filter,
    String? origin,
    bool clearOrigin = false,
  }) async {
    final s = state.value ?? const RunTableState();
    final base = s.copyWith(
      filter: filter,
      origin: origin,
      clearOrigin: clearOrigin,
      newRuns: 0,
      page: 1,
      rows: s
          .rows, // keep the last good rows on screen during the await (no empty flash) 重取不闪空
    );
    final gen = ++_gen;
    state = AsyncData(base);
    final next = await AsyncValue.guard(() => _fetch(base));
    if (!ref.mounted || gen != _gen) {
      return; // a newer pick superseded this one 更新的选择已接管
    }
    // A failed refetch keeps the previous truth (first-load errors surface via build). 失败留旧真相。
    if (next.hasValue) state = next;
  }

  /// Jump to page [page] (the pager's arrows / numbers / jump field — USER-driven geometry). Keeps
  /// the current rows on screen during the await, same no-empty-flash discipline as [refetchTop].
  /// 跳页(翻页器三入口,用户动作):await 期间留旧行,与 refetchTop 同「不闪空」纪律。
  Future<void> setPage(int page) async {
    final s = state.value;
    if (s == null || page == s.page || page < 1) return;
    final base = s.copyWith(page: page);
    final gen = ++_gen;
    state = AsyncData(base);
    final next = await AsyncValue.guard(() => _fetch(base));
    if (!ref.mounted || gen != _gen) {
      return; // a newer pick superseded this one 更新的选择已接管
    }
    if (next.hasValue) state = next;
  }
}

final schedulerRunTableProvider = AsyncNotifierProvider.autoDispose
    .family<SchedulerRunTableController, RunTableState, String>(
      SchedulerRunTableController.new,
      retry: (_, _) => null,
    );
