import 'package:anselm/features/chat/model/mention_spans.dart';
import 'package:anselm/features/chat/state/chat_queue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// CH-a §3.4 排队. The queue is a small object; what needs pinning is its ORDER and the two decisions the
// ticket left open — what `↑` takes, and what Stop does to it.
//
// CH-a §3.4 排队。队列本身是个小对象;要钉的是它的**顺序**,以及工单留待施工时定的那两件事——`↑` 取哪一条,
// 以及「停止」对它做什么。
void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  QueuedMessage msg(ChatQueue q, String text) => QueuedMessage(
    localId: q.nextLocalId(),
    text: text,
    mentions: const [],
    attachmentIds: const [],
  );

  test(
    'FIFO — the reader s own order is the only order that could be right',
    () {
      final c = container();
      final q = c.read(chatQueueProvider('cv1').notifier);
      q.enqueue(msg(q, 'first'));
      q.enqueue(msg(q, 'second'));
      q.enqueue(msg(q, 'third'));

      expect(q.takeFirst()!.text, 'first');
      expect(q.takeFirst()!.text, 'second');
      expect(q.takeFirst()!.text, 'third');
      expect(q.takeFirst(), isNull);
    },
  );

  test(
    '`↑` takes the LAST one — "wait, let me change that" is about what you just typed',
    () {
      // Taking the head would hand back a message the reader wrote several messages ago, which is not what
      // the gesture means. 取队首会把读者几条之前写的消息递回来,那不是这个手势的意思。
      final c = container();
      final q = c.read(chatQueueProvider('cv1').notifier);
      q.enqueue(msg(q, 'first'));
      q.enqueue(msg(q, 'last'));

      expect(q.takeLast()!.text, 'last');
      expect(c.read(chatQueueProvider('cv1')).single.text, 'first');
    },
  );

  test('removeAt goes by localId, not index — a chip is an identity', () {
    final c = container();
    final q = c.read(chatQueueProvider('cv1').notifier);
    final a = msg(q, 'a');
    final b = msg(q, 'b');
    final d = msg(q, 'c');
    q.enqueue(a);
    q.enqueue(b);
    q.enqueue(d);

    q.removeAt(b.localId);
    expect(
      c.read(chatQueueProvider('cv1')).map((m) => m.text),
      ['a', 'c'],
      reason: 'removing the middle chip must not shift the others out',
    );
  });

  test('each conversation has its own queue — a family, not a singleton', () {
    final c = container();
    final one = c.read(chatQueueProvider('cv1').notifier);
    final two = c.read(chatQueueProvider('cv2').notifier);
    one.enqueue(msg(one, 'for cv1'));

    expect(c.read(chatQueueProvider('cv1')), hasLength(1));
    expect(
      c.read(chatQueueProvider('cv2')),
      isEmpty,
      reason: 'a message queued in one thread must not appear in another',
    );
    expect(two.takeFirst(), isNull);
  });

  test(
    'a queued message freezes its mentions and attachment ids at enqueue time',
    () {
      // The send must read exactly what the reader thought they were sending — mentions resolved against the
      // entity list they saw, attachments already uploaded. 发送必须读到读者以为自己发的那条:提及是对着他当时看到
      // 的实体列表解析的、附件已上传完毕。
      final c = container();
      final q = c.read(chatQueueProvider('cv1').notifier);
      q.enqueue(
        QueuedMessage(
          localId: q.nextLocalId(),
          text: 'ask @fn_x',
          mentions: const [
            MentionSnapshot(type: 'function', id: 'fn_1', name: 'fn_x'),
          ],
          attachmentIds: const ['att_1', 'att_2'],
        ),
      );

      final taken = q.takeFirst()!;
      expect(taken.mentions.single.id, 'fn_1');
      expect(taken.attachmentIds, ['att_1', 'att_2']);
    },
  );
}
