import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/entities/values.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/perf/coalescing_notifier.dart';
import '../../../../core/sse/frame.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../detail/entity_detail_provider.dart';
import '../selected_entity.dart';
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

  /// The current form input (raw values: String for text/number/object/array, bool for boolean), kept off
  /// [state] so typing never rebuilds the lifecycle. Persists per entity (family + keepAlive). 当前表单草稿。
  final Map<String, Object?> draft = {};

  @override
  RunTerminalState build() {
    _repo = ref.watch(entityRepositoryProvider);
    _panelSub = _repo.panelSignals(entityRef.kind.scope(entityRef.id)).listen(_onPanel);
    ref.onDispose(() {
      _panelSub?.cancel();
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
          final comp = await _repo.getFlowrun(flowrunId);
          if (!ref.mounted || state.runSeq != seq) return;
          state = state.copyWith(
            phase: comp.flowrun.status == 'failed' ? RunPhase.failed : RunPhase.ok,
            flowNodes: comp.nodes,
            errorMsg: comp.flowrun.error,
          );
      }
    } on ApiException catch (e) {
      if (!ref.mounted || state.runSeq != seq) return;
      state = state.copyWith(phase: RunPhase.failed, errorCode: e.code, errorMsg: e.message);
    } catch (e) {
      if (!ref.mounted || state.runSeq != seq) return;
      state = state.copyWith(phase: RunPhase.failed, errorMsg: e.toString());
    } finally {
      // Release the keep-alive once THIS run is the settled current one — a superseding run (seq bumped)
      // or a cancel keeps/handles it. Guarded by mounted so we never read state on a disposed notifier.
      // 本运行为当前且收尾才释放(被新运行接管/被 cancel 则另行处理);mounted 守卫防读已释放 notifier 的 state。
      if (ref.mounted && state.runSeq == seq) {
        _releaseRun?.call();
        _releaseRun = null;
      }
    }
  }

  /// Abandon the UI-side wait (the in-flight result is dropped via the seq bump; the backend run still
  /// completes + records its audit row). Releases the keep-alive — the bumped seq makes the in-flight
  /// run's `finally` skip its own release, so cancel owns it. 放弃前端等待(后端续跑落审计行);释放 keepAlive。
  void cancel() {
    state = state.copyWith(phase: RunPhase.cancelled, runSeq: state.runSeq + 1);
    _releaseRun?.call();
    _releaseRun = null;
  }

  // Coerce the draft into the request by the entity's declared field types. workflow = one optional JSON
  // payload; fn/ag/hd = per-field (object/array via jsonDecode, surfacing a parse error). 草稿→请求强转。
  (Map<String, Object?>, String?) _coerce() {
    final detail = ref.read(entityDetailProvider(entityRef)).value;
    if (entityRef.kind == EntityKind.workflow) {
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
      case EntityKind.function:
      case EntityKind.handler:
        final f = env.frame;
        if (f is FrameDelta) stream.mutate((s) => s..appendText(f.chunk));
      case EntityKind.agent:
        stream.mutate((s) => s..tree.apply(env));
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

/// One run-terminal controller PER executable entity (autoDispose family) — freed when the entity is
/// deselected UNLESS a run is in flight (which pins it via keepAlive, so it streams in the background).
/// The right island shows the SELECTED entity's controller. 每可执行实体一个 controller(autoDispose family);
/// 选区移开即释放,除非有运行在 keepAlive 钉住(后台续流)。
final runTerminalProvider =
    NotifierProvider.autoDispose.family<RunTerminalController, RunTerminalState, EntityRef>(
        RunTerminalController.new);
