import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 5 gate (pure model) — the BlockTreeReducer folds open/delta/close into a nested tree: live deltas
// before close, the close snapshot wins, E3 parentId nesting, danger/args on tool_call, and defensive
// handling of unknown types / orphan frames / signals (no throw, no spurious node).

const _scope = StreamScope(kind: 'agent', id: 'a');

StreamEnvelope _open(String id, String type, {String? parent, Map<String, dynamic>? content}) =>
    StreamEnvelope(seq: 1, scope: _scope, id: id, frame: FrameOpen(parentId: parent, node: StreamNode(type: type, content: content)));
StreamEnvelope _delta(String id, String chunk) =>
    StreamEnvelope(seq: 0, scope: _scope, id: id, frame: FrameDelta(chunk: chunk));
StreamEnvelope _close(String id, String type, Map<String, dynamic> content) =>
    StreamEnvelope(seq: 2, scope: _scope, id: id, frame: FrameClose(status: 'completed', result: StreamNode(type: type, content: content)));
StreamEnvelope _closeBare(String id, {String status = 'completed', String? error}) =>
    StreamEnvelope(seq: 2, scope: _scope, id: id, frame: FrameClose(status: status, error: error));

void main() {
  test('open→delta→close: live deltas before close, snapshot wins after', () {
    final r = BlockTreeReducer();
    r.apply(_open('b1', 'text'));
    r.apply(_delta('b1', 'Hel'));
    r.apply(_delta('b1', 'lo'));
    expect(r.roots.single.displayText, 'Hello'); // live deltas
    r.apply(_close('b1', 'text', {'content': 'Hello world'}));
    expect(r.roots.single.kind, BlockKind.text);
    expect(r.roots.single.displayText, 'Hello world'); // durable snapshot wins
    expect(r.roots.single.status, 'completed');
  });

  test('tool_result nests under its tool_call (E3 parentId)', () {
    final r = BlockTreeReducer();
    r.apply(_open('tc', 'tool_call', content: {'name': 'web-search'}));
    r.apply(_open('tr', 'tool_result', parent: 'tc', content: {'content': '3 hits'}));
    r.apply(_closeBare('tr'));
    expect(r.roots.length, 1); // only the tool_call is a root
    final tc = r.roots.single;
    expect(tc.kind, BlockKind.toolCall);
    expect(tc.name, 'web-search');
    expect(tc.children.single.kind, BlockKind.toolResult);
    expect(tc.children.single.displayText, '3 hits');
  });

  test('tool_call carries danger + the final arguments snapshot', () {
    final r = BlockTreeReducer();
    r.apply(_open('tc', 'tool_call', content: {'name': 'rm'}));
    r.apply(_delta('tc', '{"path"'));
    r.apply(_close('tc', 'tool_call', {'name': 'rm', 'arguments': '{"path":"/"}', 'danger': 'dangerous'}));
    final tc = r.roots.single;
    expect(tc.danger, 'dangerous');
    expect(tc.argumentsText, '{"path":"/"}');
  });

  test('unknown node type → BlockKind.unknown (forward-compat, no throw)', () {
    final r = BlockTreeReducer();
    r.apply(_open('x', 'some_future_type'));
    expect(r.roots.single.kind, BlockKind.unknown);
  });

  test('orphan delta/close for an unseen id is a no-op', () {
    final r = BlockTreeReducer();
    r.apply(_delta('ghost', 'x'));
    r.apply(_closeBare('ghost'));
    expect(r.isEmpty, isTrue);
  });

  test('a signal builds no tree node', () {
    final r = BlockTreeReducer();
    r.apply(StreamEnvelope(
        seq: 0,
        scope: const StreamScope(kind: 'workflow'),
        id: 's',
        frame: const FrameSignal(node: StreamNode(type: 'run', content: {'nodeId': 'n1'}))));
    expect(r.isEmpty, isTrue);
  });

  test('open with an unseen parent attaches to roots (defensive)', () {
    final r = BlockTreeReducer();
    r.apply(_open('child', 'text', parent: 'missing'));
    expect(r.roots.single.id, 'child');
  });

  test('error close marks isError + carries the error', () {
    final r = BlockTreeReducer();
    r.apply(_open('tr', 'tool_result', content: {'content': ''}));
    r.apply(_closeBare('tr', status: 'error', error: 'boom'));
    expect(r.roots.single.isError, isTrue);
    expect(r.roots.single.error, 'boom');
  });

  test('re-open of the same id is idempotent (no duplicate node)', () {
    final r = BlockTreeReducer();
    r.apply(_open('b1', 'text'));
    r.apply(_open('b1', 'text'));
    expect(r.roots.length, 1);
    expect(r.nodeCount, 1);
  });
}
