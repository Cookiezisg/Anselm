import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/perf/coalescing_notifier.dart';
import '../../../../core/sse/frame.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../selected_entity.dart';
import 'run_terminal_state.dart';

/// The high-frequency streaming body of the terminal, held OUTSIDE Riverpod (in a [CoalescingNotifier])
/// so a stderr/token firehose repaints the body leaf ≤1×/frame and never churns the lifecycle state.
/// Per kind: fn/hd append the run-node deltas to [text]; agent folds the messages-block frames into
/// [tree]; workflow stamps live flowrun ticks into [liveNodes] (the durable list is in the state).
///
/// 终端的高频流式 body,在 Riverpod 之外(CoalescingNotifier)——stderr/token 风暴下 body 每帧最多重画一次、
/// 不搅生命周期态。各 kind:fn/hd 把 run 节点 delta 追加到 text;agent 把块帧折进 tree;workflow 把实时
/// flowrun tick 盖进 liveNodes(durable 列表在 state)。
class RunStream {
  final BlockTreeReducer tree = BlockTreeReducer();
  final StringBuffer _text = StringBuffer();
  final Map<String, String> liveNodes =
      {}; // nodeId → status (workflow live ticks) 工作流实时节点状态

  String get text => _text.toString();
  void appendText(String s) => _text.write(s);

  void reset() {
    tree.clear();
    _text.clear();
    liveNodes.clear();
  }
}

/// The right-island run terminal — wires the four verb CTAs (`:run`/`:call`/`:invoke`/`:trigger`) to the
/// repository execute methods and renders the live output. The lifecycle ([RunTerminalState]) lives in
/// this [Notifier]; the streamed body lives in [stream] (a [CoalescingNotifier]). The terminal subscribes
/// to the entity's panel SSE scope BEFORE issuing the execute call, so the live stderr / ReAct-trace /
/// flowrun ticks that fire DURING execution are captured. The sync verbs (`:run`/`:call`/`:invoke`)
/// return the bare result in the HTTP response (the entities-stream close carries no body for fn/hd — the
/// HTTP result + DB row are the truth); `:trigger` is async (202 → flowrunId), then the durable node list
/// is re-fetched (GET /flowruns/{id}). Cancel ABANDONS the UI wait (sync verbs aren't abortable here; the
/// backend run continues + lands its audit row).
///
/// 右岛 run 终端——把四个动词 CTA 接到 repository execute 方法、渲实时输出。生命周期在本 Notifier、流式 body
/// 在 stream(CoalescingNotifier)。先订实体面板 SSE scope 再发执行,捕获执行期实时帧。同步动词裸结果在 HTTP
/// 响应里(fn/hd 的 entities close 不带 body,HTTP 结果 + DB 行才是真相);:trigger 异步(202→flowrunId),
/// 再重取 durable 节点列表。Cancel 放弃前端等待(同步动词此处不可中止,后端继续跑完落审计行)。
class RunTerminalController extends Notifier<RunTerminalState> {
  late EntityRepository _repo;
  StreamSubscription<StreamEnvelope>? _panelSub;
  StreamScope? _scope;

  final CoalescingNotifier<RunStream> stream = CoalescingNotifier(RunStream());

  @override
  RunTerminalState build() {
    _repo = ref.watch(entityRepositoryProvider);
    ref.onDispose(() {
      _panelSub?.cancel();
      stream.dispose();
    });
    return const RunTerminalState();
  }

  /// Open the terminal for [target] in idle (the input form). Resets the body; (re)subscribes the panel
  /// scope. If a run for the SAME entity is already in flight, just reveal it. 为目标打开终端(idle 表单)。
  void openFor(EntityRef target) {
    if (state.ref == target && state.isRunning) {
      state = state.copyWith(open: true);
      return;
    }
    _ensurePanel(target);
    stream.mutate((s) => s..reset());
    state = RunTerminalState(open: true, ref: target, runSeq: state.runSeq);
  }

  /// Hide the right island (keeps the bound entity so re-opening is instant). 收起右岛(保留绑定)。
  void close() => state = state.copyWith(open: false);

