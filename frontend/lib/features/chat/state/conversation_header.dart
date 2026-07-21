import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/conversation.dart';
import '../../../core/runtime.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../data/conversation_signal.dart';

/// The open thread's HEAD state (title + per-thread model override) — one fetch on open, then patched by
/// the same two paths the rail uses: the initiator's authoritative PATCH response (rename / model set
/// here) and the notifications lifecycle echo (an `updated`-class signal for THIS id → quiet re-read;
/// this is exactly how the backend's post-first-turn AUTO-TITLE lands in the head, live, no refresh).
///
/// 打开线程的头部状态(标题 + 线程级模型覆写)——打开取一次,随后与 rail 同两条路 patch:发起端权威 PATCH 响应
/// (此处的改名/选模型)+ notifications 生命周期回声(本 id 的 updated 类信号 → 静默重读;**首回合后的自动命名
/// 正是走这条路活着落进头部**,零刷新)。
class ConversationHeaderController extends AsyncNotifier<Conversation> {
  ConversationHeaderController(this.conversationId);

  final String conversationId;
  late ChatRepository _repo;

  @override
  Future<Conversation> build() async {
    _repo = ref.watch(chatRepositoryProvider);
    final sub = _repo.lifecycleSignals().listen(_onSignal);
    ref.onDispose(sub.cancel);
    return _repo.getConversation(conversationId);
  }

  Future<void> _onSignal(ConversationSignal s) async {
    if (!s.durable || s.id != conversationId) return;
    if (s.action == ConversationAction.deleted) {
      return; // the rail navigates away; nothing to show 删除由 rail 导航走
    }
    try {
      final c = await _repo.getConversation(conversationId);
      if (ref.mounted) state = AsyncData(c);
    } catch (_) {
      /* deleted between signal and read — leave the last state 信号与读之间被删,保持现状 */
    }
  }

  /// Rename from the head (same PATCH as the rail's ⋯ rename; authoritative response patches state —
  /// never waits on the echo). 头部改名(同 rail PATCH;权威响应即 patch,不等回声)。
  Future<void> rename(String title) async {
    final trimmed = title.trim();
    final current = state.value;
    if (trimmed.isEmpty || current == null || trimmed == current.title) return;
    final updated = await _repo.renameConversation(conversationId, trimmed);
    if (ref.mounted) state = AsyncData(updated);
  }

  /// Set / clear the per-thread model (tristate PATCH). 设/清线程级模型(三态 PATCH)。
  Future<void> setModel(({String apiKeyId, String modelId})? refValue) async {
    final updated = await _repo.setModelOverride(conversationId, refValue);
    if (ref.mounted) state = AsyncData(updated);
  }
}

final conversationHeaderProvider = AsyncNotifierProvider.autoDispose
    .family<ConversationHeaderController, Conversation, String>(
      ConversationHeaderController.new,
    );

/// The LANDING's model choice — sticky across new chats (null = Auto). The backend's create endpoint
/// takes only a title, so the first send stamps this via PATCH between create and send (see
/// startConversation); it stays put afterwards so the next new chat inherits the choice.
///
/// landing 的模型选择——跨新对话粘性(null=Auto)。后端建会话只收 title,首发在 create 与 send 之间经
/// PATCH 盖章(见 startConversation);选择保留,下一个新对话继承。
class LandingModel extends Notifier<({String apiKeyId, String modelId})?> {
  @override
  ({String apiKeyId, String modelId})? build() {
    // A workspace switch voids the sticky choice — the (apiKeyId, modelId) pair belongs to the OLD
    // workspace's key set (S3-pre self-heal). 切 workspace 即作废:键对属旧 workspace 的 key 集。
    ref.watch(activeWorkspaceProvider);
    return null;
  }

  void set(({String apiKeyId, String modelId})? value) => state = value;
}

final landingModelProvider =
    NotifierProvider<LandingModel, ({String apiKeyId, String modelId})?>(
      LandingModel.new,
    );
