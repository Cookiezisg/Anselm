import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/entities/values.dart';
import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/perf/coalescing_notifier.dart';
import '../../../../core/run/flowrun_watch.dart';
import '../../../../core/sse/frame.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../detail/entity_detail_provider.dart';
import '../selected_entity.dart';
import '../../data/entity_format.dart';
import 'recent_runs_provider.dart';
import 'run_draft_store.dart';
import 'run_fields.dart';
import 'run_terminal_state.dart';

/// The high-frequency streamed body of one entity's terminal, held OUTSIDE Riverpod (in a
/// [CoalescingNotifier]) so a stderr/token firehose repaints the body leaf ≤1×/frame and never churns the
/// lifecycle state. fn/hd append the run-node deltas to [text]; agent folds the block frames into [tree];
/// workflow stamps live flowrun ticks into [liveNodes]. 一个实体终端的高频流式 body(coalescer 之内)。
class RunStream {
  final BlockTreeReducer tree = BlockTreeReducer();
  final StringBuffer _text = StringBuffer();
  final Map<String, String> liveNodes = {};

  String get text => _text.toString();
  void appendText(String s) => _text.write(s);

  void reset() {
    tree.clear();
    _text.clear();
    liveNodes.clear();
  }
}

/// The run terminal for ONE executable entity ([entityRef]) — an autoDispose FAMILY keyed by [EntityRef].
/// Each member owns its own panel SSE subscription + streamed body + lifecycle. autoDispose means selecting
/// an entity (without running) and leaving it frees the controller + its panel subscription — a
/// non-autoDispose family would leak one per executable entity ever selected. A RUN takes a keep-alive
/// ([ref.keepAlive], released when the run settles), so a run keeps streaming in the BACKGROUND across
/// deselection and is intact on return; once it finishes, leaving the entity frees it. The verb CTA
/// (header) and the form's run button both call [run] — the typed input DRAFT lives here (so the header
/// can trigger a run without reaching into the form), coerced to the request on [run] using the entity's
/// declared [Field] types. Cancel ABANDONS the UI wait (sync verbs aren't abortable; the backend run
/// completes + records its row).
///
/// 一个可执行实体的 run 终端(按 [EntityRef] 的 **autoDispose** family)。各成员自管面板 SSE 订阅 + 流式 body +
/// 生命周期。autoDispose:仅选中(未运行)后离开即释放 controller + 面板订阅(非 autoDispose 会每选一个可执行实体
/// 泄漏一个)。**一次运行取 keepAlive(运行收尾时释放)** → 切走后台续流、切回完好;跑完离开即释放。头部动词 CTA 与
/// 表单按钮都调 run——类型化输入草稿在此,run 时按声明的 Field 类型强转成请求。
class RunTerminalController extends Notifier<RunTerminalState> {
  RunTerminalController(this.entityRef);

  final EntityRef entityRef;
  late EntityRepository _repo;
  StreamSubscription<StreamEnvelope>? _panelSub;
  // Closes the keep-alive link taken on run start (KeepAliveLink isn't publicly nameable in riverpod 3.3.2,
  // so we hold its .close tear-off). Non-null = a run is pinning this controller against autoDispose.
  // 运行起取的 keepAlive 释放钮(KeepAliveLink 3.3.2 不可公开命名,故持 .close);非空 = 有运行钉住本 controller 防 autoDispose。
  void Function()? _releaseRun;

  final CoalescingNotifier<RunStream> stream = CoalescingNotifier(RunStream());

  // Workflow reconcile plumbing: ticks are ephemeral (droppable, resultless) — the DB row is the
  // truth, so every tick schedules a debounced GET /flowruns/{id}, and a slow poll backstops a
  // fully-dropped tick stream. Both die on terminal/cancel/dispose. workflow 对账管道:tick 可丢
  // 且无 result——DB 行是真相,每 tick 去抖重取,慢轮询兜底全丢;终态/取消/释放即停。
  Timer? _reconcileDebounce;
  Timer? _poll;

  void _stopFlowrunTimers() {
    _reconcileDebounce?.cancel();
    _reconcileDebounce = null;
    _poll?.cancel();
    _poll = null;
  }

