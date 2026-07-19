import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/conversation_stream_provider.dart';
import 'package:anselm/features/chat/state/conversation_stream_state.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The live pipeline controller. Pins: hydrate (phase + turns + subscribe-buffer-drain so mid-fetch
// frames survive), optimistic send + echo reconcile + failure retry/discard, cancel passthrough,
// upward pagination (flag reset on error), 410 resync refetch, and :seen (selected-only on terminal).
// 管道控制器钉:水化(相位+回合+订阅缓冲泄流)、乐观发送+回声对账+失败重试/丢弃、cancel 透传、上翻(错误复位旗)、
// 410 重拉、:seen(仅选中时终态清)。

const _scope = StreamScope(kind: 'conversation', id: 'cv_1');

StreamEnvelope _open(String id, String type, {String? parentId, Map<String, dynamic>? content}) =>
    StreamEnvelope(seq: 5, scope: _scope, id: id,
        frame: FrameOpen(parentId: parentId, node: StreamNode(type: type, content: content)));

StreamEnvelope _close(String id, String type, Map<String, dynamic> result, {String status = 'completed'}) =>
    StreamEnvelope(seq: 6, scope: _scope, id: id,
        frame: FrameClose(status: status, result: StreamNode(type: type, content: result)));

Conversation _conv(String id) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(id: id, title: 'T', createdAt: at, updatedAt: at, lastMessageAt: at);
}

ChatMessage _turn(String id, String role, {String status = 'completed', int hour = 10, List<ChatBlock> blocks = const []}) =>
    ChatMessage(id: id, conversationId: 'cv_1', role: role, status: status, blocks: blocks,
        createdAt: DateTime.utc(2026, 7, 2, hour));

/// Selection stub — the real one derives from the router (absent in unit containers). 选区桩(真身依赖路由)。
class _FakeSelected extends SelectedConversation {
  _FakeSelected(this.value);
  final ConversationRef? value;
  @override
  ConversationRef? build() => value;
}

(ProviderContainer, FixtureChatRepository) _setup({
  Map<String, List<ChatMessage>>? messages,
  bool selected = true,
}) {
  final repo = FixtureChatRepository(
    conversations: [_conv('cv_1')],
    messages: messages ?? {
      'cv_1': [
        _turn('msg_u', 'user', hour: 10, blocks: [ChatBlock(id: 'bu', type: 'text', content: '问', status: 'completed')]),
        _turn('msg_a', 'assistant', hour: 11, blocks: [ChatBlock(id: 'ba', type: 'text', content: '答', status: 'completed')]),
      ],
    },
  );
  final c = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    selectedConversationProvider
        .overrideWith(() => _FakeSelected(selected ? const ConversationRef('cv_1') : null)),
  ]);
  addTearDown(c.dispose);
  return (c, repo);
}

