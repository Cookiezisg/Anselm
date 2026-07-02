import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../../../core/sse/frame.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../model/conversation_transcript.dart';
import '../model/mention_spans.dart';
import 'conversation_stream_state.dart';
import 'selected_conversation.dart';

/// The live pipeline of ONE open conversation (autoDispose family by id) — hydration, the frame fold,
/// optimistic sends, cancel, upward pagination, 410 resync, and the unread/:seen contract.
///
/// Correctness spine:
///  - **Subscribe → buffer → hydrate → drain.** The frame subscription starts BEFORE the REST fetch;
///    frames that land mid-fetch buffer and drain after [ConversationTranscript.setHistory] seeds any
///    in-flight turn — nothing is lost in the window, duplicate opens are idempotent no-ops.
///  - **The transcript rides a [CoalescingNotifier] recreated EVERY build** (a `final` one would be
///    disposed by a build-over and freeze bound ValueListenableBuilders — the documented pitfall); the
///    Riverpod [state] stays low-frequency (phase/paging only).
///  - **A send/streaming turn pins the controller** ([Ref.keepAlive]) so deselecting keeps it streaming
///    in the background; the pin releases when nothing is in flight.
///  - **410 resync**: drop the live layer, re-buffer, refetch the head (which re-seeds a still-running
///    turn), drain — deltas lost to the gap are gone by design (DB row is truth), interactions replay
///    lands with the human-loop slice.
///  - **:seen**: an assistant terminal while THIS thread is selected clears unread server-side
///    (idempotent 204); opening a thread does the same. Background completions never call it — that's
///    exactly the green dot's job.
///
/// 一个打开会话的 live 管道(autoDispose family)。正确性主轴:①订阅→缓冲→水化→泄流(取窗内不丢帧,重复 open
/// 幂等);②transcript 骑**每 build 重建**的 CoalescingNotifier(final 会被 build-over 释放→冻结绑定的 VLB,
/// 已记档的坑),Riverpod state 只留低频;③发送/流中回合 keepAlive 钉住(切走后台续流,无在飞即释放);
/// ④410:丢 live 层→再缓冲→重拉头(重种在飞回合)→泄流;⑤:seen:**选中时**的 assistant 终态清未读(幂等),
/// 后台完成绝不清——绿点正是干这个的。
class ConversationStreamController extends Notifier<ConversationStreamState> {
  ConversationStreamController(this.conversationId);

  final String conversationId;
  static const int _pageSize = 30;

  late ChatRepository _repo;

  /// The high-frequency transcript body — read it FRESH each widget build (`controller.transcript`), it
  /// is a new instance after a provider rebuild. 高频本体;widget 每 build 重取(重建后是新实例)。
  late CoalescingNotifier<ConversationTranscript> transcript;

  StreamSubscription<StreamEnvelope>? _frameSub;
  StreamSubscription<void>? _resyncSub;
  List<StreamEnvelope>? _prelude; // non-null ⇒ buffering until hydration lands 非空=水化前缓冲
  void Function()? _releasePin;
  int _localSeq = 0;
  int _hydrateSeq = 0;

  @override
  ConversationStreamState build() {
    _repo = ref.watch(chatRepositoryProvider);
    final coalescer = CoalescingNotifier(ConversationTranscript(conversationId));
    transcript = coalescer;
    _prelude = [];
    _frameSub = _repo.conversationFrames(conversationId).listen(_onFrame);
    _resyncSub = _repo.transcriptResync().listen((_) => _onResync());
    ref.onDispose(() {
      _frameSub?.cancel();
      _resyncSub?.cancel();
      coalescer.dispose(); // THIS build's instance — never a later one 本 build 的实例
      _releasePin?.call();
      _releasePin = null;
    });
    unawaited(_hydrate());
    return const ConversationStreamState();
  }

  // ── hydration 水化 ──

  Future<void> _hydrate() async {
    final seq = ++_hydrateSeq;
    try {
      final page = await _repo.listMessages(conversationId, limit: _pageSize);
      if (!ref.mounted || seq != _hydrateSeq) return;
      transcript.mutate((t) => t..setHistory(page.items));
      _drainPrelude();
      state = state.copyWith(
        phase: TranscriptPhase.ready,
        error: null,
        nextCursor: page.nextCursor,
        hasMoreOlder: !page.isLastPage,
      );
      _syncPin();
      // Opening a thread marks it seen (idempotent; clears the rail's green dot). 打开即清未读。
      if (_isSelected) unawaited(_quietlySeen());
    } catch (e) {
      if (!ref.mounted || seq != _hydrateSeq) return;
      state = state.copyWith(
        phase: TranscriptPhase.error,
        error: e is ApiException ? e.message : e.toString(),
      );
    }
  }

  /// Explicit retry from the error surface. 错误面的显式重试。
  Future<void> retryHydrate() async {
    if (!ref.mounted) return;
    state = state.copyWith(phase: TranscriptPhase.hydrating, error: null);
    _prelude ??= [];
    await _hydrate();
  }

