import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/conversation_signal.dart';
import 'package:flutter_test/flutter_test.dart';

// The conversation lifecycle projection off the notifications stream. Frames arrive with
// scope.kind="notification", so the domain+action live in node.type ("conversation.auto_titled") and the
// id in the payload (conversationId). Pins: domain match, id extraction, action vocab, durability.

StreamEnvelope _notif(
  String type,
  Map<String, dynamic>? content, {
  int seq = 7,
}) => StreamEnvelope(
  seq: seq,
  scope: const StreamScope(kind: 'notification', id: 'noti_1'),
  id: 'noti_1',
  frame: FrameSignal(
    node: StreamNode(type: type, content: content),
  ),
);

void main() {
  test('projects a matching conversation frame (id + action + durable)', () {
    final s = ConversationSignal.fromEnvelope(
      _notif('conversation.created', {'conversationId': 'cv_1'}),
    );
    expect(s, isNotNull);
    expect(s!.id, 'cv_1');
    expect(s.action, ConversationAction.created);
    expect(s.durable, isTrue);
  });

  test('drops a frame for a different domain', () {
    expect(
      ConversationSignal.fromEnvelope(
        _notif('function.created', {'functionId': 'fn_1'}),
      ),
      isNull,
    );
  });

  test('drops a non-Signal frame and a frame missing the id', () {
    final delta = StreamEnvelope(
      seq: 7,
      scope: const StreamScope(kind: 'notification', id: 'noti_1'),
      id: 'noti_1',
      frame: const FrameDelta(chunk: 'x'),
    );
    expect(ConversationSignal.fromEnvelope(delta), isNull);
    expect(
      ConversationSignal.fromEnvelope(_notif('conversation.updated', null)),
      isNull,
    );
    expect(
      ConversationSignal.fromEnvelope(_notif('conversation.updated', const {})),
      isNull,
    );
  });

  test('ephemeral frame (seq 0) → durable false (list must NOT patch)', () {
    final s = ConversationSignal.fromEnvelope(
      _notif('conversation.updated', {'conversationId': 'cv_1'}, seq: 0),
    );
    expect(s!.durable, isFalse);
  });

  test('action vocab collapses correctly', () {
    ConversationAction act(String type) => ConversationSignal.fromEnvelope(
      _notif(type, {'conversationId': 'cv_1'}),
    )!.action;

    expect(act('conversation.created'), ConversationAction.created);
    expect(act('conversation.deleted'), ConversationAction.deleted);
    expect(act('conversation.updated'), ConversationAction.updated);
    expect(act('conversation.auto_titled'), ConversationAction.updated);
    expect(act('conversation.archived'), ConversationAction.updated);
    expect(act('conversation.unarchived'), ConversationAction.updated);
    expect(act('conversation.pinned'), ConversationAction.updated);
    expect(act('conversation.unpinned'), ConversationAction.updated);
    expect(act('conversation.model_override'), ConversationAction.updated);
    // WRK-083 B1 — and the reason this test could not be the guard. It enumerates the vocabulary BY
    // HAND, so it drifts exactly the way the switch it checks drifts: `work_dir` was added to the
    // backend in WRK-077 WD1, nobody added it here, and the missing line looked identical to a line
    // that was never needed. The mechanical cross-check now lives in `cmd/docs`
    // (`driftSignalVocabulary`), which diffs the switch against the family registered in events.md.
    // This line stays because a behavioural assertion still says something the diff cannot: that the
    // verb collapses to `updated` — i.e. that the rail RE-READS the row — rather than merely being
    // present somewhere in the file.
    // WRK-083 B1——也正是本测试当不了守卫的原因。它**手工**列举词表,故它与它所检查的 switch 以完全相同的方式漂移:
    // `work_dir` 在 WRK-077 WD1 加进后端,没人往这里补,而缺的那一行看起来与「本来就不需要的一行」一模一样。机械
    // 对账现在住在 `cmd/docs`(`driftSignalVocabulary`),它把 switch 与 events.md 登记的族逐字 diff。这一行保留,
    // 因为行为断言仍说了 diff 说不出的事:该动词坍缩为 `updated`——即 rail 会**重读那一行**——而不只是「在文件里
    // 某处出现过」。
    expect(act('conversation.work_dir'), ConversationAction.updated);
    expect(act('conversation.compacted'), ConversationAction.updated);
    expect(act('conversation.surprise'), ConversationAction.unknown);
  });
}
