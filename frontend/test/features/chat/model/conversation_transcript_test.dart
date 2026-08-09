import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
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

StreamEnvelope _open(
  String id,
  String type, {
  String? parentId,
  Map<String, dynamic>? content,
  int seq = 5,
}) => _env(
  id,
  FrameOpen(
    parentId: parentId,
    node: StreamNode(type: type, content: content),
  ),
  seq: seq,
);

StreamEnvelope _delta(String id, String chunk) =>
    _env(id, FrameDelta(chunk: chunk), seq: 0);

StreamEnvelope _close(
  String id, {
  String status = 'completed',
  Map<String, dynamic>? result,
  String? type,
  int seq = 6,
}) => _env(
  id,
  FrameClose(
    status: status,
    result: result == null
        ? null
        : StreamNode(type: type ?? 'x', content: result),
  ),
  seq: seq,
);

ChatMessage _turn(
  String id,
  String role, {
  String status = 'completed',
  String stopReason = '',
  String subagentId = '',
  Map<String, dynamic>? attrs,
  List<ChatBlock> blocks = const [],
  int hour = 10,
}) => ChatMessage(
  id: id,
  conversationId: 'cv_1',
  role: role,
  status: status,
  stopReason: stopReason,
  subagentId: subagentId,
  attrs: attrs,
  blocks: blocks,
  createdAt: DateTime.utc(2026, 7, 2, hour),
);

ChatBlock _blk(
  String id,
  String type,
  String content, {
  String parent = '',
  String status = 'completed',
  Map<String, dynamic>? attrs,
}) => ChatBlock(
  id: id,
  type: type,
  content: content,
  parentBlockId: parent,
  status: status,
  attrs: attrs,
);

