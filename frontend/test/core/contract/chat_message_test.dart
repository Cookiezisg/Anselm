import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

// The REST message/block wire contract — field names verified against the backend's json tags
// (messages.go). Pins: full decode, omitted-optional defaults, attrs snapshots (attachments id array +
// mention snapshots incl. the "(unavailable)" stub WITHOUT a content key), block nesting order.
// REST 消息/块契约(字段逐字核对后端 json tag)。钉:全量解码、缺省默认、attrs 快照(附件 id 数组 + 提及快照含
// 无 content 键的 "(unavailable)" stub)、块序。

void main() {
  test('decodes a full assistant terminal turn', () {
    final m = ChatMessage.fromJson({
      'id': 'msg_1',
      'conversationId': 'cv_1',
      'role': 'assistant',
      'status': 'completed',
      'stopReason': 'end_turn',
      'inputTokens': 120,
      'outputTokens': 456,
      'provider': 'anselm',
      'modelId': 'deepseek-chat',
      'createdAt': '2026-07-02T10:00:00Z',
      'updatedAt': '2026-07-02T10:00:30Z',
      'blocks': [
        {
          'id': 'blk_1', 'conversationId': 'cv_1', 'messageId': 'msg_1', 'seq': 3,
          'type': 'reasoning', 'content': '想想…', 'status': 'completed',
          'createdAt': '2026-07-02T10:00:01Z', 'updatedAt': '2026-07-02T10:00:02Z',
        },
        {
          'id': 'blk_2', 'conversationId': 'cv_1', 'messageId': 'msg_1', 'seq': 4,
          'type': 'text', 'content': '答案。', 'status': 'completed',
          'createdAt': '2026-07-02T10:00:02Z', 'updatedAt': '2026-07-02T10:00:03Z',
        },
      ],
    });
    expect(m.role, 'assistant');
    expect(m.stopReason, 'end_turn');
    expect(m.outputTokens, 456);
    expect(m.blocks.map((b) => b.type), ['reasoning', 'text']); // wire order preserved 保序
    expect(m.blocks.first.seq, 3);
    expect(m.errorCode, ''); // omitted optional → default 缺省默认
    expect(m.subagentId, '');
  });

  test('decodes a user turn with frozen attachment + mention snapshots (incl. unavailable stub)', () {
    final m = ChatMessage.fromJson({
      'id': 'msg_2', 'conversationId': 'cv_1', 'role': 'user', 'status': 'completed',
      'createdAt': '2026-07-02T10:00:00Z', 'updatedAt': '2026-07-02T10:00:00Z',
      'attrs': {
        'attachments': ['att_1', 'att_2'],
        'mentions': [
          {'type': 'function', 'id': 'fn_1', 'name': 'sync_inventory', 'content': 'def …'},
          {'type': 'agent', 'id': 'ag_9', 'name': '(unavailable)'}, // no content key 无 content 键
        ],
      },
    });
    expect((m.attrs?['attachments'] as List).cast<String>(), ['att_1', 'att_2']);
    final mentions = (m.attrs?['mentions'] as List).cast<Map<String, dynamic>>();
    expect(mentions.first['name'], 'sync_inventory');
    expect(mentions.last.containsKey('content'), isFalse); // availability signal 可用性信号
    expect(m.blocks, isEmpty); // user echo may carry no blocks 用户回合可无块
  });

  test('unknown wire keys are ignored; parentBlockId nests', () {
    final b = ChatBlock.fromJson({
      'id': 'blk_9', 'type': 'tool_call', 'parentBlockId': 'blk_root', 'seq': 9,
      'attrs': {'tool': 'web_search', 'danger': 'safe'},
      'contextRole': 'hot', 'someFutureKey': 42,
      'createdAt': '2026-07-02T10:00:00Z', 'updatedAt': '2026-07-02T10:00:00Z',
    });
    expect(b.parentBlockId, 'blk_root');
    expect(b.attrs?['tool'], 'web_search');
  });
}