  void _ensurePanel(EntityRef target) {
    final scope = target.kind.scope(target.id);
    if (_scope == scope && _panelSub != null) return;
    _panelSub?.cancel();
    _scope = scope;
    _panelSub = _repo.panelSignals(scope).listen(_onPanel);
  }

  /// Execute the verb for the bound entity with [request] (the typed form result; [method] only for
  /// handler). Captures execution-time stream frames; finalizes from the result. 执行绑定实体的动词。
  Future<void> run({
    required Map<String, Object?> request,
    String method = '',
  }) async {
    final target = state.ref;
    if (target == null) return;
    _ensurePanel(target);
    final seq = state.runSeq + 1;
    stream.mutate((s) => s..reset());
    state = state.copyWith(
      phase: RunPhase.running,
      request: request,
      method: method,
      runSeq: seq,
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
      switch (target.kind) {
        case EntityKind.function:
          final r = await _repo.runFunction(target.id, args: args);
          if (state.runSeq != seq) return;
          state = state.copyWith(
            phase: r.ok ? RunPhase.ok : RunPhase.failed,
            output: r.output,
            errorMsg: r.errorMsg.isEmpty ? null : r.errorMsg,
            elapsedMs: r.elapsedMs,
            logs: r.logs,
          );
        case EntityKind.handler:
          final r = await _repo.callHandler(
            target.id,
            method: method,
            args: args,
          );
          if (state.runSeq != seq) return;
          state = state.copyWith(phase: RunPhase.ok, output: r);
        case EntityKind.agent:
          final r = await _repo.invokeAgent(target.id, input: args);
          if (state.runSeq != seq) return;
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
          final flowrunId = await _repo.triggerWorkflow(
            target.id,
            payload: request.isEmpty ? null : args,
          );
          if (state.runSeq != seq) return;
          state = state.copyWith(flowrunId: flowrunId);
          final comp = await _repo.getFlowrun(flowrunId);
          if (state.runSeq != seq) return;
          final failed = comp.flowrun.status == 'failed';
          state = state.copyWith(
            phase: failed ? RunPhase.failed : RunPhase.ok,
            flowNodes: comp.nodes,
            errorMsg: comp.flowrun.error,
          );
      }
    } on ApiException catch (e) {
      if (state.runSeq != seq) return;
      state = state.copyWith(
        phase: RunPhase.failed,
        errorCode: e.code,
        errorMsg: e.message,
      );
    } catch (e) {
      if (state.runSeq != seq) return;
      state = state.copyWith(phase: RunPhase.failed, errorMsg: e.toString());
    }
  }

  /// Abandon the UI-side wait (the in-flight result is dropped via the seq bump; sync verbs aren't
  /// abortable here, so the backend run still completes + records its audit row). 放弃前端等待。
  void cancel() => state = state.copyWith(
    phase: RunPhase.cancelled,
    runSeq: state.runSeq + 1,
  );

  void _onPanel(StreamEnvelope env) {
    final kind = state.ref?.kind;
    if (kind == null) return;
    switch (kind) {
      // fn/hd: the entities `run` node's deltas are the live stderr / method-yield text. fn/hd 实时输出。
      case EntityKind.function:
      case EntityKind.handler:
        final f = env.frame;
        if (f is FrameDelta) stream.mutate((s) => s..appendText(f.chunk));
      // agent: fold the messages-block frames (text/reasoning/tool_call/tool_result) into the tree. agent 树。
      case EntityKind.agent:
        stream.mutate((s) => s..tree.apply(env));
      // workflow: an ephemeral signal {flowrunId,nodeId,iteration,status} → live node status. wf 实时节点。
      case EntityKind.workflow:
        final f = env.frame;
        if (f is FrameSignal) {
          final c = f.node.content;
          final nodeId = c?['nodeId'] as String?;
          final status = c?['status'] as String?;
          if (nodeId != null && status != null) {
            stream.mutate((s) => s..liveNodes[nodeId] = status);
          }
        }
    }
  }
}

/// The single run-terminal controller (one right island). The shell watches `open`; the terminal watches
/// the rest + `controller.stream`. 唯一 run 终端控制器(一个右岛)。
final runTerminalProvider =
    NotifierProvider<RunTerminalController, RunTerminalState>(
      RunTerminalController.new,
    );
