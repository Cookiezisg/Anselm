import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/messages/block_content.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/sse/frame.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../model/conversation_transcript.dart';
import '../model/stage_director.dart';
import '../model/tool_card_state.dart';
import '../../../core/run/flowrun_progress.dart';
import 'conversation_stream_provider.dart';
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
  // G5/A1-8④ — the old single map stored a tool NAME then overwrote it with a workflowId (dual
  // meaning told apart by string comparison). Split honestly. G5:旧单 map 先存工具名再覆写
  // workflowId、靠字符串比对区分双义——诚实拆分。
  final Set<String> _pollCalls = {}; // poll-lifecycle blockIds
  final Map<String, String> _pollWorkflow = {}; // blockId → workflowId
  final Map<String, String> _pollFlowrun =
      {}; // blockId → flowrunId (from the receipt)
  final Map<String, StreamSubscription<StreamEnvelope>> _terminalSubs = {};
  // A tool_call closes when the model has finished its argument stream; that is NOT the execution
  // terminal. The backend opens its tool_result at actual execution start and closes it at the real
  // terminal, so remember that child → parent linkage here. 参流 Close≠执行终态；真实执行由 tool_result
  // open→close 围住，记住 child→parent 才能让侧幕一直留在现场。
  final Map<String, String> _executionParents = {};
  // G4/A1-17 — nested child block → its owning TOP-LEVEL tool_call, built transitively at open time
  // (tool_result under the call, progress under the result, a delegate's nested tree). Execution
  // progress then feeds the OWNER's activity clock; the old per-id onActivity no-opped on children,
  // so an actively executing subject read as idle and lost arbitration. [_tracked] = stage-worthy
  // top-level calls (kept until their execution terminal — a tool_result opens AFTER the call
  // closes). G4:子块→属主顶层 tool_call(开帧时传递构建);执行 progress 喂回属主活性钟——旧径按
  // 子块 id no-op,执行中的主角被判静默丢台。_tracked=登台闭表内顶层调用(留到执行终态)。
  final Map<String, String> _ownerOf = {};
  // blockId → tool name for stage-worthy TOP-LEVEL calls (G7: the name gates the name-addressed
  // itemId whitelist at close time). 顶层调用账本(id→工具名;G7 关帧名寻址白名单要用名)。
  final Map<String, String> _tracked = {};
  static final _flowrunRe = RegExp(r'"flowrunId"\s*:\s*"([^"]{1,64})"');
  static final _workflowRe = RegExp(r'"workflowId"\s*:\s*"([^"]{1,64})"');

  CoalescingNotifier<ConversationTranscript>? _tx;

  /// Re-ground whenever the transcript's SUBAGENT EPOCH moves — it bumps exactly on the rare
  /// re-grounding moments (hydration/resync window turnover via setHistory/dropLive, subagent
  /// open/close) and never per delta (S7), so the walk stays off the hot path. This covers cold
  /// start (hydration carries in-flight tool_calls the stream will never re-open, A2-10) AND every
  /// 410 gap (a swallowed close otherwise leaves an eternal «Live» ghost, A1-5).
  /// G5:按 subagentEpoch 变化重新接地——它恰在稀有的接地时刻自增(水化/重同步换窗、分身开合),
  /// 绝不逐 delta(S7),全树走查不进热路;同时覆盖冷启动在飞种子与 410 幽灵。
  int _lastRealignEpoch = -1;

  @override
  StageState build() {
    // Re-entry hygiene (G5/A1-15): a re-run of build() must not leak the previous run's
    // subscriptions / timer / bookkeeping — the old code overwrote them in place (double-fed
    // frames, stacked disposals). 重入卫生:build 重跑先清上一轮的订阅/闹钟/账本。
    _sub?.cancel();
    _timer?.cancel();
    for (final sub in _terminalSubs.values) {
      sub.cancel();
    }
    _terminalSubs.clear();
    _pollCalls.clear();
    _pollWorkflow.clear();
    _pollFlowrun.clear();
    _executionParents.clear();
    _ownerOf.clear();
    _tracked.clear();
    _tx?.removeListener(_onTranscript);
    _lastRealignEpoch = -1;

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
    final tx = ref
        .read(conversationStreamProvider(conversationId).notifier)
        .transcript;
    _tx = tx;
    tx.addListener(_onTranscript);
    ref.onDispose(() {
      _sub?.cancel();
      _timer?.cancel();
      _tx?.removeListener(_onTranscript);
      for (final sub in _terminalSubs.values) {
        sub.cancel();
      }
    });
    return _director.state;
  }

  void _onTranscript() {
    if (!ref.mounted) return;
    final epoch = _tx?.value.subagentEpoch ?? -1;
    if (epoch == _lastRealignEpoch) return;
    _lastRealignEpoch = epoch;
    _realign();
  }

  /// G5 — the director's ONE re-grounding path («DB 行是真相、流只为实时»): the transcript decides
  /// which stage-worthy top-level tool_calls are still executing; everything else the director
  /// holds is a ghost whose terminal a stream gap swallowed — cleared; anything missing (an
  /// in-flight call seeded by hydration) re-earns the stage through the normal debounce.
  /// G5 重新接地:transcript 判定哪些顶层调用仍在执行;导演器多出的=缺口吞了终态的幽灵,清;
  /// 缺少的=水化种进来的在飞调用,走正常防抖重新登台。
  void _realign() {
    final tx = _tx?.value;
    if (tx == null) return;
    final now = DateTime.now();
    final live = <String, String>{}; // blockId → tool name
    void consider(BlockNode b) {
      if (b.kind != BlockKind.toolCall) return;
      final name = b.name ?? '';
      if (stageRouteOf(name) == null) return;
      final ph = ToolCardState.of(b).phase;
      final executing =
          ph == ToolCardPhase.argsStreaming ||
          ph == ToolCardPhase.running ||
          ph == ToolCardPhase.awaitingConfirm;
      if (executing) live[b.id] = name;
    }

    // Walk EVERY live root: message turns carry their tool_call children, and a defensive orphan
    // tool_call root is still stream truth. 走查全部 live 根:回合带子块,孤儿根也是流真相。
    for (final root in tx.liveRoots) {
      if (root.kind == BlockKind.message) {
        root.children.forEach(consider);
      } else {
        consider(root);
      }
    }
    _director.onRealign(live.keys.toSet(), now);
    for (final e in live.entries) {
      _tracked[e.key] = e.value;
      _director.onToolOpen(
        e.key,
        e.value,
        now,
      ); // idempotent on known ids 已知 id 幂等
    }
    _publish();
  }

  @override
  bool updateShouldNotify(StageState previous, StageState next) =>
      previous != next;

  void _onFrame(StreamEnvelope env) {
    final now = DateTime.now();
    switch (env.frame) {
      case FrameOpen(:final node, :final parentId)
          when node.type == 'tool_call':
        // G6/A1-7 — a delegate's INNER tool_call (nested anywhere under a tracked top-level call)
        // must NOT enter the director: on the priority ladder it out-ranked its own Subagent
        // (build > execution > subagent), stole the stage mid-broadcast, minted phantom rows and
        // lit R-15. It feeds the owner's activity clock instead; a top-level call's parent is the
        // assistant message root, which maps to no owner, so it passes untouched.
        // G6:分身体内工具不入导演器——旧行为按优先级反超自家分身抢台、造幻影行、点亮 R-15;
        // 改喂属主活性钟。顶层调用的父=回合根,映不到属主,原路放行。
        if (parentId != null) {
          final owner = _tracked.containsKey(parentId)
              ? parentId
              : _ownerOf[parentId];
          if (owner != null) {
            _ownerOf[env.id] = owner;
            _director.onActivity(owner, now);
            return;
          }
        }
        final name = (node.content?['name'] as String?) ?? '';
        if (stageRouteOf(name) != null) _tracked[env.id] = name;
        if (stageRouteOf(name)?.lifecycle == LifecycleSource.poll) {
          _pollCalls.add(env.id);
        }
        _director.onToolOpen(env.id, name, now);
      case FrameOpen(:final node, :final parentId)
          when node.type == 'tool_result' && parentId != null:
        // Since the execution-lifecycle upgrade this OPEN is emitted BEFORE dispatch, with an empty
        // body. Keep legacy compatibility too: older servers carried the receipt body on OPEN.
        // 执行生命周期升级后此 Open 在 dispatch 前、正文为空；同时兼容旧服务器（回执正文在 Open）。
        _executionParents[env.id] = parentId;
        if (_tracked.containsKey(parentId)) _ownerOf[env.id] = parentId;
        final body = '${node.content?['content'] ?? ''}';
        final m = _flowrunRe.firstMatch(body);
        if (m != null && _pollCalls.contains(parentId)) {
          _pollFlowrun[parentId] = m.group(1)!;
        }
        _director.onActivity(parentId, now);
      case FrameOpen(:final parentId) when parentId != null:
        // Any other nested child (progress under the result, a delegate's message/reasoning tree):
        // inherit the owner transitively and count the open as the owner's activity (G4/A1-17).
        // 其余嵌套子块传递继承属主,开帧计属主活性。
        final owner = _tracked.containsKey(parentId)
            ? parentId
            : _ownerOf[parentId];
        if (owner != null) {
          _ownerOf[env.id] = owner;
          _director.onActivity(owner, now);
        }
        return;
      case FrameDelta():
        // A delta only bumps unread (excluded from StageState equality, C-003) + lastActivityAt (not
        // on the published view) — it NEVER changes the published state and no DEADLINE depends on
        // it either, so the old per-delta timer re-arm was pure churn (G4: hundreds of Timer
        // cancel+creates per second for nothing). Children route to their owning call (A1-17).
        // delta 只记活性:不发布、无期限依赖——旧径每 delta 白拆装一次闹钟;子块路由到属主。
        _director.onActivity(_ownerOf[env.id] ?? env.id, now);
        return;
      case FrameClose(:final status, :final result):
        _ownerOf.remove(
          env.id,
        ); // closed children take no more deltas 已关子块不再来 delta
        final parent = _executionParents.remove(env.id);
        if (parent != null) {
          _tracked.remove(
            parent,
          ); // execution terminal — the call's bookkeeping retires 执行终态退账
          // The tool_result close is the ONE true execution terminal. Its durable snapshot is also
          // where a poll receipt's flowrun id now lives. tool_result Close 才是真正执行终态；其耐久快照
          // 同时承载 poll 回执的 flowrun id。
          final ok = status != 'error' && status != 'cancelled';
          final body = '${result?.content?['content'] ?? ''}';
          // G7/A2-11 — the CREATE receipt carries the newborn's REAL id: resolving it here merges
          // the synthetic live row with the touchpoint ledger row the moment it lands (the old
          // display-name fallback minted `function:<名字>` keys that never matched `function:fn_…`
          // — one entity, two rows forever). G7:创建回执带真身 id,在此解出即与台账行合流——旧显示名
          // 兜底铸出永不合并的键,同一实体永久双行。
          if (ok) {
            final rid = _receiptID(body);
            if (rid != null) _director.onItemResolved(parent, rid);
          }
          final m = _flowrunRe.firstMatch(body);
          if (m != null && _pollCalls.contains(parent)) {
            _pollFlowrun[parent] = m.group(1)!;
          }
          // G5/A1-8②: only a SUCCESSFUL dispatch earns a terminal watch — watching after an
          // error/cancel would let an UNRELATED run's first terminal «settle» the wreck (the
          // receipt carries no flowrunId to match). 只有成功派发才装终态监听——错误/取消后装表,
          // 会被同工作流无关 run 的终态洗白现场。
          final workflowID = ok && _pollCalls.contains(parent)
              ? _pollWorkflow[parent]
              : null;
          if (workflowID != null) {
            _watchTerminal(parent, workflowID);
          } else if (!ok) {
            _pollCalls.remove(parent);
            _pollWorkflow.remove(parent);
            _pollFlowrun.remove(parent);
          }
          _director.onToolClose(parent, now, ok: ok);
          break;
        }

        // The tool-call close only completes argument streaming. Resolve a stable target NOW, before
        // any stage body happens to be expanded; parallel calls to the same target can therefore share
        // one right-island row immediately. 参数流收束时即解析稳定目标，不依赖某张卡是否展开；同目标并行调用可立即合行。
        final args = '${result?.content?['arguments'] ?? ''}';
        final target = _primaryTargetID(_tracked[env.id] ?? '', args);
        if (target != null) _director.onItemResolved(env.id, target);
        if (_pollCalls.contains(env.id)) {
          final m = _workflowRe.firstMatch(args);
          if (m != null) _pollWorkflow[env.id] = m.group(1)!;
        }
        if (status == 'error' || status == 'cancelled') {
          // The model stream itself aborted, so no execution child will ever arrive. 模型流中止，无执行子节点可等。
          _director.onToolClose(env.id, now, ok: false);
        }
      default:
        return;
    }
    _publish();
  }

  /// Extract the conventional entity-id keys from a closed tool-call snapshot — TOP-LEVEL keys only
  /// (G7/A3-7: a deep search false-hit workflow ops' node/edge `id`s and forged `workflow:n1` row
  /// keys). Creates have no durable target before their receipt ([_receiptID] resolves that at the
  /// execution terminal); a NAME is an identity only for the name-addressed kinds (skill / memory /
  /// mcp — their ledger rows key by name), never a general fallback (A2-11).
  /// 只取顶层常规键(深搜会被 workflow ops 节点 id 假命中);创建等回执;名字只对名寻址 kind 是身份
  /// (skill/memory/mcp 台账即按名建键),绝非通用兜底。
  static const _nameAddressed = {
    'create_skill',
    'edit_skill',
    'write_memory',
    'install_mcp_server',
  };
  static String? _primaryTargetID(String toolName, String raw) {
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
      if (_nameAddressed.contains(toolName)) {
        final n = value['name'];
        if (n is String && n.isNotEmpty) return n;
      }
    } catch (_) {
      // A malformed LLM call still receives an honest tool result; it simply cannot join an entity row.
    }
    return null;
  }

  /// The created entity's id off an execution receipt body (top-level `id` only). 回执顶层 id。
  static String? _receiptID(String raw) {
    if (raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      if (v is Map) {
        final id = v['id'];
        if (id is String && id.isNotEmpty) return id;
      }
    } catch (_) {
      // Plain-text receipts (LLM prose) carry no id — the row stays block-keyed. 纯文本回执无 id。
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
      _pollCalls.remove(blockId);
      _pollWorkflow.remove(blockId);
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
  // G2: pin()/resume() retired with the camera lock — user ownership is the panel's row-level claim.
  // G2:pin/resume 随镜头锁退役——用户所有权=面板行级认领。

  /// Clear one activity's row — the failed-hold exit (G3). 行级清除(失败出口)。
  void clearActivity(String blockId) {
    _director.onClearActivity(blockId, DateTime.now());
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
