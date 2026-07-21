import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/sse/frame.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../model/stage_director.dart';
import '../../../core/run/flowrun_progress.dart';
import 'pending_interactions_provider.dart';

/// One conversation's stage director as a provider: projects the conversation's frame feed onto the
/// pure [StageDirector] (tool_call open/delta/close), threads the human-gate flag from
/// pendingInteractions, and schedules ONE timer for the machine's next deadline. Timer firings advance
/// the machine TO THE DEADLINE (not wall-now) — deterministic under fake-async tests and immune to
/// callback lateness. [StageState]'s value equality suppresses no-op broadcasts (the on-stage
/// subject's own deltas change nothing here — its content rides the transcript coalescer).
///
/// 导演器宿主:把会话帧流投影到纯状态机(open/delta/close),从 pendingInteractions 接人闸旗,按机器的
/// nextDeadline 排唯一闹钟。到点 advance(到期时刻)而非墙钟——fakeAsync 下确定、免回调迟到漂移。
/// StageState 值相等抑制无效广播(主角自身 delta 不惊动 watcher,内容走 transcript coalescer)。
class StageDirectorController extends Notifier<StageState> {
  StageDirectorController(this.conversationId);

  final String conversationId;

  late StageDirector _director;
  late ChatRepository _repo;
  StreamSubscription<StreamEnvelope>? _sub;
  Timer? _timer;

  // R-10 retirement bookkeeping: a poll-type stage (trigger_workflow) holds past its 202 close
  // until the flowrun's DURABLE run_terminal signal arrives on the entities stream (W6 backend).
  // The tool name is kept from the open, the workflowId parsed from the close's args, the
  // flowrunId from the enqueue receipt — the terminal is matched by flowrunId, never guessed.
  // R-10 退役记账:poll 型舞台在 202 关帧后驻留,直到 flowrun 的 durable run_terminal 信号到达
  // (W6 后端)。工具名留自 open、workflowId 解自关帧 args、flowrunId 解自入队回执——终态按
  // flowrunId 匹配,绝不猜。
  final Map<String, String> _pollBlocks = {}; // blockId → tool name
  final Map<String, String> _pollFlowrun =
      {}; // blockId → flowrunId (from the receipt)
  final Map<String, StreamSubscription<StreamEnvelope>> _terminalSubs = {};
  // A tool_call closes when the model has finished its argument stream; that is NOT the execution
  // terminal. The backend opens its tool_result at actual execution start and closes it at the real
  // terminal, so remember that child → parent linkage here. 参流 Close≠执行终态；真实执行由 tool_result
  // open→close 围住，记住 child→parent 才能让侧幕一直留在现场。
  final Map<String, String> _executionParents = {};
  final Set<String> _awaitingExecution = {};
  static final _flowrunRe = RegExp(r'"flowrunId"\s*:\s*"([^"]{1,64})"');
  static final _workflowRe = RegExp(r'"workflowId"\s*:\s*"([^"]{1,64})"');

  @override
  StageState build() {
    final repo = ref.watch(chatRepositoryProvider);
    _repo = repo;
    _director = StageDirector(followMode: ref.read(followModeProvider));
    ref.listen<FollowMode>(
      followModeProvider,
      (_, mode) => _director.followMode = mode,
    );
    ref.listen(pendingInteractionsProvider(conversationId), (_, records) {
      _director.onGateWaiting(records.values.any((r) => r.isAwaiting));
      _publish();
    });
    _sub = repo.conversationFrames(conversationId).listen(_onFrame);
    ref.onDispose(() {
      _sub?.cancel();
      _timer?.cancel();
      for (final sub in _terminalSubs.values) {
        sub.cancel();
      }
    });
    return _director.state;
  }

  @override
  bool updateShouldNotify(StageState previous, StageState next) =>
      previous != next;

