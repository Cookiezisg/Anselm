import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/run/flowrun_watch.dart';
import '../../../core/runtime.dart';
import '../../../core/sse/frame.dart';
import '../data/scheduler_repository.dart';
import '../ui/scheduler_run_model.dart';

// The run flagship's whole subject (WRK-069 §5 S4) — ONE provider owning the four reads a single run
// needs (the run + all its node rows / the activity aggregation / the PINNED version's graph / the
// host workflow) plus the live seam. 活性军规 holds throughout: a tick only paints (bars grow, the
// graph breathes, the ledger's live front advances) and schedules the debounced reconcile GET that
// lands truth; a durable run_terminal reconciles the WHOLE page once and flashes it settled. The
// viewport and the selection are never touched by a frame.
// run 旗舰的整个主语:一个 provider 持四读(run+全节点行/活动聚合/钉版图/宿主)与活线。tick 只作画并
// 去抖对账;durable run_terminal 整页对账一次并洗亮;帧永不动视口与选区。

/// Everything the flagship renders. [graph] is the run's PINNED version topology — §5.2 pins «按
/// flowrun.versionId 取钉版拓扑» precisely because reading today's active graph mis-draws a historical
/// run (the run_cockpit 错图 bug). [graphPinned] false = we had to fall back to the active version
/// (a pre-versionId run, or the version row is gone) and the page SAYS so rather than passing the
/// wrong map off as the right one. [orphan] = the host workflow was soft-deleted; the page stays
/// reachable as a tombstone (§5.7).
/// 旗舰的全部输入。graph=run 的钉版拓扑(§5.2:读当下 active 图会把历史 run 画错——run_cockpit 的错图
/// bug);graphPinned=false 即回退了 active 版本,页面会明说,绝不把错的地图当对的递出去;orphan=宿主已
/// 软删,本页仍以墓碑态可达(§5.7)。
class SchedulerRunData {
  const SchedulerRunData({
    required this.comp,
    this.activity = const [],
    this.graph,
    this.graphPinned = true,
    this.workflow,
    this.orphan = false,
    this.tickRows = const [],
    this.settledFlash = false,
  });

  final FlowrunComposite comp;
  final List<FlowrunActivityRow> activity;
  final Graph? graph;
  final bool graphPinned;
  final WorkflowEntity? workflow;
  final bool orphan;

  /// EPHEMERAL tick-born placeholder rows (§9 铁律:DB 行是真相、流只为实时). They render, they never
  /// enter the durable cache: every reconcile rebuilds [comp] from the wire and drops the ones truth
  /// has caught up with. tick 占位行:只渲、不进耐久缓存;每次对账由真相接管。
  final List<FlowrunNode> tickRows;

  /// The one settle flash after a durable run_terminal (谢幕落账洗亮先例). 落定洗亮一次。
  final bool settledFlash;

  Flowrun get run => comp.flowrun;

  /// The rows to RENDER = DB truth + the tick placeholders truth hasn't reached yet. A truth row
  /// always wins its (nodeId, iteration) key. 渲染用行=真相 + 真相尚未追上的 tick 占位;同键真相恒胜。
  List<FlowrunNode> get nodes {
    if (tickRows.isEmpty) return comp.nodes;
    var out = comp.nodes;
    for (final t in tickRows) {
      out = upsertNodeRow(out, t);
    }
    return out;
  }

  /// The composite as the pure models want it (truth + live placeholders). 供纯模型的复合。
  FlowrunComposite get merged =>
      tickRows.isEmpty ? comp : FlowrunComposite(flowrun: comp.flowrun, nodes: nodes);

  SchedulerRunData copyWith({
    FlowrunComposite? comp,
    List<FlowrunActivityRow>? activity,
    Graph? graph,
    bool? graphPinned,
    WorkflowEntity? workflow,
    bool? orphan,
    List<FlowrunNode>? tickRows,
    bool? settledFlash,
  }) =>
      SchedulerRunData(
        comp: comp ?? this.comp,
        activity: activity ?? this.activity,
        graph: graph ?? this.graph,
        graphPinned: graphPinned ?? this.graphPinned,
        workflow: workflow ?? this.workflow,
        orphan: orphan ?? this.orphan,
        tickRows: tickRows ?? this.tickRows,
        settledFlash: settledFlash ?? this.settledFlash,
      );
}

