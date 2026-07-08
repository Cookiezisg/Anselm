import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/state/conversation_stream_provider.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// W6 deep-jump (re-anchor): the transcript model's window primitives + the controller's jump
// pipeline over the fixture's ?around= closed loop (near retarget / deep window / forward paging /
// back-to-live / send exits the window). W6 深跳(重锚)电池。

Conversation _conv(String id) {
  final at = DateTime.utc(2026, 7, 8, 9);
  return Conversation(id: id, title: 'T', createdAt: at, updatedAt: at, lastMessageAt: at);
}

ChatMessage _turn(int i) => ChatMessage(
      id: 'msg_$i',
      conversationId: 'cv_1',
      role: i.isEven ? 'user' : 'assistant',
      status: 'completed',
      blocks: [ChatBlock(id: 'b_$i', type: 'text', content: '第 $i 回', status: 'completed')],
      createdAt: DateTime.utc(2026, 7, 8, 9).add(Duration(minutes: i)),
    );

(ProviderContainer, FixtureChatRepository) _setup({int count = 60}) {
  final repo = FixtureChatRepository(
    conversations: [_conv('cv_1')],
    messages: {
      'cv_1': [for (var i = 0; i < count; i++) _turn(i)],
    },
  );
  final c = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    selectedConversationProvider.overrideWith(_NoSelection.new),
  ]);
  addTearDown(c.dispose);
  return (c, repo);
}

class _NoSelection extends SelectedConversation {
  @override
  ConversationRef? build() => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationTranscript window primitives 模型窗口原语', () {
    test('setWindow re-anchors on the target; setHistory resets windowMode', () {
      final t = ConversationTranscript('cv_1');
      // newest-first wire order, msg_5 the target. 线缆新→旧,目标 msg_5。
      t.setWindow([for (var i = 8; i >= 2; i--) _turn(i)], 'msg_5');
      expect(t.windowMode, isTrue);
      expect(t.settled.length, 7);
      expect(t.olderCount, 3); // msg_2..msg_4 above the anchor 锚上三行
      expect(t.settled[t.olderCount].id, 'msg_5'); // the target IS the center row 目标即中心行
      t.setHistory([_turn(9)]);
      expect(t.windowMode, isFalse);
    });

    test('retargetCenter moves the anchor to a LOADED row only', () {
      final t = ConversationTranscript('cv_1');
      t.setHistory([for (var i = 9; i >= 0; i--) _turn(i)]);
      expect(t.retargetCenter('msg_3'), isTrue);
      expect(t.olderCount, 3);
      expect(t.retargetCenter('msg_99'), isFalse);
    });

    test('appendNewer extends the window downward', () {
      final t = ConversationTranscript('cv_1');
      t.setWindow([for (var i = 5; i >= 3; i--) _turn(i)], 'msg_4');
      t.appendNewer([_turn(7), _turn(6)]);
      expect(t.settled.map((n) => n.id).toList(), ['msg_3', 'msg_4', 'msg_5', 'msg_6', 'msg_7']);
    });

    test('messageIdOf walks a nested live block to its turn (the R-14 anchor)', () {
      final t = ConversationTranscript('cv_1');
      const scope = StreamScope(kind: 'conversation', id: 'cv_1');
      t.applyFrame(const StreamEnvelope(
          seq: 1, scope: scope, id: 'm1',
          frame: FrameOpen(node: StreamNode(type: 'message', content: {'role': 'assistant'}))));
      t.applyFrame(const StreamEnvelope(
          seq: 2, scope: scope, id: 'tc1',
          frame: FrameOpen(parentId: 'm1', node: StreamNode(type: 'tool_call', content: {'name': 'Subagent'}))));
      t.applyFrame(const StreamEnvelope(
          seq: 3, scope: scope, id: 'r1',
          frame: FrameOpen(parentId: 'tc1', node: StreamNode(type: 'reasoning', content: {}))));
      expect(t.messageIdOf('r1'), 'm1'); // any depth 任意深
      expect(t.messageIdOf('tc1'), 'm1');
      expect(t.messageIdOf('ghost'), isNull);
    });
  });

  group('controller jump pipeline 控制器跳转管道', () {
    test('near jump re-centers without entering window mode', () async {
      final (c, _) = _setup();
      c.listen(conversationStreamProvider('cv_1'), (_, _) {});
      await pumpEventQueue();
      final ctl = c.read(conversationStreamProvider('cv_1').notifier);
      // The head page (30) holds msg_30..59 — msg_45 is loaded. 头页含 msg_45。
      expect(await ctl.jumpTo('msg_45'), isTrue);
      expect(c.read(conversationStreamProvider('cv_1')).windowMode, isFalse);
      expect(ctl.transcript.value.settled[ctl.transcript.value.olderCount].id, 'msg_45');
    });

    test('deep jump opens the window; both directions page; back-to-live rejoins the head', () async {
      final (c, _) = _setup();
      c.listen(conversationStreamProvider('cv_1'), (_, _) {});
      await pumpEventQueue();
      final ctl = c.read(conversationStreamProvider('cv_1').notifier);

      expect(await ctl.jumpTo('msg_5'), isTrue);
      var s = c.read(conversationStreamProvider('cv_1'));
      expect(s.windowMode, isTrue);
      final t = ctl.transcript.value;
      expect(t.windowMode, isTrue);
      expect(t.settled[t.olderCount].id, 'msg_5');
      expect(s.hasMoreNewer, isTrue); // msg_21.. remain newer 更新方向未尽

      await ctl.loadNewer();
      final after = ctl.transcript.value.settled.length;
      expect(after, greaterThan(t.settled.length - 1)); // grew downward 向下长

      await ctl.backToLive();
      s = c.read(conversationStreamProvider('cv_1'));
      expect(s.windowMode, isFalse);
      expect(ctl.transcript.value.windowMode, isFalse);
      // The head page is back — the newest turn is loaded again. 头页归位。
      expect(ctl.transcript.value.turns.last.id, 'msg_59');
    });

    test('a deep jump to an unknown target fails honestly (identity anchoring)', () async {
      final (c, _) = _setup();
      c.listen(conversationStreamProvider('cv_1'), (_, _) {});
      await pumpEventQueue();
      final ctl = c.read(conversationStreamProvider('cv_1').notifier);
      expect(await ctl.jumpTo('msg_nope'), isFalse);
      expect(c.read(conversationStreamProvider('cv_1')).windowMode, isFalse);
    });

    test('a send exits the window first (a send speaks to the present)', () async {
      final (c, _) = _setup();
      c.listen(conversationStreamProvider('cv_1'), (_, _) {});
      await pumpEventQueue();
      final ctl = c.read(conversationStreamProvider('cv_1').notifier);
      await ctl.jumpTo('msg_5');
      expect(c.read(conversationStreamProvider('cv_1')).windowMode, isTrue);
      await ctl.send('回到当下');
      await pumpEventQueue();
      expect(c.read(conversationStreamProvider('cv_1')).windowMode, isFalse);
    });
  });
}
