import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/model/mention_spans.dart';
import 'package:flutter_test/flutter_test.dart';

// The transcript merge model — the one place plain chat can rot. Pins: hydration (order/subagent
// exclusion/user-text-in-child-block), the non-terminal SEED (an in-flight turn hydrates into the live
// reducer and the ongoing stream CONTINUES it), the full live turn lifecycle, FIFO echo reconcile (+ the
// mention merge, + ephemeral never reconciles), resync drop, and pagination prepend.
// 合并模型——纯聊天唯一会烂的地方。钉:水化(序/剔 subagent/用户文本在子块)、未完回合种子续接、live 全生命周期、
// FIFO 回声对账(+提及并入、ephemeral 不对账)、resync 丢层、上翻插前。

const _scope = StreamScope(kind: 'conversation', id: 'cv_1');

StreamEnvelope _env(String id, StreamFrame f, {int seq = 5}) =>
    StreamEnvelope(seq: seq, scope: _scope, id: id, frame: f);

StreamEnvelope _open(String id, String type, {String? parentId, Map<String, dynamic>? content, int seq = 5}) =>
    _env(id, FrameOpen(parentId: parentId, node: StreamNode(type: type, content: content)), seq: seq);

StreamEnvelope _delta(String id, String chunk) => _env(id, FrameDelta(chunk: chunk), seq: 0);

StreamEnvelope _close(String id, {String status = 'completed', Map<String, dynamic>? result, String? type, int seq = 6}) =>
    _env(id, FrameClose(status: status, result: result == null ? null : StreamNode(type: type ?? 'x', content: result)), seq: seq);

ChatMessage _turn(
  String id,
  String role, {
  String status = 'completed',
  String stopReason = '',
  String subagentId = '',
  Map<String, dynamic>? attrs,
  List<ChatBlock> blocks = const [],
  int hour = 10,
}) =>
    ChatMessage(
      id: id, conversationId: 'cv_1', role: role, status: status, stopReason: stopReason,
      subagentId: subagentId, attrs: attrs, blocks: blocks, createdAt: DateTime.utc(2026, 7, 2, hour),
    );

ChatBlock _blk(String id, String type, String content, {String parent = '', String status = 'completed', Map<String, dynamic>? attrs}) =>
    ChatBlock(id: id, type: type, content: content, parentBlockId: parent, status: status, attrs: attrs);

