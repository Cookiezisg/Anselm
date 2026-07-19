import 'package:anselm/core/contract/interaction.dart';
import 'package:flutter_test/flutter_test.dart';

// The wire contract for the human-loop interaction payload (WRK-057 census §10.5). These JSON shapes
// are exactly what the `interaction` signal's node.content and a `GET interactions` row carry — the
// parser must handle both variants + the empty-field resolution signal.
// 人在环交互 payload 的线缆契约。以下 JSON 即信号 content 与 GET 一行的精确形状。

void main() {
  test('danger variant: prompt = {summary, args (cleaned)}', () {
    final it = Interaction.fromJson({
      'toolCallId': 'blk_1',
      'kind': 'danger',
      'tool': 'Bash',
      'conversationId': 'conv_1',
      'prompt': {
        'summary': 'delete the temp dir',
        'args': {'command': 'rm -rf /tmp/x'},
      },
    });
    expect(it.toolCallId, 'blk_1');
    expect(it.kind, InteractionKind.danger);
    expect(it.tool, 'Bash');
    expect(it.resolved, isFalse);
    expect(it.isAwaiting, isTrue);
    expect(it.summary, 'delete the temp dir');
    expect(it.args, {'command': 'rm -rf /tmp/x'});
    expect(it.message, isNull);
    expect(it.options, isNull);
  });

  test('ask variant: prompt = {message, options}', () {
    final it = Interaction.fromJson({
      'toolCallId': 'blk_2',
      'kind': 'ask',
      'tool': 'ask_user',
      'conversationId': 'conv_1',
      'prompt': {
        'message': 'Which day works?',
        'options': ['Mon', 'Tue', 'Wed'],
      },
    });
    expect(it.kind, InteractionKind.ask);
    expect(it.message, 'Which day works?');
    expect(it.options, ['Mon', 'Tue', 'Wed']);
    expect(it.summary, isNull);
    expect(it.isAwaiting, isTrue);
  });

  test('ask with no options → free-text only (options null, not empty list)', () {
    final it = Interaction.fromJson({
      'toolCallId': 'blk_3',
      'kind': 'ask',
      'tool': 'ask_user',
      'prompt': {'message': 'Describe the bug.'},
    });
    expect(it.kind, InteractionKind.ask);
    expect(it.message, 'Describe the bug.');
    expect(it.options, isNull);
  });

  test('resolution signal: resolved:true with EMPTY kind/tool (no omitempty) → unknown, not awaiting', () {
    // The census correction: Request.Kind/Tool have no omitempty, so the resolution signal carries
    // them as empty strings. Resolution MUST key on `resolved`, never on kind/tool absence.
    final it = Interaction.fromJson({
      'toolCallId': 'blk_1',
      'kind': '',
      'tool': '',
      'conversationId': 'conv_1',
      'resolved': true,
    });
    expect(it.resolved, isTrue);
    expect(it.kind, InteractionKind.unknown);
    expect(it.tool, '');
    expect(it.isAwaiting, isFalse);
  });

  test('forward-compat: an unrecognized kind degrades to unknown, never crashes', () {
    final it = Interaction.fromJson({'toolCallId': 'blk_9', 'kind': 'future_kind'});
    expect(it.kind, InteractionKind.unknown);
    expect(it.isAwaiting, isFalse); // unknown is never awaiting (only danger/ask gate the user)
  });

  test('action wire tokens are the exact closed set', () {
    expect(InteractionAction.approve.wire, 'approve');
    expect(InteractionAction.approveAlways.wire, 'approve_always');
    expect(InteractionAction.deny.wire, 'deny');
    expect(InteractionAction.accept.wire, 'accept');
    expect(InteractionAction.decline.wire, 'decline');
  });
}