  /// The current form input (raw values: String for text/number/object/array, bool for boolean), kept off
  /// [state] so typing never rebuilds the lifecycle. Lives in the SESSION-LIVED [RunDraftStore] (调试台
  /// 参数记忆, 0719 拍板): the controller is autoDispose, so an in-notifier map would forget on deselect —
  /// the store keeps values per (entity, method|source) bucket for the whole app session.
  /// 当前表单草稿——住 session 草稿库(autoDispose 下 notifier 内 map 会忘;库按 实体×方法|来源 分桶养全会话)。
  Map<String, Object?> get draft => ref.read(runDraftStoreProvider).bucket(draftKey);

  /// The CURRENT bucket coordinate: hd varies by method, wf by source. 当前桶坐标。
  String get draftKey => switch (entityRef.kind) {
        EntityKind.handler => runDraftKey(entityRef, state.method),
        EntityKind.workflow => runDraftKey(entityRef, state.source),
        _ => runDraftKey(entityRef),
      };

  @override
  RunTerminalState build() {
    _repo = ref.watch(entityRepositoryProvider);
    _panelSub = _repo.panelSignals(entityRef.kind.scope(entityRef.id)).listen(_onPanel);
    ref.onDispose(() {
      _panelSub?.cancel();
      _stopFlowrunTimers();
      stream.dispose();
    });
    return const RunTerminalState();
  }

  /// Form text/bool field write — draft only, no rebuild (the inputs are uncontrolled). 表单字段写入(不重建)。
  void setField(String name, Object? value) => draft[name] = value;

  /// Handler method pick — in [state] because it swaps which fields render. 方法选择(在 state、换字段)。
  void setMethod(String method) {
    if (state.method != method) state = state.copyWith(method: method, inputError: null);
  }

  /// Workflow payload-source pick ('manual' | trigger id) — swaps the payload fields + draft bucket.
  /// workflow 来源选择:换 payload 字段与草稿桶。
  void setSource(String source) {
    if (state.source != source) state = state.copyWith(source: source, inputError: null);
  }

  /// The reproduce key (重现钥匙, 0719 拍板): fill the form back from a past execution — hd restores
  /// the METHOD, wf restores the SOURCE, and the input lands in the exact seed shape (scalars→text,
  /// bool→bool, structures→pretty JSON). The store bumps its revision so open forms re-seed.
  /// 重现:把某次执行的输入原样回填(hd 连方法、wf 连来源);库自增版本使表单立即重播。
  void reproduce(RecentRun run) {
    if (entityRef.kind == EntityKind.handler && run.method.isNotEmpty) setMethod(run.method);
    if (entityRef.kind == EntityKind.workflow) setSource(run.triggerId ?? 'manual');
    final values = <String, Object?>{};
    if (entityRef.kind == EntityKind.workflow) {
      // Flowrun rows don't project the entry payload — the source is restored, the payload is the
      // one part the user re-supplies (报告注明的唯一打折点). wf 行未投影 payload:还原来源,payload 留手填。
    } else {
      run.input.forEach((k, v) {
        values[k] = switch (v) {
          bool b => b,
          num n => '$n',
          String t => t,
          null => null,
          _ => prettyJson(v),
        };
      });
    }
    ref.read(runDraftStoreProvider).reproduce(draftKey, values);
    state = state.copyWith(inputError: null);
  }