void main() {
  group('hydration', () {
    test('setHistory reverses wire order, hydrates terminal turns, excludes subagent rows', () {
      final t = ConversationTranscript('cv_1');
      t.setHistory([
        _turn('msg_3', 'assistant', hour: 12, blocks: [_blk('b3', 'text', '第二答')]),
        _turn('msg_sub', 'assistant', subagentId: 'sa_1', hour: 11),
        _turn('msg_2', 'user', hour: 11, blocks: [_blk('b2', 'text', '再问')]),
        _turn('msg_1', 'assistant', hour: 10, blocks: [_blk('b1', 'text', '首答')]),
      ]);
      expect(t.turns.map((n) => n.id), ['msg_1', 'msg_2', 'msg_3']); // chronological, no subagent
      expect(t.isGenerating, isFalse);
    });

    test('user text lives in the child block; attrs snapshots surface via accessors', () {
      final node = ConversationTranscript.hydrateTurn(_turn('msg_u', 'user', attrs: {
        'attachments': ['att_1'],
        'mentions': [
          {'type': 'function', 'id': 'fn_1', 'name': 'sync', 'content': 'def…'},
          {'type': 'agent', 'id': 'ag_1', 'name': '(unavailable)'},
        ],
      }, blocks: [
        _blk('b1', 'text', '看下 @sync')
      ]));
      expect(ConversationTranscript.turnText(node), '看下 @sync');
      expect(ConversationTranscript.turnAttachmentIds(node), ['att_1']);
      final mentions = ConversationTranscript.turnMentions(node);
      expect(mentions.first.available, isTrue);
      expect(mentions.last.available, isFalse); // no content key 无 content 键
    });

    test('tool_call hydration reconciles attrs→content (name/arguments); progress keeps its text key', () {
      final tc = ConversationTranscript.hydrateBlockContent(
          _blk('b', 'tool_call', '{"q":1}', attrs: {'tool': 'web_search', 'danger': 'safe'}));
      expect(tc['name'], 'web_search');
      expect(tc['arguments'], '{"q":1}');
      final pg = ConversationTranscript.hydrateBlockContent(_blk('b', 'progress', 'line1\n'));
      expect(pg['text'], 'line1\n');
      expect(pg['content'], isNull);
    });

    test('nested blocks attach by parentBlockId', () {
      final node = ConversationTranscript.hydrateTurn(_turn('msg_a', 'assistant', blocks: [
        _blk('call', 'tool_call', '{}', attrs: {'tool': 'x'}),
        _blk('result', 'tool_result', 'ok', parent: 'call'),
      ]));
      expect(node.children.single.id, 'call');
      expect(node.children.single.children.single.id, 'result');
    });

    test('prependOlder inserts above, chronological', () {
      final t = ConversationTranscript('cv_1')
        ..setHistory([_turn('msg_2', 'user', hour: 11)])
        ..prependOlder([_turn('msg_1', 'assistant', hour: 9), _turn('msg_0', 'user', hour: 8)]);
      expect(t.turns.map((n) => n.id), ['msg_0', 'msg_1', 'msg_2']);
    });
  });

  group('non-terminal seed (the in-flight turn survives a reload)', () {
    test('a pending tail hydrates into the LIVE layer and the stream continues it', () {
      final t = ConversationTranscript('cv_1');
      t.setHistory([
        _turn('msg_a', 'assistant', status: 'streaming', hour: 12,
            blocks: [_blk('bText', 'text', '已经写了一半', status: 'open')]),
        _turn('msg_u', 'user', hour: 11, blocks: [_blk('bu', 'text', '问题')]),
      ]);
      expect(t.settled.map((n) => n.id), ['msg_u']); // only the terminal one settles 仅终态入 settled
      expect(t.liveTurns.single.id, 'msg_a');
      expect(t.isGenerating, isTrue);

      // The ongoing stream now continues the seeded block — a delta APPENDS (id was seeded, not orphan).
      // 流续写种子块——delta 追加(id 已种、非孤儿)。
      t.applyFrame(_delta('bText', ',现在写完了'));
      final text = t.liveTurns.single.children.single;
      expect(text.displayText, contains('已经写了一半')); // snapshot preserved 快照在
      t.applyFrame(_close('bText', result: {'content': '已经写了一半,现在写完了'}, type: 'text'));
      t.applyFrame(_close('msg_a', result: {'role': 'assistant', 'status': 'completed', 'stopReason': 'end_turn'}, type: 'message'));
      expect(t.isGenerating, isFalse);
      expect(text.displayText, '已经写了一半,现在写完了');
    });
  });

  group('live turn lifecycle', () {
    test('user echo + assistant streaming turn fold in order; isGenerating tracks the open turn', () {
      final t = ConversationTranscript('cv_1')..setHistory(const []);
      t.applyFrame(_open('msg_u', 'message', content: {'role': 'user'}));
      t.applyFrame(_close('msg_u', result: {'role': 'user', 'content': '你好', 'attachmentIds': []}, type: 'message'));
      t.applyFrame(_open('msg_a', 'message', content: {'role': 'assistant'}));
      expect(t.isGenerating, isTrue);
      t.applyFrame(_open('b1', 'text', parentId: 'msg_a', content: {'content': ''}));
      t.applyFrame(_delta('b1', '你'));
      t.applyFrame(_delta('b1', '好!'));
      expect(t.liveTurns.last.children.single.displayText, '你好!');
      t.applyFrame(_close('b1', result: {'content': '你好!'}, type: 'text'));
      t.applyFrame(_close('msg_a', result: {'role': 'assistant', 'status': 'completed', 'stopReason': 'end_turn'}, type: 'message'));
      expect(t.isGenerating, isFalse);
      expect(t.turns.map((n) => n.id), ['msg_u', 'msg_a']);
      expect(ConversationTranscript.turnText(t.turns.first), '你好'); // inline echo text 回声内联文本
    });
  });

  group('optimistic FIFO reconcile', () {
    test('the durable user echo consumes the oldest bubble and inherits its mentions', () {
      final t = ConversationTranscript('cv_1')..setHistory(const []);
      t.addPending(PendingSend(localId: 'l1', text: '让 @bot 跑', mentions: const [
        MentionSnapshot(type: 'agent', id: 'ag_1', name: 'bot'),
      ]));
      expect(t.hasInFlight, isTrue);
      t.applyFrame(_open('msg_u', 'message', content: {'role': 'user'}));
      t.applyFrame(_close('msg_u', result: {'role': 'user', 'content': '让 @bot 跑'}, type: 'message'));
      expect(t.pending, isEmpty); // consumed 已消费
      final mentions = ConversationTranscript.turnMentions(t.turns.single);
      expect(mentions.single.name, 'bot'); // local mentions merged (echo carries none) 本地快照并入
    });

    test('two sends reconcile in order; an EPHEMERAL echo never reconciles', () {
      final t = ConversationTranscript('cv_1')..setHistory(const []);
      t.addPending(PendingSend(localId: 'l1', text: 'a'));
      t.addPending(PendingSend(localId: 'l2', text: 'b'));
      t.applyFrame(_env('msg_x', const FrameDelta(chunk: 'x'), seq: 0)); // ephemeral noise 不对账
      expect(t.pending, hasLength(2));
      t.applyFrame(_open('msg_1', 'message', content: {'role': 'user'}));
      expect(t.pending.map((p) => p.localId), ['l2']); // FIFO: l1 consumed on the durable OPEN
      t.applyFrame(_open('msg_2', 'message', content: {'role': 'user'}));
      expect(t.pending, isEmpty);
      // duplicate close for msg_1 must not consume anything else (already reconciled). 重复帧不再消费。
      t.applyFrame(_close('msg_1', result: {'role': 'user', 'content': 'a'}, type: 'message'));
      expect(t.pending, isEmpty);
    });

    test('failed / discard bookkeeping', () {
      final t = ConversationTranscript('cv_1')..setHistory(const []);
      t.addPending(PendingSend(localId: 'l1', text: 'x'));
      t.markPendingFailed('l1');
      expect(t.pending.single.failed, isTrue);
      expect(t.hasInFlight, isFalse); // a failed bubble no longer pins 失败泡不再钉
      t.removePending('l1');
      expect(t.pending, isEmpty);
    });
  });

  group('resync', () {
    test('dropLive clears the live layer only; a head refetch re-seeds the still-running turn', () {
      final t = ConversationTranscript('cv_1');
      t.setHistory([_turn('msg_u', 'user', hour: 10, blocks: [_blk('bu', 'text', '问')])]);
      t.applyFrame(_open('msg_a', 'message', content: {'role': 'assistant'}));
      t.applyFrame(_open('b1', 'text', parentId: 'msg_a'));
      t.applyFrame(_delta('b1', '半截'));
      expect(t.liveTurns, hasLength(1));

      t.dropLive();
      expect(t.liveTurns, isEmpty);
      expect(t.settled, hasLength(1)); // history intact 史不动

      // The refetched head carries the still-running turn (durable snapshot) → seeded live again.
      // 重拉的头带在飞回合(耐久快照)→ 再种进 live。
      t.setHistory([
        _turn('msg_a', 'assistant', status: 'streaming', hour: 11,
            blocks: [_blk('b1', 'text', '半截(耐久快照)', status: 'open')]),
        _turn('msg_u', 'user', hour: 10, blocks: [_blk('bu', 'text', '问')]),
      ]);
      expect(t.liveTurns.single.id, 'msg_a');
      expect(t.liveTurns.single.children.single.displayText, '半截(耐久快照)');
      expect(t.isGenerating, isTrue);
    });
  });
}
