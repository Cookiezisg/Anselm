import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/conversation.dart';
import '../data/chat_providers.dart';
import 'chat_drafts.dart';
import 'conversation_list_provider.dart';

/// The fork SOURCE's row, for the head's lineage line. Null = unreadable (deleted, or a transport
/// failure) and the line degrades to its generic form.
///
/// It swallows the error on purpose rather than surfacing an [AsyncError]: the INTERESTING failure here
/// is a source the user deleted — a hard 404 that will never start succeeding — and Riverpod's default
/// exponential retry on a failed build would poll it forever behind a line that has already degraded
/// gracefully. A fork deliberately outlives its parent (the ids just dangle, nothing cascades), so
/// "cannot read the source" is a normal steady state, not an error to keep retrying.
///
/// Read here rather than embedded in the fork's own row because the wire carries only the id: lineage
/// is provenance, and a copied title would go stale the moment the source is renamed.
///
/// 分叉**源**的行,供头部血缘行用。null = 读不到(已删,或传输失败),血缘行降级为泛称形态。
///
/// 它**刻意**吞掉错误、不抛出 AsyncError:这里有意思的失败是**用户删掉了源**——一个永远不会开始成功的硬
/// 404——而 Riverpod 对失败 build 的默认指数重试会在一条已经优雅降级的行后面永远轮询它。分叉刻意活得比
/// 父长(id 只是悬空、不级联任何东西),故「读不到源」是正常稳态、不是要不断重试的错误。
///
/// 在此读、而非内嵌在分叉自己的行里,因为线缆只带 id:血缘是溯源,而复制来的标题在源改名那一刻就过期了。
final forkSourceProvider = FutureProvider.autoDispose
    .family<Conversation?, String>((ref, id) async {
      if (id.isEmpty) return null;
      try {
        return await ref.watch(chatRepositoryProvider).getConversation(id);
      } catch (_) {
        return null;
      }
    });

/// The result of a fork: the new thread's id, plus whether the caller should prefill a composer.
///
/// 分叉的结果：新线程 id + 调用方是否该预填 composer。
class ForkResult {
  const ForkResult({required this.conversationId, this.landing = false});

  /// The thread to navigate to — empty when the fork was "before the very first message", which is
  /// semantically the landing (a thread with nothing said yet). 要导航去的线程；「在第一条消息之前」时为空
  /// ——那在语义上就是 landing（一条还没人说过话的线程）。
  final String conversationId;

  /// True when there is no thread to open and the caller should go to `/` instead. 无线程可开、去 `/`。
  final bool landing;
}

/// Fork a thread and fold the new row into the rail — the shared half of all three fork entries
/// (message action row, the rail's ⋯ menu, and the user-message "stop before I said it" variant).
///
/// [atMessageId] null = fork at the latest message (the rail entry holds no message id).
/// [prefill] non-empty = seed the NEW thread's composer draft with it, which is how the user-message
/// variant works: the backend forks at the message BEFORE the one you clicked (so the thread stops
/// just short of your sentence) and the sentence itself comes back as editable draft text. The draft
/// store is the existing seam — `ChatComposer.initState` reads it, and the composer is keyed per
/// thread, so arriving at the new id constructs fresh state that picks the draft up. No new
/// mechanism, no imperative reach into a mounted composer.
///
/// 分叉一条线程并把新行折进 rail——三个分叉入口共用的那一半（消息动作排、rail 的 ⋯ 菜单、user 消息的
/// 「停在我说出它之前」变体）。
///
/// atMessageId 为 null = 从最新消息处分叉（rail 入口手上没有 message id）。prefill 非空 = 用它种下**新**
/// 线程的 composer 草稿，这正是 user 消息变体的做法：后端分叉到你点的那条的**前一条**（故线程停在你那句话
/// 之前），而那句话本身作为可编辑草稿回来。草稿存储是**既有**接缝——`ChatComposer.initState` 读它，且
/// composer 按线程 key，故抵达新 id 会构造出新状态并取走草稿。无新机制、不伸手去改已挂载的 composer。
Future<ForkResult> forkConversation(
  Ref ref,
  String conversationId, {
  String? atMessageId,
  String prefill = '',
}) async {
  // "Fork before the first message" has no prefix to copy — a thread with nothing said IS the
  // landing, so send the user there with the sentence in hand instead of minting an empty twin.
  // 「在第一条消息之前分叉」没有前缀可复制——什么都没说的线程**就是** landing，故把用户送去那里、句子
  // 带在手上，而不是铸一个空的孪生线程。
  if (atMessageId != null && atMessageId.isEmpty) {
    if (prefill.isNotEmpty) {
      ref.read(chatDraftsProvider).set(ChatDrafts.landingKey, prefill);
    }
    return const ForkResult(conversationId: '', landing: true);
  }
  final fork = await ref
      .read(chatRepositoryProvider)
      .forkConversation(conversationId, atMessageId: atMessageId);
  // Fold the authoritative row in immediately: the initiator never waits on its own SSE echo
  // (notifications are for OTHER clients and carry no echo suppression, so the merge is idempotent).
  // 立刻折入权威行：发起方从不等自己的 SSE 回声（通知是给**其他**客户端的、无回声抑制，故合并幂等）。
  ref.read(conversationListProvider.notifier).applyUpdate(fork);
  if (prefill.isNotEmpty) {
    ref.read(chatDraftsProvider).set(fork.id, prefill);
  }
  return ForkResult(conversationId: fork.id);
}

/// Riverpod-callable wrapper for widgets (WidgetRef lacks the plain Ref surface). widget 侧包装。
final forkConversationProvider =
    Provider<
      Future<ForkResult> Function(
        String conversationId, {
        String? atMessageId,
        String prefill,
      })
    >(
      (ref) =>
          (conversationId, {atMessageId, prefill = ''}) => forkConversation(
            ref,
            conversationId,
            atMessageId: atMessageId,
            prefill: prefill,
          ),
    );
