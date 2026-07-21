import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/todo.dart';
import '../../../core/sse/frame.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';

/// The RUNDOWN state (WRK-061 §6-②): every todo list this conversation carries, keyed by subagentId
/// ("" = the conversation's own board). Lists arrive as durable WHOLE-LIST `todo` Signals (≤64 rows,
/// no ids — replace, never merge) patched STRAIGHT into this cache (never through CoalescingNotifier,
/// W0 §5-5); the GET hydrates the main board on entry/reconnect. Read-only — the rundown renders, the
/// model writes. autoDispose family per conversation.
///
/// 场记状态:会话携带的全部清单(按 subagentId,空=主清单)。durable todo 信号=整表替换直 patch 缓存
/// (绝不过 CoalescingNotifier);GET 水化主清单(进入/重连)。只读。autoDispose family。
class RundownController extends Notifier<Map<String, ConversationTodos>> {
  RundownController(this.conversationId);

  final String conversationId;

  late ChatRepository _repo;
  StreamSubscription<StreamEnvelope>? _sub;
  StreamSubscription<void>? _resyncSub;

  @override
  Map<String, ConversationTodos> build() {
    _repo = ref.watch(chatRepositoryProvider);
    _sub = _repo.conversationFrames(conversationId).listen(_onFrame);
    _resyncSub = _repo.transcriptResync().listen((_) => unawaited(_hydrate()));
    ref.onDispose(() {
      _sub?.cancel();
      _resyncSub?.cancel();
    });
    unawaited(_hydrate());
    return const {};
  }

  Future<void> _hydrate() async {
    await null; // yield past build() (uninitialized-state guard, ledger precedent) 让过 build
    try {
      final main = await _repo.getTodos(conversationId);
      if (!ref.mounted) return;
      if (main.todos.isNotEmpty || state.containsKey('')) {
        state = {...state, '': main};
      }
    } catch (_) {
      /* hydration is best-effort — signals still flow 水化尽力,信号仍流 */
    }
  }

  void _onFrame(StreamEnvelope env) {
    final frame = env.frame;
    if (frame is! FrameSignal || frame.node.type != 'todo') return;
    if (!env.durable) return; // DB row is truth 只吃 durable
    final content = frame.node.content;
    if (content == null) return;
    final list = ConversationTodos.fromJson(content);
    // WHOLE-LIST replace per board (the wire's semantics — no per-row merge). 整表替换。
    state = {...state, list.subagentId: list};
  }
}

/// All boards of one conversation, keyed by subagentId ("" = main). 会话全部清单(空键=主)。
final rundownProvider = NotifierProvider.autoDispose
    .family<RundownController, Map<String, ConversationTodos>, String>(
      RundownController.new,
    );