  void _onFrame(StreamEnvelope env) {
    final now = DateTime.now();
    switch (env.frame) {
      case FrameOpen(:final node) when node.type == 'tool_call':
        final name = (node.content?['name'] as String?) ?? '';
        if (stageRouteOf(name)?.lifecycle == LifecycleSource.poll) {
          _pollBlocks[env.id] = name;
        }
        _director.onToolOpen(env.id, name, now);
      case FrameOpen(:final node, :final parentId)
          when node.type == 'tool_result' && parentId != null:
        // Since the execution-lifecycle upgrade this OPEN is emitted BEFORE dispatch, with an empty
        // body. Keep legacy compatibility too: older servers carried the receipt body on OPEN.
        // 执行生命周期升级后此 Open 在 dispatch 前、正文为空；同时兼容旧服务器（回执正文在 Open）。
        _executionParents[env.id] = parentId;
        final body = '${node.content?['content'] ?? ''}';
        final m = _flowrunRe.firstMatch(body);
        if (m != null && _pollBlocks.containsKey(parentId)) {
          _pollFlowrun[parentId] = m.group(1)!;
        }
        _director.onActivity(parentId, now);
      case FrameDelta():
        // A delta only bumps unread (excluded from StageState equality, C-003) + lastActivityAt (not on
        // the published view) — it NEVER changes the published state. Skip the per-delta state
        // re-allocation (数百 delta/s × StageState + views, C-020); just re-arm the schedule since activity
        // pushes the dwell/switch deadlines. delta 不改已发布 state:跳重造分配,仅重排闹钟。
        _director.onActivity(env.id, now);
        _schedule();
        return;
      case FrameClose(:final status, :final result):
        final parent = _executionParents.remove(env.id);
        if (parent != null) {
          // The tool_result close is the ONE true execution terminal. Its durable snapshot is also
          // where a poll receipt's flowrun id now lives. tool_result Close 才是真正执行终态；其耐久快照
          // 同时承载 poll 回执的 flowrun id。
          final body = '${result?.content?['content'] ?? ''}';
          final m = _flowrunRe.firstMatch(body);
          if (m != null && _pollBlocks.containsKey(parent)) {
            _pollFlowrun[parent] = m.group(1)!;
          }
          final workflowID = _pollBlocks.containsKey(parent)
              ? _workflowIDFor(parent)
              : null;
          if (workflowID != null) {
            _watchTerminal(parent, workflowID);
          }
          _awaitingExecution.remove(parent);
          _director.onToolClose(
            parent,
            now,
            ok: status != 'error' && status != 'cancelled',
          );
          break;
        }

        // The tool-call close only completes argument streaming. Resolve a stable target NOW, before
        // any stage body happens to be expanded; parallel calls to the same target can therefore share
        // one right-island row immediately. 参数流收束时即解析稳定目标，不依赖某张卡是否展开；同目标并行调用可立即合行。
        final args = '${result?.content?['arguments'] ?? ''}';
        final target = _primaryTargetID(args);
        if (target != null) _director.onItemResolved(env.id, target);
        if (_pollBlocks.containsKey(env.id)) {
          final m = _workflowRe.firstMatch(args);
          if (m != null) _pollBlocks[env.id] = m.group(1)!;
        }
        if (status == 'error' || status == 'cancelled') {
          // The model stream itself aborted, so no execution child will ever arrive. 模型流中止，无执行子节点可等。
          _director.onToolClose(env.id, now, ok: false);
        } else {
          _awaitingExecution.add(env.id);
        }
      default:
        return;
    }
    _publish();
  }

  String? _workflowIDFor(String blockID) {
    final value = _pollBlocks[blockID];
    if (value == null || value == 'trigger_workflow') return null;
    return value;
  }

  /// Extract the conventional entity-id keys from a closed tool-call snapshot. Creates have no
  /// durable target before their receipt, so they intentionally remain distinct; runs/edits carry
  /// their target id and can be grouped before execution begins. 从关帧参数提取常规实体 id；创建在回执前没有
  /// 稳定目标，刻意各自独立；执行/编辑带目标 id，执行前即可聚合。
  static String? _primaryTargetID(String raw) {
    if (raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return null;
      for (final key in const [
        'functionId',
        'handlerId',
        'agentId',
        'workflowId',
        'triggerId',
        'id',
      ]) {
        final id = value[key];
        if (id is String && id.isNotEmpty) return id;
      }
    } catch (_) {
      // A malformed LLM call still receives an honest tool result; it simply cannot join an entity row.
    }
    return null;
  }