  /// Execute the verb for this entity using the current draft (the header CTA + the form button both land
  /// here). Coerces draft → request by declared field type, captures execution-time stream frames, and
  /// finalizes from the result. Takes a keep-alive so the run survives deselection (background streaming).
  /// 用当前草稿执行本实体动词(头钮 + 表单按钮都到这)。按字段类型强转、捕获执行期帧、从结果收尾;取 keepAlive 后台续流。
  Future<void> run() async {
    final (request, inputError) = _coerce();
    if (inputError != null) {
      state = state.copyWith(inputError: inputError);
      return;
    }
    final seq = state.runSeq + 1;
    stream.mutate((s) => s..reset());
    state = state.copyWith(
      phase: RunPhase.running,
      runSeq: seq,
      inputError: null,
      output: null,
      errorCode: null,
      errorMsg: null,
      logs: null,
      steps: 0,
      tokensIn: 0,
      tokensOut: 0,
      flowrunId: null,
      flowNodes: const [],
    );
    final args = Map<String, dynamic>.from(request);
    try {
      // Pin this controller against autoDispose so the run keeps streaming if the user deselects; released
      // in `finally` once THIS run settles (so a finished run, once left, frees the panel subscription).
      // Taken INSIDE try, after runSeq=seq is set, so a throw anywhere below is still covered by the finally
      // release — no path can leave it permanently pinned. 钉住本 controller 防 autoDispose(切走后台续流);
      // 在 try 内取(runSeq=seq 之后),下方任意抛错仍被 finally 释放、绝不永钉。
      _releaseRun ??= ref.keepAlive().close;
      switch (entityRef.kind) {
        case EntityKind.control:
        case EntityKind.approval:
        case EntityKind.trigger:
          return; // support kinds — not runnable (defensive; no run CTA reaches here) 支撑 kind 不可跑
        case EntityKind.function:
          final r = await _repo.runFunction(entityRef.id, args: args);
          if (!ref.mounted || state.runSeq != seq) return;
          state = state.copyWith(
            phase: r.ok ? RunPhase.ok : RunPhase.failed,
            output: r.output,
            errorMsg: r.errorMsg.isEmpty ? null : r.errorMsg,
            elapsedMs: r.elapsedMs,
            logs: r.logs,
          );
        case EntityKind.handler:
          final r = await _repo.callHandler(entityRef.id, method: state.method, args: args);
          if (!ref.mounted || state.runSeq != seq) return;
          state = state.copyWith(phase: RunPhase.ok, output: r);
        case EntityKind.agent:
          final r = await _repo.invokeAgent(entityRef.id, input: args);
          if (!ref.mounted || state.runSeq != seq) return;
          state = state.copyWith(
            phase: r.ok ? RunPhase.ok : RunPhase.failed,
            output: r.output,
            errorMsg: (r.errorMsg ?? '').isEmpty ? null : r.errorMsg,
            elapsedMs: r.elapsedMs,
            steps: r.steps,
            tokensIn: r.tokensIn,
            tokensOut: r.tokensOut,
          );
        case EntityKind.workflow:
          final flowrunId =
              await _repo.triggerWorkflow(entityRef.id, payload: args.isEmpty ? null : args);
          if (!ref.mounted || state.runSeq != seq) return;
          state = state.copyWith(flowrunId: flowrunId);
          // Reconcile-driven from here: the first GET may still say running (long runs, parked
          // approvals) — ticks + the poll keep truing it up until the header goes terminal. The old
          // one-shot GET froze long runs as ok. 此后对账驱动:首拉可能仍 running(长跑/停车),
          // tick+轮询持续对账到 run 头终态;旧的一次性拉取会把长跑冻成 ok。
          await _reconcileFlowrun(seq);
          if (ref.mounted && state.runSeq == seq && state.isRunning) {
            _poll?.cancel();
            _poll = Timer.periodic(FlowrunWatch.pollEvery, (_) => _reconcileFlowrun(seq));
          }
      }
    } on ApiException catch (e) {
      if (!ref.mounted || state.runSeq != seq) return;
      state = state.copyWith(phase: RunPhase.failed, errorCode: e.code, errorMsg: e.message);
    } catch (e) {
      if (!ref.mounted || state.runSeq != seq) return;
      state = state.copyWith(phase: RunPhase.failed, errorMsg: e.toString());
    } finally {
      // Release the keep-alive once THIS run is the settled current one — a superseding run (seq bumped)
      // or a cancel keeps/handles it. A workflow still in flight (reconcile-driven) keeps the pin;
      // its terminal reconcile releases. Guarded by mounted so we never read a disposed notifier.
      // 本运行为当前且收尾才释放(被新运行接管/被 cancel 另行处理);workflow 在途(对账驱动)保钉,
      // 终态对账处释放;mounted 守卫防读已释放 notifier 的 state。
      if (ref.mounted && state.runSeq == seq && !state.isRunning) {
        _releaseRun?.call();
        _releaseRun = null;
      }
      // The bench strip re-reads its five as soon as this run has an audit row (wf: the flowrun row
      // exists right after :trigger). 运行落账即刷新「最近」条。
      if (ref.mounted) ref.invalidate(recentRunsProvider(entityRef));
    }
  }

  /// Abandon the UI-side wait (the in-flight result is dropped via the seq bump; the backend run still
  /// completes + records its audit row). Releases the keep-alive — the bumped seq makes the in-flight
  /// run's `finally` skip its own release, so cancel owns it. 放弃前端等待(后端续跑落审计行);释放 keepAlive。
  void cancel() {
    _stopFlowrunTimers();
    state = state.copyWith(phase: RunPhase.cancelled, runSeq: state.runSeq + 1);
    _releaseRun?.call();
    _releaseRun = null;
  }