class SchedulerRunController extends AsyncNotifier<SchedulerRunData> {
  SchedulerRunController(this.flowrunId);

  final String flowrunId;

  Timer? _reconcile;
  Timer? _poll;
  StreamSubscription<StreamEnvelope>? _sub;

  @override
  Future<SchedulerRunData> build() async {
    ref.onDispose(_stopTimers);
    final data = await _fetch();
    // Subscribe AFTER the first read: the tick scope is the WORKFLOW (concurrent runs interleave on
    // it), and we only learn our host workflow from the run itself. 首读之后再订阅:tick 是 workflow
    // 级 scope,而宿主 workflow 要从 run 本身才知道。
    final gateway = ref.read(sseGatewayProvider);
    if (gateway != null && data.run.workflowId.isNotEmpty) {
      _sub = gateway
          .scopeStream(StreamScope(kind: 'workflow', id: data.run.workflowId))
          .listen(_onFrame);
      ref.onDispose(() => _sub?.cancel());
    }
    _armPoll(data);
    return data;
  }

  void _stopTimers() {
    _reconcile?.cancel();
    _reconcile = null;
    _poll?.cancel();
    _poll = null;
  }

  /// A live run gets the slow poll backstop (a tick stream dropped WHOLE must still converge); a
  /// settled run needs no clock at all. 活 run 挂慢轮询兜底(tick 全丢也要收敛);落定 run 无需任何钟。
  void _armPoll(SchedulerRunData d) {
    _poll?.cancel();
    _poll = null;
    if (d.run.status == 'running') {
      _poll = Timer.periodic(FlowrunWatch.pollEvery, (_) => unawaited(_reconcileNow(flash: false)));
    }
  }

  /// The frame seam, exposed for the liveness batteries (a real gateway would need a live socket;
  /// the RULE under test is this fold). 帧缝测试出口:待测的是折叠规则本身,不必起真 socket。
  @visibleForTesting
  void onFrameForTest(StreamEnvelope env) => _onFrame(env);

  void _onFrame(StreamEnvelope env) {
    final d = state.value;
    if (d == null) return;
    final frame = env.frame;
    if (env.durable) {
      // The ONE durable we act on: OUR run reached a terminal → reconcile the whole page once and
      // flash it settled (§5.6). run_started belongs to another run by definition.
      // 唯一响应的 durable:本 run 到终态→整页对账一次 + 落定洗亮;run_started 按定义属于别的 run。
      if (frame is FrameSignal &&
          frame.node.type == 'run_terminal' &&
          frame.node.content?['flowrunId'] == flowrunId) {
        unawaited(_reconcileNow(flash: true));
      }
      return;
    }
    // Ephemeral: a tick paints, nothing more. Ticks for a SIBLING run on the same workflow scope are
    // not ours. tick 只作画;同 workflow scope 上兄弟 run 的 tick 不是我们的。
    final tick = flowrunTickOf(frame);
    if (tick == null || tick.flowrunId != flowrunId) return;
    state = AsyncData(d.copyWith(
      tickRows: upsertNodeRow(d.tickRows, tick.row(DateTime.now())),
      settledFlash: false,
    ));
    // Ticks carry no stamps and no result — the debounced GET is where truth lands.
    // tick 无戳无 result——去抖 GET 落真相。
    _reconcile?.cancel();
    _reconcile = Timer(FlowrunWatch.reconcileDelay, () => unawaited(_reconcileNow(flash: false)));
  }

  /// Re-read the whole subject from the DB and settle it in place. Best-effort: a transient failure
  /// keeps the last good truth on screen (the poll / the next tick retries) — an archive page must
  /// never blank out because one read blipped.
  /// 整体对账:尽力而为,瞬态失败保留屏上旧真相(轮询/下个 tick 会再来)——档案页绝不因一次读抖动而空白。
  Future<void> _reconcileNow({required bool flash}) async {
    if (!ref.mounted) return;
    try {
      // Carry the MAP forward: a run's pinned version is immutable by construction (that is what
      // «pinned» means) and its host's identity doesn't move under it either — re-reading them on
      // every 4s poll would be two wasted round-trips per tick for data that cannot have changed.
      // Only the run + its activity are re-read. 带上地图重用:钉版按定义不可变、宿主身份也不会在
      // run 底下换人——每 4s 轮询重读它们,是为不可能变的数据白跑两趟。只重读 run 与它的活动。
      final next = await _fetch(carry: state.value);
      if (!ref.mounted) return;
      state = AsyncData(next.copyWith(settledFlash: flash));
      _armPoll(next);
    } catch (_) {
      // keep the last good value 保留旧真相
    }
  }