  void _drainPrelude() {
    final buffered = _prelude;
    _prelude = null;
    if (buffered == null || buffered.isEmpty) return;
    transcript.mutate((t) {
      for (final env in buffered) {
        t.applyFrame(env);
      }
      return t;
    });
  }

  // ── the frame fold 帧折叠 ──

  void _onFrame(StreamEnvelope env) {
    final buffered = _prelude;
    if (buffered != null) {
      buffered.add(env);
      return;
    }
    transcript.mutate((t) => t..applyFrame(env));
    // Durable terminal of an assistant turn → maybe release the pin + clear unread (selected only).
    // assistant 回合 durable 终态 → 视情况释放 pin + 清未读(仅选中)。
    if (env.durable && env.frame is FrameClose) {
      final node = transcript.value.turns.where((n) => n.id == env.id).firstOrNull;
      if (node != null && ConversationTranscript.turnRole(node) == 'assistant') {
        _syncPin();
        if (_isSelected) unawaited(_quietlySeen());
      }
    }
  }

  void _onResync() {
    if (!ref.mounted) return;
    _prelude = []; // re-buffer while the head refetches 重拉头期间再缓冲
    transcript.mutate((t) => t..dropLive());
    unawaited(_hydrate());
  }

  // ── sends 发送 ──

  /// Optimistic send: the bubble appears NOW; the durable user echo replaces it (FIFO reconcile in the
  /// model). Failure marks the bubble failed (retry/discard affordances) — nothing is silently dropped.
  /// 乐观发送:泡立即出现,durable 回声替换(模型内 FIFO 对账);失败标 failed(重试/丢弃),绝不静默丢。
  Future<void> send(String text, {List<MentionSnapshot> mentions = const []}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final localId = 'local_${_localSeq++}';
    transcript.mutate(
        (t) => t..addPending(PendingSend(localId: localId, text: trimmed, mentions: mentions)));
    _syncPin();
    await _post(localId, trimmed, mentions);
  }

  Future<void> _post(String localId, String text, List<MentionSnapshot> mentions) async {
    try {
      await _repo.sendMessage(
        conversationId,
        content: text,
        mentions: [for (final m in mentions) (type: m.type, id: m.id)],
      );
    } catch (_) {
      if (!ref.mounted) return;
      transcript.mutate((t) => t..markPendingFailed(localId));
      _syncPin();
    }
  }

  /// Re-POST a failed bubble (same content, same bubble — it un-fails while in flight). 重发失败泡。
  Future<void> retrySend(String localId) async {
    final p = transcript.value.pending.where((p) => p.localId == localId).firstOrNull;
    if (p == null) return;
    transcript.mutate((t) {
      p.failed = false;
      return t;
    });
    _syncPin();
    await _post(localId, p.text, p.mentions);
  }

  /// Drop a failed bubble. 丢弃失败泡。
  void discardFailed(String localId) {
    transcript.mutate((t) => t..removePending(localId));
    _syncPin();
  }

  /// Cancel the in-flight turn — the terminal (`cancelled`) arrives via the stream; never fabricated
  /// locally. Errors are swallowed (idempotent; a lost race just means the turn already ended).
  /// 取消在途回合——终态经流到达、绝不本地伪造;吞错(幂等,竞态输了=回合本就结束)。
  Future<void> cancelTurn() async {
    try {
      await _repo.cancelTurn(conversationId);
    } catch (_) {/* idempotent — the stream terminal settles the truth 流终态定真相 */}
  }

  // ── upward pagination 向上分页 ──

  Future<void> loadOlder() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingOlder || !state.hasMoreOlder) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.listMessages(conversationId, cursor: cursor, limit: _pageSize);
      if (!ref.mounted) return;
      transcript.mutate((t) => t..prependOlder(page.items));
      state = state.copyWith(
        nextCursor: page.nextCursor,
        hasMoreOlder: !page.isLastPage,
        loadingOlder: false,
      );
    } catch (_) {
      // try/finally-style reset (the documented pitfall: a stuck flag kills pagination forever).
      // 复位旗标(已记档的坑:旗标卡死=分页永瘫)。
      if (ref.mounted) state = state.copyWith(loadingOlder: false);
    }
  }

  // ── pins + seen 钉与已读 ──

  bool get _isSelected =>
      ref.read(selectedConversationProvider)?.id == conversationId;

  void _syncPin() {
    final inFlight = transcript.value.hasInFlight;
    if (inFlight) {
      _releasePin ??= ref.keepAlive().close;
    } else {
      _releasePin?.call();
      _releasePin = null;
    }
  }

  Future<void> _quietlySeen() async {
    try {
      await _repo.markSeen(conversationId);
    } catch (_) {/* cosmetic; the next open retries 装饰性,下次打开重试 */}
  }
}

/// One live pipeline per OPEN conversation — autoDispose family: leaving the thread frees the
/// subscription unless a send/stream is in flight (keepAlive pins it, so it finishes in the background
/// and the rail's dots stay honest). 每打开会话一条管道(autoDispose family);在飞时 keepAlive 钉住后台跑完。
final conversationStreamProvider = NotifierProvider.autoDispose
    .family<ConversationStreamController, ConversationStreamState, String>(
        ConversationStreamController.new);