  // Coerce the draft into the request by the entity's declared field types. workflow = one optional JSON
  // payload; fn/ag/hd = per-field (object/array via jsonDecode, surfacing a parse error). 草稿→请求强转。
  (Map<String, Object?>, String?) _coerce() {
    final detail = ref.read(entityDetailProvider(entityRef)).value;
    if (entityRef.kind == EntityKind.workflow) {
      // Payload by SOURCE (0718 拍板: the payload impersonates what the picked trigger releases):
      // cron releases nothing → empty; fsnotify/sensor → their kind-template fields; webhook and
      // manual → one JSON body. 按来源构造 payload:cron 空;fsnotify/sensor 走模板字段;webhook/手动=JSON。
      switch (wfSourceKind(ref, entityRef, state.source)) {
        case 'cron':
          return (const {}, null);
        case 'fsnotify':
          final path = (draft['path'] as String?)?.trim() ?? '';
          final event = (draft['event'] as String?)?.trim() ?? '';
          return ({if (path.isNotEmpty) 'path': path, if (event.isNotEmpty) 'event': event}, null);
        case 'sensor':
          final raw = (draft['value'] as String?)?.trim() ?? '';
          if (raw.isEmpty) return (const {}, null);
          return ({'value': num.tryParse(raw) ?? raw}, null);
        default: // webhook / manual — one JSON payload body 单 JSON 体
          final raw = (draft['__payload__'] as String?)?.trim() ?? '';
          if (raw.isEmpty) return (const {}, null);
          final Object? decoded;
          try {
            decoded = jsonDecode(raw);
          } catch (_) {
            return (const {}, 'payloadInvalid');
          }
          if (decoded is! Map<String, dynamic>) return (const {}, 'payloadObject');
          return (decoded, null);
      }
    }
    final req = <String, Object?>{};
    for (final f in runInputFields(entityRef.kind, detail, method: state.method)) {
      if (f.type == 'boolean') {
        final b = draft[f.name];
        if (b is bool) req[f.name] = b;
        continue;
      }
      final raw = (draft[f.name] as String?)?.trim() ?? '';
      if (raw.isEmpty) continue;
      switch (f.type) {
        case 'number':
          req[f.name] = num.tryParse(raw) ?? raw;
        case 'object' || 'array':
          try {
            req[f.name] = jsonDecode(raw);
          } catch (_) {
            return (const {}, 'field:${f.name}');
          }
        default:
          req[f.name] = raw;
      }
    }
    return (req, null);
  }

  void _onPanel(StreamEnvelope env) {
    switch (entityRef.kind) {
      case EntityKind.control:
      case EntityKind.approval:
      case EntityKind.trigger:
        return; // support kinds — no run panel 支撑 kind 无 run 面板
      case EntityKind.function:
      case EntityKind.handler:
        final f = env.frame;
        if (f is FrameDelta) stream.mutate((s) => s..appendText(f.chunk));
      case EntityKind.agent:
        stream.mutate((s) => s..tree.apply(env));
      case EntityKind.workflow:
        // The tick scope is workflow-level — concurrent flowruns interleave on it, so frames not
        // for OUR run are dropped (the old code mixed them). The parse + the placeholder row + the
        // cadence are the shared core seam (WRK-069 §9 三消费一源). tick 是 workflow 级 scope——并发
        // 多 run 混流,非本 run 的帧丢弃;解析/占位行/节拍走 core 共享缝。
        final tick = flowrunTickOf(env.frame);
        if (tick == null || tick.flowrunId != state.flowrunId) return;
        // A tick arriving after cancel/terminal must not resurrect the phase: reading runSeq HERE
        // would capture the post-cancel seq and sail through the reconcile guard — gate on the
        // phase instead. cancel/终态后的迟到 tick 不得复活状态机:此处读 runSeq 会拿到 bump 后的
        // 新值、穿透对账守卫——改按 phase 闸。
        if (!state.isRunning) return;
        stream.mutate((s) => s..liveNodes[tick.nodeId] = tick.status);
        state = state.copyWith(
          flowNodes: upsertNodeRow(state.flowNodes, tick.row(DateTime.now())),
        );
        // Ticks carry no result (a control's chosen port arrives only via the row) and the run
        // header has NO terminal signal — the debounced GET is where truth lands. tick 无 result、
        // run 头无终态信号——去抖 GET 落真相。
        final seq = state.runSeq;
        _reconcileDebounce?.cancel();
        _reconcileDebounce = Timer(FlowrunWatch.reconcileDelay, () => _reconcileFlowrun(seq));
    }
  }