  /// The user-driven refetch (post-action settle). USER geometry is 军规-legal. 用户动作后的重取。
  Future<void> refresh() => _reconcileNow(flash: false);

  /// [carry] = the last good load, whose IMMUTABLE half (the pinned graph + the host) is reused. Null
  /// on the first load, where everything is read. 首读全取;此后重用不可变的一半。
  Future<SchedulerRunData> _fetch({SchedulerRunData? carry}) async {
    final repo = ref.read(schedulerRepositoryProvider);
    final comp = await repo.getRunFull(flowrunId);

    // Activity is re-read every time — it GROWS as the run walks (工单⑤). 活动每次重读:run 在走,它在长。
    final activity = await _activityOf(repo, comp);

    // The map half. Reused when we already resolved it; a carry that FAILED to pin last time is
    // retried (a transient 404 on the version row must not brand the page «un-pinned» forever).
    // 地图那一半:已解出即重用;上次没钉上的会重试(版本行的瞬态 404 不该把页面永久烙成「未钉版」)。
    if (carry != null && carry.graphPinned && carry.graph != null) {
      return SchedulerRunData(
        comp: comp,
        activity: activity,
        graph: carry.graph,
        graphPinned: true,
        workflow: carry.workflow,
        orphan: carry.orphan,
      );
    }

    // Both reads are INDEPENDENT and each is allowed to fail on its own terms — an orphan run has no
    // workflow, a run whose version row is gone has no pinned graph. One missing read must never
    // take the page down with it. 两读各自独立、各自允许按自己的方式失败(孤儿 run 无宿主 / 版本行没了
    // 则无钉版图);一次缺失绝不拖垮整页。
    final results = await Future.wait([
      _workflowOf(repo, comp.flowrun.workflowId),
      _pinnedVersionOf(repo, comp.flowrun),
    ]);
    final workflow = results[0] as WorkflowEntity?;
    final pinned = results[1] as WorkflowVersion?;

    // The pinned version is the map the run ACTUALLY walked. Only when it can't be resolved do we
    // fall back to today's active graph — and then we SAY so. 钉版才是 run 真正走过的地图;解不出才
    // 回退当下 active 图,且明说。
    var graph = graphOfVersion(pinned);
    final graphPinned = graph != null;
    graph ??= graphOfVersion(workflow?.activeVersion);

    return SchedulerRunData(
      comp: comp,
      activity: activity,
      graph: graph,
      graphPinned: graphPinned,
      workflow: workflow,
      orphan: workflow == null,
    );
  }

  Future<List<FlowrunActivityRow>> _activityOf(
      SchedulerRepository repo, FlowrunComposite comp) async {
    try {
      return await repo.listActivity(comp.flowrun.id);
    } catch (_) {
      // No activity aggregation → the gantt degrades to the row's own stamps (工单⑤ 未落的诚实回退).
      // 无活动聚合→甘特回落到行自身的戳。
      return const [];
    }
  }

  Future<WorkflowEntity?> _workflowOf(SchedulerRepository repo, String id) async {
    if (id.isEmpty) return null;
    try {
      return await repo.getWorkflow(id);
    } on ApiException catch (e) {
      // 404 = the host was soft-deleted: an ORPHAN run, still a first-class archive page (§5.7).
      // Any other failure is also survivable here — the page just wears the tombstone.
      // 404=宿主软删:孤儿 run 仍是一等档案页;其余失败同样可活,页面戴墓碑即可。
      if (e.httpStatus == 404) return null;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<WorkflowVersion?> _pinnedVersionOf(SchedulerRepository repo, Flowrun run) async {
    if (run.versionId.isEmpty || run.workflowId.isEmpty) return null;
    try {
      return await repo.getWorkflowVersion(run.workflowId, run.versionId);
    } catch (_) {
      return null;
    }
  }
}

/// One controller per run (autoDispose family) — the flagship's only server-state. 每 run 一个。
final schedulerRunProvider = AsyncNotifierProvider.autoDispose
    .family<SchedulerRunController, SchedulerRunData, String>(
  SchedulerRunController.new,
  retry: (_, _) => null,
);