  /// Subscribe ONE workflow's entities frames for the held poll stage: node `run` ticks (matched
  /// by flowrunId) feed the live run-progress scroll, and the durable `run_terminal` settles the
  /// stage (R-10 retires). A missing receipt id falls back to first-terminal for the settle —
  /// better one honest settle than an eternal hold — but ticks NEVER guess (a wrong run's
  /// progress would be a lie; a missing scroll is only a gap).
  ///
  /// 为驻留的 poll 舞台订阅该 workflow 帧:节点 `run` tick(按 flowrunId 匹配)喂活进度卷,durable
  /// `run_terminal` 落定舞台(R-10 退役)。回执缺 id 时终态退化为先到先落——一次诚实落定胜过永久驻留;
  /// 但 tick **绝不猜**(错 run 的进度是谎言,缺卷只是缺口)。
  void _watchTerminal(String blockId, String workflowId) {
    _terminalSubs[blockId]?.cancel();
    final flowrunId = _pollFlowrun[blockId];
    if (flowrunId != null) {
      ref.read(flowrunProgressProvider(blockId).notifier).begin(flowrunId);
    }
    _terminalSubs[blockId] = _repo.workflowFrames(workflowId).listen((env) {
      final frame = env.frame;
      if (frame is! FrameSignal) return;
      final content = frame.node.content ?? const {};
      final wanted = _pollFlowrun[blockId];
      final frameRun = '${content['flowrunId'] ?? ''}';
      if (frame.node.type == 'run' && wanted != null && frameRun == wanted) {
        ref
            .read(flowrunProgressProvider(blockId).notifier)
            .tick(
              NodeTick(
                nodeId: '${content['nodeId'] ?? ''}',
                iteration: (content['iteration'] as num?)?.toInt() ?? 0,
                status: '${content['status'] ?? ''}',
                port: '${content['port'] ?? ''}',
              ),
            );
        return;
      }
      if (frame.node.type != 'run_terminal') return;
      if (wanted != null && frameRun != wanted) return;
      final status = '${content['status'] ?? ''}';
      ref.read(flowrunProgressProvider(blockId).notifier).terminal(status);
      _terminalSubs.remove(blockId)?.cancel();
      _pollBlocks.remove(blockId);
      _pollFlowrun.remove(blockId);
      _director.onRunTerminal(
        blockId,
        DateTime.now(),
        ok: status == 'completed',
      );
      _publish();
    });
  }

  // ── user-side inputs 用户侧 ──

  /// Take the camera (Cast row / channel tab / pin / in-stage interaction). 持镜。
  void pin({String? blockId}) {
    _director.onUserPin(DateTime.now(), blockId: blockId);
    _publish();
  }

  /// The follow pill / «回到直播». 交还镜头。
  void resume() {
    _director.onFollowResume(DateTime.now());
    _publish();
  }

  /// ✕ — close the stage. 收场。
  void dismiss() {
    _director.onDismiss(DateTime.now());
    _publish();
  }

  /// The stage resolved its subject's primary entity id (Cast pulse, R-6). 主目标 id 解出。
  void itemResolved(String blockId, String itemId) {
    _director.onItemResolved(blockId, itemId);
    _publish();
  }

  void _publish() {
    state = _director.state;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final due = _director.nextDeadline;
    if (due == null) return;
    final wait = due.difference(DateTime.now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      // Advance TO the deadline that made us fire — exact under fakeAsync, late-callback-proof live.
      // advance 到促发本闹钟的期限本身——fakeAsync 精确、真机免迟到漂移。
      final d = _director.nextDeadline;
      if (d != null) _director.advance(d);
      _publish();
    });
  }
}

/// One conversation's stage state (the sidestage's spine). autoDispose family — leaving the thread
/// releases the subscription + timer. 会话侧幕导演器;切走即释放。
final stageDirectorProvider = NotifierProvider.autoDispose
    .family<StageDirectorController, StageState, String>(
      StageDirectorController.new,
    );