  /// GET /flowruns/{id} and apply. The node page is NEWEST-FIRST and one page is NOT the whole run
  /// (WRK-055 契约:long loop runs overflow a page — early nodes would read as future and a parked
  /// row could get squeezed out, vanishing the gate): the FIRST reconcile of a flowrun pages through
  /// the full history; later reconciles fetch one page and UNION-merge (rows are record-once
  /// immutable — except parked→completed, which always lands in the newest window).
  /// 对账。节点页**最新在前且一页非全量**(长循环溢页会把早期节点误判 future、parked 行被挤出页外
  /// 让审批门凭空消失):本 flowrun 首次对账翻页拉全,此后取一页并**并集合并**(行 record-once 不可变,
  /// 唯一会变的 parked→completed 必在最新窗口)。
  Future<void> _reconcileFlowrun(int seq) async {
    final id = state.flowrunId;
    if (id == null || !ref.mounted || state.runSeq != seq || !state.isRunning) return;
    final FlowrunComposite comp;
    var rows = <FlowrunNode>[];
    try {
      final full = state.flowNodes.every(isTickRow); // no truth yet 尚无真相行
      comp = await _repo.getFlowrun(id, limit: 200);
      rows = [...comp.nodes];
      if (full) {
        var cursor = comp.nextCursor;
        var pages = 0;
        while (cursor != null && pages < 20) {
          final page = await _repo.getFlowrun(id, cursor: cursor, limit: 200);
          rows.addAll(page.nodes);
          cursor = page.nextCursor;
          pages++;
        }
      }
    } catch (_) {
      return; // transient — the poll retries 瞬态失败,轮询会再来
    }
    if (!ref.mounted || state.runSeq != seq) return;
    _applyFlowrun(comp, rows);
  }

  void _applyFlowrun(FlowrunComposite comp, List<FlowrunNode> fetched) {
    // Union by (node, iteration): fetched truth wins; older truth rows outside this page window
    // survive; tick rows fill the not-yet-covered races. 按 (节点,迭代) 并集:新取真相赢;窗口外
    // 旧真相行存活;tick 行补未覆盖的竞速。
    final merged = <(String, int), FlowrunNode>{
      for (final r in state.flowNodes.where((r) => !r.id.startsWith('tick_')))
        (r.nodeId, r.iteration): r,
      for (final r in fetched) (r.nodeId, r.iteration): r,
    };
    for (final t in state.flowNodes.where((r) => r.id.startsWith('tick_'))) {
      merged.putIfAbsent((t.nodeId, t.iteration), () => t);
    }
    final rows = merged.values.toList();
    final status = comp.flowrun.status;
    final terminal = status == 'completed' || status == 'failed' || status == 'cancelled';
    state = state.copyWith(
      flowNodes: rows,
      flowrunStatus: status,
      phase: terminal
          ? (status == 'completed'
              ? RunPhase.ok
              : status == 'failed'
                  ? RunPhase.failed
                  : RunPhase.cancelled)
          : RunPhase.running,
      errorMsg: comp.flowrun.error,
    );
    if (terminal) {
      _stopFlowrunTimers();
      _releaseRun?.call();
      _releaseRun = null;
    }
  }

  /// Decide a parked approval (yes/no). The 202 snapshot applies directly; a first-wins loss (422)
  /// or any failure falls back to a reconcile — truth wins, the gate self-corrects.
  /// 决断 parked 审批;202 快照直接应用,输了 first-wins(422)或任何失败回落对账——真相赢,门自纠。
  Future<void> decide(String nodeId, String decision) async {
    final id = state.flowrunId;
    if (id == null) return;
    final seq = state.runSeq;
    try {
      final comp = await _repo.decideApproval(id, nodeId, decision: decision);
      if (!ref.mounted || state.runSeq != seq) return;
      _applyFlowrun(comp, comp.nodes);
    } catch (_) {
      await _reconcileFlowrun(seq);
    }
  }

}

/// One run-terminal controller PER executable entity (autoDispose family) — freed when the entity is
/// deselected UNLESS a run is in flight (which pins it via keepAlive, so it streams in the background).
/// The right island shows the SELECTED entity's controller. 每可执行实体一个 controller(autoDispose family);
/// 选区移开即释放,除非有运行在 keepAlive 钉住(后台续流)。
final runTerminalProvider =
    NotifierProvider.autoDispose.family<RunTerminalController, RunTerminalState, EntityRef>(
        RunTerminalController.new);
