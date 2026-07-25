import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/mention_spans.dart';

/// One message the reader wrote while the previous turn was still generating (§3.4 排队).
///
/// It carries everything the send needs, frozen at the moment of enqueue: mentions were resolved
/// against the entity list the reader saw, and attachment ids are already uploaded — the server holds
/// the bytes, so a queued message is a small record, not a pending upload.
///
/// 读者在上一轮还在生成时写下的一条消息(§3.4 排队)。
///
/// 它带着发送所需的一切、**冻结于入队那一刻**:提及是对着读者当时看到的实体列表解析出来的,附件 id 也已上传完毕
/// ——字节在服务端,故一条排队消息是一小条记录、不是一个待上传任务。
class QueuedMessage {
  const QueuedMessage({
    required this.localId,
    required this.text,
    required this.mentions,
    required this.attachmentIds,
  });

  /// Identity for the chip row — the list is reordered and spliced, so an index is not an identity.
  /// chip 行的身份:列表会被增删,索引不是身份。
  final String localId;
  final String text;
  final List<MentionSnapshot> mentions;
  final List<String> attachmentIds;
}

/// The per-conversation send queue.
///
/// **Stop does not clear it** — that is the decision §3.4 left open, resolved here. Stop means "stop this
/// answer", which is a statement about the turn in flight; the messages the reader typed afterwards are
/// separate statements they have not withdrawn. Throwing them away because an unrelated answer was cut
/// short would destroy typed input the reader can no longer recover, and the queue chips already offer an
/// explicit ✕ for the case where they do want them gone. The asymmetry is deliberate: discarding is
/// cheap to undo by retyping only when the text was short, and we cannot know that it was.
///
/// 按对话的发送队列。
///
/// **按停止不清队列**——这是 §3.4 留待施工时定的那个问题,在此裁定。「停止」的意思是「停下这个回答」,那是对**在飞
/// 那一轮**的表态;读者随后打的消息是另外的、他并未撤回的表态。因为一个无关的回答被截断就把它们扔掉,会销毁读者
/// 再也找不回来的输入,而队列 chip 本就为「确实想扔」提供了明确的 ✕。这个不对称是刻意的:只有文字短时「重打一遍」
/// 才是便宜的撤销,而我们无从知道它短。
class ChatQueue extends Notifier<List<QueuedMessage>> {
  ChatQueue(this.conversationId);

  final String conversationId;
  int _seq = 0;

  /// The next local id — a queue-local counter, not an ID_CONSTITUTION id: nothing outside this queue ever
  /// sees it, and a queued message has no server identity until it is sent.
  /// 下一个本地 id:队列内计数器、不是 S15 那种 id——队列之外无人见它,而排队消息在发出前没有服务端身份。
  String nextLocalId() => 'q${_seq++}';

  @override
  List<QueuedMessage> build() => const [];

  /// FIFO — the reader's own order is the only order that could be right. 先进先出:读者自己的顺序是唯一可能对的顺序。
  void enqueue(QueuedMessage m) => state = [...state, m];

  void removeAt(String localId) => state = [
    for (final m in state)
      if (m.localId != localId) m,
  ];

  /// Pull the LAST one back out — the `↑` affordance, for "wait, let me change that". 取回最后一条(`↑`)。
  QueuedMessage? takeLast() {
    if (state.isEmpty) return null;
    final last = state.last;
    state = state.sublist(0, state.length - 1);
    return last;
  }

  /// Pull the head out for sending. 取出队首以发送。
  QueuedMessage? takeFirst() {
    if (state.isEmpty) return null;
    final first = state.first;
    state = state.sublist(1);
    return first;
  }

  void clear() => state = const [];
}

final chatQueueProvider =
    NotifierProvider.family<ChatQueue, List<QueuedMessage>, String>(
      ChatQueue.new,
    );