void main() {
  group('hydration', () {
    test(
      'setHistory reverses wire order, hydrates terminal turns, excludes subagent rows',
      () {
        final t = ConversationTranscript('cv_1');
        t.setHistory([
          _turn(
            'msg_3',
            'assistant',
            hour: 12,
            blocks: [_blk('b3', 'text', '第二答')],
          ),
          _turn('msg_sub', 'assistant', subagentId: 'sa_1', hour: 11),
          _turn('msg_2', 'user', hour: 11, blocks: [_blk('b2', 'text', '再问')]),
          _turn(
            'msg_1',
            'assistant',
            hour: 10,
            blocks: [_blk('b1', 'text', '首答')],
          ),
        ]);
        expect(t.turns.map((n) => n.id), [
          'msg_1',
          'msg_2',
          'msg_3',
        ]); // chronological, no subagent
        expect(t.isGenerating, isFalse);
      },
    );

    test(
      'user text lives in the child block; attrs snapshots surface via accessors',
      () {
        final node = ConversationTranscript.hydrateTurn(
          _turn(
            'msg_u',
            'user',
            attrs: {
              'attachments': ['att_1'],
              'mentions': [
                {
                  'type': 'function',
                  'id': 'fn_1',
                  'name': 'sync',
                  'content': 'def…',
                },
                {'type': 'agent', 'id': 'ag_1', 'name': '(unavailable)'},
              ],
            },
            blocks: [_blk('b1', 'text', '看下 @sync')],
          ),
        );
        expect(ConversationTranscript.turnText(node), '看下 @sync');
        expect(ConversationTranscript.turnAttachmentIds(node), ['att_1']);
        final mentions = ConversationTranscript.turnMentions(node);
        expect(mentions.first.available, isTrue);
        expect(mentions.last.available, isFalse); // no content key 无 content 键
      },
    );

    test(
      'tool_call hydration reconciles attrs→content (name/arguments); progress keeps its text key',
      () {
        final tc = ConversationTranscript.hydrateBlockContent(
          _blk(
            'b',
            'tool_call',
            '{"q":1}',
            attrs: {'tool': 'web_search', 'danger': 'safe'},
          ),
        );
        expect(tc['name'], 'web_search');
        expect(tc['arguments'], '{"q":1}');
        final pg = ConversationTranscript.hydrateBlockContent(
          _blk('b', 'progress', 'line1\n'),
        );
        expect(pg['text'], 'line1\n');
        expect(pg['content'], isNull);
      },
    );

    test('nested blocks attach by parentBlockId', () {
      final node = ConversationTranscript.hydrateTurn(
        _turn(
          'msg_a',
          'assistant',
          blocks: [
            _blk('call', 'tool_call', '{}', attrs: {'tool': 'x'}),
            _blk('result', 'tool_result', 'ok', parent: 'call'),
          ],
        ),
      );
      expect(node.children.single.id, 'call');
      expect(node.children.single.children.single.id, 'result');
    });

    test('prependOlder inserts above, chronological', () {
      final t = ConversationTranscript('cv_1')
        ..setHistory([_turn('msg_2', 'user', hour: 11)])
        ..prependOlder([
          _turn('msg_1', 'assistant', hour: 9),
          _turn('msg_0', 'user', hour: 8),
        ]);
      expect(t.turns.map((n) => n.id), ['msg_0', 'msg_1', 'msg_2']);
    });
  });

  group('non-terminal seed (the in-flight turn survives a reload)', () {
    test(
      'a pending tail hydrates into the LIVE layer and the stream continues it',
      () {
        final t = ConversationTranscript('cv_1');
        t.setHistory([
          _turn(
            'msg_a',
            'assistant',
            status: 'streaming',
            hour: 12,
            blocks: [_blk('bText', 'text', '已经写了一半', status: 'open')],
          ),
          _turn('msg_u', 'user', hour: 11, blocks: [_blk('bu', 'text', '问题')]),
        ]);
        expect(t.settled.map((n) => n.id), [
          'msg_u',
        ]); // only the terminal one settles 仅终态入 settled
        expect(t.liveTurns.single.id, 'msg_a');
        expect(t.isGenerating, isTrue);

        // The ongoing stream now continues the seeded block — a delta APPENDS (id was seeded, not orphan).
        // 流续写种子块——delta 追加(id 已种、非孤儿)。
        t.applyFrame(_delta('bText', ',现在写完了'));
        final text = t.liveTurns.single.children.single;
        expect(text.displayText, contains('已经写了一半')); // snapshot preserved 快照在
        t.applyFrame(
          _close('bText', result: {'content': '已经写了一半,现在写完了'}, type: 'text'),
        );
        t.applyFrame(
          _close(
            'msg_a',
            result: {
              'role': 'assistant',
              'status': 'completed',
              'stopReason': 'end_turn',
            },
            type: 'message',
          ),
        );
        expect(t.isGenerating, isFalse);
        expect(text.displayText, '已经写了一半,现在写完了');
      },
    );
  });

  group('live turn lifecycle', () {
    test(
      'user echo + assistant streaming turn fold in order; isGenerating tracks the open turn',
      () {
        final t = ConversationTranscript('cv_1')..setHistory(const []);
        t.applyFrame(_open('msg_u', 'message', content: {'role': 'user'}));
        t.applyFrame(
          _close(
            'msg_u',
            result: {'role': 'user', 'content': '你好', 'attachmentIds': []},
            type: 'message',
          ),
        );
        t.applyFrame(_open('msg_a', 'message', content: {'role': 'assistant'}));
        expect(t.isGenerating, isTrue);
        t.applyFrame(
          _open('b1', 'text', parentId: 'msg_a', content: {'content': ''}),
        );
        t.applyFrame(_delta('b1', '你'));
        t.applyFrame(_delta('b1', '好!'));
        expect(t.liveTurns.last.children.single.displayText, '你好!');
        t.applyFrame(_close('b1', result: {'content': '你好!'}, type: 'text'));
        t.applyFrame(
          _close(
            'msg_a',
            result: {
              'role': 'assistant',
              'status': 'completed',
              'stopReason': 'end_turn',
            },
            type: 'message',
          ),
        );
        expect(t.isGenerating, isFalse);
        expect(t.turns.map((n) => n.id), ['msg_u', 'msg_a']);
        expect(
          ConversationTranscript.turnText(t.turns.first),
          '你好',
        ); // inline echo text 回声内联文本
      },
    );
  });

  group('optimistic FIFO reconcile', () {
    test(
      'an accepted REST head consumes a bubble when its SSE echo was missed',
      () {
        final t = ConversationTranscript('cv_1')..setHistory(const []);
        t.addPending(PendingSend(localId: 'l1', text: '首条消息'));

        t.reconcilePendingWithDurableHead([
          _turn('msg_u', 'user', blocks: [_blk('text', 'text', '首条消息')]),
        ]);

        expect(t.pending, isEmpty);
      },
    );

    test(
      'the durable user echo consumes the oldest bubble and inherits its mentions',
      () {
        final t = ConversationTranscript('cv_1')..setHistory(const []);
        t.addPending(
          PendingSend(
            localId: 'l1',
            text: '让 @bot 跑',
            mentions: const [
              MentionSnapshot(type: 'agent', id: 'ag_1', name: 'bot'),
            ],
          ),
        );
        expect(t.hasInFlight, isTrue);
        t.applyFrame(_open('msg_u', 'message', content: {'role': 'user'}));
        t.applyFrame(
          _close(
            'msg_u',
            result: {'role': 'user', 'content': '让 @bot 跑'},
            type: 'message',
          ),
        );
        expect(t.pending, isEmpty); // consumed 已消费
        final mentions = ConversationTranscript.turnMentions(t.turns.single);
        expect(
          mentions.single.name,
          'bot',
        ); // local mentions merged (echo carries none) 本地快照并入
      },
    );

    test(
      'a buffered durable echo already hydrated in settled does not create a live duplicate',
      () {
        final t = ConversationTranscript('cv_1')
          ..addPending(PendingSend(localId: 'l1', text: '首条消息'))
          ..setHistory([
            _turn('msg_u', 'user', blocks: [_blk('text', 'text', '首条消息')]),
          ]);

        // This is the prelude that arrived while REST hydration was in flight.
        t.applyFrame(_open('msg_u', 'message', content: {'role': 'user'}));
        t.applyFrame(
          _close(
            'msg_u',
            result: {'role': 'user', 'content': '首条消息'},
            type: 'message',
          ),
        );

        expect(t.pending, isEmpty);
        expect(t.turns.map((n) => n.id), ['msg_u']);
        expect(t.liveTurns, isEmpty);
      },
    );

    test('two sends reconcile in order; an EPHEMERAL echo never reconciles', () {
      final t = ConversationTranscript('cv_1')..setHistory(const []);
      t.addPending(PendingSend(localId: 'l1', text: 'a'));
      t.addPending(PendingSend(localId: 'l2', text: 'b'));
      t.applyFrame(
        _env('msg_x', const FrameDelta(chunk: 'x'), seq: 0),
      ); // ephemeral noise 不对账
      expect(t.pending, hasLength(2));
      t.applyFrame(_open('msg_1', 'message', content: {'role': 'user'}));
      expect(t.pending.map((p) => p.localId), [
        'l2',
      ]); // FIFO: l1 consumed on the durable OPEN
      t.applyFrame(_open('msg_2', 'message', content: {'role': 'user'}));
      expect(t.pending, isEmpty);
      // duplicate close for msg_1 must not consume anything else (already reconciled). 重复帧不再消费。
      t.applyFrame(
        _close(
          'msg_1',
          result: {'role': 'user', 'content': 'a'},
          type: 'message',
        ),
      );
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

    test(
      'a durable echo SKIPS a leftover failed bubble and reconciles the real in-flight send (M3)',
      () {
        final t = ConversationTranscript('cv_1')..setHistory(const []);
        // send1 failed and is still shown (its retry/discard); send2 is now in flight. send1 失败仍在,send2 在飞。
        t.addPending(PendingSend(localId: 'l1', text: 'send1'));
        t.markPendingFailed('l1');
        t.addPending(PendingSend(localId: 'l2', text: 'send2'));
        // send2's durable echo arrives — it must consume l2 (the real send), NOT the failed l1. send2 回声到。
        t.applyFrame(_open('msg_1', 'message', content: {'role': 'user'}));
        expect(t.pending.map((p) => p.localId), [
          'l1',
        ]); // l2 consumed; the failed l1 survives 失败泡存活
        expect(t.pending.single.failed, isTrue);
        expect(
          t.hasInFlight,
          isFalse,
        ); // only a failed bubble remains → composer NOT pinned in stop 不卡 composer
      },
    );
  });

  group('resync', () {
    test(
      'dropLive clears the live layer only; a head refetch re-seeds the still-running turn',
      () {
        final t = ConversationTranscript('cv_1');
        t.setHistory([
          _turn('msg_u', 'user', hour: 10, blocks: [_blk('bu', 'text', '问')]),
        ]);
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
          _turn(
            'msg_a',
            'assistant',
            status: 'streaming',
            hour: 11,
            blocks: [_blk('b1', 'text', '半截(耐久快照)', status: 'open')],
          ),
          _turn('msg_u', 'user', hour: 10, blocks: [_blk('bu', 'text', '问')]),
        ]);
        expect(t.liveTurns.single.id, 'msg_a');
        expect(t.liveTurns.single.children.single.displayText, '半截(耐久快照)');
        expect(t.isGenerating, isTrue);
      },
    );
  });

  // WRK-064 B6: a subagent run is persisted as a SIBLING sub-message (subagentId ≠ '', attrs.parentBlockId
  // = the spawning Subagent tool_call). The transcript folds each under its tool_call so a settled
  // subagent's nested trajectory rehydrates on the sidestage. Batteries: fold, empty, orphan (cross-page),
  // out-of-order, settle-metadata lift, live-reducer inclusion. subagent 折树。
  group('subagent fold', () {
    // A top-level assistant turn carrying a Subagent tool_call, plus its sibling sub-message (the run's
    // reasoning/tool_call/text). 顶层含 Subagent tool_call + 兄弟子消息。
    List<ChatMessage> thread({
      String parentBlockId = 'call_1',
      int inTok = 0,
      int outTok = 0,
      String stop = '',
    }) => [
      _turn(
        'msg_top',
        'assistant',
        hour: 10,
        blocks: [
          _blk(
            'call_1',
            'tool_call',
            '{"description":"research the spec"}',
            attrs: {'tool': 'Subagent'},
          ),
        ],
      ),
      ChatMessage(
        id: 'msg_sa',
        conversationId: 'cv_1',
        role: 'assistant',
        status: 'completed',
        subagentId: 'sa_1',
        stopReason: stop,
        inputTokens: inTok,
        outputTokens: outTok,
        attrs: {'parentBlockId': parentBlockId},
        blocks: [
          _blk('r1', 'reasoning', '想一想'),
          _blk(
            't1',
            'tool_call',
            '{"pattern":"spec"}',
            attrs: {'tool': 'grep'},
          ),
          _blk('x1', 'text', '找到了'),
        ],
        createdAt: DateTime.utc(2026, 7, 2, 11),
      ),
    ];

    test(
      'folds the sub-message under its Subagent tool_call as a message wrapper (E3 shape)',
      () {
        final t = ConversationTranscript('cv_1');
        t.setHistory(
          thread().reversed.toList(),
        ); // pass in wire order (newest-first)
        // The subagent run is NOT a top-level turn — only msg_top renders. 子运行不作顶层回合。
        expect(t.turns.map((n) => n.id), ['msg_top']);
        // subagentBlocks surfaces the tool_call; its folded child is the sub-run message wrapper.
        final subs = t.subagentBlocks;
        expect(subs, hasLength(1));
        expect(subs.single.id, 'call_1');
        expect(subs.single.name, 'Subagent');
        final wrappers = subs.single.children
            .where((c) => c.kind == BlockKind.message)
            .toList();
        expect(wrappers, hasLength(1)); // the sub-run message wrapper 子运行消息包装
        expect(wrappers.single.children.map((c) => c.kind), [
          BlockKind.reasoning,
          BlockKind.toolCall,
          BlockKind.text,
        ]); // the trajectory 轨迹
      },
    );

    test(
      'empty — a thread with no subagent has no subagent blocks, tops untouched',
      () {
        final t = ConversationTranscript('cv_1');
        t.setHistory([
          _turn('msg_1', 'assistant', blocks: [_blk('b1', 'text', '答')]),
        ]);
        expect(t.subagentBlocks, isEmpty);
        expect(t.turns.map((n) => n.id), ['msg_1']);
      },
    );

    test(
      'orphan — a sub whose parent is not loaded stays pending, then folds when a later page brings it',
      () {
        final t = ConversationTranscript('cv_1');
        // Head page: ONLY the sub-message (its parent tool_call is in an older, not-yet-loaded page).
        t.setHistory([
          _turn(
            'msg_sa',
            'assistant',
            subagentId: 'sa_1',
            hour: 11,
            attrs: {'parentBlockId': 'call_1'},
            blocks: [_blk('x1', 'text', '找到了')],
          ),
        ]);
        expect(
          t.subagentBlocks,
          isEmpty,
        ); // orphan — nothing to fold onto 孤儿,无处可折
        expect(t.turns, isEmpty);
        // An older page brings the spawning turn → the pending sub now folds in. 上翻带来父回合→补折。
        t.prependOlder([
          _turn(
            'msg_top',
            'assistant',
            hour: 10,
            blocks: [
              _blk(
                'call_1',
                'tool_call',
                '{"description":"x"}',
                attrs: {'tool': 'Subagent'},
              ),
            ],
          ),
        ]);
        final subs = t.subagentBlocks;
        expect(subs, hasLength(1));
        expect(
          subs.single.children.where((c) => c.kind == BlockKind.message),
          hasLength(1),
        );
      },
    );

    test(
      'lifts the sub-run settle metadata (tokens / stopReason) onto the tool_call for the settle line',
      () {
        final t = ConversationTranscript('cv_1');
        t.setHistory(
          thread(inTok: 120, outTok: 45, stop: 'max_tokens').reversed.toList(),
        );
        final call = t.subagentBlocks.single;
        expect(call.content?['tokens'], {'in': 120, 'out': 45});
        expect(call.content?['stopReason'], 'max_tokens');
      },
    );

    test('a fold never double-applies across re-fold passes (idempotent)', () {
      final t = ConversationTranscript('cv_1');
      t.setHistory(thread().reversed.toList());
      // A later older page (no new subagent) re-runs the fold — the already-folded sub must not duplicate.
      t.prependOlder([
        _turn('msg_old', 'user', hour: 9, blocks: [_blk('bo', 'text', '早问')]),
      ]);
      final wrappers = t.subagentBlocks.single.children.where(
        (c) => c.kind == BlockKind.message,
      );
      expect(wrappers, hasLength(1)); // still exactly one wrapper 仍恰一个包装
    });

    test(
      'a LIVE subagent tool_call (open, in the live reducer) is surfaced too',
      () {
        final t = ConversationTranscript('cv_1');
        t.applyFrame(_open('msg_a', 'message', content: {'role': 'assistant'}));
        t.applyFrame(
          _open(
            'call_live',
            'tool_call',
            parentId: 'msg_a',
            content: {'name': 'Subagent'},
          ),
        );
        final subs = t.subagentBlocks;
        expect(subs, hasLength(1));
        expect(subs.single.id, 'call_live');
        expect(subs.single.isOpen, isTrue); // still streaming 仍在流
      },
    );
  });

  group('subagentEpoch (S7 — per-frame consumers compare one int)', () {
    test('streaming deltas NEVER bump the epoch; Subagent open/close do', () {
      final t = ConversationTranscript('cv_1');
      t.applyFrame(_open('msg_a', 'message', content: {'role': 'assistant'}));
      t.applyFrame(
        _open('b1', 'text', parentId: 'msg_a', content: {'content': ''}),
      );
      final base = t.subagentEpoch;

      // The token firehose — the hot path that must stay O(1). token 火喉,必须 O(1)。
      for (var i = 0; i < 50; i++) {
        t.applyFrame(_delta('b1', 'chunk $i'));
      }
      expect(t.subagentEpoch, base, reason: 'deltas must not bump');

      t.applyFrame(
        _open(
          'sub1',
          'tool_call',
          parentId: 'msg_a',
          content: {'name': 'Subagent'},
        ),
      );
      expect(t.subagentEpoch, greaterThan(base), reason: 'Subagent open bumps');

      final afterOpen = t.subagentEpoch;
      t.applyFrame(_delta('sub1', 'thinking…'));
      expect(t.subagentEpoch, afterOpen, reason: 'subagent deltas still free');

      t.applyFrame(_close('sub1'));
      expect(
        t.subagentEpoch,
        greaterThan(afterOpen),
        reason: 'the open→closed flip changes the activity/accordion answer',
      );
    });

    test('a non-Subagent tool_call is structurally irrelevant — no bump', () {
      final t = ConversationTranscript('cv_1');
      t.applyFrame(_open('msg_a', 'message', content: {'role': 'assistant'}));
      final base = t.subagentEpoch;
      t.applyFrame(
        _open('tc1', 'tool_call', parentId: 'msg_a', content: {'name': 'Read'}),
      );
      t.applyFrame(_close('tc1'));
      expect(t.subagentEpoch, base);
    });

    test('settled window turnover and a live drop both bump', () {
      final t = ConversationTranscript('cv_1');
      final base = t.subagentEpoch;
      t.setHistory(const []);
      expect(t.subagentEpoch, greaterThan(base), reason: 'page load bumps');
      final afterHistory = t.subagentEpoch;
      t.dropLive();
      expect(
        t.subagentEpoch,
        greaterThan(afterHistory),
        reason: '410 resync drops live subagents',
      );
    });

    test(
      'subagentBlocks is memoized by epoch — identical list across frames',
      () {
        final t = ConversationTranscript('cv_1');
        t.applyFrame(_open('msg_a', 'message', content: {'role': 'assistant'}));
        t.applyFrame(
          _open(
            'sub1',
            'tool_call',
            parentId: 'msg_a',
            content: {'name': 'Subagent'},
          ),
        );
        final first = t.subagentBlocks;
        expect(first.single.id, 'sub1');

        t.applyFrame(_delta('sub1', 'chunk'));
        expect(
          identical(t.subagentBlocks, first),
          isTrue,
          reason: 'no structural change → the cached list, zero walk',
        );

        t.applyFrame(_close('sub1'));
        expect(identical(t.subagentBlocks, first), isFalse);
      },
    );
  });
  // ── version groups (WRK-077 CH-c) 版本组 ──

  group('version groups', () {
    // The list the transcript renders is a list of GROUPS, so this is the function that decides whether a
    // retried round reads as one turn with a pager or as the same question answered twice.
    // transcript 渲的是一个**组**的列表,故这个函数决定了一个被重试过的回合读起来是「一个回合 + 翻页」还是「同一个问题
    // 被答了两遍」。
    List<BlockNode> nodes(List<ChatMessage> rows) => [
      for (final m in rows) ConversationTranscript.hydrateTurn(m),
    ];

    test('a thread nobody retried is one group per turn, in order', () {
      final groups = ConversationTranscript.groupVersions(
        nodes([
          _turn('m1', 'user', blocks: [_blk('b1', 'text', 'ask')]),
          _turn('m2', 'assistant', blocks: [_blk('b2', 'text', 'reply')]),
        ]),
      );
      expect(groups.length, 2);
      expect(groups.every((g) => g.count == 1), isTrue);
      expect(groups.first.root.id, 'm1');
      expect(groups.last.current.id, 'm2');
    });

    test('a retry chain collapses into ONE group, oldest → newest', () {
      final groups = ConversationTranscript.groupVersions(
        nodes([
          _turn('m1', 'user', blocks: [_blk('b1', 'text', 'ask')]),
          _turn('m2', 'assistant', blocks: [_blk('b2', 'text', 'v1')]),
          _turn(
            'm3',
            'assistant',
            attrs: const {'retryOf': 'm2'},
            blocks: [_blk('b3', 'text', 'v2')],
          ),
          _turn(
            'm4',
            'assistant',
            attrs: const {'retryOf': 'm3'},
            blocks: [_blk('b4', 'text', 'v3')],
          ),
        ]),
      );
      expect(groups.length, 2, reason: 'the question + ONE answer group');
      final answers = groups.last;
      expect(answers.versions.map((n) => n.id), ['m2', 'm3', 'm4']);
      expect(answers.root.id, 'm2');
      expect(
        answers.current.id,
        'm4',
        reason: 'the last link is what the thread continued from',
      );
      expect(answers.at(99).id, 'm4', reason: 'a stale index clamps');
      expect(answers.at(-1).id, 'm2');
    });

    test(
      'an edit-resend groups the QUESTION too, and the two groups stay separate',
      () {
        final groups = ConversationTranscript.groupVersions(
          nodes([
            _turn('m1', 'user', blocks: [_blk('b1', 'text', 'old ask')]),
            _turn('m2', 'assistant', blocks: [_blk('b2', 'text', 'old reply')]),
            _turn(
              'm3',
              'user',
              attrs: const {'retryOf': 'm1'},
              blocks: [_blk('b3', 'text', 'new ask')],
            ),
            _turn(
              'm4',
              'assistant',
              attrs: const {'retryOf': 'm2'},
              blocks: [_blk('b4', 'text', 'new reply')],
            ),
          ]),
        );
        // Two groups of two, each at its ROOT's position — so the question still comes before the answer, and a
        // resend does not shove the round to the bottom of the transcript.
        // 两个各含两版的组,各自在其**根**的位置——故问句仍在回答之前,重发不会把这一轮推到 transcript 底部。
        expect(groups.length, 2);
        expect(groups.first.versions.map((n) => n.id), ['m1', 'm3']);
        expect(groups.last.versions.map((n) => n.id), ['m2', 'm4']);
      },
    );

    test('a live retry open frame joins its version group before close arrives', () {
      // The backend publishes the version pointer on message open as well as close. The transcript must
      // classify the new live turn immediately, so the reader never sees a duplicate round during the
      // short interval before its durable close snapshot arrives.
      // 后端在 message open 与 close 都发布版本指针。transcript 必须立即归组，不能在 durable close 到达前的短窗口
      // 把同一回合渲成重复的新轮次。
      final old = ConversationTranscript.hydrateTurn(
        _turn('m1', 'user', blocks: [_blk('b1', 'text', 'old ask')]),
      );
      final liveOpen = BlockNode(id: 'm2', kind: BlockKind.message)
        ..content = {'role': 'user', 'retryOf': 'm1'};

      final groups = ConversationTranscript.groupVersions([old, liveOpen]);

      expect(groups.length, 1);
      expect(groups.single.versions.map((n) => n.id), ['m1', 'm2']);
      expect(groups.single.current.id, 'm2');
    });

    test('a version whose predecessor is not loaded becomes its own root', () {
      // The paged reality: a `?around=` window can hold v2 without v1. Grouping must describe what IS loaded
      // (a group of one) rather than drop the row or dangle at a node it does not have.
      // 分页的现实:一扇 `?around=` 窗可能有 v2 而没有 v1。分组必须描述**已加载的东西**(一个单成员组),而不是丢掉这行
      // 或悬空指向一个它没有的节点。
      final groups = ConversationTranscript.groupVersions(
        nodes([
          _turn(
            'm3',
            'assistant',
            attrs: const {'retryOf': 'm2'},
            blocks: [_blk('b3', 'text', 'v2')],
          ),
        ]),
      );
      expect(groups.length, 1);
      expect(groups.single.count, 1);
      expect(groups.single.current.id, 'm3');
    });

    test(
      'every input turn appears in exactly one group, even with a pointer cycle',
      () {
        // The backend cannot mint a cycle; a corrupted/garbage attrs pair could. Terminating on the visited set
        // matters because the alternative is an infinite walk inside a build.
        // 后端造不出环;一对损坏/垃圾 attrs 可能。在 visited 集上终止之所以重要,是因为另一种结果是 build 里的无限走查。
        final rows = nodes([
          _turn(
            'm1',
            'assistant',
            attrs: const {'retryOf': 'm2'},
            blocks: [_blk('b1', 'text', 'a')],
          ),
          _turn(
            'm2',
            'assistant',
            attrs: const {'retryOf': 'm1'},
            blocks: [_blk('b2', 'text', 'b')],
          ),
        ]);
        final groups = ConversationTranscript.groupVersions(rows);
        final seen = <String>{};
        for (final g in groups) {
          for (final v in g.versions) {
            expect(seen.add(v.id), isTrue, reason: 'no turn is rendered twice');
          }
        }
        expect(seen, {'m1', 'm2'});
      },
    );
  });
}