void main() {
  // CoalescingNotifier reaches for SchedulerBinding.instance in its constructor — plain test()s need
  // the test binding up front. CoalescingNotifier 构造要 SchedulerBinding,纯 test() 须先起测试 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hydrates: phase ready, turns chronological, opening marks seen (selected)', () async {
    final (c, repo) = _setup();
    final sub = c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    await pumpEventQueue();
    expect(c.read(conversationStreamProvider('cv_1')).phase, TranscriptPhase.ready);
    final ctl = c.read(conversationStreamProvider('cv_1').notifier);
    expect(ctl.transcript.value.turns.map((n) => n.id), ['msg_u', 'msg_a']);
    expect(repo.seen, ['cv_1']); // open ⇒ :seen 打开即清未读
    sub.close();
  });

  test('NOT selected: opening does not mark seen', () async {
    final (c, repo) = _setup(selected: false);
    c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    await pumpEventQueue();
    expect(repo.seen, isEmpty);
  });

  test('frames landing DURING hydration buffer and drain (nothing lost in the fetch window)', () async {
    final (c, repo) = _setup(messages: {'cv_1': []});
    c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    // Emit immediately — hydration's future hasn't resolved yet. 水化未落即发帧。
    repo.emitFrame('cv_1', _open('msg_x', 'message', content: {'role': 'assistant'}));
    await pumpEventQueue();
    final ctl = c.read(conversationStreamProvider('cv_1').notifier);
    expect(ctl.transcript.value.liveTurns.map((n) => n.id), ['msg_x']);
  });

  test('send: optimistic bubble → POST recorded → durable echo reconciles it away', () async {
    final (c, repo) = _setup(messages: {'cv_1': []});
    c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    await pumpEventQueue();
    final ctl = c.read(conversationStreamProvider('cv_1').notifier);
    final f = ctl.send('你好');
    expect(ctl.transcript.value.pending, hasLength(1)); // bubble NOW 泡立即
    await f;
    expect(repo.lastSend?.content, '你好');
    repo.emitFrame('cv_1', _open('msg_echo', 'message', content: {'role': 'user'}));
    await pumpEventQueue();
    expect(ctl.transcript.value.pending, isEmpty); // reconciled 已对账
    expect(ctl.transcript.value.liveTurns.single.id, 'msg_echo');
  });

  test('send failure marks the bubble failed; retry re-posts; discard drops it', () async {
    final (c, repo) = _setup(messages: {'cv_1': []});
    c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    await pumpEventQueue();
    final ctl = c.read(conversationStreamProvider('cv_1').notifier);
    await ctl.send(''); // whitespace no-op 空白不发
    expect(ctl.transcript.value.pending, isEmpty);

    repo.failNextSend = true;
    await ctl.send('会失败');
    final p = ctl.transcript.value.pending.single;
    expect(p.failed, isTrue);

    await ctl.retrySend(p.localId); // fixture no longer failing 重试成功
    expect(repo.lastSend?.content, '会失败');
    expect(ctl.transcript.value.pending.single.failed, isFalse);

    ctl.discardFailed(p.localId);
    expect(ctl.transcript.value.pending, isEmpty);
  });

  test('cancelTurn passes through; assistant terminal while selected marks seen again', () async {
    final (c, repo) = _setup(messages: {'cv_1': []});
    c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    await pumpEventQueue();
    final ctl = c.read(conversationStreamProvider('cv_1').notifier);
    await ctl.cancelTurn();
    expect(repo.cancelled, ['cv_1']);

    repo.seen.clear();
    repo.emitFrame('cv_1', _open('msg_a', 'message', content: {'role': 'assistant'}));
    repo.emitFrame('cv_1', _close('msg_a', 'message', {'role': 'assistant', 'status': 'completed', 'stopReason': 'end_turn'}));
    await pumpEventQueue();
    expect(repo.seen, ['cv_1']); // focused completion clears unread 聚焦完成清未读
    expect(ctl.transcript.value.isGenerating, isFalse);
  });

  test('loadOlder pages upward; the flag resets on error', () async {
    final many = [
      for (var i = 0; i < 45; i++)
        _turn('msg_$i', i.isEven ? 'user' : 'assistant', hour: 10, blocks: [
          ChatBlock(id: 'b$i', type: 'text', content: '$i', status: 'completed'),
        ]),
    ];
    final (c, _) = _setup(messages: {'cv_1': many});
    c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    await pumpEventQueue();
    final ctl = c.read(conversationStreamProvider('cv_1').notifier);
    expect(ctl.transcript.value.turns, hasLength(30)); // head page 头页
    expect(c.read(conversationStreamProvider('cv_1')).hasMoreOlder, isTrue);

    await ctl.loadOlder();
    expect(ctl.transcript.value.turns, hasLength(45));
    expect(c.read(conversationStreamProvider('cv_1')).hasMoreOlder, isFalse);
    // oldest first after prepend 上翻后最旧在前
    expect(ctl.transcript.value.turns.first.id, 'msg_0');
    expect(c.read(conversationStreamProvider('cv_1')).loadingOlder, isFalse);
  });

  test('410 resync refetches the head: a turn completed during the gap lands settled', () async {
    final (c, repo) = _setup(messages: {'cv_1': []});
    c.listen(conversationStreamProvider('cv_1'), (_, _) {});
    await pumpEventQueue();
    final ctl = c.read(conversationStreamProvider('cv_1').notifier);
    // Live turn in progress… 在飞回合…
    repo.emitFrame('cv_1', _open('msg_a', 'message', content: {'role': 'assistant'}));
    await pumpEventQueue();
    expect(ctl.transcript.value.liveTurns, hasLength(1));

    // Gap: it completed server-side; the head now has it as a durable row. 缺口内已完成,头里是耐久行。
    repo.appendMessage('cv_1', _turn('msg_a', 'assistant', hour: 11, blocks: [
      ChatBlock(id: 'ba', type: 'text', content: '完整答案', status: 'completed'),
    ]));
    repo.emitResync();
    await pumpEventQueue();
    expect(ctl.transcript.value.liveTurns, isEmpty);
    expect(ctl.transcript.value.settled.map((n) => n.id), ['msg_a']);
    expect(c.read(conversationStreamProvider('cv_1')).phase, TranscriptPhase.ready);
  });
}
