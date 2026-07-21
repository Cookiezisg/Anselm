import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/interaction.dart';
import '../../../core/sse/frame.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';

/// One conversation's session memory of a single human-loop interaction — the awaiting request plus,
/// if it was decided IN THIS SESSION, the action taken. `decided != null` freezes it: the gate shows
/// the decision章 (provenance), not live buttons. The distinction matters because the resolution SIGNAL
/// carries no action — only a LOCAL resolve knows what was chosen, and cold history (a reload, broker
/// forgot) can reconstruct deny/decline/cancel from tool_result prose but NOT approve (族律3).
///
/// 一个会话对单个人在环交互的会话级记忆:待决请求 + (若本会话内已决)所采取动作。decided≠null 即冻结:
/// 门显决议章(出处凭据)、非活按钮。resolved 信号不带动作——只有**本地**决议知道选了什么;冷历史(重载、
/// broker 已忘)能从 tool_result 散文重建 deny/decline/cancel、但重建不出 approve(族律3)。
class InteractionRecord {
  const InteractionRecord({required this.interaction, this.decided});

  final Interaction interaction;

  /// The action taken THIS session (null = still awaiting the user). 本会话所采动作(null=仍待用户)。
  final InteractionAction? decided;

  /// Still needs the user — the gate renders live (buttons + fail-safe). 仍需用户:门渲活态。
  bool get isAwaiting => decided == null && interaction.isAwaiting;

  InteractionRecord freeze(InteractionAction action) =>
      InteractionRecord(interaction: interaction, decided: action);
}

/// The three-source truth of ONE conversation's human-loop interactions (WRK-056 F16 §族律4), keyed by
/// toolCallId: the EPHEMERAL `interaction` signal (live) ⊕ the `GET interactions` reconnect snapshot ⊕
/// the symmetric `resolved` signal. It is the state base the danger gate / ask card / rail amber dot all
/// derive from. autoDispose family by conversationId — leaving the thread frees the subscription; a
/// send/stream in flight is pinned by the transcript controller, not here.
///
/// 一个会话人在环交互的**三源合一**真相(按 toolCallId 键):ephemeral interaction 信号(live)⊕ GET
/// interactions 重连快照 ⊕ resolved 对称信号。危险门 / ask 卡 / rail 琥珀点皆由此派生。autoDispose family
/// by conversationId——切走即释放订阅。
class PendingInteractionsController
    extends Notifier<Map<String, InteractionRecord>> {
  PendingInteractionsController(this.conversationId);

  final String conversationId;

  late ChatRepository _repo;
  StreamSubscription<StreamEnvelope>? _sub;
  StreamSubscription<void>? _resyncSub;

  @override
  Map<String, InteractionRecord> build() {
    _repo = ref.watch(chatRepositoryProvider);
    // Subscribe BEFORE the snapshot fetch so a signal landing mid-fetch is never lost (the merge in
    // _reconcile keeps live signals over a stale snapshot row). 订阅先于快照:取窗内信号不丢。
    _sub = _repo.conversationFrames(conversationId).listen(_onFrame);
    // A mid-session 410 resync evicts the messages buffer past our cursor — the EPHEMERAL `interaction`
    // signals (seq=0, unbuffered) that arrived in the disconnect window are gone, so a danger/ask gate
    // raised then would never render and the turn would stay blocked forever. Re-fetch `GET interactions`
    // + RECONCILE (add new + prune phantoms) on every resync. 断线重连:窗内 ephemeral 交互信号丢 → 重拉
    // GET interactions 对账(增新 + 删幻影),否则门永不显、回合永阻塞。
    _resyncSub = _repo.transcriptResync().listen(
      (_) => unawaited(_reconcile(prune: true)),
    );
    ref.onDispose(() {
      _sub?.cancel();
      _resyncSub?.cancel();
    });
    unawaited(_reconcile());
    return const {};
  }

  /// Fetch the authoritative `GET interactions` snapshot and merge it in. Additive on cold seed; on a
  /// reconnect ([prune] = true) it also REMOVES local AWAITING records the snapshot no longer lists
  /// (resolved / timed-out during the disconnect — phantom gates), while KEEPING locally-decided (frozen)
  /// records (the provenance章 outlives the snapshot). 拉权威快照并入:冷启只增;重连还删幻影待决(保已决章)。
  Future<void> _reconcile({bool prune = false}) async {
    try {
      final pending = await _repo.listInteractions(conversationId);
      if (!ref.mounted) return;
      final authoritative = {for (final it in pending) it.toolCallId: it};
      final next = {...state};
      for (final entry in authoritative.entries) {
        // A live signal / locally-decided record for this toolCallId wins over the snapshot row. 已有优先。
        if (!next.containsKey(entry.key)) {
          next[entry.key] = InteractionRecord(interaction: entry.value);
        }
      }
      if (prune) {
        next.removeWhere(
          (id, rec) => rec.decided == null && !authoritative.containsKey(id),
        );
      }
      state = next;
    } catch (_) {
      /* snapshot best-effort — live signals still flow 快照尽力,live 仍流 */
    }
  }

  void _onFrame(StreamEnvelope env) {
    final frame = env.frame;
    if (frame is! FrameSignal || frame.node.type != 'interaction') return;
    final content = frame.node.content;
    if (content == null) return;
    final it = Interaction.fromJson(content);
    if (it.toolCallId.isEmpty) return;
    if (it.resolved) {
      // Resolution signal (no action). If WE decided it, keep the frozen章 (this is our own echo);
      // otherwise (another window / broker) drop it — the tool_result phase takes over.
      // 决议信号(无动作)。本地已决→保冻结章(自身回声);否则(别处/broker)移除,交 tool_result 相位接管。
      final existing = state[it.toolCallId];
      if (existing != null && existing.decided == null) {
        state = {...state}..remove(it.toolCallId);
      }
      return;
    }
    // A fresh pending gate. Don't clobber a record already decided this session. 新待决门,不盖本会话已决记录。
    if (state[it.toolCallId]?.decided != null) return;
    state = {...state, it.toolCallId: InteractionRecord(interaction: it)};
  }

  /// Resolve an awaiting interaction — OPTIMISTIC freeze (the gate flips to the decision章 now), then
  /// POST. fail-safe: on POST failure the record is restored to awaiting so the user can retry (nothing
  /// executed server-side without an explicit approve). Missing/unknown record → no-op.
  /// 决议一个待决交互——乐观冻结(门即刻翻决议章)再 POST;fail-safe:POST 失败复原待决供重试(未显式 approve
  /// 后端不执行)。无记录→空操作。
  Future<void> resolve(
    String toolCallId,
    InteractionAction action, {
    String? answer,
  }) async {
    final prev = state[toolCallId];
    if (prev == null || prev.decided != null) return; // not awaiting 无待决
    state = {...state, toolCallId: prev.freeze(action)};
    try {
      await _repo.resolveInteraction(
        conversationId,
        toolCallId,
        action: action,
        answer: answer,
      );
    } catch (e) {
      if (ref.mounted) {
        state = {
          ...state,
          toolCallId: prev,
        }; // restore awaiting (fail-safe) 复原待决
      }
      rethrow;
    }
  }
}

/// The three-source interaction truth for a conversation (keyed by toolCallId). 会话级三源交互真相。
final pendingInteractionsProvider = NotifierProvider.autoDispose
    .family<
      PendingInteractionsController,
      Map<String, InteractionRecord>,
      String
    >(PendingInteractionsController.new);
